class_name SimulationWorld
extends RefCounted

## Authoritative simulation skeleton. Tick is a counter, not a wall-clock duration.
## Pose fields are Q48.16; yaw is BAM; vy is Q48.16 vertical speed in units per tick.
## Hash order: tick_index, then id,x,y,z,yaw,vy by id.
## Radius, cylinder_height, and static AABBs are Q48.16 geometry and are not part of hash_state.
## Collaborators are SimulationWorldQuery / SimulationWorldMove so this file stays
## under E9 400 lines. Public API stays on this type.
## set_pose / try_set_pose keep vy so a yaw rewrite is not a landing. Teleports that
## should kill a jump (reset, portal, out-of-range) call set_vy(0) themselves.
## set_static_box_solid toggles whether a static AABB blocks occupancy; ids stay
## 1-based and non-solid boxes stay in the array. Solidity is not part of hash_state.
## Occupancy, support, bound, and volume queries do not write pose, tick, or hash_state.
## Overflowing overlap math counts as intersecting. Queries are not hashed.
## try_set_pose occupancy-checks then teleports; it is not a sweep.
## try_move_* sample the displacement segment with discrete substeps (not TOI).
## A blocked sample or overflow rejects the whole move; there is no slide.
## until_blocked commits the last unblocked sample. radius is the only step scale.
## spawn_capsule still skips occupancy checks. set_pose still writes without checks
## so respawn can teleport into a blocked pose.

const QueryGd := preload("res://src/simulation/simulation_world_query.gd")
const MoveGd := preload("res://src/simulation/simulation_world_move.gd")

var tick_index: int = 0
var query: QueryGd = QueryGd.new()
var move: MoveGd = MoveGd.new()

var _rng: SimRng = SimRng.new()
var _x: Array[int] = []
var _y: Array[int] = []
var _z: Array[int] = []
var _yaw: Array[int] = []
var _vy: Array[int] = []
var _radius: Array[int] = []
var _cylinder_height: Array[int] = []
var _boxes: Array[StaticAabb] = []
var _box_solid: Array[bool] = []


func _init(p_seed: int = 1) -> void:
	_rng.seed(p_seed)


func tick() -> void:
	tick_index += 1


func spawn_capsule(x: int, y: int, z: int, yaw: int, radius: int = 0, cylinder_height: int = 0) -> int:
	_x.append(x)
	_y.append(y)
	_z.append(z)
	_yaw.append(yaw)
	_vy.append(0)
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
	_box_solid.append(true)
	return _boxes.size()


func set_static_box_solid(box_id: int, solid: bool) -> bool:
	if not _has_box(box_id):
		return false
	_box_solid[box_id - 1] = solid
	return true


func is_static_box_solid(box_id: int) -> bool:
	if not _has_box(box_id):
		return false
	return _box_solid[box_id - 1]


func overlaps_static_box(entity_id: int, box_id: int) -> bool:
	return query.overlaps_static_box(self, entity_id, box_id)


func overlaps_static_box_at(entity_id: int, box_id: int, x: int, y: int, z: int) -> bool:
	return query.overlaps_static_box_at(self, entity_id, box_id, x, y, z)


func overlapping_static_boxes(entity_id: int) -> PackedInt32Array:
	return query.overlapping_static_boxes(self, entity_id)


func overlapping_static_boxes_at(entity_id: int, x: int, y: int, z: int) -> PackedInt32Array:
	return query.overlapping_static_boxes_at(self, entity_id, x, y, z)


func overlaps_solid_static_box(entity_id: int, box_id: int) -> bool:
	return query.overlaps_solid_static_box(self, entity_id, box_id)


func overlaps_solid_static_box_at(entity_id: int, box_id: int, x: int, y: int, z: int) -> bool:
	return query.overlaps_solid_static_box_at(self, entity_id, box_id, x, y, z)


func overlapping_solid_static_boxes(entity_id: int) -> PackedInt32Array:
	return query.overlapping_solid_static_boxes(self, entity_id)


func overlapping_solid_static_boxes_at(entity_id: int, x: int, y: int, z: int) -> PackedInt32Array:
	return query.overlapping_solid_static_boxes_at(self, entity_id, x, y, z)


