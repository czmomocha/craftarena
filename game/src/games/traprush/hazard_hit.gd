class_name TraprushHazardHit
extends RefCounted

## 服务端裁决的周期机关命中：固体半周期占用重叠才算击中。
## 不读 Authoring `hazard.damage` / `hazard.knockback`（官方课仍是 0），
## 击退步长由调用方注入，不是产品表，也不是客户端命中断言。
## 先按盒心→胶囊的 8 向水平击退（中心重叠时向 +Z；已嵌入时用 set_pose
## 瞬时位移，不走 until_blocked 扫掠），再若仍重叠则环境失败复位到最近检查点。


const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")


static func try_apply(
	world: SimulationWorld,
	capsule_id: int,
	entries: Array,
	knockback_step: int,
	spawn: CheckpointSpawn,
	track: CheckpointTrack
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null or spawn == null or track == null:
		return failed
	var hits: Array[Dictionary] = _overlapping_solid_entries(world, capsule_id, entries)
	if hits.is_empty():
		return {"ok": true, "knocked": false, "reset": false}
	var knocked: bool = false
	if _knockback_step_allowed(knockback_step):
		var first: Dictionary = hits[0]
		var pose: Dictionary = world.get_pose(capsule_id)
		if pose.is_empty():
			return failed
		var pose_x_raw: Variant = pose.get("x", null)
		var pose_z_raw: Variant = pose.get("z", null)
		var box_x_raw: Variant = first.get("x", null)
		var box_z_raw: Variant = first.get("z", null)
		if typeof(pose_x_raw) != TYPE_INT or typeof(pose_z_raw) != TYPE_INT:
			return failed
		if typeof(box_x_raw) != TYPE_INT or typeof(box_z_raw) != TYPE_INT:
			return failed
		var pose_x: int = pose_x_raw
		var pose_z: int = pose_z_raw
		var box_x: int = box_x_raw
		var box_z: int = box_z_raw
		var pose_y_raw: Variant = pose.get("y", null)
		var yaw_raw: Variant = pose.get("yaw", null)
		if typeof(pose_y_raw) != TYPE_INT or typeof(yaw_raw) != TYPE_INT:
			return failed
		var pose_y: int = pose_y_raw
		var yaw: int = yaw_raw
		var delta: Dictionary = _knockback_delta(pose_x, pose_z, box_x, box_z, knockback_step)
		var dx_raw: Variant = delta.get("dx", null)
		var dz_raw: Variant = delta.get("dz", null)
		if typeof(dx_raw) != TYPE_INT or typeof(dz_raw) != TYPE_INT:
			return failed
		var dx: int = dx_raw
		var dz: int = dz_raw
		var next_x_add: FixedResult = Fixed.try_add(pose_x, dx)
		var next_z_add: FixedResult = Fixed.try_add(pose_z, dz)
		if not next_x_add.ok or not next_z_add.ok:
			return failed
		## 已嵌在固体机关里时扫掠无法挤出；击退是瞬时位移，不走 until_blocked。
		if not world.set_pose(capsule_id, next_x_add.value, pose_y, next_z_add.value, yaw):
			return failed
		knocked = true
	var still: Array[Dictionary] = _overlapping_solid_entries(world, capsule_id, entries)
	if still.is_empty():
		return {"ok": true, "knocked": knocked, "reset": false}
	var respawn: Dictionary = spawn.pose_for(track)
	var pose_ok: bool = respawn.get("ok", false)
	if not pose_ok:
		return failed
	var x_raw: Variant = respawn.get("x", null)
	var y_raw: Variant = respawn.get("y", null)
	var z_raw: Variant = respawn.get("z", null)
	var yaw_raw: Variant = respawn.get("yaw_bam", null)
	if typeof(x_raw) != TYPE_INT or typeof(y_raw) != TYPE_INT:
		return failed
	if typeof(z_raw) != TYPE_INT or typeof(yaw_raw) != TYPE_INT:
		return failed
	var x: int = x_raw
	var y: int = y_raw
	var z: int = z_raw
	var yaw_bam: int = yaw_raw
	if not world.set_pose(capsule_id, x, y, z, yaw_bam):
		return failed
	world.set_vy(capsule_id, 0)
	return {"ok": true, "knocked": knocked, "reset": true}


static func _knockback_step_allowed(step: int) -> bool:
	if step < 1:
		return false
	if step > Fixed.SCALE:
		return false
	return true


static func _knockback_delta(
	pose_x: int,
	pose_z: int,
	box_x: int,
	box_z: int,
	step: int
) -> Dictionary:
	var sign_x: int = _axis_sign(pose_x - box_x)
	var sign_z: int = _axis_sign(pose_z - box_z)
	if sign_x == 0 and sign_z == 0:
		return {"dx": 0, "dz": step}
	return {
		"dx": sign_x * step,
		"dz": sign_z * step,
	}


static func _axis_sign(delta: int) -> int:
	if delta > 0:
		return 1
	if delta < 0:
		return -1
	return 0


static func _overlapping_solid_entries(
	world: SimulationWorld,
	capsule_id: int,
	entries: Array
) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var ordered: Array[Dictionary] = []
	for item: Variant in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		if typeof(entry.get("entity_id", null)) != TYPE_INT:
			continue
		if typeof(entry.get("box_id", null)) != TYPE_INT:
			continue
		if typeof(entry.get("x", null)) != TYPE_INT:
			continue
		if typeof(entry.get("z", null)) != TYPE_INT:
			continue
		ordered.append(entry)
	ordered.sort_custom(_entity_id_less)
	for entry: Dictionary in ordered:
		var box_id: int = entry["box_id"]
		if not world.is_static_box_solid(box_id):
			continue
		if not world.overlaps_static_box(capsule_id, box_id):
			continue
		hits.append(entry)
	return hits


static func _entity_id_less(left: Dictionary, right: Dictionary) -> bool:
	var left_id: int = left["entity_id"]
	var right_id: int = right["entity_id"]
	return left_id < right_id
