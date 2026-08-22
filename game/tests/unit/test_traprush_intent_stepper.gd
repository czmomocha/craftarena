extends GutTest

## TraprushIntentStepper：把 Move / Jump / ResetToCheckpoint 接到 SimulationWorld。
## CD-21 §3 / §8：短跳是按钮意图。位移、jump_dy、support_dy 由调用方传入。
## 不发明默认速度、跳跃高度、重力或 coyote。Jump 仅在 is_supported_by_solid 时
## try_move_y_until_blocked：开阔地终点与成功 try_move_y 相同；路径上有盒则
## {ok: true} 且停在最后未阻挡样本；对照 try_move_y 仍 false 且不写。
## Move 走 try_move_xz_until_blocked：开阔地终点与成功 try_move_xz 相同；路径上有盒/胶囊则
## {ok: true} 且停在最后未阻挡样本；对照 try_move_xz 仍 false 且不写。第一步即挡则保持起点。
## 可选 yaw 在接触推进之后写入。本刀不调用 world.tick()，不应用 Shove。
## 测试里的位移 / support_dy / jump_dy 只写在本文件。

const IntentStepper := preload("res://src/games/traprush/intent_stepper.gd")
const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const Track := preload("res://src/games/traprush/checkpoint_track.gd")
const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const FixedResultClass := preload("res://src/shared/fixed/fixed_result.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const ONE_METER_Q48_16: int = 65536
const QUARTER_TURN_BAM: int = 16384


func test_open_space_move_changes_xz_not_y_or_tick() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var y: int = _whole(4)
	var entity_id: int = world.spawn_capsule(0, y, 0, 16)
	var dx: int = _whole(2)
	var dz: int = _whole(-1)
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.MOVE, "dx": dx, "dz": dz},
		0,
		_unused_spawn(),
		_unused_track()
	)
	assert_true(_ok(result))
	_assert_pose(world, entity_id, dx, y, dz, 16)
	assert_eq(world.tick_index, 0)


func test_open_space_move_matches_successful_try_move_xz() -> void:
	var start_x: int = _whole(3)
	var y: int = _whole(4)
	var start_z: int = _whole(5)
	var dx: int = _whole(2)
	var dz: int = _whole(-1)
	var yaw: int = 16
	var radius: int = _whole(1)
	var height: int = _whole(2)
	var stepper_world: SimulationWorld = SimulationWorld.new(1)
	var stepper_id: int = stepper_world.spawn_capsule(start_x, y, start_z, yaw, radius, height)
	var xz_world: SimulationWorld = SimulationWorld.new(1)
	var xz_id: int = xz_world.spawn_capsule(start_x, y, start_z, yaw, radius, height)
	assert_true(xz_world.try_move_xz(xz_id, dx, dz))
	var result: Dictionary = _apply(
		stepper_world,
		stepper_id,
		{"intent": PlayerIntentNames.MOVE, "dx": dx, "dz": dz},
		0,
		_unused_spawn(),
		_unused_track()
	)
	assert_true(_ok(result))
	_assert_pose_matches(stepper_world, stepper_id, xz_world, xz_id)
	assert_eq(stepper_world.tick_index, 0)


func test_move_blocked_by_other_capsule_is_ok_and_keeps_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var radius: int = _whole(1)
	var along_x: int = _whole(3)
	var toward: int = _whole(2)
	var mover_id: int = world.spawn_capsule(0, 0, 0, 0, radius, 0)
	world.spawn_capsule(along_x, 0, 0, 0, radius, 0)
	var contrast: SimulationWorld = SimulationWorld.new(1)
	var contrast_id: int = contrast.spawn_capsule(0, 0, 0, 0, radius, 0)
	contrast.spawn_capsule(along_x, 0, 0, 0, radius, 0)
	assert_false(contrast.try_move_xz(contrast_id, toward, 0))
	_assert_pose(contrast, contrast_id, 0, 0, 0, 0)
	var result: Dictionary = _apply(
		world,
		mover_id,
		{"intent": PlayerIntentNames.MOVE, "dx": toward, "dz": 0},
		0,
		_unused_spawn(),
		_unused_track()
	)
	assert_true(_ok(result))
	_assert_pose(world, mover_id, 0, 0, 0, 0)


