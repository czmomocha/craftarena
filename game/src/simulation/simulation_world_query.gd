class_name SimulationWorldQuery
extends RefCounted

## Occupancy and bound queries for SimulationWorld.
## Public API stays on the world facade so this file can stay under E9.


func overlaps_static_box(world: SimulationWorld, entity_id: int, box_id: int) -> bool:
	if not world._has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	return overlaps_static_box_at(
		world, entity_id, box_id, world._x[pose_index], world._y[pose_index], world._z[pose_index]
	)


func overlaps_static_box_at(
	world: SimulationWorld, entity_id: int, box_id: int, x: int, y: int, z: int
) -> bool:
	if not world._has_entity(entity_id) or not world._has_box(box_id):
		return false
	var pose_index: int = entity_id - 1
	var capsule: KinematicCapsule = world._capsule_at(pose_index, x, y, z)
	var box: StaticAabb = world._boxes[box_id - 1]
	return box.overlaps_capsule(capsule) or not box.overlap_math_ok


func overlapping_static_boxes(world: SimulationWorld, entity_id: int) -> PackedInt32Array:
	if not world._has_entity(entity_id):
		return PackedInt32Array()
	var pose_index: int = entity_id - 1
	return overlapping_static_boxes_at(
		world, entity_id, world._x[pose_index], world._y[pose_index], world._z[pose_index]
	)


func overlapping_static_boxes_at(
	world: SimulationWorld, entity_id: int, x: int, y: int, z: int
) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	if not world._has_entity(entity_id):
		return ids
	for box_id: int in range(1, world._boxes.size() + 1):
		if overlaps_static_box_at(world, entity_id, box_id, x, y, z):
			ids.append(box_id)
	return ids


func overlaps_solid_static_box(world: SimulationWorld, entity_id: int, box_id: int) -> bool:
	if not world._has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	return overlaps_solid_static_box_at(
		world, entity_id, box_id, world._x[pose_index], world._y[pose_index], world._z[pose_index]
	)


func overlaps_solid_static_box_at(
	world: SimulationWorld, entity_id: int, box_id: int, x: int, y: int, z: int
) -> bool:
	if not world.is_static_box_solid(box_id):
		return false
	return overlaps_static_box_at(world, entity_id, box_id, x, y, z)


func overlapping_solid_static_boxes(world: SimulationWorld, entity_id: int) -> PackedInt32Array:
	if not world._has_entity(entity_id):
		return PackedInt32Array()
	var pose_index: int = entity_id - 1
	return overlapping_solid_static_boxes_at(
		world, entity_id, world._x[pose_index], world._y[pose_index], world._z[pose_index]
	)


func overlapping_solid_static_boxes_at(
	world: SimulationWorld, entity_id: int, x: int, y: int, z: int
) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	if not world._has_entity(entity_id):
		return ids
	for box_id: int in range(1, world._boxes.size() + 1):
		if overlaps_solid_static_box_at(world, entity_id, box_id, x, y, z):
			ids.append(box_id)
	return ids


func supporting_solid_static_boxes(
	world: SimulationWorld, entity_id: int, support_dy: int
) -> PackedInt32Array:
	if not world._has_entity(entity_id):
		return PackedInt32Array()
	var pose_index: int = entity_id - 1
	return supporting_solid_static_boxes_at(
		world,
		entity_id,
		world._x[pose_index],
		world._y[pose_index],
		world._z[pose_index],
		support_dy
	)


func supporting_solid_static_boxes_at(
	world: SimulationWorld, entity_id: int, x: int, y: int, z: int, support_dy: int
) -> PackedInt32Array:
	if not world._has_entity(entity_id):
		return PackedInt32Array()
	var probe_y_res: FixedResult = Fixed.try_add(y, support_dy)
	if not probe_y_res.ok:
		return PackedInt32Array()
	return overlapping_solid_static_boxes_at(world, entity_id, x, probe_y_res.value, z)


func is_supported_by_solid(world: SimulationWorld, entity_id: int, support_dy: int) -> bool:
	return supporting_solid_static_boxes(world, entity_id, support_dy).size() > 0


func is_supported_by_solid_at(
	world: SimulationWorld, entity_id: int, x: int, y: int, z: int, support_dy: int
) -> bool:
	return supporting_solid_static_boxes_at(world, entity_id, x, y, z, support_dy).size() > 0


