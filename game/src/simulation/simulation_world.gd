class_name SimulationWorld
extends RefCounted

## Authoritative simulation skeleton. Tick is a counter, not a wall-clock duration.
## Pose fields are Q48.16; yaw is BAM. Hash order: tick_index, then id,x,y,z,yaw by id.

var tick_index: int = 0

var _rng: SimRng = SimRng.new()
var _x: Array[int] = []
var _y: Array[int] = []
var _z: Array[int] = []
var _yaw: Array[int] = []


func _init(p_seed: int = 1) -> void:
	_rng.seed(p_seed)


func tick() -> void:
	tick_index += 1


func spawn_capsule(x: int, y: int, z: int, yaw: int) -> int:
	_x.append(x)
	_y.append(y)
	_z.append(z)
	_yaw.append(yaw)
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


func _has_entity(entity_id: int) -> bool:
	return entity_id >= 1 and entity_id <= _x.size()