func test_move_stops_at_last_unblocked_sample_before_box() -> void:
	var radius: int = _whole(1)
	var height: int = _whole(2)
	var start_x: int = _whole(10)
	var dx: int = -_whole(10)
	var yaw: int = 8
	var stepper_world: SimulationWorld = SimulationWorld.new(1)
	var stepper_id: int = stepper_world.spawn_capsule(start_x, 0, 0, yaw, radius, height)
	assert_eq(stepper_world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	var contrast: SimulationWorld = SimulationWorld.new(1)
	var contrast_id: int = contrast.spawn_capsule(start_x, 0, 0, yaw, radius, height)
	assert_eq(contrast.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_false(contrast.try_move_xz(contrast_id, dx, 0))
	_assert_pose(contrast, contrast_id, start_x, 0, 0, yaw)
	var oracle: SimulationWorld = SimulationWorld.new(1)
	var oracle_id: int = oracle.spawn_capsule(start_x, 0, 0, yaw, radius, height)
	assert_eq(oracle.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_true(oracle.try_move_xz_until_blocked(oracle_id, dx, 0))
	var result: Dictionary = _apply(
		stepper_world,
		stepper_id,
		{"intent": PlayerIntentNames.MOVE, "dx": dx, "dz": 0},
		0,
		_unused_spawn(),
		_unused_track()
	)
	assert_true(_ok(result))
	_assert_pose_matches(stepper_world, stepper_id, oracle, oracle_id)
	var after: Dictionary = stepper_world.get_pose(stepper_id)
	var after_x: int = after.get("x", start_x)
	assert_ne(after_x, start_x)
	assert_eq(stepper_world.tick_index, 0)


func test_move_stops_at_last_unblocked_sample_before_capsule() -> void:
	var radius: int = _whole(1)
	var start_x: int = 0
	var other_x: int = _whole(10)
	var dx: int = _whole(10)
	var yaw: int = 0
	var stepper_world: SimulationWorld = SimulationWorld.new(1)
	var stepper_id: int = stepper_world.spawn_capsule(start_x, 0, 0, yaw, radius, 0)
	stepper_world.spawn_capsule(other_x, 0, 0, yaw, radius, 0)
	var contrast: SimulationWorld = SimulationWorld.new(1)
	var contrast_id: int = contrast.spawn_capsule(start_x, 0, 0, yaw, radius, 0)
	contrast.spawn_capsule(other_x, 0, 0, yaw, radius, 0)
	assert_false(contrast.try_move_xz(contrast_id, dx, 0))
	_assert_pose(contrast, contrast_id, start_x, 0, 0, yaw)
	var oracle: SimulationWorld = SimulationWorld.new(1)
	var oracle_id: int = oracle.spawn_capsule(start_x, 0, 0, yaw, radius, 0)
	oracle.spawn_capsule(other_x, 0, 0, yaw, radius, 0)
	assert_true(oracle.try_move_xz_until_blocked(oracle_id, dx, 0))
	var result: Dictionary = _apply(
		stepper_world,
		stepper_id,
		{"intent": PlayerIntentNames.MOVE, "dx": dx, "dz": 0},
		0,
		_unused_spawn(),
		_unused_track()
	)
	assert_true(_ok(result))
	_assert_pose_matches(stepper_world, stepper_id, oracle, oracle_id)
	var after: Dictionary = stepper_world.get_pose(stepper_id)
	var after_x: int = after.get("x", start_x)
	assert_ne(after_x, start_x)
	assert_eq(stepper_world.tick_index, 0)


func test_optional_yaw_updates_even_when_move_is_blocked() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var radius: int = _whole(1)
	var along_x: int = _whole(3)
	var toward: int = _whole(2)
	var mover_id: int = world.spawn_capsule(0, 0, 0, 8, radius, 0)
	world.spawn_capsule(along_x, 0, 0, 0, radius, 0)
	var result: Dictionary = _apply(
		world,
		mover_id,
		{
			"intent": PlayerIntentNames.MOVE,
			"dx": toward,
			"dz": 0,
			"yaw_bam": QUARTER_TURN_BAM,
		},
		0,
		_unused_spawn(),
		_unused_track()
	)
	assert_true(_ok(result))
	_assert_pose(world, mover_id, 0, 0, 0, QUARTER_TURN_BAM)


func test_optional_yaw_updates_after_contact_advance() -> void:
	var radius: int = _whole(1)
	var height: int = _whole(2)
	var start_x: int = _whole(10)
	var dx: int = -_whole(10)
	var yaw: int = 8
	var stepper_world: SimulationWorld = SimulationWorld.new(1)
	var stepper_id: int = stepper_world.spawn_capsule(start_x, 0, 0, yaw, radius, height)
	assert_eq(stepper_world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	var oracle: SimulationWorld = SimulationWorld.new(1)
	var oracle_id: int = oracle.spawn_capsule(start_x, 0, 0, yaw, radius, height)
	assert_eq(oracle.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_true(oracle.try_move_xz_until_blocked(oracle_id, dx, 0))
	var contact: Dictionary = oracle.get_pose(oracle_id)
	var contact_x: int = contact.get("x", start_x)
	assert_ne(contact_x, start_x)
	var result: Dictionary = _apply(
		stepper_world,
		stepper_id,
		{
			"intent": PlayerIntentNames.MOVE,
			"dx": dx,
			"dz": 0,
			"yaw_bam": QUARTER_TURN_BAM,
		},
		0,
		_unused_spawn(),
		_unused_track()
	)
	assert_true(_ok(result))
	_assert_pose(stepper_world, stepper_id, contact_x, 0, 0, QUARTER_TURN_BAM)


func test_omitted_yaw_does_not_change_yaw_after_move() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 16)
	var dx: int = _whole(1)
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.MOVE, "dx": dx, "dz": 0},
		0,
		_unused_spawn(),
		_unused_track()
	)
	assert_true(_ok(result))
	_assert_pose(world, entity_id, dx, 0, 0, 16)


func test_jump_uses_caller_dy_not_payload_metrics() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var x: int = _whole(3)
	var z: int = _whole(5)
	var stand_y: int = _whole(4)
	var support_dy: int = -_whole(1)
	var caller_dy: int = _whole(2)
	var entity_id: int = world.spawn_capsule(x, stand_y, z, 16, _whole(1), _whole(2))
	assert_eq(world.spawn_static_box(x, 0, z, _whole(1), _whole(1), _whole(1)), 1)
	assert_true(world.is_supported_by_solid(entity_id, support_dy))
	var result: Dictionary = _apply(
		world,
		entity_id,
		{
			"intent": PlayerIntentNames.JUMP,
			"dy": _whole(9),
			"height": 64,
			"y": 888,
			"x": 999,
			"z": 777,
		},
		caller_dy,
		_unused_spawn(),
		_unused_track(),
		support_dy
	)
	assert_true(_ok(result))
	_assert_pose(world, entity_id, x, stand_y + caller_dy, z, 16)
	assert_eq(world.tick_index, 0)


func test_airborne_jump_is_ok_and_keeps_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var x: int = _whole(3)
	var y: int = _whole(4)
	var z: int = _whole(5)
	var support_dy: int = -_whole(1)
	var jump_dy: int = _whole(2)
	var entity_id: int = world.spawn_capsule(x, y, z, 16, _whole(1), _whole(2))
	assert_false(world.is_supported_by_solid(entity_id, support_dy))
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.JUMP, "dy": _whole(9), "height": 64},
		jump_dy,
		_unused_spawn(),
		_unused_track(),
		support_dy
	)
	assert_true(_ok(result))
	_assert_pose(world, entity_id, x, y, z, 16)
	assert_eq(world.tick_index, 0)


