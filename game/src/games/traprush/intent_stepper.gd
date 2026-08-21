class_name TraprushIntentStepper
extends RefCounted

## 把已解码的 Move / Jump / ResetToCheckpoint 接到 SimulationWorld。
## 依据 CD-21 §8：客户端只发意图，不得发送最终位置。位移与跳跃 dy 由调用方传入，
## 不发明默认速度或跳跃高度（跳跃数值见 CD-63，本刀不锁定）。
## 不调用 world.tick()；Tick 仍由调用方推进。本刀不处理 Shove、传送落地等待、道具或扫掠。

const MoveIntent := preload("res://src/games/traprush/move_intent.gd")
const JumpIntent := preload("res://src/games/traprush/jump_intent.gd")
const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")

## Matches TraprushMoveIntent omitted-yaw sentinel. Do not read the private const.
const _YAW_BAM_OMITTED: int = -1


static func apply(
	world: SimulationWorld,
	entity_id: int,
	payload: Dictionary,
	jump_dy: int,
	spawn: TraprushCheckpointSpawn,
	track: TraprushCheckpointTrack
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
		world.try_move_y(entity_id, jump_dy)
		return {"ok": true}
	if CheckpointSpawn.is_reset_intent(payload):
		return _apply_reset(world, entity_id, spawn, track)
	return failed


static func _apply_move(world: SimulationWorld, entity_id: int, decoded: Dictionary) -> void:
	var dx: int = decoded.get("dx", 0)
	var dz: int = decoded.get("dz", 0)
	world.try_move_xz(entity_id, dx, dz)
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
	return {"ok": true}
