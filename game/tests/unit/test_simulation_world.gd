extends GutTest

## SimulationWorld 骨架：Tick 计数、姿态读写、Canonical 状态哈希、可取出的 SimRng。

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


func test_get_rng_uses_constructor_seed() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var rng: SimRng = world.get_rng()
	assert_eq(rng.next_u64(), SEED_1_FIRST)


func _two_capsule_world() -> SimulationWorld:
	var world: SimulationWorld = SimulationWorld.new(1)
	world.spawn_capsule(_whole(3), _whole(4), _whole(5), 16)
	world.spawn_capsule(_whole(1), _whole(2), _whole(3), 0)
	return world


func _whole(units: int) -> int:
	var converted: FixedResultClass = FixedClass.try_from_whole(units)
	assert_true(converted.ok)
	return converted.value
