class_name TraprushIntentStepper
extends RefCounted

## 把已解码的 Move / Jump / ResetToCheckpoint 接到 SimulationWorld。
## 依据 CD-21 §3 / §8：短跳是按钮意图，始终直立；客户端不得发送最终位置。
## 位移、jump_dy、support_dy 由调用方传入，不发明默认速度、跳跃高度、重力或 coyote。
## Move 只调用 try_move_xz_until_blocked：停在最后未阻挡 XZ 样本，剩余位移丢弃，非贴墙滑行。
## 解码成功的 Move 仍 {ok: true}，不因接触或整段扫掠失败改为 false。不调用 try_move_xz。
## Jump 仅当 world.is_supported_by_solid(entity_id, support_dy) 为 true 时才
## TraprushGravity.apply_jump：按 jump_dy 冲量位移并把 vy 写成冲量（顶棚则 vy=0）。
## 不调用 try_move_y。解码成功的 Jump 仍 {ok: true}。未支撑仍 {ok: true} 且不位移、不改 vy。
## Move / Reset 不读 support_dy。无二段跳缓冲。Reset 写回落点后 set_vy(0)。
## 可选 yaw 在 XZ 接触推进之后 set_pose（保留 vy，转身不是落地）。不调用 world.tick()；Tick 仍由调用方推进。
## Shove 不在本步进器应用。不处理传送落地等待或道具。

const MoveIntent := preload("res://src/games/traprush/move_intent.gd")
const JumpIntent := preload("res://src/games/traprush/jump_intent.gd")
const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const Gravity := preload("res://src/games/traprush/gravity.gd")

## Matches TraprushMoveIntent omitted-yaw sentinel. Do not read the private const.
const _YAW_BAM_OMITTED: int = -1


static func apply(
	world: SimulationWorld,
	entity_id: int,
	payload: Dictionary,
	jump_dy: int,
	spawn: TraprushCheckpointSpawn,
	track: TraprushCheckpointTrack,
	support_dy: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null:
		return failed
	var current: Dictionary = world.get_pose(entity_id)
	if current.is_empty():
		return failed
	var move_decoded: Dictionary = MoveIntent.decode(payload)
	var move_ok: bool = move_decoded.get("ok", false)
	if move_ok:
		_apply_move(world, entity_id, move_decoded)
		return {"ok": true}
	var jump_decoded: Dictionary = JumpIntent.decode(payload)
	var jump_ok: bool = jump_decoded.get("ok", false)
	if jump_ok:
		if world.is_supported_by_solid(entity_id, support_dy):
			Gravity.apply_jump(world, entity_id, jump_dy)
		return {"ok": true}
	if CheckpointSpawn.is_reset_intent(payload):
		return _apply_reset(world, entity_id, spawn, track)
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
