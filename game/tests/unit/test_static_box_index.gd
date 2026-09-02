extends GutTest

## C5 第 16 章：静态盒均匀格阔相。窄相与 ID 顺序必须与全量扫描一致。
## 权威占用断言，不是占位表现。

const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const IndexGd := preload("res://src/simulation/simulation_world_index.gd")
const KinematicCapsuleGd := preload("res://src/simulation/kinematic_capsule.gd")
const PlaceholderSpecGd := preload("res://src/shared/placeholder_spec.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")

const PROD_RADIUS: int = PlaceholderSpecGd.CHARACTER_RADIUS
const PROD_HEIGHT: int = PlaceholderSpecGd.CHARACTER_HEIGHT


func test_cell_of_floors_toward_negative_infinity() -> void:
	assert_eq(IndexGd.cell_of(0), 0)
	assert_eq(IndexGd.cell_of(FixedClass.SCALE - 1), 0)
	assert_eq(IndexGd.cell_of(FixedClass.SCALE), 1)
	assert_eq(IndexGd.cell_of(-1), -1)
	assert_eq(IndexGd.cell_of(-FixedClass.SCALE), -1)
	assert_eq(IndexGd.cell_of(-FixedClass.SCALE - 1), -2)


func test_budget_constants() -> void:
	assert_eq(IndexGd.BUCKET, FixedClass.SCALE)
	assert_eq(IndexGd.MAX_CELLS, 125)


func test_near_and_far_boxes_match_naive_and_far_is_not_a_candidate() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var near_id: int = world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1))
	var far_id: int = world.spawn_static_box(_whole(20), 0, 0, _whole(1), _whole(1), _whole(1))
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0, PROD_RADIUS, PROD_HEIGHT)
	_assert_ids(world.overlapping_static_boxes(entity_id), _naive_ids(world, entity_id, 2))
	_assert_ids(world.overlapping_static_boxes(entity_id), PackedInt32Array([near_id]))
	var capsule: KinematicCapsuleGd = _prod_capsule(0, 0, 0)
	var candidates: PackedInt32Array = world.index.candidates_for_capsule(capsule)
	var has_near: bool = _has_id(candidates, near_id)
	var has_far: bool = _has_id(candidates, far_id)
	assert_true(has_near)
	assert_false(has_far)


func test_negative_cell_box_matches_naive() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var box_id: int = world.spawn_static_box(
		-_whole(3), 0, -_whole(2), _whole(1), _whole(1), _whole(1)
	)
	var entity_id: int = world.spawn_capsule(
		-_whole(3), 0, -_whole(2), 0, PROD_RADIUS, PROD_HEIGHT
	)
	_assert_ids(world.overlapping_static_boxes(entity_id), PackedInt32Array([box_id]))
	_assert_ids(world.overlapping_static_boxes(entity_id), _naive_ids(world, entity_id, 1))


func test_solid_toggle_still_filters_after_broadphase() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var box_id: int = world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1))
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0, PROD_RADIUS, PROD_HEIGHT)
	_assert_ids(world.overlapping_solid_static_boxes(entity_id), PackedInt32Array([box_id]))
	var toggled: bool = world.set_static_box_solid(box_id, false)
	assert_true(toggled)
	_assert_ids(world.overlapping_static_boxes(entity_id), PackedInt32Array([box_id]))
	_assert_ids(world.overlapping_solid_static_boxes(entity_id), PackedInt32Array())
	var blocked: bool = world.is_pose_blocked(entity_id, 0, 0, 0)
	assert_false(blocked)


func test_overflow_box_is_always_tested_and_counts_as_overlap() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var box_id: int = world.spawn_static_box(FixedClass.INT64_MAX, 0, 0, 1, 1, 1)
	assert_eq(box_id, 1)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0, PROD_RADIUS, PROD_HEIGHT)
	_assert_ids(world.overlapping_static_boxes(entity_id), PackedInt32Array([box_id]))
	var blocked: bool = world.is_pose_blocked(entity_id, 0, 0, 0)
	assert_true(blocked)


