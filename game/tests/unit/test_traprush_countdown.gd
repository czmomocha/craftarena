extends GutTest

## Opening countdown: go_tick=0 keeps existing tests; product injects 180 ticks.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchRealtime := preload("res://src/server/match_realtime.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const OverlayGd := preload("res://src/shared/play_hud_overlay.gd")
const UiCopyPlayGd := preload("res://src/shared/ui_copy_play.gd")
const PlayClockGd := preload("res://src/shared/play_clock.gd")

const COURSE_01: String = "res://content/official/traprush/course_01.json"
const CELL: int = Fixed.SCALE
const PLAY_RADIUS: int = CELL / 8


func test_countdown_constants_are_three_seconds() -> void:
	assert_eq(PlayStubs.COUNTDOWN_MS, 3000)
	assert_eq(PlayStubs.COUNTDOWN_TICKS, 180)
	assert_eq(PlayStubs.overlay_seconds(0, 180), 3)
	assert_eq(PlayStubs.overlay_seconds(60, 180), 2)
	assert_eq(PlayStubs.overlay_seconds(120, 180), 1)
	assert_eq(PlayStubs.overlay_seconds(179, 180), 1)
	assert_eq(PlayStubs.overlay_seconds(180, 180), 0)
	assert_true(PlayStubs.is_racing(0, 0))
	assert_false(PlayStubs.is_racing(179, 180))
	assert_true(PlayStubs.is_racing(180, 180))
	assert_eq(PlayStubs.racing_tick(200, 180), 20)


func test_default_session_accepts_move_immediately() -> void:
	var session: TraprushMatchSession = _one_player()
	PlayStubs.apply_match(session)
	var before: Dictionary = session.player_pose(0)
	assert_true(session.apply_player_intent(0, {"intent": PlayerIntentNames.MOVE, "dx": CELL, "dz": 0}))
	var after: Dictionary = session.player_pose(0)
	assert_eq(_coord(after, "x"), _coord(before, "x") + CELL)


func test_countdown_rejects_intents_until_go_tick() -> void:
	var session: TraprushMatchSession = _one_player()
	PlayStubs.apply_match(session)
	PlayStubs.apply_opening_countdown(session)
	assert_eq(session.go_tick, 180)
	var spawn: Dictionary = session.player_pose(0)
	var spawn_x: int = _coord(spawn, "x")
	assert_false(session.apply_player_intent(0, {"intent": PlayerIntentNames.MOVE, "dx": CELL, "dz": 0}))
	assert_false(session.apply_player_intent(0, {"intent": PlayerIntentNames.JUMP}))
	assert_false(session.apply_player_intent(0, {"intent": PlayerIntentNames.USE_ITEM}))
	assert_false(session.apply_player_intent(0, {"intent": PlayerIntentNames.SHOVE}))
	assert_false(session.apply_player_intent(0, {"intent": PlayerIntentNames.RESET_TO_CHECKPOINT}))
	assert_eq(_coord(session.player_pose(0), "x"), spawn_x)
	assert_eq(session.player_finish_tick(0), -1)
	assert_eq(session.destructible_alive_count(), 1)
	for _step: int in range(PlayStubs.COUNTDOWN_TICKS):
		session.commit_tick()
	assert_eq(session.tick_index(), 180)
	assert_eq(session.player_finish_tick(0), -1)
	assert_eq(session.destructible_alive_count(), 1)
	assert_true(session.apply_player_intent(0, {"intent": PlayerIntentNames.MOVE, "dx": CELL, "dz": 0}))
	assert_eq(_coord(session.player_pose(0), "x"), spawn_x + CELL)


func test_countdown_clock_stays_zero_and_falls_are_frozen() -> void:
	var session: TraprushMatchSession = _one_player()
	PlayStubs.apply_match(session)
	PlayStubs.apply_opening_countdown(session)
	var spawn_y: int = _coord(session.player_pose(0), "y")
	var hazard_id: int = -1
	var hazard_before: bool = false
	if not session._hazard_cycle.is_empty():
		var entry: Dictionary = session._hazard_cycle[0]
		hazard_id = _coord(entry, "box_id")
		hazard_before = session._world.is_static_box_solid(hazard_id)
	for _step: int in range(30):
		session.commit_tick()
	assert_eq(_coord(session.player_pose(0), "y"), spawn_y)
	assert_eq(PlayStubs.racing_tick(session.tick_index(), session.go_tick), 0)
	if hazard_id >= 0:
		assert_eq(session._world.is_static_box_solid(hazard_id), hazard_before)


func test_unfilled_two_player_match_does_not_tick() -> void:
	var realtime: MatchRealtime = MatchRealtime.create(_two_player())
	PlayStubs.apply_opening_countdown(realtime.session)
	assert_eq(realtime.add_player(), 0)
	var spawn_x: int = _coord(realtime.session.player_pose(0), "x")
	assert_true(realtime.accept_command(0, MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)))
	realtime.commit_tick()
	assert_eq(realtime.session.tick_index(), 0)
	assert_eq(_coord(realtime.session.player_pose(0), "x"), spawn_x)
	assert_eq(realtime.add_player(), 1)
	realtime.commit_tick()
	assert_eq(realtime.session.tick_index(), 1)
	assert_eq(_coord(realtime.session.player_pose(0), "x"), spawn_x)


func test_countdown_overlay_wait_then_digits_then_go() -> void:
	assert_eq(OverlayGd.countdown_line(0, 180, 2, true), UiCopy.text(UiCopyPlayGd.COUNTDOWN_WAIT))
	assert_eq(OverlayGd.countdown_line(0, 180, 1, true), "3")
	assert_eq(OverlayGd.countdown_line(1, 180, 1, true), "3")
	assert_eq(OverlayGd.countdown_line(180, 180, 1, true), UiCopy.text(UiCopyPlayGd.COUNTDOWN_GO))
	assert_eq(OverlayGd.countdown_line(180 + PlayStubs.COUNTDOWN_GO_TICKS, 180, 1, true), "")
	assert_eq(OverlayGd.countdown_line(0, 0, 1, true), "")


func _one_player() -> TraprushMatchSession:
	return _session(1)


func _two_player() -> TraprushMatchSession:
	return _session(2)


func _coord(pose: Dictionary, key: String) -> int:
	return PlayClockGd.dict_int(pose, key, -1)


func _session(count: int) -> TraprushMatchSession:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	var offsets: Array[Dictionary] = []
	for index: int in range(count):
		offsets.append({"dx": 0, "dy": 0, "dz": -index * 4 * PLAY_RADIUS})
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle, 1, count, offsets, PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	return session
