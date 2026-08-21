extends GutTest

## SimulationWorld 骨架：Tick 计数、姿态读写、XZ/Y 目的地阻挡、Canonical 状态哈希、可取出的 SimRng。

const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const FixedResultClass := preload("res://src/shared/fixed/fixed_result.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")
const SimRng := preload("res://src/simulation/sim_rng.gd")

const SEED_1_FIRST: int = -7995527694508729151


func test_tick_index_starts_at_zero_and_only_counts() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	assert_eq(world.tick_index, 0)
	world.tick()
	assert_eq(world.tick_index, 1)
	world.tick()
	assert_eq(world.tick_index, 2)


func test_spawn_capsule_ids_increment_and_pose_roundtrips() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var x: int = _whole(3)
	var y: int = _whole(4)
	var z: int = _whole(5)
	var first_id: int = world.spawn_capsule(x, y, z, 16)
	var second_id: int = world.spawn_capsule(0, 0, 0, 0)
	assert_eq(first_id, 1)
	assert_eq(second_id, 2)
	var pose: Dictionary = world.get_pose(first_id)
	var pose_x: int = pose.get("x", 0)
	var pose_y: int = pose.get("y", 0)
	var pose_z: int = pose.get("z", 0)
	var pose_yaw: int = pose.get("yaw", -1)
	assert_eq(pose_x, x)
	assert_eq(pose_y, y)
	assert_eq(pose_z, z)
	assert_eq(pose_yaw, 16)
	assert_true(world.set_pose(first_id, x + 1, y, z, 32))
	var updated: Dictionary = world.get_pose(first_id)
	var updated_x: int = updated.get("x", 0)
	var updated_yaw: int = updated.get("yaw", -1)
	assert_eq(updated_x, x + 1)
	assert_eq(updated_yaw, 32)
	assert_false(world.set_pose(99, 0, 0, 0, 0))


func test_hash_state_is_stable_until_a_coordinate_changes() -> void:
	var left: SimulationWorld = _two_capsule_world()
	var right: SimulationWorld = _two_capsule_world()
	var left_hash: PackedByteArray = left.hash_state()
	var right_hash: PackedByteArray = right.hash_state()
	assert_eq(left_hash.size(), 32)
	assert_eq(left_hash.hex_encode(), right_hash.hex_encode())
	left.tick()
	assert_ne(left.hash_state().hex_encode(), right_hash.hex_encode())
	assert_true(right.set_pose(1, _whole(3) + 1, _whole(4), _whole(5), 16))
	assert_ne(right.hash_state().hex_encode(), left_hash.hex_encode())


func test_hash_state_ignores_capsule_radius_and_height() -> void:
	var posed: SimulationWorld = SimulationWorld.new(1)
	posed.spawn_capsule(_whole(3), _whole(4), _whole(5), 16)
	var sized: SimulationWorld = SimulationWorld.new(1)
	sized.spawn_capsule(_whole(3), _whole(4), _whole(5), 16, _whole(1), _whole(2))
	assert_eq(posed.hash_state().hex_encode(), sized.hash_state().hex_encode())


func test_try_move_xz_in_open_space_changes_x_z_not_y_or_yaw() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var y: int = _whole(4)
	var entity_id: int = world.spawn_capsule(0, y, 0, 16)
	var dx: int = _whole(2)
	var dz: int = _whole(-1)
	assert_true(world.try_move_xz(entity_id, dx, dz))
	_assert_pose(world, entity_id, dx, y, dz, 16)


func test_try_move_xz_rejects_destination_overlap_and_keeps_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var radius: int = _whole(1)
	var along_x: int = _whole(3)
	var toward: int = _whole(2)
	var mover_id: int = world.spawn_capsule(0, 0, 0, 0, radius, 0)
	world.spawn_capsule(along_x, 0, 0, 0, radius, 0)
	assert_false(world.try_move_xz(mover_id, toward, 0))
	_assert_pose(world, mover_id, 0, 0, 0, 0)
	assert_true(world.try_move_xz(mover_id, 0, 0))
	_assert_pose(world, mover_id, 0, 0, 0, 0)
	assert_true(world.try_move_xz(mover_id, 1, 0))
	_assert_pose(world, mover_id, 1, 0, 0, 0)


func test_try_move_xz_rejects_overflow_and_unknown_id() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(FixedClass.INT64_MAX, 0, FixedClass.INT64_MAX, 8)
	assert_false(world.try_move_xz(entity_id, 1, 0))
	_assert_pose(world, entity_id, FixedClass.INT64_MAX, 0, FixedClass.INT64_MAX, 8)
	assert_false(world.try_move_xz(entity_id, 0, 1))
	_assert_pose(world, entity_id, FixedClass.INT64_MAX, 0, FixedClass.INT64_MAX, 8)
	assert_false(world.try_move_xz(0, 1, 0))
	assert_false(world.try_move_xz(-1, 1, 0))
	assert_false(world.try_move_xz(99, 1, 0))


func test_try_move_y_in_open_space_changes_y_not_x_z_or_yaw() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var x: int = _whole(3)
	var z: int = _whole(5)
	var entity_id: int = world.spawn_capsule(x, 0, z, 16)
	var dy: int = _whole(-1)
	assert_true(world.try_move_y(entity_id, dy))
	_assert_pose(world, entity_id, x, dy, z, 16)


