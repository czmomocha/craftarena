extends GutTest

## TRAPRUSH match session: one compiled topology loaded into a shared
## authoritative SimulationWorld with 1~8 players. Per-player checkpoint
## progress, finish tick and portal latch; destructible crates are shared.
## Caller supplies spawn offsets and motion stubs. Same course + same intent
## tape -> same hash sequence. No network, no settlement, no online writes.
## Live standings derive from accepted_count / finish_tick. Never settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushStanding := preload("res://src/games/traprush/standing.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8


func test_create_bounds_player_count() -> void:
	var bundle: SimulationBundle = _compile_course_01()
	assert_not_null(bundle)
	assert_null(TraprushMatchSession.create(bundle, 1, 0, [], PLAY_RADIUS, PLAY_RADIUS))
	assert_null(TraprushMatchSession.create(bundle, 1, 9, _offsets(9), PLAY_RADIUS, PLAY_RADIUS))
	assert_null(TraprushMatchSession.create(bundle, 1, 2, _offsets(1), PLAY_RADIUS, PLAY_RADIUS))
	var one: TraprushMatchSession = TraprushMatchSession.create(bundle, 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS)
	assert_not_null(one)
	assert_eq(one.player_count(), 1)
	var eight: TraprushMatchSession = TraprushMatchSession.create(bundle, 1, 8, _offsets(8), PLAY_RADIUS, PLAY_RADIUS)
	assert_not_null(eight)
	assert_eq(eight.player_count(), 8)
	assert_ne(one.player_capsule_id(0), eight.player_capsule_id(7))


func test_two_players_progress_independently() -> void:
	var session: TraprushMatchSession = _two_player_session()
	assert_eq(session.player_accepted_count(0), 1)
	assert_eq(session.player_accepted_count(1), 1)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(session.player_accepted_count(0), 2)
	assert_eq(session.player_last_accepted_id(0), 2)
	assert_eq(session.player_accepted_count(1), 1)
	assert_eq(session.tick_index(), 0)


func test_shared_crate_break_visible_to_both() -> void:
	var session: TraprushMatchSession = _two_player_session()
	assert_eq(session.destructible_alive_count(), 1)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_true(session.apply_player_intent(1, _move(0, CELL)))
	var blocked: Dictionary = session.player_pose(1)
	var blocked_z: int = blocked.get("z", -1)
	assert_lt(blocked_z, CELL)
	session.use_item_damage = 1
	session.use_item_reach_dz = CELL
	assert_true(session.apply_player_intent(1, _use_item()))
	assert_eq(session.destructible_alive_count(), 0)
	assert_true(session.apply_player_intent(1, _move(0, CELL)))
	var opened: Dictionary = session.player_pose(1)
	var opened_z: int = opened.get("z", -1)
	assert_gte(opened_z, CELL)


func test_reset_only_moves_that_player() -> void:
	var session: TraprushMatchSession = _two_player_session()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var before: Dictionary = session.player_pose(1)
	var before_x: int = before.get("x", -3)
	var before_z: int = before.get("z", -3)
	assert_true(session.apply_player_intent(0, _reset()))
	var pose0: Dictionary = session.player_pose(0)
	var pose1: Dictionary = session.player_pose(1)
	var x0: int = pose0.get("x", -1)
	var x1: int = pose1.get("x", -2)
	var z1: int = pose1.get("z", -2)
	assert_eq(x0, 0)
	assert_eq(x1, before_x)
	assert_eq(z1, before_z)


