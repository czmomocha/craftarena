class_name TraprushIntentStepper
extends RefCounted

## 把已解码的 Move / Jump / ResetToCheckpoint 接到 SimulationWorld。
## 依据 CD-21 §3 / §8：短跳是按钮意图，始终直立；客户端不得发送最终位置。
## 位移、jump_dy、support_dy、coyote_ticks 由调用方传入，不发明默认速度、跳跃高度或重力。
## Move 只调用 try_move_xz_until_blocked：停在最后未阻挡 XZ 样本，剩余位移丢弃，非贴墙滑行。
## 解码成功的 Move 仍 {ok: true}，不因接触或整段扫掠失败改为 false。不调用 try_move_xz。
## Jump 在支撑上，或离开支撑后 coyote_ticks 内且尚未消费时，才 TraprushGravity.apply_jump。
## 不调用 try_move_y。解码成功的 Jump 仍 {ok: true}。窗口外仍 {ok: true} 且不位移、不改 vy。
## Move / Reset 不读 support_dy。起跳成功后消费（无二段跳）。Reset 写回落点后 set_vy(0)。
## 可选 yaw 在 XZ 接触推进之后 set_pose（保留 vy，转身不是落地）。不调用 world.tick()；Tick 仍由调用方推进。
## Shove 不在本步进器应用。不处理传送落地等待或道具。
## 土狼状态（last_supported_tick / consumed）由调用方按世界 tick 观察支撑后传入，不进快照。

const MoveIntent := preload("res://src/games/traprush/move_intent.gd")
const JumpIntent := preload("res://src/games/traprush/jump_intent.gd")
const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const Gravity := preload("res://src/games/traprush/gravity.gd")
const Coyote := preload("res://src/games/traprush/coyote.gd")

## Matches TraprushMoveIntent omitted-yaw sentinel. Do not read the private const.
const _YAW_BAM_OMITTED: int = -1


static func apply(
	world: SimulationWorld,
	entity_id: int,
	payload: Dictionary,
	jump_dy: int,
	spawn: TraprushCheckpointSpawn,
	track: TraprushCheckpointTrack,
	support_dy: int,
	now_tick: int = 0,
	last_supported_tick: int = -1,
	jump_consumed: bool = false,
	coyote_ticks: int = 0
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null:
		return failed
	var current: Dictionary = world.get_pose(entity_id)
	if current.is_empty():
		return failed
	var prior: Dictionary = Coyote.observe_world(
		world, entity_id, support_dy, now_tick, last_supported_tick, jump_consumed
	)
	last_supported_tick = prior["last_supported_tick"]
	jump_consumed = prior["consumed"]
	var move_decoded: Dictionary = MoveIntent.decode(payload)
	var move_ok: bool = move_decoded.get("ok", false)
	if move_ok:
		_apply_move(world, entity_id, move_decoded)
		return _ok_state(world, entity_id, support_dy, now_tick, last_supported_tick, jump_consumed)
	var jump_decoded: Dictionary = JumpIntent.decode(payload)
	var jump_ok: bool = jump_decoded.get("ok", false)
	if jump_ok:
		var supported: bool = world.is_supported_by_solid(entity_id, support_dy)
		if Coyote.can_jump(supported, now_tick, last_supported_tick, jump_consumed, coyote_ticks):
			Gravity.apply_jump(world, entity_id, jump_dy)
			return {
				"ok": true,
				"last_supported_tick": last_supported_tick,
				"consumed": true,
			}
		return {
			"ok": true,
			"last_supported_tick": last_supported_tick,
			"consumed": jump_consumed,
		}
	if CheckpointSpawn.is_reset_intent(payload):
		var reset: Dictionary = _apply_reset(world, entity_id, spawn, track)
		var reset_ok: bool = reset.get("ok", false)
		if not reset_ok:
			return reset
		return _ok_state(world, entity_id, support_dy, now_tick, last_supported_tick, jump_consumed)
	return failed


static func _apply_move(world: SimulationWorld, entity_id: int, decoded: Dictionary) -> void:
	var dx: int = decoded.get("dx", 0)
	var dz: int = decoded.get("dz", 0)
	world.try_move_xz_until_blocked(entity_id, dx, dz)
	var yaw_bam: int = decoded.get("yaw_bam", _YAW_BAM_OMITTED)
	if yaw_bam == _YAW_BAM_OMITTED:
		return
	var pose: Dictionary = world.get_pose(entity_id)
	var x: int = pose.get("x", 0)
	var y: int = pose.get("y", 0)
	var z: int = pose.get("z", 0)
	world.set_pose(entity_id, x, y, z, yaw_bam)


static func _apply_reset(
	world: SimulationWorld,
	entity_id: int,
	spawn: TraprushCheckpointSpawn,
	track: TraprushCheckpointTrack
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if spawn == null:
		return failed
	var pose: Dictionary = spawn.pose_for(track)
	var pose_ok: bool = pose.get("ok", false)
	if not pose_ok:
		return failed
	var x: int = pose.get("x", 0)
	var y: int = pose.get("y", 0)
	var z: int = pose.get("z", 0)
	var yaw_bam: int = pose.get("yaw_bam", 0)
	world.set_pose(entity_id, x, y, z, yaw_bam)
	world.set_vy(entity_id, 0)
	return {"ok": true}


static func _ok_state(
	world: SimulationWorld,
	entity_id: int,
	support_dy: int,
	now_tick: int,
	last_supported_tick: int,
	consumed: bool
) -> Dictionary:
	var observed: Dictionary = Coyote.observe_world(
		world, entity_id, support_dy, now_tick, last_supported_tick, consumed
	)
	return {
		"ok": true,
		"last_supported_tick": observed["last_supported_tick"],
		"consumed": observed["consumed"],
	}