func test_try_move_y_rejects_destination_overlap_and_keeps_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var radius: int = _whole(1)
	var cylinder_height: int = _whole(2)
	var half_height: int = cylinder_height / 2
	var contact_y: int = half_height + half_height + radius + radius
	var along_y: int = contact_y + _whole(1)
	var toward: int = _whole(1)
	var mover_id: int = world.spawn_capsule(0, 0, 0, 0, radius, cylinder_height)
	world.spawn_capsule(0, along_y, 0, 0, radius, cylinder_height)
	assert_false(world.try_move_y(mover_id, toward))
	_assert_pose(world, mover_id, 0, 0, 0, 0)
	assert_true(world.try_move_y(mover_id, 0))
	_assert_pose(world, mover_id, 0, 0, 0, 0)
	assert_true(world.try_move_y(mover_id, 1))
	_assert_pose(world, mover_id, 0, 1, 0, 0)


func test_try_move_y_rejects_overflow_unknown_id_and_overlap_math() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, FixedClass.INT64_MAX, 0, 8)
	assert_false(world.try_move_y(entity_id, 1))
	_assert_pose(world, entity_id, 0, FixedClass.INT64_MAX, 0, 8)
	assert_false(world.try_move_y(0, 1))
	assert_false(world.try_move_y(-1, 1))
	assert_false(world.try_move_y(99, 1))
	var math_world: SimulationWorld = SimulationWorld.new(1)
	var mover_id: int = math_world.spawn_capsule(FixedClass.INT64_MAX, 0, 0, 0, _whole(1), _whole(2))
	math_world.spawn_capsule(FixedClass.INT64_MIN, 0, 0, 0, _whole(1), _whole(2))
	assert_false(math_world.try_move_y(mover_id, 0))
	_assert_pose(math_world, mover_id, FixedClass.INT64_MAX, 0, 0, 0)


func test_spawn_static_box_rejects_negative_half_extents() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	assert_eq(world.spawn_static_box(0, 0, 0, -1, 0, 0), 0)
	assert_eq(world.spawn_static_box(0, 0, 0, 0, -1, 0), 0)
	assert_eq(world.spawn_static_box(0, 0, 0, 0, 0, -1), 0)
	assert_eq(world.spawn_static_box(0, 0, 0, 0, 0, 0), 1)


func test_spawn_static_box_does_not_change_hash_state() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	world.spawn_capsule(_whole(3), _whole(4), _whole(5), 16, _whole(1), _whole(2))
	var before_hex: String = world.hash_state().hex_encode()
	assert_eq(world.spawn_static_box(_whole(8), 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_eq(world.hash_state().hex_encode(), before_hex)


func test_try_move_xz_rejects_static_box_and_allows_going_around() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var radius: int = _whole(1)
	var start_x: int = _whole(4)
	var into_box: int = -_whole(2)
	var around_z: int = _whole(1)
	var mover_id: int = world.spawn_capsule(start_x, 0, 0, 0, radius, _whole(2))
	assert_eq(world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_false(world.try_move_xz(mover_id, into_box, 0))
	_assert_pose(world, mover_id, start_x, 0, 0, 0)
	assert_true(world.try_move_xz(mover_id, 0, around_z))
	_assert_pose(world, mover_id, start_x, 0, around_z, 0)


func test_try_move_y_rejects_static_box_overhead() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var radius: int = _whole(1)
	var cylinder_height: int = _whole(2)
	var toward: int = _whole(1)
	var mover_id: int = world.spawn_capsule(0, 0, 0, 0, radius, cylinder_height)
	assert_eq(world.spawn_static_box(0, _whole(4), 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_false(world.try_move_y(mover_id, toward))
	_assert_pose(world, mover_id, 0, 0, 0, 0)


func test_try_move_rejects_when_static_box_overlap_math_overflows() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var mover_id: int = world.spawn_capsule(
		FixedClass.INT64_MAX, 0, 0, 0, _whole(1), _whole(2)
	)
	assert_eq(world.spawn_static_box(FixedClass.INT64_MIN, 0, 0, 0, 0, 0), 1)
	assert_false(world.try_move_xz(mover_id, 0, 0))
	_assert_pose(world, mover_id, FixedClass.INT64_MAX, 0, 0, 0)
	assert_false(world.try_move_y(mover_id, 0))
	_assert_pose(world, mover_id, FixedClass.INT64_MAX, 0, 0, 0)


func test_get_rng_uses_constructor_seed() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var rng: SimRng = world.get_rng()
	assert_eq(rng.next_u64(), SEED_1_FIRST)


func _two_capsule_world() -> SimulationWorld:
	var world: SimulationWorld = SimulationWorld.new(1)
	world.spawn_capsule(_whole(3), _whole(4), _whole(5), 16)
	world.spawn_capsule(_whole(1), _whole(2), _whole(3), 0)
	return world


func _assert_pose(world: SimulationWorld, entity_id: int, x: int, y: int, z: int, yaw: int) -> void:
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	var pose_yaw: int = pose.get("yaw", -1)
	assert_eq(pose_x, x)
	assert_eq(pose_y, y)
	assert_eq(pose_z, z)
	assert_eq(pose_yaw, yaw)


func _whole(units: int) -> int:
	var converted: FixedResultClass = FixedClass.try_from_whole(units)
	assert_true(converted.ok)
	return converted.value