func test_finish_tick_is_per_player() -> void:
	var session: TraprushMatchSession = _two_player_session()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var landed: Dictionary = session.player_pose(0)
	var landed_y: int = landed.get("y", -1)
	assert_eq(landed_y, CELL)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(session.player_accepted_count(0), 3)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(session.player_finish_tick(0), 0)
	assert_eq(session.player_finish_tick(1), -1)
	assert_eq(session.tick_index(), 0)
	var standing: Dictionary = TraprushStanding.from_players([
		{
			"accepted_count": session.player_accepted_count(0),
			"finish_tick": session.player_finish_tick(0),
		},
		{
			"accepted_count": session.player_accepted_count(1),
			"finish_tick": session.player_finish_tick(1),
		},
	])
	var ok: bool = standing.get("ok", false)
	assert_true(ok)
	var rows_raw: Variant = standing.get("rows", [])
	assert_eq(typeof(rows_raw), TYPE_ARRAY)
	var rows: Array = rows_raw
	assert_eq(rows.size(), 2)
	var first_raw: Variant = rows[0]
	var second_raw: Variant = rows[1]
	assert_eq(typeof(first_raw), TYPE_DICTIONARY)
	assert_eq(typeof(second_raw), TYPE_DICTIONARY)
	var first: Dictionary = first_raw
	var second: Dictionary = second_raw
	var first_slot: int = first.get("slot", -1)
	var first_place: int = first.get("place", 0)
	var first_finished: bool = first.get("finished", false)
	var second_slot: int = second.get("slot", -1)
	var second_place: int = second.get("place", 0)
	var mvp_slot: int = standing.get("mvp_slot", -2)
	assert_eq(first_slot, 0)
	assert_eq(first_place, 1)
	assert_eq(first_finished, true)
	assert_eq(second_slot, 1)
	assert_eq(second_place, 2)
	assert_eq(mvp_slot, 0)


func test_oversize_move_is_rejected_without_teleport() -> void:
	assert_eq(TraprushMatchSession.MOVE_STEP_MAX, CELL)
	assert_true(TraprushMatchSession.move_step_allowed(CELL, 0))
	assert_true(TraprushMatchSession.move_step_allowed(0, -CELL))
	assert_true(TraprushMatchSession.move_step_allowed(CELL, CELL))
	assert_false(TraprushMatchSession.move_step_allowed(CELL + 1, 0))
	assert_false(TraprushMatchSession.move_step_allowed(0, -CELL - 1))
	var session: TraprushMatchSession = _two_player_session()
	var before: Dictionary = session.player_pose(0)
	var before_x: int = before.get("x", -1)
	assert_false(session.apply_player_intent(0, _move(CELL + 1, 0)))
	var blocked: Dictionary = session.player_pose(0)
	var blocked_x: int = blocked.get("x", -2)
	assert_eq(blocked_x, before_x)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var moved: Dictionary = session.player_pose(0)
	var moved_x: int = moved.get("x", -3)
	assert_eq(moved_x, before_x + CELL)


func test_shove_nearest_other_capsule_along_xz() -> void:
	assert_eq(TraprushMatchSession.SHOVE_STEP_MAX, CELL)
	assert_eq(TraprushMatchSession.SHOVE_REACH_MAX, CELL)
	assert_true(TraprushMatchSession.shove_step_allowed(0))
	assert_true(TraprushMatchSession.shove_step_allowed(CELL))
	assert_false(TraprushMatchSession.shove_step_allowed(-1))
	assert_false(TraprushMatchSession.shove_step_allowed(CELL + 1))
	var session: TraprushMatchSession = _two_player_session()
	session.shove_step = CELL / 4
	session.shove_cooldown_ticks = 1
	var actor_before: Dictionary = session.player_pose(0)
	var target_before: Dictionary = session.player_pose(1)
	var actor_z: int = actor_before.get("z", 1)
	var target_z: int = target_before.get("z", 1)
	assert_lt(target_z, actor_z)
	assert_true(session.apply_player_intent(0, _shove()))
	var actor_after: Dictionary = session.player_pose(0)
	var target_after: Dictionary = session.player_pose(1)
	var actor_after_z: int = actor_after.get("z", 2)
	var target_after_z: int = target_after.get("z", 2)
	assert_eq(actor_after_z, actor_z)
	assert_eq(target_after_z, target_z - CELL / 4)


