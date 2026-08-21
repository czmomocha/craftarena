class_name SimulationWorld
extends RefCounted

## Authoritative simulation skeleton. Tick is a counter, not a wall-clock duration.
## Pose fields are Q48.16; yaw is BAM. Hash order: tick_index, then id,x,y,z,yaw by id.
## Radius and cylinder_height are Q48.16 but are not part of hash_state.
## try_move_xz rejects a destination that overlaps another upright capsule.
## Continuous sweep / substepping along the segment is not implemented in this slice.

var tick_index: int = 0

var _rng: SimRng = SimRng.new()
var _x: Array[int] = []
var _y: Array[int] = []
var _z: Array[int] = []
var _yaw: Array[int] = []
var _radius: Array[int] = []
var _cylinder_height: Array[int] = []


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
	var mover: KinematicCapsule = _capsule_at(pose_index, new_x_res.value, _y[pose_index], new_z_res.value)
	for other_id: int in range(1, _x.size() + 1):
		if other_id == entity_id:
			continue
		var other_index: int = other_id - 1
		var other: KinematicCapsule = _capsule_at(
			other_index, _x[other_index], _y[other_index], _z[other_index]
		)
		if mover.overlaps(other) or not mover.overlap_math_ok:
			return false
	_x[pose_index] = new_x_res.value
	_z[pose_index] = new_z_res.value
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