func test_huge_box_over_cell_budget_still_matches_naive() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var half: int = 10 * FixedClass.SCALE
	var box_id: int = world.spawn_static_box(0, 0, 0, half, half, half)
	var entity_id: int = world.spawn_capsule(_whole(8), 0, 0, 0, PROD_RADIUS, PROD_HEIGHT)
	_assert_ids(world.overlapping_static_boxes(entity_id), _naive_ids(world, entity_id, 1))
	_assert_ids(world.overlapping_static_boxes(entity_id), PackedInt32Array([box_id]))


func test_scattered_boxes_match_naive_at_several_poses() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var halves: int = _whole(1)
	assert_gt(world.spawn_static_box(0, 0, 0, halves, halves, halves), 0)
	assert_gt(world.spawn_static_box(_whole(4), 0, 0, halves, halves, halves), 0)
	assert_gt(world.spawn_static_box(0, 0, _whole(4), halves, halves, halves), 0)
	assert_gt(world.spawn_static_box(-_whole(4), _whole(1), 0, halves, halves, halves), 0)
	assert_gt(world.spawn_static_box(_whole(2), 0, -_whole(3), halves, halves, halves), 0)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0, PROD_RADIUS, PROD_HEIGHT)
	var poses: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(_whole(4), 0, 0),
		Vector3i(0, 0, _whole(4)),
		Vector3i(-_whole(4), _whole(1), 0),
		Vector3i(_whole(10), 0, 0),
		Vector3i(_whole(2), 0, -_whole(3)),
	]
	for pose: Vector3i in poses:
		var moved: bool = world.set_pose(entity_id, pose.x, pose.y, pose.z, 0)
		assert_true(moved)
		_assert_ids(
			world.overlapping_static_boxes_at(entity_id, pose.x, pose.y, pose.z),
			_naive_ids_at(world, entity_id, pose.x, pose.y, pose.z, 5)
		)


func test_volume_blocked_uses_the_same_box_candidates() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	assert_gt(world.spawn_static_box(_whole(2), 0, 0, _whole(1), _whole(1), _whole(1)), 0)
	var open: bool = world.is_volume_blocked(0, 0, 0, PROD_RADIUS, PROD_HEIGHT)
	assert_false(open)
	var hit: bool = world.is_volume_blocked(_whole(2), 0, 0, PROD_RADIUS, PROD_HEIGHT)
	assert_true(hit)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0, PROD_RADIUS, PROD_HEIGHT)
	var open_pose: bool = world.is_pose_blocked(entity_id, 0, 0, 0)
	var hit_pose: bool = world.is_pose_blocked(entity_id, _whole(2), 0, 0)
	assert_false(open_pose)
	assert_true(hit_pose)


func _prod_capsule(x: int, y: int, z: int) -> KinematicCapsuleGd:
	var capsule: KinematicCapsuleGd = KinematicCapsuleGd.new()
	capsule.x = x
	capsule.y = y
	capsule.z = z
	capsule.radius = PROD_RADIUS
	capsule.cylinder_height = PROD_HEIGHT
	return capsule


func _naive_ids(world: SimulationWorld, entity_id: int, box_count: int) -> PackedInt32Array:
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_x: int = pose.get("x", 0)
	var pose_y: int = pose.get("y", 0)
	var pose_z: int = pose.get("z", 0)
	return _naive_ids_at(world, entity_id, pose_x, pose_y, pose_z, box_count)


func _naive_ids_at(
	world: SimulationWorld, entity_id: int, x: int, y: int, z: int, box_count: int
) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	var box_id: int = 1
	while box_id <= box_count:
		if world.overlaps_static_box_at(entity_id, box_id, x, y, z):
			ids.append(box_id)
		box_id += 1
	return ids


func _whole(cells: int) -> int:
	return cells * FixedClass.SCALE


func _has_id(ids: PackedInt32Array, want: int) -> bool:
	for box_id: int in ids:
		if box_id == want:
			return true
	return false


func _assert_ids(actual: PackedInt32Array, expected: PackedInt32Array) -> void:
	assert_eq(actual.size(), expected.size())
	var i: int = 0
	while i < actual.size():
		assert_eq(actual[i], expected[i])
		i += 1
