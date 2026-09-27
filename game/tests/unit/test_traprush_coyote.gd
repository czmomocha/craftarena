extends GutTest

## 土狼时间：离开支撑后 COYOTE_TICKS 内仍可起跳；N+1 不能；空中已跳过不能再跳。
## 支撑上与现在一致。状态由世界+tick 观察，不进 hash_state。占位桩，不是产品定稿。

const AuthoringPreviewGd := preload("res://src/creator/authoring_preview.gd")
const AuthoringSessionGd := preload("res://src/creator/authoring_session.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const Coyote := preload("res://src/games/traprush/coyote.gd")
const IntentStepper := preload("res://src/games/traprush/intent_stepper.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const Track := preload("res://src/games/traprush/checkpoint_track.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const STAND_Y: int = CELL
const SUPPORT_DY: int = -CELL
const JUMP_DY: int = CELL / 4


func test_coyote_ticks_is_six_placeholder() -> void:
	assert_eq(TraprushPlayStubsGd.COYOTE_TICKS, 6)


func test_can_jump_on_support_ignores_window() -> void:
	assert_true(Coyote.can_jump(true, 9, -1, true, 0))
	assert_true(Coyote.can_jump(true, 0, 0, false, TraprushPlayStubsGd.COYOTE_TICKS))


func test_never_supported_cannot_coyote() -> void:
	assert_false(Coyote.can_jump(false, 3, -1, false, TraprushPlayStubsGd.COYOTE_TICKS))


func test_window_allows_one_through_n_and_rejects_n_plus_one() -> void:
	var n: int = TraprushPlayStubsGd.COYOTE_TICKS
	var last: int = 10
	for age: int in range(1, n + 1):
		assert_true(
			Coyote.can_jump(false, last + age, last, false, n),
			"age %s should jump" % age
		)
	assert_false(Coyote.can_jump(false, last + n + 1, last, false, n))


func test_consumed_blocks_second_airborne_jump() -> void:
	var n: int = TraprushPlayStubsGd.COYOTE_TICKS
	assert_true(Coyote.can_jump(false, 12, 10, false, n))
	assert_false(Coyote.can_jump(false, 12, 10, true, n))


func test_stepper_jumps_at_age_one_and_n_not_n_plus_one() -> void:
	var n: int = TraprushPlayStubsGd.COYOTE_TICKS
	_assert_stepper_jump_at_age(1, true)
	_assert_stepper_jump_at_age(n, true)
	_assert_stepper_jump_at_age(n + 1, false)


func test_stepper_consumed_jump_cannot_jump_again() -> void:
	var world: SimulationWorld = _ledge_world()
	var entity_id: int = 1
	var last: int = 0
	var now_tick: int = 2
	var first: Dictionary = _step_jump(world, entity_id, now_tick, last, false)
	assert_true(_ok(first))
	assert_true(_flag(first, "consumed"))
	var hopped: Dictionary = world.get_pose(entity_id)
	var hopped_y: int = _int(hopped, "y")
	assert_eq(hopped_y, STAND_Y + JUMP_DY)
	var keep_last: int = _int(first, "last_supported_tick")
	var second: Dictionary = IntentStepper.apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.JUMP},
		JUMP_DY,
		_unused_spawn(),
		_unused_track(),
		SUPPORT_DY,
		now_tick,
		keep_last,
		true,
		TraprushPlayStubsGd.COYOTE_TICKS
	)
	assert_true(_ok(second))
	var after: Dictionary = world.get_pose(entity_id)
	assert_eq(_int(after, "y"), hopped_y)


func test_stepper_grounded_jump_matches_pre_coyote() -> void:
	var world: SimulationWorld = _ledge_world()
	var entity_id: int = 1
	assert_true(world.is_supported_by_solid(entity_id, SUPPORT_DY))
	var result: Dictionary = IntentStepper.apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.JUMP},
		JUMP_DY,
		_unused_spawn(),
		_unused_track(),
		SUPPORT_DY,
		0,
		-1,
		false,
		TraprushPlayStubsGd.COYOTE_TICKS
	)
	assert_true(_ok(result))
	var pose: Dictionary = world.get_pose(entity_id)
	assert_eq(_int(pose, "y"), STAND_Y + JUMP_DY)
	assert_true(_flag(result, "consumed"))


func test_session_walk_off_jumps_at_n_not_n_plus_one() -> void:
	var n: int = TraprushPlayStubsGd.COYOTE_TICKS
	var hopped: TraprushMatchSessionGd = _ledge_session()
	_walk_off(hopped)
	for _step: int in range(n):
		hopped.commit_tick()
	var before: Dictionary = hopped.player_pose(0)
	var before_y: int = _int(before, "y")
	assert_true(hopped.apply_player_intent(0, {"intent": PlayerIntentNames.JUMP}))
	var after: Dictionary = hopped.player_pose(0)
	assert_eq(_int(after, "y"), before_y + JUMP_DY)
	var blocked: TraprushMatchSessionGd = _ledge_session()
	_walk_off(blocked)
	for _step: int in range(n + 1):
		blocked.commit_tick()
	var rest: Dictionary = blocked.player_pose(0)
	var rest_y: int = _int(rest, "y")
	assert_true(blocked.apply_player_intent(0, {"intent": PlayerIntentNames.JUMP}))
	var still: Dictionary = blocked.player_pose(0)
	assert_eq(_int(still, "y"), rest_y)


