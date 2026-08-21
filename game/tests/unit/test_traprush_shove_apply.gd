extends GutTest

## TraprushShoveApply：解码 + 冷却门闩通过后，用调用方 Q48.16 dx/dz 推开目标。
## CD-21 §2 / §5.3：基础推击独立于道具；力度与冷却秒数见 CD-63，本刀不锁定。
## 不发明默认位移，不从 payload 读 impulse/dx/dz，不调用 world.tick()。

const ShoveApply := preload("res://src/games/traprush/shove_apply.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const FixedResultClass := preload("res://src/shared/fixed/fixed_result.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")


func test_open_space_shove_moves_target_not_actor_or_tick() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var y: int = _whole(4)
	var actor_id: int = world.spawn_capsule(0, y, 0, 16)
	var target_id: int = world.spawn_capsule(0, y, _whole(5), 8)
	var dx: int = _whole(2)
	var dz: int = _whole(-1)
	var result: Dictionary = _apply(
		world,
		actor_id,
		target_id,
		{"intent": PlayerIntentNames.SHOVE},
		0,
		-1,
		1,
		dx,
		dz
	)
	assert_true(_ok(result))
	assert_true(_shoved(result))
	_assert_pose(world, actor_id, 0, y, 0, 16)
	_assert_pose(world, target_id, dx, y, _whole(4), 8)
	assert_eq(world.tick_index, 0)


func test_cooldown_not_ready_is_ok_without_shove() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var actor_id: int = world.spawn_capsule(1, 2, 3, 4)
	var target_id: int = world.spawn_capsule(5, 6, 7, 8)
	var result: Dictionary = _apply(
		world,
		actor_id,
		target_id,
		{"intent": PlayerIntentNames.SHOVE},
		14,
		10,
		5,
		_whole(3),
		_whole(3)
	)
	assert_true(_ok(result))
	assert_false(_shoved(result))
	_assert_pose(world, actor_id, 1, 2, 3, 4)
	_assert_pose(world, target_id, 5, 6, 7, 8)
	assert_eq(world.tick_index, 0)


func test_self_shove_fails_and_keeps_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var actor_id: int = world.spawn_capsule(1, 2, 3, 4)
	var result: Dictionary = _apply(
		world,
		actor_id,
		actor_id,
		{"intent": PlayerIntentNames.SHOVE},
		0,
		-1,
		1,
		_whole(4),
		_whole(5)
	)
	assert_false(_ok(result))
	assert_false(result.has("shoved"))
	_assert_pose(world, actor_id, 1, 2, 3, 4)


func test_wrong_or_missing_intent_fails_and_keeps_poses() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var actor_id: int = world.spawn_capsule(1, 2, 3, 4)
	var target_id: int = world.spawn_capsule(5, 6, 7, 8)
	assert_false(_ok(_apply(
		world, actor_id, target_id, {}, 0, -1, 1, 1, 1
	)))
	assert_false(_ok(_apply(
		world, actor_id, target_id, {"intent": 1}, 0, -1, 1, 1, 1
	)))
	assert_false(_ok(_apply(
		world,
		actor_id,
		target_id,
		{"intent": PlayerIntentNames.MOVE, "dx": 1, "dz": 1},
		0,
		-1,
		1,
		_whole(4),
		_whole(5)
	)))
	assert_false(_ok(_apply(
		world,
		actor_id,
		target_id,
		{"intent": PlayerIntentNames.JUMP},
		0,
		-1,
		1,
		1,
		1
	)))
	_assert_pose(world, actor_id, 1, 2, 3, 4)
	_assert_pose(world, target_id, 5, 6, 7, 8)


func test_payload_dx_does_not_override_caller_displacement() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var actor_id: int = world.spawn_capsule(0, 0, 0, 16)
	var target_id: int = world.spawn_capsule(0, 0, _whole(8), 8)
	var caller_dx: int = _whole(2)
	var caller_dz: int = 0
	var result: Dictionary = _apply(
		world,
		actor_id,
		target_id,
		{
			"intent": PlayerIntentNames.SHOVE,
			"dx": _whole(9),
			"dz": _whole(7),
			"impulse": 50,
			"force": 12,
			"x": 999,
			"z": 777,
		},
		0,
		-1,
		1,
		caller_dx,
		caller_dz
	)
	assert_true(_ok(result))
	assert_true(_shoved(result))
	_assert_pose(world, actor_id, 0, 0, 0, 16)
	_assert_pose(world, target_id, caller_dx, 0, _whole(8), 8)


func test_blocked_shove_is_still_shoved_and_does_not_pass_through_wall() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var radius: int = _whole(1)
	var start_x: int = _whole(4)
	var into_box: int = -_whole(2)
	var actor_id: int = world.spawn_capsule(0, 0, _whole(10), 16, radius, _whole(2))
	var target_id: int = world.spawn_capsule(start_x, 0, 0, 8, radius, _whole(2))
	assert_eq(world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	var result: Dictionary = _apply(
		world,
		actor_id,
		target_id,
		{"intent": PlayerIntentNames.SHOVE},
		0,
		-1,
		1,
		into_box,
		0
	)
	assert_true(_ok(result))
	assert_true(_shoved(result))
	_assert_pose(world, actor_id, 0, 0, _whole(10), 16)
	_assert_pose(world, target_id, start_x, 0, 0, 8)
	assert_eq(world.tick_index, 0)


func test_zero_displacement_is_legal_shove() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var actor_id: int = world.spawn_capsule(1, 2, 3, 4)
	var target_id: int = world.spawn_capsule(5, 6, 7, 8)
	var result: Dictionary = _apply(
		world,
		actor_id,
		target_id,
		{"intent": PlayerIntentNames.SHOVE},
		0,
		-1,
		1,
		0,
		0
	)
	assert_true(_ok(result))
	assert_true(_shoved(result))
	_assert_pose(world, actor_id, 1, 2, 3, 4)
	_assert_pose(world, target_id, 5, 6, 7, 8)


func test_missing_actor_or_target_pose_fails() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var actor_id: int = world.spawn_capsule(1, 2, 3, 4)
	var target_id: int = world.spawn_capsule(5, 6, 7, 8)
	assert_false(_ok(_apply(
		world, 99, target_id, {"intent": PlayerIntentNames.SHOVE}, 0, -1, 1, 1, 1
	)))
	assert_false(_ok(_apply(
		world, actor_id, 99, {"intent": PlayerIntentNames.SHOVE}, 0, -1, 1, 1, 1
	)))
	_assert_pose(world, actor_id, 1, 2, 3, 4)
	_assert_pose(world, target_id, 5, 6, 7, 8)


func _apply(
	world: SimulationWorld,
	actor_id: int,
	target_id: int,
	payload: Dictionary,
	now_tick: int,
	last_shove_tick: int,
	cooldown_ticks: int,
	dx: int,
	dz: int
) -> Dictionary:
	return ShoveApply.apply(
		world,
		actor_id,
		target_id,
		payload,
		now_tick,
		last_shove_tick,
		cooldown_ticks,
		dx,
		dz
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


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _shoved(result: Dictionary) -> bool:
	var flag: bool = result.get("shoved", false)
	return flag


func _whole(units: int) -> int:
	var converted: FixedResultClass = FixedClass.try_from_whole(units)
	assert_true(converted.ok)
	return converted.value
