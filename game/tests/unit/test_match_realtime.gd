extends GutTest

## Match realtime core: per-connection slot assignment on top of
## TraprushMatchSession, binary command frames (MatchFrameCodec) decoded and
## queued FIFO, applied at the next commit_tick; at most one queued command
## per occupied slot per tick (first wins). Disconnect drops that slot's
## queue. Snapshot frames encode all configured slots plus crate durability.
## The command tick field is decoded but never trusted for timing: the
## server tick is authoritative. Sockets are a thin wrapper in
## match_server.gd; network correctness tests stay manual (CD-91 D.8).
## No settlement, no online writes.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchRealtime := preload("res://src/server/match_realtime.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8


func test_slot_assignment_bounds_and_reuse() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	assert_eq(realtime.add_player(), 0)
	assert_eq(realtime.add_player(), 1)
	assert_eq(realtime.add_player(), -1)
	assert_eq(realtime.occupied_count(), 2)
	assert_true(realtime.remove_player(0))
	assert_eq(realtime.occupied_count(), 1)
	assert_eq(realtime.add_player(), 0)
	assert_false(realtime.remove_player(7))
	assert_false(realtime.remove_player(-1))


func test_accept_command_rejects_bad_input() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	var slot: int = realtime.add_player()
	assert_eq(slot, 0)
	assert_false(realtime.accept_command(slot, PackedByteArray([1, 2, 3])))
	var wrong_version: PackedByteArray = MatchFrameCodec.encode_command(0, PlayerIntentNames.JUMP, 0, 0, 0)
	wrong_version[0] = 9
	assert_false(realtime.accept_command(slot, wrong_version))
	assert_false(realtime.accept_command(1, MatchFrameCodec.encode_command(0, PlayerIntentNames.JUMP, 0, 0, 0)))
	assert_false(realtime.accept_command(-1, MatchFrameCodec.encode_command(0, PlayerIntentNames.JUMP, 0, 0, 0)))
	assert_true(realtime.accept_command(slot, MatchFrameCodec.encode_command(0, PlayerIntentNames.JUMP, 0, 0, 0)))


func test_queued_move_applies_at_commit_tick_and_server_tick_wins() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	var slot: int = realtime.add_player()
	var before: Dictionary = realtime.session.player_pose(slot)
	var before_x: int = before.get("x", -1)
	assert_eq(before_x, 0)
	assert_true(realtime.accept_command(slot, MatchFrameCodec.encode_command(999, PlayerIntentNames.MOVE, CELL, 0, -1)))
	var still: Dictionary = realtime.session.player_pose(slot)
	var still_x: int = still.get("x", -1)
	assert_eq(still_x, 0)
	realtime.commit_tick()
	var moved: Dictionary = realtime.session.player_pose(slot)
	var moved_x: int = moved.get("x", -1)
	assert_eq(moved_x, CELL)
	var snapshot: Dictionary = MatchFrameCodec.decode_snapshot(realtime.snapshot_frame())
	var snapshot_tick: int = snapshot.get("tick", -1)
	assert_eq(snapshot_tick, 1)


func test_snapshot_frame_decodes_back_with_crates() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	realtime.add_player()
	realtime.commit_tick()
	var snapshot: Dictionary = MatchFrameCodec.decode_snapshot(realtime.snapshot_frame())
	var snapshot_ok: bool = snapshot.get("ok", false)
	assert_true(snapshot_ok)
	var players: Array = snapshot.get("players", [])
	assert_eq(players.size(), 2)
	var p0: Dictionary = players[0]
	var accepted: int = p0.get("accepted_count", -1)
	var finish_tick: int = p0.get("finish_tick", 0)
	assert_eq(accepted, 1)
	assert_eq(finish_tick, -1)
	var crates: Array = snapshot.get("crates", [])
	assert_eq(crates.size(), 1)
	var crate: Dictionary = crates[0]
	var durability: int = crate.get("durability", -1)
	assert_eq(durability, 1)


func test_use_item_over_wire_breaks_crate() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	realtime.session.use_item_damage = 1
	realtime.session.use_item_reach_dz = CELL
	var slot: int = realtime.add_player()
	assert_true(realtime.accept_command(slot, MatchFrameCodec.encode_command(0, PlayerIntentNames.USE_ITEM, 0, 0, 0)))
	realtime.commit_tick()
	var snapshot: Dictionary = MatchFrameCodec.decode_snapshot(realtime.snapshot_frame())
	var crates: Array = snapshot.get("crates", [])
	var crate: Dictionary = crates[0]
	var durability: int = crate.get("durability", -1)
	assert_eq(durability, 0)
	assert_eq(realtime.session.destructible_alive_count(), 0)


func test_full_run_finish_over_wire() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	var slot: int = realtime.add_player()
	for index: int in range(5):
		assert_true(realtime.accept_command(slot, MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)))
		realtime.commit_tick()
	var snapshot: Dictionary = MatchFrameCodec.decode_snapshot(realtime.snapshot_frame())
	var players: Array = snapshot.get("players", [])
	var p0: Dictionary = players[0]
	var p1: Dictionary = players[1]
	var finish0: int = p0.get("finish_tick", -1)
	var finish1: int = p1.get("finish_tick", 0)
	var accepted0: int = p0.get("accepted_count", -1)
	assert_eq(finish0, 4)
	assert_eq(finish1, -1)
	assert_eq(accepted0, 3)