func test_support_dy_zero_overlapping_solid_can_jump() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var jump_dy: int = _whole(2)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 16)
	assert_eq(world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_true(world.is_supported_by_solid(entity_id, 0))
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.JUMP},
		jump_dy,
		_unused_spawn(),
		_unused_track(),
		0
	)
	assert_true(_ok(result))
	_assert_pose(world, entity_id, 0, jump_dy, 0, 16)
	assert_eq(world.tick_index, 0)


func test_non_solid_underfoot_cannot_jump() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var stand_y: int = _whole(4)
	var support_dy: int = -_whole(1)
	var jump_dy: int = _whole(2)
	var entity_id: int = world.spawn_capsule(0, stand_y, 0, 16, _whole(1), _whole(2))
	assert_eq(world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_true(world.set_static_box_solid(1, false))
	assert_false(world.is_supported_by_solid(entity_id, support_dy))
	assert_false(world.is_supported_by_solid(entity_id, 0))
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.JUMP},
		jump_dy,
		_unused_spawn(),
		_unused_track(),
		support_dy
	)
	assert_true(_ok(result))
	_assert_pose(world, entity_id, 0, stand_y, 0, 16)
	assert_eq(world.tick_index, 0)


func test_move_ignores_support_dy() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var y: int = _whole(4)
	var dx: int = _whole(2)
	var support_dy: int = -_whole(1)
	var entity_id: int = world.spawn_capsule(0, y, 0, 16, _whole(1), _whole(2))
	assert_eq(world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_true(world.is_supported_by_solid(entity_id, support_dy))
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.MOVE, "dx": dx, "dz": 0},
		_whole(3),
		_unused_spawn(),
		_unused_track(),
		support_dy
	)
	assert_true(_ok(result))
	_assert_pose(world, entity_id, dx, y, 0, 16)
	assert_eq(world.tick_index, 0)


