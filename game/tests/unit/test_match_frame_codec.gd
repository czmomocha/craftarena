extends GutTest

## Match wire protocol v1: versioned binary frames for realtime commands and
## snapshots, pure GDScript (CD-43 §1). Fixed-length command frame, variable
## snapshot frame. Decode rejects wrong version, unknown type, truncation,
## trailing bytes and non-zero reserved fields. Encoding is canonical.
## Tick/snapshot rates and interpolation windows stay unlocked (CD-43 §4).
## v1 also has 18-byte ping/pong probes (type 3/4); they are not commands.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const CELL: int = 65536
const BIG: int = 140737488355328


func test_command_round_trip_all_intents() -> void:
	var move: Dictionary = MatchFrameCodec.decode_command(
		MatchFrameCodec.encode_command(7, PlayerIntentNames.MOVE, CELL, -CELL, 100)
	)
	var move_ok: bool = move.get("ok", false)
	assert_true(move_ok)
	var move_tick: int = move.get("tick", -1)
	var move_intent: String = move.get("intent", "")
	var move_dx: int = move.get("dx", 0)
	var move_dz: int = move.get("dz", 0)
	var move_yaw: int = move.get("yaw_bam", 0)
	assert_eq(move_tick, 7)
	assert_eq(move_intent, PlayerIntentNames.MOVE)
	assert_eq(move_dx, CELL)
	assert_eq(move_dz, -CELL)
	assert_eq(move_yaw, 100)
	var omitted: Dictionary = MatchFrameCodec.decode_command(
		MatchFrameCodec.encode_command(8, PlayerIntentNames.MOVE, CELL, 0, -1)
	)
	var omitted_yaw: int = omitted.get("yaw_bam", 0)
	assert_eq(omitted_yaw, -1)
	for intent: String in [
		PlayerIntentNames.JUMP,
		PlayerIntentNames.RESET_TO_CHECKPOINT,
		PlayerIntentNames.USE_ITEM,
		PlayerIntentNames.SHOVE,
		PlayerIntentNames.SPRINT,
	]:
		var decoded: Dictionary = MatchFrameCodec.decode_command(
			MatchFrameCodec.encode_command(9, intent, 0, 0, 0)
		)
		var decoded_ok: bool = decoded.get("ok", false)
		var decoded_intent: String = decoded.get("intent", "")
		var decoded_tick: int = decoded.get("tick", -1)
		assert_true(decoded_ok)
		assert_eq(decoded_intent, intent)
		assert_eq(decoded_tick, 9)


func test_command_encode_rejects_unwired_intent() -> void:
	assert_eq(MatchFrameCodec.encode_command(1, PlayerIntentNames.INTERACT, 0, 0, 0).size(), 0)
	assert_eq(MatchFrameCodec.encode_command(1, "NopeIntent", 0, 0, 0).size(), 0)


