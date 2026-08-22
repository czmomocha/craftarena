class_name TraprushGrayboxCourse
extends RefCounted

## TRAPRUSH 单人灰盒跑道夹具：组装检查点、上下/侧向传送、墙盒、可破坏箱、周期 hazard。
## 依据 CD-21 §4.2 / §5.2 / §8 与 CD-61 M1 灰盒：有序检查点、传送不得跳点、破坏后开路、1 个周期障碍 stub。
## 灰盒检查点垫走 PadAccept / CD-21 §8：完成由占用判定，客户端不得断言。
## 终点垫走 FinishAccept：冲线由占用 + 全部强制检查点完成判定；无 FinishIntent（CD-21 §6 / §8）。
## finish_tick 是权威 world.tick_index，未冲线哨兵为 -1；不写入 SimulationWorld.hash_state。
## 位移、jump_dy、support_dy、fall_dy、范围边界、max_hops、max_health、period、snapshot capacity 均由调用方传入，不锁定 Tick/快照 Hz、重力或掉出次数 N（CD-63）。
## 成功 PLAYER 意图写入 SimReplayBuffer（CD-43 命令日志 + 种子）。成功的 place_pose / 检查点 / 落地传送 / 冲线 / 出界复位 / try_break_crate / try_commit_tick / try_apply_fall 写入 SYSTEM 记录（actor_id = 0），不是 FinishIntent。
## assemble 记录 tick 0 关键快照；layout 可选 shove_target 时在盒之后再生成第二胶囊，缺省 shove_target_id = 0。try_commit_tick(fall_dy) 先内部下落（不经 try_apply_fall），成功后再推进 tick、按调用方周期切换 hazard 阻挡、再 record，成功入 SYSTEM 带。
## try_step_intent(payload, jump_dy, support_dy) 把 support_dy 传给 apply；Jump 走直到阻挡；成功 PLAYER 意图入带。Shove 不经 IntentStepper。
## try_shove(payload, cooldown_ticks, dx, dz) 委托 ShoveApply；dx/dz/冷却由调用方传入，不从 payload 读 impulse。ok 则 PLAYER 入带；shoved 才更新 last_shove_tick。无目标、解码失败不入带。不 tick。
## try_apply_fall(fall_dy) 只调用 world.try_move_y_until_blocked；成功入 SYSTEM 带，不 tick、不 record。
## try_reset_if_out_of_range 用已合入的只读范围查询；出界则 set_pose 到最近检查点复活落点（CD-21 §6），成功复位入 SYSTEM 带，不 tick，不计数 N。
## try_interact / try_use_item / 成功 try_shove 入 PLAYER 带；try_place_pose / 成功检查点 / 成功落地传送 / 首次冲线 / 成功出界复位 / 成功 try_break_crate / 成功 try_commit_tick / 成功 try_apply_fall 入 SYSTEM 带。world.set_pose 仍不入带。
## try_interact 仅在 overlapping_static_boxes 含 crate 时按调用方 damage 走 Destructible；摧毁则关闭 crate 盒阻挡。
## try_use_item 用当前姿态加调用方 reach 得到候选坐标，overlapping_static_boxes_at 含 crate 时才伤害；伤害与 reach 不从 payload 读取。
## try_break_crate 保持测试入口：不要求重叠；成功伤害入 SYSTEM 带。
## 整段 M1 切片（检查点、传送、周期窗口、爆破开路、冲线）由 TraprushGrayboxAcceptance.try_run 编排；本夹具不发明寻路。Acceptance 仍不含推击。
## 不从客户端 Dictionary 读最终位置、障碍死亡、道具命中、冲线结果或完成标志；不实现道具栏、2p、名次或 Headless。