func test_reset_ignores_support_dy() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var start_x: int = 0
	var start_y: int = ONE_METER_Q48_16
	var entity_id: int = world.spawn_capsule(_whole(9), _whole(8), _whole(7), 99)
	var spawn: CheckpointSpawn = _two_checkpoint_spawn()
	var track: Track = Track.new(PackedInt32Array([10, 20]))
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.RESET_TO_CHECKPOINT},
		_whole(3),
		spawn,
		track,
		-_whole(1)
	)
	assert_true(_ok(result))
	_assert_pose(world, entity_id, start_x, start_y, 0, 0)
	assert_eq(world.tick_index, 0)


func test_grounded_jump_blocked_by_overhead_matches_until_blocked() -> void:
	var stand_y: int = _whole(4)
	var support_dy: int = -_whole(1)
	var jump_dy: int = _whole(1)
	var radius: int = _whole(1)
	var height: int = _whole(2)
	var yaw: int = 16
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, stand_y, 0, yaw, radius, height)
	assert_eq(world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_eq(world.spawn_static_box(0, _whole(8), 0, _whole(1), _whole(1), _whole(1)), 2)
	assert_true(world.is_supported_by_solid(entity_id, support_dy))
	var contrast: SimulationWorld = SimulationWorld.new(1)
	var contrast_id: int = contrast.spawn_capsule(0, stand_y, 0, yaw, radius, height)
	assert_eq(contrast.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_eq(contrast.spawn_static_box(0, _whole(8), 0, _whole(1), _whole(1), _whole(1)), 2)
	assert_false(contrast.try_move_y(contrast_id, jump_dy))
	_assert_pose(contrast, contrast_id, 0, stand_y, 0, yaw)
	var oracle: SimulationWorld = SimulationWorld.new(1)
	var oracle_id: int = oracle.spawn_capsule(0, stand_y, 0, yaw, radius, height)
	assert_eq(oracle.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_eq(oracle.spawn_static_box(0, _whole(8), 0, _whole(1), _whole(1), _whole(1)), 2)
	assert_true(oracle.try_move_y_until_blocked(oracle_id, jump_dy))
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.JUMP},
		jump_dy,
		_unused_spawn(),
		_unused_track(),
		support_dy
	)
	assert_true(_ok(result))
	_assert_pose_matches(world, entity_id, oracle, oracle_id)
	assert_eq(world.tick_index, 0)


func test_jump_stops_at_last_unblocked_sample_before_ceiling() -> void:
	var stand_y: int = _whole(4)
	var support_dy: int = -_whole(1)
	var jump_dy: int = _whole(10)
	var radius: int = _whole(1)
	var height: int = _whole(2)
	var yaw: int = 16
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, stand_y, 0, yaw, radius, height)
	assert_eq(world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_eq(world.spawn_static_box(0, _whole(10), 0, _whole(1), _whole(1), _whole(1)), 2)
	assert_true(world.is_supported_by_solid(entity_id, support_dy))
	var contrast: SimulationWorld = SimulationWorld.new(1)
	var contrast_id: int = contrast.spawn_capsule(0, stand_y, 0, yaw, radius, height)
	assert_eq(contrast.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_eq(contrast.spawn_static_box(0, _whole(10), 0, _whole(1), _whole(1), _whole(1)), 2)
	assert_false(contrast.try_move_y(contrast_id, jump_dy))
	_assert_pose(contrast, contrast_id, 0, stand_y, 0, yaw)
	var oracle: SimulationWorld = SimulationWorld.new(1)
	var oracle_id: int = oracle.spawn_capsule(0, stand_y, 0, yaw, radius, height)
	assert_eq(oracle.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	assert_eq(oracle.spawn_static_box(0, _whole(10), 0, _whole(1), _whole(1), _whole(1)), 2)
	assert_true(oracle.try_move_y_until_blocked(oracle_id, jump_dy))
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.JUMP},
		jump_dy,
		_unused_spawn(),
		_unused_track(),
		support_dy
	)
	assert_true(_ok(result))
	_assert_pose_matches(world, entity_id, oracle, oracle_id)
	var after: Dictionary = world.get_pose(entity_id)
	var after_y: int = after.get("y", stand_y)
	assert_ne(after_y, stand_y)
	assert_eq(world.tick_index, 0)


func test_zero_displacement_and_zero_jump_dy_are_legal() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(1, 2, 3, 4)
	var move_result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.MOVE, "dx": 0, "dz": 0},
		99,
		_unused_spawn(),
		_unused_track()
	)
	assert_true(_ok(move_result))
	_assert_pose(world, entity_id, 1, 2, 3, 4)
	var jump_result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.JUMP},
		0,
		_unused_spawn(),
		_unused_track()
	)
	assert_true(_ok(jump_result))
	_assert_pose(world, entity_id, 1, 2, 3, 4)