func test_session_hash_does_not_include_coyote_fields() -> void:
	var left: TraprushMatchSessionGd = _ledge_session()
	var right: TraprushMatchSessionGd = _ledge_session()
	assert_eq(left.hash_state(), right.hash_state())
	_walk_off(left)
	left.commit_tick()
	var player: Dictionary = left._players[0]
	player["last_supported_tick"] = 99
	player["jump_consumed"] = true
	var hashed: String = left.hash_state()
	player["last_supported_tick"] = -1
	player["jump_consumed"] = false
	assert_eq(left.hash_state(), hashed)


func test_preview_advance_counts_coyote() -> void:
	var n: int = TraprushPlayStubsGd.COYOTE_TICKS
	var hopped: AuthoringPreviewGd = _ledge_preview()
	assert_true(hopped.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	hopped.play_jump_dy = JUMP_DY
	hopped.play_support_dy = SUPPORT_DY
	hopped.play_fall_dy = TraprushPlayStubsGd.FALL_DY
	hopped.play_coyote_ticks = n
	hopped.intents.refresh_coyote(hopped)
	assert_true(hopped.try_apply_play_intent(_move(CELL, 0)))
	for _step: int in range(n):
		assert_true(hopped.try_advance_play())
	var before: Dictionary = hopped.play_world.get_pose(hopped.player_id)
	var before_y: int = _int(before, "y")
	assert_true(hopped.try_apply_play_intent({"intent": PlayerIntentNames.JUMP}))
	var after: Dictionary = hopped.play_world.get_pose(hopped.player_id)
	assert_eq(_int(after, "y"), before_y + JUMP_DY)
	var blocked: AuthoringPreviewGd = _ledge_preview()
	assert_true(blocked.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	blocked.play_jump_dy = JUMP_DY
	blocked.play_support_dy = SUPPORT_DY
	blocked.play_fall_dy = TraprushPlayStubsGd.FALL_DY
	blocked.play_coyote_ticks = n
	blocked.intents.refresh_coyote(blocked)
	assert_true(blocked.try_apply_play_intent(_move(CELL, 0)))
	for _step: int in range(n + 1):
		assert_true(blocked.try_advance_play())
	var rest: Dictionary = blocked.play_world.get_pose(blocked.player_id)
	var rest_y: int = _int(rest, "y")
	assert_true(blocked.try_apply_play_intent({"intent": PlayerIntentNames.JUMP}))
	var still: Dictionary = blocked.play_world.get_pose(blocked.player_id)
	assert_eq(_int(still, "y"), rest_y)


func _assert_stepper_jump_at_age(age: int, should_hop: bool) -> void:
	var world: SimulationWorld = _ledge_world()
	var entity_id: int = 1
	var last: int = 0
	var result: Dictionary = _step_jump(world, entity_id, last + age, last, false)
	assert_true(_ok(result))
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_y: int = _int(pose, "y")
	if should_hop:
		assert_eq(pose_y, STAND_Y + JUMP_DY)
		assert_true(_flag(result, "consumed"))
	else:
		assert_eq(pose_y, STAND_Y)
		assert_false(_flag(result, "consumed"))


func _step_jump(
	world: SimulationWorld,
	entity_id: int,
	now_tick: int,
	last_supported_tick: int,
	consumed: bool
) -> Dictionary:
	world.set_pose(entity_id, CELL, STAND_Y, 0, 0)
	return IntentStepper.apply(
		world,
		entity_id,
		{"intent": PlayerIntentNames.JUMP},
		JUMP_DY,
		_unused_spawn(),
		_unused_track(),
		SUPPORT_DY,
		now_tick,
		last_supported_tick,
		consumed,
		TraprushPlayStubsGd.COYOTE_TICKS
	)


func _ledge_world() -> SimulationWorld:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, STAND_Y, 0, 0, PLAY_RADIUS, PLAY_RADIUS)
	assert_eq(entity_id, 1)
	assert_eq(world.spawn_static_box(0, 0, 0, CELL / 2, CELL / 2, CELL / 2), 1)
	assert_true(world.is_supported_by_solid(entity_id, SUPPORT_DY))
	return world


func _ledge_session() -> TraprushMatchSessionGd:
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		TraprushTopologyCompilerGd.compile(_ledge_authoring()),
		1,
		1,
		[{"dx": 0, "dy": 0, "dz": 0}],
		PLAY_RADIUS,
		PLAY_RADIUS
	)
	assert_not_null(session)
	TraprushPlayStubsGd.apply_match(session)
	return session


func _ledge_preview() -> AuthoringPreviewGd:
	var session: AuthoringSessionGd = AuthoringSessionGd.new()
	session.world = _ledge_authoring()
	var preview: AuthoringPreviewGd = AuthoringPreviewGd.new()
	assert_true(preview.connect_from(session))
	return preview


func _ledge_authoring() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	assert_true(world.put(SharedComponentRecordGd.create(2, {
		"transform": {"x": 0, "y": -CELL, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid"],
		},
	})))
	return world


func _walk_off(session: TraprushMatchSessionGd) -> void:
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_false(session.player_supported_by_solid(0))


func _move(dx: int, dz: int) -> Dictionary:
	return {"intent": PlayerIntentNames.MOVE, "dx": dx, "dz": dz}


func _unused_spawn() -> CheckpointSpawn:
	return CheckpointSpawn.new({"x": 0, "y": 0, "z": 0, "yaw_bam": 0}, [])


func _unused_track() -> Track:
	return Track.new(PackedInt32Array())


func _ok(result: Dictionary) -> bool:
	return _flag(result, "ok")


func _flag(body: Dictionary, key: String) -> bool:
	var raw: Variant = body.get(key, false)
	if typeof(raw) != TYPE_BOOL:
		return false
	var flag: bool = raw
	return flag


func _int(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	var value: int = raw
	return value