func test_shove_without_target_or_oversize_step_is_rejected() -> void:
	var one: TraprushMatchSession = TraprushMatchSession.create(
		_compile_course_01(), 1, 1, _offsets(1), PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(one)
	one.shove_step = CELL / 4
	assert_false(one.apply_player_intent(0, _shove()))
	var two: TraprushMatchSession = _two_player_session()
	var before: Dictionary = two.player_pose(1)
	var before_z: int = before.get("z", -1)
	two.shove_step = CELL + 1
	assert_false(two.apply_player_intent(0, _shove()))
	var blocked: Dictionary = two.player_pose(1)
	var blocked_z: int = blocked.get("z", -2)
	assert_eq(blocked_z, before_z)
	two.shove_step = CELL / 4
	assert_true(two.apply_player_intent(1, _move(CELL, 0)))
	assert_true(two.apply_player_intent(1, _move(CELL, 0)))
	assert_false(two.apply_player_intent(0, _shove()))
	var far: Dictionary = two.player_pose(1)
	var far_z: int = far.get("z", -3)
	assert_eq(far_z, before_z)


func test_shove_picks_nearest_slot_and_respects_cooldown() -> void:
	var three: TraprushMatchSession = TraprushMatchSession.create(
		_compile_course_01(), 1, 3, _offsets(3), PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(three)
	three.shove_step = CELL / 4
	three.shove_cooldown_ticks = 1
	var slot2_before: Dictionary = three.player_pose(2)
	var slot2_z: int = slot2_before.get("z", 1)
	var slot1_before: Dictionary = three.player_pose(1)
	var slot1_z: int = slot1_before.get("z", 1)
	assert_true(three.apply_player_intent(0, _shove()))
	var slot1_after: Dictionary = three.player_pose(1)
	var slot2_after: Dictionary = three.player_pose(2)
	var slot1_after_z: int = slot1_after.get("z", 2)
	var slot2_after_z: int = slot2_after.get("z", 2)
	assert_lt(slot1_after_z, slot1_z)
	assert_eq(slot2_after_z, slot2_z)
	var two: TraprushMatchSession = _two_player_session()
	two.shove_step = CELL / 4
	two.shove_cooldown_ticks = 1
	assert_true(two.apply_player_intent(0, _shove()))
	var first: Dictionary = two.player_pose(1)
	var first_z: int = first.get("z", 1)
	assert_true(two.apply_player_intent(0, _shove()))
	var cooled: Dictionary = two.player_pose(1)
	var cooled_z: int = cooled.get("z", 3)
	assert_eq(cooled_z, first_z)
	two.commit_tick()
	assert_true(two.apply_player_intent(0, _shove()))
	var second: Dictionary = two.player_pose(1)
	var second_z: int = second.get("z", 4)
	assert_eq(second_z, first_z - CELL / 4)


func test_commit_tick_advances_and_intents_do_not() -> void:
	var session: TraprushMatchSession = _two_player_session()
	assert_eq(session.tick_index(), 0)
	session.commit_tick()
	assert_eq(session.tick_index(), 1)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(session.tick_index(), 1)
	session.commit_tick()
	session.commit_tick()
	assert_eq(session.tick_index(), 3)


func test_same_tape_same_hash_sequence() -> void:
	var tape: Array = [
		[0, _move(CELL, 0)],
		[-1, {}],
		[1, _move(0, CELL)],
		[-1, {}],
		[0, _move(CELL, 0)],
		[-1, {}],
	]
	var first: Array[String] = _run_tape(tape)
	var second: Array[String] = _run_tape(tape)
	assert_eq(first, second)
	assert_gt(first.size(), 0)
	var shorter: Array[String] = _run_tape([[-1, {}]])
	assert_ne(first[first.size() - 1], shorter[shorter.size() - 1])


func test_range_defaults_off_so_two_cell_move_stays() -> void:
	var session: TraprushMatchSession = _two_player_session()
	assert_false(session.range_enabled)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 2 * CELL)
	assert_eq(session.player_accepted_count(0), 2)


func test_tight_range_resets_before_occupying_next_pad() -> void:
	var session: TraprushMatchSession = _two_player_session()
	session.enable_play_range(CELL)
	assert_true(session.range_enabled)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)
	assert_eq(session.player_accepted_count(0), 1)


func test_out_of_range_reset_does_not_rewind_progress() -> void:
	var session: TraprushMatchSession = _two_player_session()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(session.player_accepted_count(0), 2)
	assert_true(session.apply_player_intent(0, _reset()))
	var expected: Dictionary = session.player_pose(0)
	session.enable_play_range(2 * CELL)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var after: Dictionary = session.player_pose(0)
	var after_x: int = after.get("x", -3)
	var after_z: int = after.get("z", -3)
	var expected_x: int = expected.get("x", -4)
	var expected_z: int = expected.get("z", -4)
	assert_eq(session.player_accepted_count(0), 2)
	assert_eq(after_x, expected_x)
	assert_eq(after_z, expected_z)
	assert_ne(after_x, 3 * CELL)


func test_enable_play_range_zero_disables() -> void:
	var session: TraprushMatchSession = _two_player_session()
	session.enable_play_range(CELL)
	session.enable_play_range(0)
	assert_false(session.range_enabled)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 2 * CELL)


