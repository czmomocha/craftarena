class_name SimulationWorld
extends RefCounted

## Authoritative simulation skeleton. Tick is a counter, not a wall-clock duration.
## Pose fields are Q48.16; yaw is BAM. Hash order: tick_index, then id,x,y,z,yaw by id.
## Radius, cylinder_height, and static AABBs are Q48.16 geometry and are not part of hash_state.
## try_move_xz / try_move_y sample the displacement segment with discrete substeps
## (not continuous analytic TOI) against other upright capsules and static AABBs.
## A blocked sample or overflow rejects the whole move; there is no slide.
## radius <= 0 keeps destination-only checks; radius is the only step scale.

var tick_index: int = 0

var _rng: SimRng = SimRng.new()
var _x: Array[int] = []
var _y: Array[int] = []
var _z: Array[int] = []
var _yaw: Array[int] = []
var _radius: Array[int] = []
var _cylinder_height: Array[int] = []
var _boxes: Array[StaticAabb] = []


func _init(p_seed: int = 1) -> void:
	_rng.seed(p_seed)


func tick() -> void:
	tick_index += 1


func spawn_capsule(x: int, y: int, z: int, yaw: int, radius: int = 0, cylinder_height: int = 0) -> int:
	_x.append(x)
	_y.append(y)
	_z.append(z)
	_yaw.append(yaw)
	_radius.append(radius)
	_cylinder_height.append(cylinder_height)
	return _x.size()


func spawn_static_box(x: int, y: int, z: int, half_x: int, half_y: int, half_z: int) -> int:
	if half_x < 0 or half_y < 0 or half_z < 0:
		return 0
	var box: StaticAabb = StaticAabb.new()
	box.x = x
	box.y = y
	box.z = z
	box.half_x = half_x
	box.half_y = half_y
	box.half_z = half_z
	_boxes.append(box)
	return _boxes.size()


func set_pose(entity_id: int, x: int, y: int, z: int, yaw: int) -> bool:
	if not _has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	_x[pose_index] = x
	_y[pose_index] = y
	_z[pose_index] = z
	_yaw[pose_index] = yaw
	return true


func get_pose(entity_id: int) -> Dictionary:
	if not _has_entity(entity_id):
		return {}
	var pose_index: int = entity_id - 1
	return {
		"x": _x[pose_index],
		"y": _y[pose_index],
		"z": _z[pose_index],
		"yaw": _yaw[pose_index],
	}


## dx/dz are this-tick displacement in Q48.16 internal units, not metres per second.
func try_move_xz(entity_id: int, dx: int, dz: int) -> bool:
	if not _has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	var new_x_res: FixedResult = Fixed.try_add(_x[pose_index], dx)
	if not new_x_res.ok:
		return false
	var new_z_res: FixedResult = Fixed.try_add(_z[pose_index], dz)
	if not new_z_res.ok:
		return false
	if not _sweep_clear_xz(entity_id, pose_index, dx, dz, new_x_res.value, new_z_res.value):
		return false
	_x[pose_index] = new_x_res.value
	_z[pose_index] = new_z_res.value
	return true


## dy is this-tick displacement in Q48.16 internal units, not metres per second.
func try_move_y(entity_id: int, dy: int) -> bool:
	if not _has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	var new_y_res: FixedResult = Fixed.try_add(_y[pose_index], dy)
	if not new_y_res.ok:
		return false
	if not _sweep_clear_y(entity_id, pose_index, dy, new_y_res.value):
		return false
	_y[pose_index] = new_y_res.value
	return true


func hash_state() -> PackedByteArray:
	var hasher: StateHasher = StateHasher.new()
	var values: Array[int] = [tick_index]
	var ids: Array[int] = []
	for pose_index: int in range(_x.size()):
		ids.append(pose_index + 1)
	ids.sort()
	for entity_id: int in ids:
		var pose_index: int = entity_id - 1
		values.append(entity_id)
		values.append(_x[pose_index])
		values.append(_y[pose_index])
		values.append(_z[pose_index])
		values.append(_yaw[pose_index])
	if not hasher.write_canonical(values):
		return PackedByteArray()
	var digest_hex: String = hasher.digest_hex()
	return digest_hex.hex_decode()


func get_rng() -> SimRng:
	return _rng