func test_reset_lands_on_spawn_table_and_ignores_payload_coordinates() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var start_x: int = 0
	var start_y: int = ONE_METER_Q48_16
	var entity_id: int = world.spawn_capsule(_whole(9), _whole(8), _whole(7), 99)
	var spawn: CheckpointSpawn = _two_checkpoint_spawn()
	var track: Track = Track.new(PackedInt32Array([10, 20]))
	var result: Dictionary = _apply(
		world,
		entity_id,
		{
			"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
			"x": 123456,
			"y": 654321,
			"z": 111,
			"yaw_bam": 99,
		},
		0,
		spawn,
		track
	)
	assert_true(_ok(result))
	_assert_pose(world, entity_id, start_x, start_y, 0, 0)
	assert_true(track.try_accept(10))
	var after_checkpoint: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.RESET_TO_CHECKPOINT, "x": 1, "y": 2, "z": 3},
		0,
		spawn,
		track
	)
	assert_true(_ok(after_checkpoint))
	_assert_pose(world, entity_id, ONE_METER_Q48_16, 0, 2 * ONE_METER_Q48_16, QUARTER_TURN_BAM)


func test_failed_reset_pose_does_not_set_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(5, 6, 7, 8)
	var spawn: CheckpointSpawn = CheckpointSpawn.new(
		{"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		[]
	)
	var track: Track = Track.new(PackedInt32Array([10]))
	assert_true(track.try_accept(10))
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.RESET_TO_CHECKPOINT},
		0,
		spawn,
		track
	)
	assert_false(_ok(result))
	_assert_pose(world, entity_id, 5, 6, 7, 8)


func test_shove_is_not_applied() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(1, 2, 3, 4)
	var result: Dictionary = _apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.SHOVE, "dx": _whole(4), "dz": _whole(5)},
		_whole(3),
		_unused_spawn(),
		_unused_track()
	)
	assert_false(_ok(result))
	_assert_pose(world, entity_id, 1, 2, 3, 4)