const IntentStepper := preload("res://src/games/traprush/intent_stepper.gd")
const InteractIntent := preload("res://src/games/traprush/interact_intent.gd")
const UseItemIntent := preload("res://src/games/traprush/use_item_intent.gd")
const PortalLanding := preload("res://src/games/traprush/portal_landing.gd")
const PortalGraph := preload("res://src/games/traprush/portal_graph.gd")
const PortalLink := preload("res://src/games/traprush/portal_link.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const Destructible := preload("res://src/games/traprush/destructible.gd")
const PadAccept := preload("res://src/games/traprush/pad_accept.gd")
const FinishAccept := preload("res://src/games/traprush/finish_accept.gd")
const ShoveApply := preload("res://src/games/traprush/shove_apply.gd")
const SystemOps := preload("res://src/games/traprush/graybox_system_ops.gd")

var world: SimulationWorld = null
var entity_id: int = 0
var track: TraprushCheckpointTrack = null
var wall_box_id: int = 0
var crate_box_id: int = 0
var hazard_box_id: int = 0
var finish_box_id: int = 0
var finish_tick: int = -1
var shove_target_id: int = 0
var crate: TraprushDestructible = null
var pad_box_ids: Array[int] = []
var tape: SimReplayBuffer = null
var snapshots: SimSnapshotRing = null

var _spawn: TraprushCheckpointSpawn = null
var _graph: TraprushPortalGraph = null
var _checkpoint_ids: Array[int] = []
var _actor_id: int = 0
var _content_version: String = ""
var _trace_id: String = ""
var _next_command_seq: int = 1
var _hazard_period_ticks: int = 0
var _last_shove_tick: int = -1


static func assemble(layout: Dictionary) -> TraprushGrayboxCourse:
	var seed_read: Dictionary = _require_int(layout, "seed")
	var start_x_read: Dictionary = _require_int(layout, "start_x")
	var start_y_read: Dictionary = _require_int(layout, "start_y")
	var start_z_read: Dictionary = _require_int(layout, "start_z")
	var start_yaw_read: Dictionary = _require_int(layout, "start_yaw")
	var radius_read: Dictionary = _require_int(layout, "radius")
	var height_read: Dictionary = _require_int(layout, "cylinder_height")
	var health_read: Dictionary = _require_int(layout, "crate_max_health")
	var wall_read: Dictionary = _require_box(layout, "wall")
	var crate_box_read: Dictionary = _require_box(layout, "crate")
	var ids_read: Dictionary = _require_id_array(layout, "checkpoint_ids")
	var pads_read: Dictionary = _require_box_list(layout, "checkpoint_pads")
	var spawn_start_read: Dictionary = _require_named_pose(layout, "spawn_start")
	var poses_read: Dictionary = _require_pose_list(layout, "checkpoint_poses")
	var up_read: Dictionary = _require_portal(layout, "up_portal")
	var side_read: Dictionary = _require_portal(layout, "side_portal")
	var actor_read: Dictionary = _require_actor_id(layout)
	var version_read: Dictionary = _require_nonempty_string(layout, "content_version")
	var trace_read: Dictionary = _require_nonempty_string(layout, "trace_id")
	var capacity_read: Dictionary = _require_int(layout, "snapshot_capacity")
	var hazard_read: Dictionary = _require_box(layout, "hazard")
	var period_read: Dictionary = _require_int(layout, "hazard_period_ticks")
	var finish_read: Dictionary = _require_box(layout, "finish")
	if (
		not _flag(seed_read)
		or not _flag(start_x_read)
		or not _flag(start_y_read)
		or not _flag(start_z_read)
		or not _flag(start_yaw_read)
		or not _flag(radius_read)
		or not _flag(height_read)
		or not _flag(health_read)
		or not _flag(wall_read)
		or not _flag(crate_box_read)
		or not _flag(ids_read)
		or not _flag(pads_read)
		or not _flag(spawn_start_read)
		or not _flag(poses_read)
		or not _flag(up_read)
		or not _flag(side_read)
		or not _flag(actor_read)
		or not _flag(version_read)
		or not _flag(trace_read)
		or not _flag(capacity_read)
		or not _flag(hazard_read)
		or not _flag(period_read)
		or not _flag(finish_read)
	):
		return null
	var hazard_period_ticks: int = _value(period_read)
	if hazard_period_ticks < 1:
		return null
	var ring: SimSnapshotRing = SimSnapshotRing.create(_value(capacity_read))
	if ring == null:
		return null
	var crate_max_health: int = _value(health_read)
	var crate_obj: TraprushDestructible = Destructible.create(crate_max_health)
	if crate_obj == null:
		return null
	var ids: Array[int] = _ids_from(ids_read)
	var pad_boxes: Array[Dictionary] = _boxes_from(pads_read)
	if pad_boxes.size() != ids.size():
		return null
	var spawn_start: Dictionary = _pose_from(spawn_start_read)
	var checkpoint_poses: Array[Dictionary] = _poses_from(poses_read)
	var spawn: TraprushCheckpointSpawn = CheckpointSpawn.new(spawn_start, checkpoint_poses)
	var sim: SimulationWorld = SimulationWorld.new(_value(seed_read))
	var spawned_id: int = sim.spawn_capsule(
		_value(start_x_read),
		_value(start_y_read),
		_value(start_z_read),
		_value(start_yaw_read),
		_value(radius_read),
		_value(height_read)
	)
	if spawned_id < 1:
		return null
	var wall_id: int = sim.spawn_static_box(
		_int_at(wall_read, "x"),
		_int_at(wall_read, "y"),
		_int_at(wall_read, "z"),
		_int_at(wall_read, "half_x"),
		_int_at(wall_read, "half_y"),
		_int_at(wall_read, "half_z")
	)
	if wall_id < 1:
		return null
	var crate_id: int = sim.spawn_static_box(
		_int_at(crate_box_read, "x"),
		_int_at(crate_box_read, "y"),
		_int_at(crate_box_read, "z"),
		_int_at(crate_box_read, "half_x"),
		_int_at(crate_box_read, "half_y"),
		_int_at(crate_box_read, "half_z")
	)
	if crate_id < 1:
		return null
	var hazard_id: int = sim.spawn_static_box(
		_int_at(hazard_read, "x"),
		_int_at(hazard_read, "y"),
		_int_at(hazard_read, "z"),
		_int_at(hazard_read, "half_x"),
		_int_at(hazard_read, "half_y"),
		_int_at(hazard_read, "half_z")
	)
	if hazard_id < 1:
		return null
	var spawned_pad_ids: Array[int] = []
	spawned_pad_ids.resize(pad_boxes.size())
	for pad_index: int in range(pad_boxes.size()):
		var pad: Dictionary = pad_boxes[pad_index]
		var pad_id: int = sim.spawn_static_box(
			_int_at(pad, "x"),
			_int_at(pad, "y"),
			_int_at(pad, "z"),
			_int_at(pad, "half_x"),
			_int_at(pad, "half_y"),
			_int_at(pad, "half_z")
		)
		if pad_id < 1:
			return null
		if not sim.set_static_box_solid(pad_id, false):
			return null
		spawned_pad_ids[pad_index] = pad_id
	var finish_id: int = sim.spawn_static_box(
		_int_at(finish_read, "x"),
		_int_at(finish_read, "y"),
		_int_at(finish_read, "z"),
		_int_at(finish_read, "half_x"),
		_int_at(finish_read, "half_y"),
		_int_at(finish_read, "half_z")
	)
	if finish_id < 1:
		return null
	if not sim.set_static_box_solid(finish_id, false):
		return null
	var shove_target_id: int = 0
	if layout.has("shove_target"):
		var shove_pose_read: Dictionary = _require_named_pose(layout, "shove_target")
		if not _flag(shove_pose_read):
			return null
		var dummy_id: int = sim.spawn_capsule(
			_int_at(shove_pose_read, "x"),
			_int_at(shove_pose_read, "y"),
			_int_at(shove_pose_read, "z"),
			_int_at(shove_pose_read, "yaw_bam"),
			_value(radius_read),
			_value(height_read)
		)
		if dummy_id < 1:
			return null
		shove_target_id = dummy_id
	var graph: TraprushPortalGraph = PortalGraph.new()
	if not graph.add_link(_portal_from(up_read)):
		return null
	if not graph.add_link(_portal_from(side_read)):
		return null
	var course: TraprushGrayboxCourse = TraprushGrayboxCourse.new()
	course.world = sim
	course.entity_id = spawned_id
	course.track = CheckpointTrack.from_int_array(ids)
	course.wall_box_id = wall_id
	course.crate_box_id = crate_id
	course.hazard_box_id = hazard_id
	course.finish_box_id = finish_id
	course.finish_tick = -1
	course.shove_target_id = shove_target_id
	course.crate = crate_obj
	course.pad_box_ids = spawned_pad_ids
	course._spawn = spawn
	course._graph = graph
	course._checkpoint_ids = ids
	course.tape = SimReplayBuffer.new(_value(seed_read))
	course.snapshots = ring
	course._actor_id = _value(actor_read)
	course._content_version = _text(version_read)
	course._trace_id = _text(trace_read)
	course._next_command_seq = 1
	course._hazard_period_ticks = hazard_period_ticks
	if not course.snapshots.record(course.world):
		return null
	return course


func try_step_intent(payload: Dictionary, jump_dy: int, support_dy: int) -> Dictionary:
	var result: Dictionary = IntentStepper.apply(
		world, entity_id, payload, jump_dy, _spawn, track, support_dy
	)
	if not _flag(result):
		return result
	_append_command(payload, SharedCommand.Kind.PLAYER)
	return result


func try_shove(payload: Dictionary, cooldown_ticks: int, dx: int, dz: int) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null or shove_target_id < 1:
		return failed
	var result: Dictionary = ShoveApply.apply(
		world,
		entity_id,
		shove_target_id,
		payload,
		world.tick_index,
		_last_shove_tick,
		cooldown_ticks,
		dx,
		dz
	)
	if not _flag(result):
		return result
	var shoved: bool = result.get("shoved", false)
	if shoved:
		_last_shove_tick = world.tick_index
	_append_command(payload, SharedCommand.Kind.PLAYER)
	return result


func try_apply_fall(fall_dy: int) -> bool:
	if not _move_y_until_blocked(fall_dy):
		return false
	_append_command({"op": SystemOps.APPLY_FALL, "fall_dy": fall_dy}, SharedCommand.Kind.SYSTEM)
	return true


func _move_y_until_blocked(fall_dy: int) -> bool:
	if world == null:
		return false
	return world.try_move_y_until_blocked(entity_id, fall_dy)


func try_reset_if_out_of_range(
	min_y: int,
	max_y: int,
	min_x: int,
	max_x: int,
	min_z: int,
	max_z: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null:
		return failed
	var current: Dictionary = world.get_pose(entity_id)
	if current.is_empty():
		return failed
	var below: bool = world.is_below_min_y(entity_id, min_y)
	var above: bool = world.is_above_max_y(entity_id, max_y)
	var outside_xz: bool = world.is_outside_xz(entity_id, min_x, max_x, min_z, max_z)
	if not below and not above and not outside_xz:
		return {"ok": true, "reset": false}
	if _spawn == null:
		return failed
	var pose: Dictionary = _spawn.pose_for(track)
	var pose_ok: bool = pose.get("ok", false)
	if not pose_ok:
		return failed
	var x: int = pose.get("x", 0)
	var y: int = pose.get("y", 0)
	var z: int = pose.get("z", 0)
	var yaw_bam: int = pose.get("yaw_bam", 0)
	if not world.set_pose(entity_id, x, y, z, yaw_bam):
		return failed
	_append_command(
		{
			"op": SystemOps.RESET_IF_OUT_OF_RANGE,
			"min_y": min_y,
			"max_y": max_y,
			"min_x": min_x,
			"max_x": max_x,
			"min_z": min_z,
			"max_z": max_z,
		},
		SharedCommand.Kind.SYSTEM
	)
	return {"ok": true, "reset": true}


func try_interact(payload: Dictionary, damage: int) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	var decoded: Dictionary = InteractIntent.decode(payload)
	if not _flag(decoded):
		return failed
	var overlapping: PackedInt32Array = world.overlapping_static_boxes(entity_id)
	var crate_in_reach: bool = false
	for index: int in range(overlapping.size()):
		if overlapping[index] == crate_box_id:
			crate_in_reach = true
			break
	if not crate_in_reach:
		return failed
	var result: Dictionary = crate.apply_damage(damage)
	if not _flag(result):
		return result
	var destroyed: bool = result.get("destroyed", false)
	if destroyed:
		world.set_static_box_solid(crate_box_id, false)
	_append_command(payload, SharedCommand.Kind.PLAYER)
	return result


func try_use_item(
	payload: Dictionary,
	damage: int,
	reach_dx: int,
	reach_dy: int,
	reach_dz: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	var decoded: Dictionary = UseItemIntent.decode(payload)
	if not _flag(decoded):
		return failed
	var pose: Dictionary = world.get_pose(entity_id)
	if pose.is_empty():
		return failed
	var pose_x: int = pose.get("x", 0)
	var pose_y: int = pose.get("y", 0)
	var pose_z: int = pose.get("z", 0)
	var cand_x_res: FixedResult = Fixed.try_add(pose_x, reach_dx)
	if not cand_x_res.ok:
		return failed
	var cand_y_res: FixedResult = Fixed.try_add(pose_y, reach_dy)
	if not cand_y_res.ok:
		return failed
	var cand_z_res: FixedResult = Fixed.try_add(pose_z, reach_dz)
	if not cand_z_res.ok:
		return failed
	var overlapping: PackedInt32Array = world.overlapping_static_boxes_at(
		entity_id, cand_x_res.value, cand_y_res.value, cand_z_res.value
	)
	var crate_in_reach: bool = false
	for index: int in range(overlapping.size()):
		if overlapping[index] == crate_box_id:
			crate_in_reach = true
			break
	if not crate_in_reach:
		return failed
	var result: Dictionary = crate.apply_damage(damage)
	if not _flag(result):
		return result
	var destroyed: bool = result.get("destroyed", false)
	if destroyed:
		world.set_static_box_solid(crate_box_id, false)
	_append_command(payload, SharedCommand.Kind.PLAYER)
	return result


func try_commit_tick(fall_dy: int) -> bool:
	if world == null or snapshots == null:
		return false
	if not _move_y_until_blocked(fall_dy):
		return false
	world.tick()
	var solid: bool = ((world.tick_index / _hazard_period_ticks) % 2) == 0
	if not world.set_static_box_solid(hazard_box_id, solid):
		return false
	if not snapshots.record(world):
		return false
	_append_command({"op": SystemOps.COMMIT_TICK, "fall_dy": fall_dy}, SharedCommand.Kind.SYSTEM)
	return true


func try_break_crate(damage: int) -> Dictionary:
	if crate == null or world == null:
		return {"ok": false}
	var result: Dictionary = crate.apply_damage(damage)
	if not _flag(result):
		return result
	var destroyed: bool = result.get("destroyed", false)
	if destroyed:
		world.set_static_box_solid(crate_box_id, false)
	_append_command({"op": SystemOps.BREAK_CRATE, "damage": damage}, SharedCommand.Kind.SYSTEM)
	return result


func try_place_pose(x: int, y: int, z: int, yaw_bam: int) -> bool:
	if world == null:
		return false
	if not world.set_pose(entity_id, x, y, z, yaw_bam):
		return false
	_append_command(
		{
			"op": SystemOps.PLACE_POSE,
			"x": x,
			"y": y,
			"z": z,
			"yaw_bam": yaw_bam,
		},
		SharedCommand.Kind.SYSTEM
	)
	return true


func try_land_portal(start_id: int, dest_checkpoint_id: int, max_hops: int) -> Dictionary:
	if not track.can_use_portal(dest_checkpoint_id):
		return {"ok": false}
	var landed: Dictionary = PortalLanding.try_land(
		world, entity_id, _graph, start_id, max_hops
	)
	if not _flag(landed):
		return landed
	var did_land: bool = landed.get("landed", false)
	if did_land:
		_append_command(
			{
				"op": SystemOps.LAND_PORTAL,
				"start_id": start_id,
				"dest_checkpoint_id": dest_checkpoint_id,
				"max_hops": max_hops,
			},
			SharedCommand.Kind.SYSTEM
		)
	return landed


func try_accept_checkpoint(checkpoint_id: int) -> bool:
	var pad_index: int = -1
	for index: int in range(_checkpoint_ids.size()):
		if _checkpoint_ids[index] == checkpoint_id:
			pad_index = index
			break
	if pad_index < 0 or pad_index >= pad_box_ids.size():
		return false
	if not PadAccept.try_accept_on_pad(
		world, entity_id, track, checkpoint_id, pad_box_ids[pad_index]
	):
		return false
	_append_command(
		{"op": SystemOps.ACCEPT_CHECKPOINT, "checkpoint_id": checkpoint_id},
		SharedCommand.Kind.SYSTEM
	)
	return true


func try_cross_finish() -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if finish_tick != -1:
		return {"ok": true, "finish_tick": finish_tick}
	var crossed: Dictionary = FinishAccept.try_cross(world, entity_id, track, finish_box_id)
	if not _flag(crossed):
		return failed
	finish_tick = world.tick_index
	_append_command({"op": SystemOps.CROSS_FINISH}, SharedCommand.Kind.SYSTEM)
	return {"ok": true, "finish_tick": finish_tick}


func _append_command(payload: Dictionary, kind: int) -> bool:
	if tape == null or world == null:
		push_error("TraprushGrayboxCourse: tape append missing world or tape")
		return false
	var actor_id: int = _actor_id
	if kind == SharedCommand.Kind.SYSTEM:
		actor_id = SharedIds.NULL_ID
	var command: SharedCommand = SharedCommand.create(
		_next_command_seq,
		actor_id,
		_next_command_seq,
		world.tick_index,
		0,
		_content_version,
		payload.duplicate(true),
		_trace_id,
		kind
	)
	if command == null:
		push_error("TraprushGrayboxCourse: SharedCommand.create failed after accepted command")
		return false
	if not tape.append(command):
		push_error("TraprushGrayboxCourse: SimReplayBuffer.append failed after accepted command")
		return false
	_next_command_seq += 1
	return true


static func _require_int(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": 0}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_INT:
		return {"ok": false, "value": 0}
	var number: int = raw
	return {"ok": true, "value": number}


static func _require_actor_id(source: Dictionary) -> Dictionary:
	var read: Dictionary = _require_int(source, "actor_id")
	if not _flag(read):
		return {"ok": false, "value": 0}
	var actor_id: int = _value(read)
	if not SharedIds.is_valid(actor_id):
		return {"ok": false, "value": 0}
	return {"ok": true, "value": actor_id}


static func _require_nonempty_string(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": ""}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_STRING:
		return {"ok": false, "value": ""}
	var text: String = raw
	if text.is_empty():
		return {"ok": false, "value": ""}
	return {"ok": true, "value": text}


static func _require_nested(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": {}}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "value": {}}
	var nested: Dictionary = raw
	return {"ok": true, "value": nested}


static func _require_box(source: Dictionary, key: String) -> Dictionary:
	var nested_read: Dictionary = _require_nested(source, key)
	if not _flag(nested_read):
		return {"ok": false}
	var box: Dictionary = nested_read["value"]
	return _require_box_fields(box)


static func _require_box_fields(box: Dictionary) -> Dictionary:
	var x_read: Dictionary = _require_int(box, "x")
	var y_read: Dictionary = _require_int(box, "y")
	var z_read: Dictionary = _require_int(box, "z")
	var half_x_read: Dictionary = _require_int(box, "half_x")
	var half_y_read: Dictionary = _require_int(box, "half_y")
	var half_z_read: Dictionary = _require_int(box, "half_z")
	if (
		not _flag(x_read)
		or not _flag(y_read)
		or not _flag(z_read)
		or not _flag(half_x_read)
		or not _flag(half_y_read)
		or not _flag(half_z_read)
	):
		return {"ok": false}
	return {
		"ok": true,
		"x": _value(x_read),
		"y": _value(y_read),
		"z": _value(z_read),
		"half_x": _value(half_x_read),
		"half_y": _value(half_y_read),
		"half_z": _value(half_z_read),
	}


static func _require_box_list(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": []}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_ARRAY:
		return {"ok": false, "value": []}
	var items: Array = raw
	var boxes: Array[Dictionary] = []
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false, "value": []}
		var box_source: Dictionary = item
		var box: Dictionary = _require_box_fields(box_source)
		if not _flag(box):
			return {"ok": false, "value": []}
		boxes.append({
			"x": _int_at(box, "x"),
			"y": _int_at(box, "y"),
			"z": _int_at(box, "z"),
			"half_x": _int_at(box, "half_x"),
			"half_y": _int_at(box, "half_y"),
			"half_z": _int_at(box, "half_z"),
		})
	return {"ok": true, "value": boxes}


static func _require_pose_fields(source: Dictionary) -> Dictionary:
	var x_read: Dictionary = _require_int(source, "x")
	var y_read: Dictionary = _require_int(source, "y")
	var z_read: Dictionary = _require_int(source, "z")
	var yaw_read: Dictionary = _require_int(source, "yaw_bam")
	if not _flag(x_read) or not _flag(y_read) or not _flag(z_read) or not _flag(yaw_read):
		return {"ok": false}
	return {
		"ok": true,
		"x": _value(x_read),
		"y": _value(y_read),
		"z": _value(z_read),
		"yaw_bam": _value(yaw_read),
	}


static func _require_named_pose(source: Dictionary, key: String) -> Dictionary:
	var nested_read: Dictionary = _require_nested(source, key)
	if not _flag(nested_read):
		return {"ok": false}
	var pose_source: Dictionary = nested_read["value"]
	return _require_pose_fields(pose_source)


static func _require_portal(source: Dictionary, key: String) -> Dictionary:
	var nested_read: Dictionary = _require_nested(source, key)
	if not _flag(nested_read):
		return {"ok": false}
	var portal: Dictionary = nested_read["value"]
	var source_read: Dictionary = _require_int(portal, "source_id")
	var dest_read: Dictionary = _require_int(portal, "dest_id")
	var x_read: Dictionary = _require_int(portal, "x")
	var y_read: Dictionary = _require_int(portal, "y")
	var z_read: Dictionary = _require_int(portal, "z")
	var yaw_read: Dictionary = _require_int(portal, "dest_yaw_bam")
	if (
		not _flag(source_read)
		or not _flag(dest_read)
		or not _flag(x_read)
		or not _flag(y_read)
		or not _flag(z_read)
		or not _flag(yaw_read)
	):
		return {"ok": false}
	return {
		"ok": true,
		"source_id": _value(source_read),
		"dest_id": _value(dest_read),
		"x": _value(x_read),
		"y": _value(y_read),
		"z": _value(z_read),
		"dest_yaw_bam": _value(yaw_read),
	}


static func _require_id_array(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": PackedInt32Array()}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_ARRAY:
		return {"ok": false, "value": PackedInt32Array()}
	var items: Array = raw
	var packed: PackedInt32Array = PackedInt32Array()
	packed.resize(items.size())
	for index: int in range(items.size()):
		var item: Variant = items[index]
		if typeof(item) != TYPE_INT:
			return {"ok": false, "value": PackedInt32Array()}
		var number: int = item
		packed[index] = number
	return {"ok": true, "value": packed}


static func _require_pose_list(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": []}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_ARRAY:
		return {"ok": false, "value": []}
	var items: Array = raw
	var poses: Array[Dictionary] = []
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false, "value": []}
		var pose_source: Dictionary = item
		var pose: Dictionary = _require_pose_fields(pose_source)
		if not _flag(pose):
			return {"ok": false, "value": []}
		poses.append({
			"x": _int_at(pose, "x"),
			"y": _int_at(pose, "y"),
			"z": _int_at(pose, "z"),
			"yaw_bam": _int_at(pose, "yaw_bam"),
		})
	return {"ok": true, "value": poses}


static func _ids_from(ids_read: Dictionary) -> Array[int]:
	var packed: PackedInt32Array = ids_read["value"]
	var ids: Array[int] = []
	ids.resize(packed.size())
	for index: int in range(packed.size()):
		ids[index] = packed[index]
	return ids


static func _pose_from(pose_read: Dictionary) -> Dictionary:
	return {
		"x": _int_at(pose_read, "x"),
		"y": _int_at(pose_read, "y"),
		"z": _int_at(pose_read, "z"),
		"yaw_bam": _int_at(pose_read, "yaw_bam"),
	}


static func _poses_from(poses_read: Dictionary) -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	var raw: Variant = poses_read["value"]
	if typeof(raw) != TYPE_ARRAY:
		return poses
	var items: Array = raw
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var pose: Dictionary = item
		poses.append(pose)
	return poses


static func _boxes_from(boxes_read: Dictionary) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var raw: Variant = boxes_read["value"]
	if typeof(raw) != TYPE_ARRAY:
		return boxes
	var items: Array = raw
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var box: Dictionary = item
		boxes.append(box)
	return boxes


static func _portal_from(portal_read: Dictionary) -> TraprushPortalLink:
	return PortalLink.new(
		_int_at(portal_read, "source_id"),
		_int_at(portal_read, "dest_id"),
		_int_at(portal_read, "x"),
		_int_at(portal_read, "y"),
		_int_at(portal_read, "z"),
		_int_at(portal_read, "dest_yaw_bam")
	)


static func _int_at(source: Dictionary, key: String) -> int:
	var number: int = source.get(key, 0)
	return number


static func _flag(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


static func _value(result: Dictionary) -> int:
	var number: int = result.get("value", 0)
	return number


static func _text(result: Dictionary) -> String:
	var raw: Variant = result.get("value", "")
	if typeof(raw) != TYPE_STRING:
		return ""
	var text: String = raw
	return text
