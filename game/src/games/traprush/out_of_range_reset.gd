class_name TraprushOutOfRangeReset
extends RefCounted

## 出界复位：胶囊 y 低于/高于调用方闭区间，或 XZ 落在调用方闭区间外时，
## 用已有 CheckpointSpawn.pose_for 写回最近检查点落点（尚无进度则回起点）。
## 依据 CD-21 §6：环境失败后无限复活到最近检查点。不计数掉出次数 N，
## 复位后 set_vy(0)。复活硬直由调用方在复位成功后写入，本函数不写硬直。
## 边界由调用方传入，不是产品场地尺寸。
## 不 tick。查询走 SimulationWorld 已有 is_below_min_y / is_above_max_y /
## is_outside_xz。空区间（min > max）拒绝，避免「永远出界」。

const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")

## 开发期占位半宽：±8 格。官方赛道沿路有立足固体后，这是真正的坑边界
## （走下路面才碰到），不是缺地板时的兜底。不是产品场地尺寸。
## 占用中心超出这盒时用 `half_covering` 把闭区间扩到包住中心，下限仍是本值。
const STUB_HALF: int = 8 * Fixed.SCALE


## 闭区间半宽。`max_abs` 是占用中心到原点的最大绝对值（含 X/Y/Z）。
## 不超过桩就维持 ±8，这样已有课的出界行为不变。
static func half_covering(max_abs: int) -> int:
	if max_abs > STUB_HALF:
		return max_abs
	return STUB_HALF


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
	world.set_vy(entity_id, 0)
	return {"ok": true, "reset": true}
