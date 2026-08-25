extends GutTest

## All-finished TRAPRUSH settlement from the official course_01 session.
## Unfinished sessions refuse. Same tape same hash/payload. Offline still
## never allows a write. No MMR, path-distance, or timed partial settle.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchOfflineSession := preload("res://src/client/match_offline_session.gd")
const MatchRealtime := preload("res://src/server/match_realtime.gd")
const MatchServer := preload("res://src/server/match_server.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushMatchSettlement := preload("res://src/games/traprush/match_settlement.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const FINISH_STEPS: int = 5


func test_unfinished_session_refuses_settlement() -> void:
	var session: TraprushMatchSession = _two_player_session()
	assert_false(TraprushMatchSettlement.all_finished(session))
	var built: Dictionary = TraprushMatchSettlement.try_build(session)
	var ok: bool = built.get("ok", true)
	assert_false(ok)
	var realtime: MatchRealtime = MatchRealtime.create(session)
	assert_false(realtime.allows_settlement())
	assert_false(realtime.allows_online_writes())


func test_all_finished_builds_standing_payload() -> void:
	var session: TraprushMatchSession = _run_two_player_finish()
	assert_true(TraprushMatchSettlement.all_finished(session))
	var built: Dictionary = TraprushMatchSettlement.try_build(session)
	var ok: bool = built.get("ok", false)
	var pad_total: int = built.get("pad_total", -1)
	var mvp_slot: int = built.get("mvp_slot", -2)
	var tick: int = built.get("tick", -1)
	var hash_text: String = built.get("state_hash", "")
	assert_true(ok)
	assert_eq(pad_total, 3)
	assert_eq(mvp_slot, 0)
	assert_eq(tick, FINISH_STEPS)
	assert_eq(hash_text, session.hash_state())
	assert_false(hash_text.is_empty())
	var rows_raw: Variant = built.get("rows", [])
	assert_eq(typeof(rows_raw), TYPE_ARRAY)
	var rows: Array = rows_raw
	assert_eq(rows.size(), 2)
	var first: Dictionary = _row_at(rows, 0)
	var second: Dictionary = _row_at(rows, 1)
	var slot0: int = first.get("slot", -1)
	var place0: int = first.get("place", 0)
	var finish0: int = first.get("finish_tick", -1)
	var accepted0: int = first.get("accepted_count", -1)
	var slot1: int = second.get("slot", -1)
	var place1: int = second.get("place", 0)
	var finish1: int = second.get("finish_tick", -1)
	assert_eq(slot0, 0)
	assert_eq(place0, 1)
	assert_eq(finish0, 4)
	assert_eq(accepted0, 3)
	assert_eq(slot1, 1)
	assert_eq(place1, 2)
	assert_eq(finish1, 4)
	var realtime: MatchRealtime = MatchRealtime.create(session)
	assert_true(realtime.allows_settlement())
	assert_false(realtime.allows_online_writes())


func test_same_tape_same_settlement_hash() -> void:
	var first: Dictionary = TraprushMatchSettlement.try_build(_run_two_player_finish())
	var second: Dictionary = TraprushMatchSettlement.try_build(_run_two_player_finish())
	var first_ok: bool = first.get("ok", false)
	var second_ok: bool = second.get("ok", false)
	var first_hash: String = first.get("state_hash", "")
	var second_hash: String = second.get("state_hash", "")
	var first_tick: int = first.get("tick", -1)
	var second_tick: int = second.get("tick", -1)
	var first_mvp: int = first.get("mvp_slot", -2)
	var second_mvp: int = second.get("mvp_slot", -2)
	assert_true(first_ok)
	assert_true(second_ok)
	assert_eq(first_hash, second_hash)
	assert_eq(first_tick, second_tick)
	assert_eq(first_mvp, second_mvp)


func test_heartbeat_omits_settlement_until_all_finish() -> void:
	var session: TraprushMatchSession = _two_player_session()
	session.commit_tick()
	var early_raw: Variant = JSON.parse_string(MatchServer._heartbeat_line("m1", session))
	assert_eq(typeof(early_raw), TYPE_DICTIONARY)
	var early: Dictionary = early_raw
	var early_event: String = early.get("event", "")
	assert_eq(early_event, "match_tick")
	assert_false(early.has("settlement"))
	var finished: TraprushMatchSession = _run_two_player_finish()
	var late_raw: Variant = JSON.parse_string(MatchServer._heartbeat_line("m1", finished))
	assert_eq(typeof(late_raw), TYPE_DICTIONARY)
	var late: Dictionary = late_raw
	assert_true(late.has("settlement"))
	var wire_raw: Variant = late.get("settlement", {})
	assert_eq(typeof(wire_raw), TYPE_DICTIONARY)
	var wire: Dictionary = wire_raw
	var mvp_slot: int = wire.get("mvp_slot", -2)
	var pad_total: int = wire.get("pad_total", -1)
	var state_hash: String = wire.get("state_hash", "")
	assert_eq(mvp_slot, 0)
	assert_eq(pad_total, 3)
	assert_eq(state_hash, finished.hash_state())
	var rows_raw: Variant = wire.get("rows", [])
	assert_eq(typeof(rows_raw), TYPE_ARRAY)
	var rows: Array = rows_raw
	assert_eq(rows.size(), 2)


func test_offline_finish_still_refuses_settlement_write() -> void:
	var offline: MatchOfflineSession = MatchOfflineSession.new()
	assert_true(offline.try_begin(COURSE_01_PATH))
	for _index: int in range(FINISH_STEPS):
		assert_false(offline.try_encode_intent(PlayerIntentNames.MOVE, CELL, 0, -1).is_empty())
	assert_eq(offline.session.player_finish_tick(0), 0)
	assert_true(TraprushMatchSettlement.all_finished(offline.session))
	assert_false(offline.allows_settlement())
	assert_false(offline.allows_online_writes())


func _run_two_player_finish() -> TraprushMatchSession:
	var realtime: MatchRealtime = MatchRealtime.create(_two_player_session())
	assert_eq(realtime.add_player(), 0)
	assert_eq(realtime.add_player(), 1)
	var move: PackedByteArray = MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)
	for _step: int in range(FINISH_STEPS):
		assert_true(realtime.accept_command(0, move))
		assert_true(realtime.accept_command(1, move))
		realtime.commit_tick()
	return realtime.session


func _two_player_session() -> TraprushMatchSession:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	var offsets: Array[Dictionary] = []
	for index: int in range(2):
		offsets.append({"dx": 0, "dy": 0, "dz": -index * 4 * PLAY_RADIUS})
	var session: TraprushMatchSession = TraprushMatchSession.create(bundle, 1, 2, offsets, PLAY_RADIUS, PLAY_RADIUS)
	assert_not_null(session)
	return session


func _row_at(rows: Array, index: int) -> Dictionary:
	var raw: Variant = rows[index]
	assert_eq(typeof(raw), TYPE_DICTIONARY)
	var row: Dictionary = raw
	return row
