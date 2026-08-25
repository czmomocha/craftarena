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