func test_zero_fall_dy_commit_keeps_spawn_y() -> void:
	var session: TraprushMatchSession = _two_player_session()
	assert_eq(session.fall_dy, 0)
	var before: Dictionary = session.player_pose(0)
	var before_y: int = before.get("y", 1)
	session.commit_tick()
	var after: Dictionary = session.player_pose(0)
	var after_y: int = after.get("y", 2)
	assert_eq(after_y, before_y)


func test_fall_dy_settles_on_spawn_footing_then_jump_lands() -> void:
	var session: TraprushMatchSession = _two_player_session()
	session.jump_dy = CELL / 4
	session.support_dy = -CELL
	session.fall_dy = -CELL
	session.commit_tick()
	var rest: Dictionary = session.player_pose(0)
	var rest_y: int = rest.get("y", 1)
	assert_true(session.apply_player_intent(0, _jump()))
	var hopped: Dictionary = session.player_pose(0)
	var hopped_y: int = hopped.get("y", 2)
	assert_eq(hopped_y, rest_y + CELL / 4)
	session.commit_tick()
	var landed: Dictionary = session.player_pose(0)
	var landed_y: int = landed.get("y", 3)
	assert_eq(landed_y, rest_y)


func test_fall_off_spawn_footing_drops_y() -> void:
	var session: TraprushMatchSession = _two_player_session()
	session.fall_dy = -CELL
	session.commit_tick()
	var rest: Dictionary = session.player_pose(0)
	var rest_y: int = rest.get("y", 1)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	session.commit_tick()
	var dropped: Dictionary = session.player_pose(0)
	var dropped_y: int = dropped.get("y", 2)
	assert_lt(dropped_y, rest_y)


func test_fall_off_spawn_footing_then_range_resets_to_spawn() -> void:
	var session: TraprushMatchSession = _two_player_session()
	session.fall_dy = -CELL
	session.enable_play_range(8 * CELL)
	session.commit_tick()
	var rest: Dictionary = session.player_pose(0)
	var rest_y: int = rest.get("y", 1)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var walked: Dictionary = session.player_pose(0)
	var walked_x: int = walked.get("x", -1)
	assert_eq(walked_x, CELL)
	var saw_drop: bool = false
	var saw_reset: bool = false
	for _step: int in range(16):
		session.commit_tick()
		var pose: Dictionary = session.player_pose(0)
		var pose_y: int = pose.get("y", 2)
		var pose_x: int = pose.get("x", -1)
		if pose_y < rest_y:
			saw_drop = true
		if saw_drop and pose_x == 0:
			saw_reset = true
			break
	assert_true(saw_drop)
	assert_true(saw_reset)
	var spawn: Dictionary = session.player_pose(0)
	var spawn_x: int = spawn.get("x", -1)
	assert_eq(spawn_x, 0)


func _jump() -> Dictionary:
	return {"intent": PlayerIntentNames.JUMP}


func _run_tape(tape: Array) -> Array[String]:
	var session: TraprushMatchSession = _two_player_session()
	var hashes: Array[String] = []
	for step: Variant in tape:
		var pair: Array = step
		var slot: int = pair[0]
		if slot >= 0:
			var payload: Dictionary = pair[1]
			session.apply_player_intent(slot, payload)
		else:
			session.commit_tick()
		hashes.append(session.hash_state())
	return hashes


func _two_player_session() -> TraprushMatchSession:
	var bundle: SimulationBundle = _compile_course_01()
	var session: TraprushMatchSession = TraprushMatchSession.create(bundle, 1, 2, _offsets(2), PLAY_RADIUS, PLAY_RADIUS)
	assert_not_null(session)
	return session


func _compile_course_01() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	return TraprushTopologyCompiler.compile(world)


func _offsets(count: int) -> Array[Dictionary]:
	var offsets: Array[Dictionary] = []
	for index: int in range(count):
		offsets.append({"dx": 0, "dy": 0, "dz": -index * 4 * PLAY_RADIUS})
	return offsets


func _move(dx: int, dz: int) -> Dictionary:
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	}


func _reset() -> Dictionary:
	return {
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
	}


func _use_item() -> Dictionary:
	return {
		"intent": PlayerIntentNames.USE_ITEM,
	}


func _shove() -> Dictionary:
	return {
		"intent": PlayerIntentNames.SHOVE,
	}
