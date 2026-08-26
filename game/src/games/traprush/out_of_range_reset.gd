class_name TraprushOutOfRangeReset
extends RefCounted

## 出界复位：胶囊 y 低于/高于调用方闭区间，或 XZ 落在调用方闭区间外时，
## 用已有 CheckpointSpawn.pose_for 写回最近检查点落点（尚无进度则回起点）。
## 依据 CD-21 §6：环境失败后无限复活到最近检查点。不计数掉出次数 N，
## 不接重力/下落，不写复活硬直。边界由调用方传入，不是产品场地尺寸。
## 不 tick。查询走 SimulationWorld 已有 is_below_min_y / is_above_max_y /
## is_outside_xz。空区间（min > max）拒绝，避免「永远出界」。

const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")

## 开发期占位半宽：±8 格。官方三张赛道最大约 4 格。不是产品边界。
const STUB_HALF: int = 8 * Fixed.SCALE


static func try_apply(
	world: SimulationWorld,
	entity_id: int,
	spawn: CheckpointSpawn,
	track: CheckpointTrack,
	min_y: int,
	max_y: int,
	min_x: int,
	max_x: int,
	min_z: int,
	max_z: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null or spawn == null or track == null:
		return failed
	if min_x > max_x or min_z > max_z or min_y > max_y:
		return failed
	var pose: Dictionary = world.get_pose(entity_id)
	if pose.is_empty():
		return failed
	var below: bool = world.is_below_min_y(entity_id, min_y)
	var above: bool = world.is_above_max_y(entity_id, max_y)
	var outside_xz: bool = world.is_outside_xz(entity_id, min_x, max_x, min_z, max_z)
	if not below and not above and not outside_xz:
		return {"ok": true, "reset": false}
	var respawn: Dictionary = spawn.pose_for(track)
	var pose_ok: bool = respawn.get("ok", false)
	if not pose_ok:
		return failed
	var x: int = respawn.get("x", 0)
	var y: int = respawn.get("y", 0)
	var z: int = respawn.get("z", 0)
	var yaw_bam: int = respawn.get("yaw_bam", 0)
	if not world.set_pose(entity_id, x, y, z, yaw_bam):
		return failed
	return {"ok": true, "reset": true}