func supporting_solid_static_boxes(entity_id: int, support_dy: int) -> PackedInt32Array:
	return query.supporting_solid_static_boxes(self, entity_id, support_dy)


func supporting_solid_static_boxes_at(
	entity_id: int, x: int, y: int, z: int, support_dy: int
) -> PackedInt32Array:
	return query.supporting_solid_static_boxes_at(self, entity_id, x, y, z, support_dy)


func is_supported_by_solid(entity_id: int, support_dy: int) -> bool:
	return query.is_supported_by_solid(self, entity_id, support_dy)


func is_supported_by_solid_at(
	entity_id: int, x: int, y: int, z: int, support_dy: int
) -> bool:
	return query.is_supported_by_solid_at(self, entity_id, x, y, z, support_dy)


func is_below_min_y(entity_id: int, min_y: int) -> bool:
	return query.is_below_min_y(self, entity_id, min_y)


func is_below_min_y_at(entity_id: int, x: int, y: int, z: int, min_y: int) -> bool:
	return query.is_below_min_y_at(self, entity_id, x, y, z, min_y)


func is_above_max_y(entity_id: int, max_y: int) -> bool:
	return query.is_above_max_y(self, entity_id, max_y)


func is_above_max_y_at(entity_id: int, x: int, y: int, z: int, max_y: int) -> bool:
	return query.is_above_max_y_at(self, entity_id, x, y, z, max_y)


func is_outside_xz(
	entity_id: int, min_x: int, max_x: int, min_z: int, max_z: int
) -> bool:
	return query.is_outside_xz(self, entity_id, min_x, max_x, min_z, max_z)


func is_outside_xz_at(
	entity_id: int, x: int, y: int, z: int, min_x: int, max_x: int, min_z: int, max_z: int
) -> bool:
	return query.is_outside_xz_at(self, entity_id, x, y, z, min_x, max_x, min_z, max_z)


func overlaps_entity(entity_id: int, other_id: int) -> bool:
	return query.overlaps_entity(self, entity_id, other_id)


func overlaps_entity_at(entity_id: int, other_id: int, x: int, y: int, z: int) -> bool:
	return query.overlaps_entity_at(self, entity_id, other_id, x, y, z)


func overlapping_entities(entity_id: int) -> PackedInt32Array:
	return query.overlapping_entities(self, entity_id)


func overlapping_entities_at(entity_id: int, x: int, y: int, z: int) -> PackedInt32Array:
	return query.overlapping_entities_at(self, entity_id, x, y, z)


func set_pose(entity_id: int, x: int, y: int, z: int, yaw: int) -> bool:
	if not _has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	_x[pose_index] = x
	_y[pose_index] = y
	_z[pose_index] = z
	_yaw[pose_index] = yaw
	return true


func is_pose_blocked(entity_id: int, x: int, y: int, z: int) -> bool:
	return query.is_pose_blocked(self, entity_id, x, y, z)


func is_volume_blocked(x: int, y: int, z: int, radius: int, cylinder_height: int) -> bool:
	return query.is_volume_blocked(self, x, y, z, radius, cylinder_height)


func try_set_pose(entity_id: int, x: int, y: int, z: int, yaw: int) -> bool:
	return move.try_set_pose(self, entity_id, x, y, z, yaw)


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


func get_vy(entity_id: int) -> int:
	if not _has_entity(entity_id):
		return 0
	return _vy[entity_id - 1]


func set_vy(entity_id: int, vy: int) -> bool:
	if not _has_entity(entity_id):
		return false
	_vy[entity_id - 1] = vy
	return true


func try_move_xz(entity_id: int, dx: int, dz: int) -> bool:
	return move.try_move_xz(self, entity_id, dx, dz)


func try_move_xz_until_blocked(entity_id: int, dx: int, dz: int) -> bool:
	return move.try_move_xz_until_blocked(self, entity_id, dx, dz)


func try_move_y(entity_id: int, dy: int) -> bool:
	return move.try_move_y(self, entity_id, dy)


func try_move_y_until_blocked(entity_id: int, dy: int) -> bool:
	return move.try_move_y_until_blocked(self, entity_id, dy)


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
		values.append(_vy[pose_index])
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


func _has_box(box_id: int) -> bool:
	return box_id >= 1 and box_id <= _boxes.size()
