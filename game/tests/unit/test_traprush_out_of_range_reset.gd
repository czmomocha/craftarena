extends GutTest

## TraprushOutOfRangeReset：出界则写回调用方检查点落点。不 tick、不计数 N、
## 不接重力。空区间拒绝。STUB_HALF 是开发桩，不是产品边界。

const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")

const CELL: int = 65536


func test_stub_half_is_eight_cells() -> void:
	assert_eq(OutOfRangeReset.STUB_HALF, 8 * CELL)


func test_inside_closed_range_does_not_reset() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0, CELL / 8, CELL / 8)
	var result: Dictionary = OutOfRangeReset.try_apply(
		world, entity_id, _spawn(), _track(), -CELL, CELL, -CELL, CELL, -CELL, CELL
	)
	var ok: bool = result.get("ok", false)
	var reset: bool = result.get("reset", true)
	assert_true(ok)
	assert_false(reset)
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)
	assert_eq(world.tick_index, 0)


func test_on_max_xz_bound_is_inside() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(CELL, 0, CELL, 0, CELL / 8, CELL / 8)
	var result: Dictionary = OutOfRangeReset.try_apply(
		world, entity_id, _spawn(), _track(), -CELL, CELL, -CELL, CELL, -CELL, CELL
	)
	var ok: bool = result.get("ok", false)
	var reset: bool = result.get("reset", true)
	assert_true(ok)
	assert_false(reset)


func test_past_max_x_resets_to_start_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(2 * CELL, 0, 0, 7, CELL / 8, CELL / 8)
	var result: Dictionary = OutOfRangeReset.try_apply(
		world, entity_id, _spawn(), _track(), -CELL, CELL, -CELL, CELL, -CELL, CELL
	)
	var ok: bool = result.get("ok", false)
	var reset: bool = result.get("reset", false)
	assert_true(ok)
	assert_true(reset)
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	var yaw: int = pose.get("yaw", -1)
	assert_eq(pose_x, 0)
	assert_eq(pose_y, 0)
	assert_eq(pose_z, 0)
	assert_eq(yaw, 0)
	assert_eq(world.tick_index, 0)


func test_below_min_y_resets() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, -CELL - 1, 0, 0, CELL / 8, CELL / 8)
	var result: Dictionary = OutOfRangeReset.try_apply(
		world, entity_id, _spawn(), _track(), -CELL, CELL, -4 * CELL, 4 * CELL, -4 * CELL, 4 * CELL
	)
	var reset: bool = result.get("reset", false)
	assert_true(reset)
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_y: int = pose.get("y", -2)
	assert_eq(pose_y, 0)


func test_empty_interval_is_rejected() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0, CELL / 8, CELL / 8)
	var result: Dictionary = OutOfRangeReset.try_apply(
		world, entity_id, _spawn(), _track(), 0, 0, 1, 0, -CELL, CELL
	)
	var ok: bool = result.get("ok", true)
	assert_false(ok)
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)


func test_null_world_or_unknown_entity_fails() -> void:
	var null_result: Dictionary = OutOfRangeReset.try_apply(
		null, 1, _spawn(), _track(), -CELL, CELL, -CELL, CELL, -CELL, CELL
	)
	var null_ok: bool = null_result.get("ok", true)
	assert_false(null_ok)
	var world: SimulationWorld = SimulationWorld.new(1)
	var missing: Dictionary = OutOfRangeReset.try_apply(
		world, 99, _spawn(), _track(), -CELL, CELL, -CELL, CELL, -CELL, CELL
	)
	var missing_ok: bool = missing.get("ok", true)
	assert_false(missing_ok)


func _spawn() -> CheckpointSpawn:
	return CheckpointSpawn.new(
		{"ok": true, "x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		[]
	)


func _track() -> CheckpointTrack:
	return CheckpointTrack.new()