func test_one_command_per_slot_per_tick() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	var slot: int = realtime.add_player()
	var before: Dictionary = realtime.session.player_pose(slot)
	var before_x: int = before.get("x", -1)
	var move: PackedByteArray = MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)
	assert_true(realtime.accept_command(slot, move))
	assert_eq(realtime.pending_count(), 1)
	assert_false(realtime.accept_command(slot, move))
	assert_false(realtime.accept_command(slot, move))
	assert_eq(realtime.pending_count(), 1)
	realtime.commit_tick()
	var after: Dictionary = realtime.session.player_pose(slot)
	var after_x: int = after.get("x", -1)
	assert_eq(after_x, before_x + CELL)
	assert_eq(realtime.pending_count(), 0)
	assert_true(realtime.accept_command(slot, move))
	assert_false(realtime.allows_settlement())
	assert_false(realtime.allows_online_writes())


func test_disconnect_drops_queued_command_before_rejoin() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	var slot: int = realtime.add_player()
	var move: PackedByteArray = MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)
	assert_true(realtime.accept_command(slot, move))
	assert_true(realtime.remove_player(slot))
	assert_eq(realtime.pending_count(), 0)
	assert_eq(realtime.add_player(), 0)
	realtime.commit_tick()
	var pose: Dictionary = realtime.session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)


func test_occupy_slot_binds_explicit_seat_and_resumes_pose() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	assert_true(realtime.occupy_slot(1))
	assert_eq(realtime.add_player(), 0)
	assert_false(realtime.occupy_slot(1))
	assert_false(realtime.occupy_slot(2))
	assert_false(realtime.occupy_slot(-1))
	var move: PackedByteArray = MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)
	assert_true(realtime.accept_command(1, move))
	realtime.commit_tick()
	assert_true(realtime.remove_player(1))
	assert_eq(realtime.occupied_count(), 1)
	assert_true(realtime.occupy_slot(1))
	var pose: Dictionary = realtime.session.player_pose(1)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, CELL)
	assert_eq(realtime.pending_count(), 0)


func test_parse_requested_slot_reads_query() -> void:
	var missing: Dictionary = MatchRealtime.parse_requested_slot("ws://127.0.0.1:9/")
	var missing_present: bool = missing.get("present", true)
	var missing_ok: bool = missing.get("ok", false)
	assert_false(missing_present)
	assert_true(missing_ok)
	var parsed: Dictionary = MatchRealtime.parse_requested_slot("/?slot=1")
	var parsed_present: bool = parsed.get("present", false)
	var parsed_ok: bool = parsed.get("ok", false)
	var parsed_slot: int = parsed.get("slot", -1)
	assert_true(parsed_present)
	assert_true(parsed_ok)
	assert_eq(parsed_slot, 1)
	var full: Dictionary = MatchRealtime.parse_requested_slot("ws://127.0.0.1:9/?slot=0")
	var full_slot: int = full.get("slot", -1)
	assert_eq(full_slot, 0)
	var bad: Dictionary = MatchRealtime.parse_requested_slot("/?slot=9")
	var bad_present: bool = bad.get("present", false)
	var bad_ok: bool = bad.get("ok", true)
	assert_true(bad_present)
	assert_false(bad_ok)


func test_snapshot_frame_is_not_a_command() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	var slot: int = realtime.add_player()
	var snapshot: PackedByteArray = realtime.snapshot_frame()
	assert_false(snapshot.is_empty())
	assert_false(realtime.accept_command(slot, snapshot))
	assert_eq(realtime.pending_count(), 0)


func test_two_slots_each_queue_one_fifo() -> void:
	var realtime: MatchRealtime = _two_player_realtime()
	assert_eq(realtime.add_player(), 0)
	assert_eq(realtime.add_player(), 1)
	var move: PackedByteArray = MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)
	assert_true(realtime.accept_command(1, move))
	assert_true(realtime.accept_command(0, move))
	assert_false(realtime.accept_command(1, move))
	assert_eq(realtime.pending_count(), 2)
	realtime.commit_tick()
	var p0: Dictionary = realtime.session.player_pose(0)
	var p1: Dictionary = realtime.session.player_pose(1)
	var x0: int = p0.get("x", -1)
	var x1: int = p1.get("x", -1)
	assert_eq(x0, CELL)
	assert_eq(x1, CELL)


func test_same_command_stream_same_snapshot_bytes() -> void:
	var first: MatchRealtime = _two_player_realtime()
	var second: MatchRealtime = _two_player_realtime()
	first.add_player()
	second.add_player()
	for index: int in range(3):
		var command: PackedByteArray = MatchFrameCodec.encode_command(0, PlayerIntentNames.MOVE, CELL, 0, -1)
		first.accept_command(0, command)
		second.accept_command(0, command)
		first.commit_tick()
		second.commit_tick()
		assert_eq(first.snapshot_frame(), second.snapshot_frame())


func _two_player_realtime() -> MatchRealtime:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	var offsets: Array[Dictionary] = []
	for index: int in range(2):
		offsets.append({"dx": 0, "dy": 0, "dz": -index * 4 * PLAY_RADIUS})
	var session: TraprushMatchSession = TraprushMatchSession.create(bundle, 1, 2, offsets, PLAY_RADIUS, PLAY_RADIUS)
	assert_not_null(session)
	var realtime: MatchRealtime = MatchRealtime.create(session)
	assert_not_null(realtime)
	return realtime
