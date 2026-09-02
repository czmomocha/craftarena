extends GutTest

## C5 第 15 章：单次扫掠取样预算。超限拒绝整段，不粗化密度。
## 权威路径断言，不是占位表现。

const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const MoveGd := preload("res://src/simulation/simulation_world_move.gd")
const PlaceholderSpecGd := preload("res://src/shared/placeholder_spec.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")

const PROD_RADIUS: int = PlaceholderSpecGd.CHARACTER_RADIUS
const PROD_HEIGHT: int = PlaceholderSpecGd.CHARACTER_HEIGHT


func test_budget_constant_is_256() -> void:
	assert_eq(MoveGd.MAX_SWEEP_STEPS, 256)


func test_uncapped_ceil_and_min_one() -> void:
	assert_eq(MoveGd.uncapped_sweep_step_count(0, PROD_RADIUS), 1)
	assert_eq(MoveGd.uncapped_sweep_step_count(PROD_RADIUS, PROD_RADIUS), 1)
	assert_eq(MoveGd.uncapped_sweep_step_count(PROD_RADIUS + 1, PROD_RADIUS), 2)
	assert_eq(MoveGd.uncapped_sweep_step_count(10 * PROD_RADIUS, PROD_RADIUS), 10)
	assert_eq(MoveGd.uncapped_sweep_step_count(0, 0), 0)
	assert_eq(MoveGd.uncapped_sweep_step_count(FixedClass.SCALE, -1), 0)


func test_one_cell_at_production_radius_is_eight_in_budget_steps() -> void:
	assert_eq(MoveGd.uncapped_sweep_step_count(FixedClass.SCALE, PROD_RADIUS), 8)
	assert_eq(MoveGd.sweep_step_count(FixedClass.SCALE, PROD_RADIUS), 8)


func test_exactly_max_steps_stays_in_budget() -> void:
	var length: int = MoveGd.MAX_SWEEP_STEPS * PROD_RADIUS
	assert_eq(MoveGd.uncapped_sweep_step_count(length, PROD_RADIUS), 256)
	assert_eq(MoveGd.sweep_step_count(length, PROD_RADIUS), 256)


func test_one_unit_past_max_is_rejected() -> void:
	var length: int = MoveGd.MAX_SWEEP_STEPS * PROD_RADIUS + 1
	assert_eq(MoveGd.uncapped_sweep_step_count(length, PROD_RADIUS), 257)
	assert_eq(MoveGd.sweep_step_count(length, PROD_RADIUS), 0)


func test_tiny_radius_one_cell_is_the_2026_08_28_hang_and_now_rejects() -> void:
	assert_eq(MoveGd.uncapped_sweep_step_count(FixedClass.SCALE, 1), 65536)
	assert_eq(MoveGd.sweep_step_count(FixedClass.SCALE, 1), 0)


func test_try_move_y_over_budget_keeps_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var start_y: int = _whole(10)
	var entity_id: int = world.spawn_capsule(0, start_y, 0, 0, 1, 1)
	var rejected: bool = world.try_move_y(entity_id, -FixedClass.SCALE)
	assert_false(rejected)
	_assert_pose(world, entity_id, 0, start_y, 0, 0)


func test_try_move_xz_over_budget_keeps_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 8, 1, 1)
	var rejected: bool = world.try_move_xz(entity_id, FixedClass.SCALE, 0)
	assert_false(rejected)
	_assert_pose(world, entity_id, 0, 0, 0, 8)


func test_until_blocked_over_budget_does_not_walk_clamped_samples() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var start_y: int = _whole(10)
	var entity_id: int = world.spawn_capsule(0, start_y, 0, 0, 1, 1)
	var rejected: bool = world.try_move_y_until_blocked(entity_id, -FixedClass.SCALE)
	assert_false(rejected)
	_assert_pose(world, entity_id, 0, start_y, 0, 0)
	var xz_id: int = world.spawn_capsule(_whole(1), 0, 0, 0, 1, 1)
	var xz_rejected: bool = world.try_move_xz_until_blocked(xz_id, FixedClass.SCALE, 0)
	assert_false(xz_rejected)
	_assert_pose(world, xz_id, _whole(1), 0, 0, 0)


func test_production_radius_can_travel_32_cells_in_open_space() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var dx: int = 32 * FixedClass.SCALE
	var entity_id: int = world.spawn_capsule(0, 0, 0, 16, PROD_RADIUS, PROD_HEIGHT)
	var moved: bool = world.try_move_xz(entity_id, dx, 0)
	assert_true(moved)
	_assert_pose(world, entity_id, dx, 0, 0, 16)


func test_production_radius_rejects_just_past_32_cells() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var dx: int = 32 * FixedClass.SCALE + 1
	var entity_id: int = world.spawn_capsule(0, 0, 0, 16, PROD_RADIUS, PROD_HEIGHT)
	var rejected: bool = world.try_move_xz(entity_id, dx, 0)
	assert_false(rejected)
	_assert_pose(world, entity_id, 0, 0, 0, 16)


func test_existing_ten_cell_sweep_with_one_cell_radius_still_passes() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var radius: int = _whole(1)
	var dx: int = _whole(10)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 16, radius, _whole(2))
	var moved: bool = world.try_move_xz(entity_id, dx, 0)
	assert_true(moved)
	_assert_pose(world, entity_id, dx, 0, 0, 16)


func test_zero_radius_destination_only_does_not_spend_budget() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var dest_x: int = 40 * FixedClass.SCALE
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0, 0, 0)
	var moved: bool = world.try_move_xz(entity_id, dest_x, 0)
	assert_true(moved)
	_assert_pose(world, entity_id, dest_x, 0, 0, 0)


func _whole(cells: int) -> int:
	return cells * FixedClass.SCALE


func _assert_pose(
	world: SimulationWorld, entity_id: int, x: int, y: int, z: int, yaw: int
) -> void:
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	var pose_yaw: int = pose.get("yaw", -1)
	assert_eq(pose_x, x)
	assert_eq(pose_y, y)
	assert_eq(pose_z, z)
	assert_eq(pose_yaw, yaw)
