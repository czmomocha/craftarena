extends GutTest

## Match realtime core: per-connection slot assignment on top of
## TraprushMatchSession, binary command frames (MatchFrameCodec) decoded and
## queued FIFO, applied at the next commit_tick; snapshot frames encode all
## configured slots plus crate durability. The command tick field is decoded
## but never trusted for timing: the server tick is authoritative.
## Sockets are a thin wrapper in match_server.gd; network correctness tests
## stay manual (CD-91 D.8). No settlement, no online writes.

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