func _sweep_clear_xz(
	entity_id: int, pose_index: int, dx: int, dz: int, dest_x: int, dest_z: int
) -> bool:
	var start_x: int = _x[pose_index]
	var start_y: int = _y[pose_index]
	var start_z: int = _z[pose_index]
	var radius: int = _radius[pose_index]
	if radius <= 0:
		return not _destination_blocked(entity_id, pose_index, dest_x, start_y, dest_z)
	var abs_dx_res: FixedResult = _try_abs(dx)
	if not abs_dx_res.ok:
		return false
	var abs_dz_res: FixedResult = _try_abs(dz)
	if not abs_dz_res.ok:
		return false
	var chebyshev: int = abs_dx_res.value
	if abs_dz_res.value > chebyshev:
		chebyshev = abs_dz_res.value
	var step_count: int = _sweep_step_count(chebyshev, radius)
	var sample_i: int = 1
	while true:
		var step_dx_res: FixedResult = Fixed.try_mul_div(dx, sample_i, step_count)
		if not step_dx_res.ok:
			return false
		var step_dz_res: FixedResult = Fixed.try_mul_div(dz, sample_i, step_count)
		if not step_dz_res.ok:
			return false
		var sample_x_res: FixedResult = Fixed.try_add(start_x, step_dx_res.value)
		if not sample_x_res.ok:
			return false
		var sample_z_res: FixedResult = Fixed.try_add(start_z, step_dz_res.value)
		if not sample_z_res.ok:
			return false
		if _destination_blocked(
			entity_id, pose_index, sample_x_res.value, start_y, sample_z_res.value
		):
			return false
		if sample_i == step_count:
			break
		sample_i += 1
	return true


func _sweep_clear_y(entity_id: int, pose_index: int, dy: int, dest_y: int) -> bool:
	var start_x: int = _x[pose_index]
	var start_y: int = _y[pose_index]
	var start_z: int = _z[pose_index]
	var radius: int = _radius[pose_index]
	if radius <= 0:
		return not _destination_blocked(entity_id, pose_index, start_x, dest_y, start_z)
	var abs_dy_res: FixedResult = _try_abs(dy)
	if not abs_dy_res.ok:
		return false
	var step_count: int = _sweep_step_count(abs_dy_res.value, radius)
	var sample_i: int = 1
	while true:
		var step_dy_res: FixedResult = Fixed.try_mul_div(dy, sample_i, step_count)
		if not step_dy_res.ok:
			return false
		var sample_y_res: FixedResult = Fixed.try_add(start_y, step_dy_res.value)
		if not sample_y_res.ok:
			return false
		if _destination_blocked(
			entity_id, pose_index, start_x, sample_y_res.value, start_z
		):
			return false
		if sample_i == step_count:
			break
		sample_i += 1
	return true


func _sweep_step_count(length: int, radius: int) -> int:
	var step_count: int = length / radius
	if length % radius != 0:
		step_count += 1
	if step_count < 1:
		step_count = 1
	return step_count


func _try_abs(value: int) -> FixedResult:
	if value >= 0:
		return FixedResult.success(value)
	return Fixed.try_neg(value)


func _destination_blocked(entity_id: int, pose_index: int, dest_x: int, dest_y: int, dest_z: int) -> bool:
	var mover: KinematicCapsule = _capsule_at(pose_index, dest_x, dest_y, dest_z)
	for other_id: int in range(1, _x.size() + 1):
		if other_id == entity_id:
			continue
		var other_index: int = other_id - 1
		var other: KinematicCapsule = _capsule_at(
			other_index, _x[other_index], _y[other_index], _z[other_index]
		)
		if mover.overlaps(other) or not mover.overlap_math_ok:
			return true
	for box_index: int in range(_boxes.size()):
		var box: StaticAabb = _boxes[box_index]
		if box.overlaps_capsule(mover) or not box.overlap_math_ok:
			return true
	return false


func _capsule_at(pose_index: int, x: int, y: int, z: int) -> KinematicCapsule:
	var capsule: KinematicCapsule = KinematicCapsule.new()
	capsule.x = x
	capsule.y = y
	capsule.z = z
	capsule.radius = _radius[pose_index]
	capsule.cylinder_height = _cylinder_height[pose_index]
	return capsule


func _has_entity(entity_id: int) -> bool:
	return entity_id >= 1 and entity_id <= _x.size()