func is_below_min_y(world: SimulationWorld, entity_id: int, min_y: int) -> bool:
	if not world._has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	return is_below_min_y_at(
		world, entity_id, world._x[pose_index], world._y[pose_index], world._z[pose_index], min_y
	)


func is_below_min_y_at(
	world: SimulationWorld, entity_id: int, x: int, y: int, z: int, min_y: int
) -> bool:
	if not world._has_entity(entity_id):
		return false
	return y < min_y


func is_above_max_y(world: SimulationWorld, entity_id: int, max_y: int) -> bool:
	if not world._has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	return is_above_max_y_at(
		world, entity_id, world._x[pose_index], world._y[pose_index], world._z[pose_index], max_y
	)


func is_above_max_y_at(
	world: SimulationWorld, entity_id: int, x: int, y: int, z: int, max_y: int
) -> bool:
	if not world._has_entity(entity_id):
		return false
	return y > max_y


func is_outside_xz(
	world: SimulationWorld, entity_id: int, min_x: int, max_x: int, min_z: int, max_z: int
) -> bool:
	if not world._has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	return is_outside_xz_at(
		world,
		entity_id,
		world._x[pose_index],
		world._y[pose_index],
		world._z[pose_index],
		min_x,
		max_x,
		min_z,
		max_z
	)


func is_outside_xz_at(
	world: SimulationWorld,
	entity_id: int,
	x: int,
	y: int,
	z: int,
	min_x: int,
	max_x: int,
	min_z: int,
	max_z: int
) -> bool:
	if not world._has_entity(entity_id):
		return false
	return not (min_x <= x and x <= max_x and min_z <= z and z <= max_z)


func overlaps_entity(world: SimulationWorld, entity_id: int, other_id: int) -> bool:
	if not world._has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	return overlaps_entity_at(
		world, entity_id, other_id, world._x[pose_index], world._y[pose_index], world._z[pose_index]
	)


func overlaps_entity_at(
	world: SimulationWorld, entity_id: int, other_id: int, x: int, y: int, z: int
) -> bool:
	if not world._has_entity(entity_id) or not world._has_entity(other_id):
		return false
	if entity_id == other_id:
		return false
	var pose_index: int = entity_id - 1
	var other_index: int = other_id - 1
	var mover: KinematicCapsule = world._capsule_at(pose_index, x, y, z)
	var other: KinematicCapsule = world._capsule_at(
		other_index, world._x[other_index], world._y[other_index], world._z[other_index]
	)
	return mover.overlaps(other) or not mover.overlap_math_ok


func overlapping_entities(world: SimulationWorld, entity_id: int) -> PackedInt32Array:
	if not world._has_entity(entity_id):
		return PackedInt32Array()
	var pose_index: int = entity_id - 1
	return overlapping_entities_at(
		world, entity_id, world._x[pose_index], world._y[pose_index], world._z[pose_index]
	)


func overlapping_entities_at(
	world: SimulationWorld, entity_id: int, x: int, y: int, z: int
) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	if not world._has_entity(entity_id):
		return ids
	for other_id: int in range(1, world._x.size() + 1):
		if overlaps_entity_at(world, entity_id, other_id, x, y, z):
			ids.append(other_id)
	return ids


func is_pose_blocked(world: SimulationWorld, entity_id: int, x: int, y: int, z: int) -> bool:
	if not world._has_entity(entity_id):
		return true
	return (
		overlapping_solid_static_boxes_at(world, entity_id, x, y, z).size() > 0
		or overlapping_entities_at(world, entity_id, x, y, z).size() > 0
	)


func is_volume_blocked(
	world: SimulationWorld, x: int, y: int, z: int, radius: int, cylinder_height: int
) -> bool:
	if radius < 0 or cylinder_height < 0:
		return true
	var probe: KinematicCapsule = KinematicCapsule.new()
	probe.x = x
	probe.y = y
	probe.z = z
	probe.radius = radius
	probe.cylinder_height = cylinder_height
	for box_index: int in range(world._boxes.size()):
		if not world._box_solid[box_index]:
			continue
		var box: StaticAabb = world._boxes[box_index]
		if box.overlaps_capsule(probe) or not box.overlap_math_ok:
			return true
	for pose_index: int in range(world._x.size()):
		var other: KinematicCapsule = world._capsule_at(
			pose_index, world._x[pose_index], world._y[pose_index], world._z[pose_index]
		)
		if probe.overlaps(other) or not probe.overlap_math_ok:
			return true
	return false