func test_command_decode_rejects_nonzero_reserved() -> void:
	var bytes: PackedByteArray = MatchFrameCodec.encode_command(1, PlayerIntentNames.JUMP, 0, 0, 0)
	assert_gt(bytes.size(), 0)
	bytes.encode_s64(11, CELL)
	var decoded: Dictionary = MatchFrameCodec.decode_command(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	assert_false(decoded_ok)


func test_snapshot_round_trip() -> void:
	var players: Array[Dictionary] = [
		{"x": CELL, "y": 0, "z": -CELL, "yaw_bam": 5, "accepted_count": 2, "finish_tick": -1},
		{"x": -BIG, "y": BIG, "z": 0, "yaw_bam": 0, "accepted_count": 3, "finish_tick": 42},
	]
	var crates: Array[Dictionary] = [
		{"entity_id": 40, "durability": 1},
		{"entity_id": 41, "durability": 0},
	]
	var decoded: Dictionary = MatchFrameCodec.decode_snapshot(
		MatchFrameCodec.encode_snapshot(12, players, crates)
	)
	var decoded_ok: bool = decoded.get("ok", false)
	assert_true(decoded_ok)
	var tick: int = decoded.get("tick", -1)
	assert_eq(tick, 12)
	var got_players: Array = decoded.get("players", [])
	assert_eq(got_players.size(), 2)
	var p0: Dictionary = got_players[0]
	var p0_x: int = p0.get("x", 0)
	var p0_z: int = p0.get("z", 0)
	var p0_accepted: int = p0.get("accepted_count", -1)
	var p0_finish: int = p0.get("finish_tick", 0)
	assert_eq(p0_x, CELL)
	assert_eq(p0_z, -CELL)
	assert_eq(p0_accepted, 2)
	assert_eq(p0_finish, -1)
	var p1: Dictionary = got_players[1]
	var p1_x: int = p1.get("x", 0)
	var p1_y: int = p1.get("y", 0)
	var p1_finish: int = p1.get("finish_tick", -1)
	assert_eq(p1_x, -BIG)
	assert_eq(p1_y, BIG)
	assert_eq(p1_finish, 42)
	var got_crates: Array = decoded.get("crates", [])
	assert_eq(got_crates.size(), 2)
	var c1: Dictionary = got_crates[1]
	var c1_id: int = c1.get("entity_id", -1)
	var c1_durability: int = c1.get("durability", -1)
	assert_eq(c1_id, 41)
	assert_eq(c1_durability, 0)


func test_snapshot_bounds_round_trip() -> void:
	var empty: Dictionary = MatchFrameCodec.decode_snapshot(
		MatchFrameCodec.encode_snapshot(0, [], [])
	)
	var empty_ok: bool = empty.get("ok", false)
	assert_true(empty_ok)
	var empty_players: Array = empty.get("players", [1])
	assert_eq(empty_players.size(), 0)
	var players: Array[Dictionary] = []
	for index: int in range(8):
		players.append({"x": index, "y": 0, "z": 0, "yaw_bam": 0, "accepted_count": 0, "finish_tick": -1})
	var full: Dictionary = MatchFrameCodec.decode_snapshot(
		MatchFrameCodec.encode_snapshot(1, players, [])
	)
	var full_ok: bool = full.get("ok", false)
	assert_true(full_ok)
	var full_players: Array = full.get("players", [])
	assert_eq(full_players.size(), 8)


func test_reject_wrong_version() -> void:
	var command: PackedByteArray = MatchFrameCodec.encode_command(1, PlayerIntentNames.JUMP, 0, 0, 0)
	command[0] = 2
	var command_decoded: Dictionary = MatchFrameCodec.decode_command(command)
	var command_ok: bool = command_decoded.get("ok", false)
	assert_false(command_ok)
	var snapshot: PackedByteArray = MatchFrameCodec.encode_snapshot(1, [], [])
	snapshot[0] = 0
	var snapshot_decoded: Dictionary = MatchFrameCodec.decode_snapshot(snapshot)
	var snapshot_ok: bool = snapshot_decoded.get("ok", false)
	assert_false(snapshot_ok)


func test_reject_unknown_frame_type() -> void:
	var command: PackedByteArray = MatchFrameCodec.encode_command(1, PlayerIntentNames.JUMP, 0, 0, 0)
	command[1] = 99
	var command_decoded: Dictionary = MatchFrameCodec.decode_command(command)
	var command_ok: bool = command_decoded.get("ok", false)
	assert_false(command_ok)
	var snapshot: PackedByteArray = MatchFrameCodec.encode_snapshot(1, [], [])
	snapshot[1] = 1
	var snapshot_decoded: Dictionary = MatchFrameCodec.decode_snapshot(snapshot)
	var snapshot_ok: bool = snapshot_decoded.get("ok", false)
	assert_false(snapshot_ok)


func test_reject_truncated_and_trailing() -> void:
	var command: PackedByteArray = MatchFrameCodec.encode_command(1, PlayerIntentNames.MOVE, 1, 2, 3)
	var cut: Dictionary = MatchFrameCodec.decode_command(command.slice(0, command.size() - 1))
	var cut_ok: bool = cut.get("ok", false)
	assert_false(cut_ok)
	var longer: PackedByteArray = command.duplicate()
	longer.append(0)
	var longer_decoded: Dictionary = MatchFrameCodec.decode_command(longer)
	var longer_ok: bool = longer_decoded.get("ok", false)
	assert_false(longer_ok)
	var snapshot: PackedByteArray = MatchFrameCodec.encode_snapshot(1, [{"x": 0, "y": 0, "z": 0, "yaw_bam": 0, "accepted_count": 0, "finish_tick": -1}], [])
	var cut_snapshot: Dictionary = MatchFrameCodec.decode_snapshot(snapshot.slice(0, snapshot.size() - 1))
	var cut_snapshot_ok: bool = cut_snapshot.get("ok", false)
	assert_false(cut_snapshot_ok)
	var longer_snapshot: PackedByteArray = snapshot.duplicate()
	longer_snapshot.append(0)
	var longer_snapshot_decoded: Dictionary = MatchFrameCodec.decode_snapshot(longer_snapshot)
	var longer_snapshot_ok: bool = longer_snapshot_decoded.get("ok", false)
	assert_false(longer_snapshot_ok)


func test_encode_is_canonical() -> void:
	var first: PackedByteArray = MatchFrameCodec.encode_command(3, PlayerIntentNames.MOVE, CELL, 0, -1)
	var second: PackedByteArray = MatchFrameCodec.encode_command(3, PlayerIntentNames.MOVE, CELL, 0, -1)
	assert_eq(first, second)
	var players: Array[Dictionary] = [{"x": BIG, "y": -BIG, "z": CELL, "yaw_bam": 0, "accepted_count": 1, "finish_tick": -1}]
	var snap_first: PackedByteArray = MatchFrameCodec.encode_snapshot(3, players, [])
	var snap_second: PackedByteArray = MatchFrameCodec.encode_snapshot(3, players, [])
	assert_eq(snap_first, snap_second)
	var decoded: Dictionary = MatchFrameCodec.decode_snapshot(snap_first)
	var got: Array = decoded.get("players", [])
	var p: Dictionary = got[0]
	var p_x: int = p.get("x", 0)
	var p_y: int = p.get("y", 0)
	assert_eq(p_x, BIG)
	assert_eq(p_y, -BIG)


func test_ping_pong_round_trip_and_echo() -> void:
	var ping: PackedByteArray = MatchFrameCodec.encode_ping(3, 1500)
	assert_eq(ping.size(), 18)
	var decoded_ping: Dictionary = MatchFrameCodec.decode_ping(ping)
	var ping_ok: bool = decoded_ping.get("ok", false)
	assert_true(ping_ok)
	var ping_seq: int = decoded_ping.get("seq", -1)
	var ping_ms: int = decoded_ping.get("client_send_ms", -1)
	assert_eq(ping_seq, 3)
	assert_eq(ping_ms, 1500)
	var as_command: Dictionary = MatchFrameCodec.decode_command(ping)
	var as_command_ok: bool = as_command.get("ok", true)
	assert_false(as_command_ok)
	var as_snapshot: Dictionary = MatchFrameCodec.decode_snapshot(ping)
	var as_snapshot_ok: bool = as_snapshot.get("ok", true)
	assert_false(as_snapshot_ok)
	var as_pong: Dictionary = MatchFrameCodec.decode_pong(ping)
	var as_pong_ok: bool = as_pong.get("ok", true)
	assert_false(as_pong_ok)
	var pong: PackedByteArray = MatchFrameCodec.echo_pong(ping)
	assert_eq(pong, MatchFrameCodec.encode_pong(3, 1500))
	var decoded_pong: Dictionary = MatchFrameCodec.decode_pong(pong)
	var pong_ok: bool = decoded_pong.get("ok", false)
	assert_true(pong_ok)
	var pong_seq: int = decoded_pong.get("seq", -1)
	var pong_ms: int = decoded_pong.get("client_send_ms", -1)
	assert_eq(pong_seq, 3)
	assert_eq(pong_ms, 1500)
	assert_eq(MatchFrameCodec.encode_ping(3, 1500), MatchFrameCodec.encode_ping(3, 1500))
	assert_true(MatchFrameCodec.echo_pong(MatchFrameCodec.encode_command(1, PlayerIntentNames.JUMP, 0, 0, 0)).is_empty())
	assert_true(MatchFrameCodec.encode_ping(0, 1).is_empty())
	assert_true(MatchFrameCodec.encode_ping(1, -1).is_empty())
	var cut: PackedByteArray = ping.slice(0, ping.size() - 1)
	var cut_decoded: Dictionary = MatchFrameCodec.decode_ping(cut)
	var cut_ok: bool = cut_decoded.get("ok", true)
	assert_false(cut_ok)
	var longer: PackedByteArray = ping.duplicate()
	longer.append(0)
	var longer_decoded: Dictionary = MatchFrameCodec.decode_ping(longer)
	var longer_ok: bool = longer_decoded.get("ok", true)
	assert_false(longer_ok)
	ping[0] = 2
	var versioned: Dictionary = MatchFrameCodec.decode_ping(ping)
	var versioned_ok: bool = versioned.get("ok", true)
	assert_false(versioned_ok)
