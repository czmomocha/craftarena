class_name TraprushGrayboxCourse
extends RefCounted

## TRAPRUSH 单人灰盒跑道夹具：组装检查点、上下/侧向传送、墙盒、可破坏箱、周期 hazard。
## 依据 CD-21 §4.2 / §5.2 / §8 与 CD-61 M1 灰盒：有序检查点、传送不得跳点、破坏后开路、1 个周期障碍 stub。
## 灰盒检查点垫走 PadAccept / CD-21 §8：完成由占用判定，客户端不得断言。
## 位移、jump_dy、max_hops、max_health、period、snapshot capacity 均由调用方传入，不锁定 Tick/快照 Hz（CD-63）。
## 成功 PLAYER 意图写入 SimReplayBuffer（CD-43 命令日志 + 种子）；磁带不回放进 world。
## assemble 记录 tick 0 关键快照；try_commit_tick 推进 tick、按调用方周期切换 hazard 阻挡、再 record。
## try_step_intent / try_interact 成功入带；打箱 / 传送 / 检查点不 tick、不 record。
## try_interact 仅在 overlapping_static_boxes 含 crate 时按调用方 damage 走 Destructible；摧毁则关闭 crate 盒阻挡。
## try_break_crate 保持测试入口：不要求重叠、不入带。
## 不从客户端 Dictionary 读最终位置、障碍死亡或完成标志；不实现 UseItemIntent、道具栏、2p、名次或 Headless。

const IntentStepper := preload("res://src/games/traprush/intent_stepper.gd")
const InteractIntent := preload("res://src/games/traprush/interact_intent.gd")
const PortalLanding := preload("res://src/games/traprush/portal_landing.gd")
const PortalGraph := preload("res://src/games/traprush/portal_graph.gd")
const PortalLink := preload("res://src/games/traprush/portal_link.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const Destructible := preload("res://src/games/traprush/destructible.gd")
const PadAccept := preload("res://src/games/traprush/pad_accept.gd")

var world: SimulationWorld = null
var entity_id: int = 0
var track: TraprushCheckpointTrack = null
var wall_box_id: int = 0
var crate_box_id: int = 0
var hazard_box_id: int = 0
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


func try_step_intent(payload: Dictionary, jump_dy: int) -> Dictionary:
	var result: Dictionary = IntentStepper.apply(world, entity_id, payload, jump_dy, _spawn, track)
	if not _flag(result):
		return result
	var command: SharedCommand = SharedCommand.create(
		_next_command_seq,
		_actor_id,
		_next_command_seq,
		world.tick_index,
		0,
		_content_version,
		payload.duplicate(true),
		_trace_id,
		SharedCommand.Kind.PLAYER
	)
	if command == null:
		push_error("TraprushGrayboxCourse: SharedCommand.create failed after accepted intent")
		return result
	if not tape.append(command):
		push_error("TraprushGrayboxCourse: SimReplayBuffer.append failed after accepted intent")
		return result
	_next_command_seq += 1
	return result


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
	var command: SharedCommand = SharedCommand.create(
		_next_command_seq,
		_actor_id,
		_next_command_seq,
		world.tick_index,
		0,
		_content_version,
		payload.duplicate(true),
		_trace_id,
		SharedCommand.Kind.PLAYER
	)
	if command == null:
		push_error("TraprushGrayboxCourse: SharedCommand.create failed after accepted intent")
		return result
	if not tape.append(command):
		push_error("TraprushGrayboxCourse: SimReplayBuffer.append failed after accepted intent")
		return result
	_next_command_seq += 1
	return result


func try_commit_tick() -> bool:
	if world == null or snapshots == null:
		return false
	world.tick()
	var solid: bool = ((world.tick_index / _hazard_period_ticks) % 2) == 0
	if not world.set_static_box_solid(hazard_box_id, solid):
		return false
	if not snapshots.record(world):
		return false
	return true


func try_break_crate(damage: int) -> Dictionary:
	var result: Dictionary = crate.apply_damage(damage)
	var destroyed: bool = result.get("destroyed", false)
	if destroyed:
		world.set_static_box_solid(crate_box_id, false)
	return result


func try_land_portal(start_id: int, dest_checkpoint_id: int, max_hops: int) -> Dictionary:
	if not track.can_use_portal(dest_checkpoint_id):
		return {"ok": false}
	return PortalLanding.try_land(world, entity_id, _graph, start_id, max_hops)


func try_accept_checkpoint(checkpoint_id: int) -> bool:
	var pad_index: int = -1
	for index: int in range(_checkpoint_ids.size()):
		if _checkpoint_ids[index] == checkpoint_id:
			pad_index = index
			break
	if pad_index < 0 or pad_index >= pad_box_ids.size():
		return false
	return PadAccept.try_accept_on_pad(
		world, entity_id, track, checkpoint_id, pad_box_ids[pad_index]
	)


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