func test_unknown_or_malformed_intent_fails_and_keeps_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(1, 2, 3, 4)
	var spawn: CheckpointSpawn = _unused_spawn()
	var track: Track = _unused_track()
	assert_false(_ok(_apply(
		world, entity_id, {}, 0, spawn, track
	)))
	assert_false(_ok(_apply(
		world, entity_id, {"intent": 1}, 0, spawn, track
	)))
	assert_false(_ok(_apply(
		world, entity_id, {"intent": PlayerIntentNames.USE_ITEM}, 0, spawn, track
	)))
	assert_false(_ok(_apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.MOVE, "dz": 1},
		0,
		spawn,
		track
	)))
	_assert_pose(world, entity_id, 1, 2, 3, 4)


func test_unknown_entity_id_fails() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	world.spawn_capsule(0, 0, 0, 0)
	var result: Dictionary = _apply(
		world,
		99,
		{"intent": PlayerIntentNames.MOVE, "dx": 1, "dz": 1},
		0,
		_unused_spawn(),
		_unused_track()
	)
	assert_false(_ok(result))
	_assert_pose(world, 1, 0, 0, 0, 0)


func test_identical_inputs_yield_identical_hash_state() -> void:
	var left: SimulationWorld = SimulationWorld.new(1)
	var right: SimulationWorld = SimulationWorld.new(1)
	var left_id: int = left.spawn_capsule(0, 0, 0, 16, _whole(1), 0)
	var right_id: int = right.spawn_capsule(0, 0, 0, 16, _whole(1), 0)
	var payload: Dictionary = {
		"intent": PlayerIntentNames.MOVE,
		"dx": _whole(1),
		"dz": 0,
		"yaw_bam": QUARTER_TURN_BAM,
	}
	var spawn: CheckpointSpawn = _unused_spawn()
	var track: Track = _unused_track()
	assert_true(_ok(_apply(left, left_id, payload, 0, spawn, track)))
	assert_true(_ok(_apply(right, right_id, payload, 0, spawn, track)))
	assert_eq(left.hash_state().hex_encode(), right.hash_state().hex_encode())
	assert_true(_ok(_apply(left, left_id, payload, 0, spawn, track)))
	assert_true(_ok(_apply(right, right_id, payload, 0, spawn, track)))
	assert_eq(left.hash_state().hex_encode(), right.hash_state().hex_encode())
	assert_eq(left.tick_index, 0)
	assert_eq(right.tick_index, 0)


func _two_checkpoint_spawn() -> CheckpointSpawn:
	var start: Dictionary = {
		"x": 0,
		"y": ONE_METER_Q48_16,
		"z": 0,
		"yaw_bam": 0,
	}
	var poses: Array[Dictionary] = [
		{
			"x": ONE_METER_Q48_16,
			"y": 0,
			"z": 2 * ONE_METER_Q48_16,
			"yaw_bam": QUARTER_TURN_BAM,
		},
		{
			"x": 3 * ONE_METER_Q48_16,
			"y": 0,
			"z": 4 * ONE_METER_Q48_16,
			"yaw_bam": 0,
		},
	]
	return CheckpointSpawn.new(start, poses)


func _unused_spawn() -> CheckpointSpawn:
	return CheckpointSpawn.new({"x": 0, "y": 0, "z": 0, "yaw_bam": 0}, [])


func _unused_track() -> Track:
	return Track.new(PackedInt32Array())


func _apply(
	world: SimulationWorld,
	entity_id: int,
	payload: Dictionary,
	jump_dy: int,
	spawn: CheckpointSpawn,
	track: Track,
	support_dy: int = 0
) -> Dictionary:
	return IntentStepper.apply(
		world, entity_id, payload, jump_dy, spawn, track, support_dy
	)


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


func _assert_pose_matches(
	left: SimulationWorld,
	left_id: int,
	right: SimulationWorld,
	right_id: int
) -> void:
	var expected: Dictionary = right.get_pose(right_id)
	var x: int = expected.get("x", -1)
	var y: int = expected.get("y", -1)
	var z: int = expected.get("z", -1)
	var yaw: int = expected.get("yaw", -1)
	_assert_pose(left, left_id, x, y, z, yaw)


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _whole(units: int) -> int:
	var converted: FixedResultClass = FixedClass.try_from_whole(units)
	assert_true(converted.ok)
	return converted.value
