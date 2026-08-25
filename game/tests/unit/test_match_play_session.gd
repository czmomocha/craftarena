extends GutTest

## Play session: ready ticket → gateway URL, open, follow snapshots,
## encode existing command frames. Tick field is 0. Own-slot Move/Jump
## overlay via MatchLocalPredict; a newer snapshot tick hard-snaps.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchJoinSession := preload("res://src/client/match_join_session.gd")
const MatchPlaySession := preload("res://src/client/match_play_session.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")


func test_begin_requires_ready_ticket_and_ws_base() -> void:
	var play: MatchPlaySession = MatchPlaySession.new()
	var idle: MatchJoinSession = MatchJoinSession.create()
	assert_false(play.try_begin(idle, "ws://127.0.0.1:8090"))
	assert_false(play.try_begin(_ready_join(), "http://127.0.0.1:8090"))
	assert_true(play.try_begin(_ready_join(), "ws://127.0.0.1:8090/"))
	assert_eq(play.state, MatchPlaySession.STATE_CONNECTING)
	assert_eq(play.websocket_url, "ws://127.0.0.1:8090/ws?ticket=ticket%2Fplus")
	assert_false(play.try_begin(_ready_join(), "ws://127.0.0.1:8090"))


func test_open_then_snapshot_then_commands() -> void:
	var play: MatchPlaySession = MatchPlaySession.new()
	assert_true(play.try_begin(_ready_join(), "wss://127.0.0.1:8090"))
	assert_false(play.on_binary(_one_player_snapshot(1, 4)))
	assert_true(play.on_open())
	assert_eq(play.state, MatchPlaySession.STATE_IN_MATCH)
	assert_true(play.on_binary(_one_player_snapshot(2, 8)))
	assert_eq(play.follow.tick, 2)
	var pose: Dictionary = play.follow.players[0]
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 8)
	var move: PackedByteArray = play.try_encode_intent(PlayerIntentNames.MOVE, 65536, 0, -1)
	assert_false(move.is_empty())
	assert_eq(play.predict.own_slot, 0)
	assert_eq(play.predict.dx, 65536)
	var decoded: Dictionary = MatchFrameCodec.decode_command(move)
	var decoded_ok: bool = decoded.get("ok", false)
	var decoded_tick: int = decoded.get("tick", -1)
	var decoded_intent: String = decoded.get("intent", "")
	var decoded_dx: int = decoded.get("dx", 0)
	assert_true(decoded_ok)
	assert_eq(decoded_tick, 0)
	assert_eq(decoded_intent, PlayerIntentNames.MOVE)
	assert_eq(decoded_dx, 65536)
	var jump: PackedByteArray = play.try_encode_intent(PlayerIntentNames.JUMP, 0, 0, 0)
	assert_false(jump.is_empty())
	assert_eq(play.predict.dy, 0)
	assert_true(play.try_encode_intent(PlayerIntentNames.SHOVE, 0, 0, 0).is_empty())
	assert_true(play.try_encode_intent(PlayerIntentNames.INTERACT, 0, 0, 0).is_empty())
	play.on_close()
	assert_eq(play.state, MatchPlaySession.STATE_CLOSED)
	assert_true(play.try_encode_intent(PlayerIntentNames.JUMP, 0, 0, 0).is_empty())
	assert_false(play.allows_settlement())


func test_wasd_axes_encode_move_only_when_in_match() -> void:
	var play: MatchPlaySession = MatchPlaySession.new()
	assert_true(play.try_encode_move_axes(true, false, false, false, 16).is_empty())
	assert_true(play.try_begin(_ready_join(), "ws://127.0.0.1:8090"))
	assert_true(play.on_open())
	var bytes: PackedByteArray = play.try_encode_move_axes(true, false, false, true, 16)
	var decoded: Dictionary = MatchFrameCodec.decode_command(bytes)
	var dx: int = decoded.get("dx", 0)
	var dz: int = decoded.get("dz", 0)
	assert_eq(dx, 16)
	assert_eq(dz, -16)
	assert_true(play.try_encode_move_axes(false, false, false, false, 16).is_empty())
	assert_true(play.try_leave())
	assert_eq(play.state, MatchPlaySession.STATE_IDLE)
	assert_true(play.try_encode_move_axes(true, false, false, false, 16).is_empty())
	assert_false(play.on_binary(_one_player_snapshot(3, 8)))
	assert_false(play.try_leave())


func test_gateway_url_rejects_userinfo_and_empty_ticket() -> void:
	assert_eq(MatchPlaySession.gateway_ws_url("ws://127.0.0.1:8090", ""), "")
	assert_eq(MatchPlaySession.gateway_ws_url("ws://user:pass@127.0.0.1:8090", "t"), "")
	assert_eq(
		MatchPlaySession.gateway_ws_url("ws://127.0.0.1:8090/ws", "abc"),
		"ws://127.0.0.1:8090/ws?ticket=abc"
	)


func test_close_then_reissue_follows_latest_snapshot() -> void:
	var join: MatchJoinSession = _ready_join()
	var play: MatchPlaySession = MatchPlaySession.new()
	assert_true(play.try_begin(join, "ws://127.0.0.1:8090"))
	assert_true(play.on_open())
	assert_true(play.on_binary(_one_player_snapshot(2, 8)))
	assert_eq(play.follow.tick, 2)
	play.on_close()
	assert_eq(play.state, MatchPlaySession.STATE_CLOSED)
	assert_true(join.try_reconnect())
	assert_true(join.accept_http(201, {
		"ticket": "ticket-b",
		"matchId": "match-1",
		"expiresAt": "2026-08-25T04:11:00.000Z",
		"seat": 0,
	}))
	assert_true(play.try_begin(join, "ws://127.0.0.1:8090"))
	assert_eq(play.websocket_url, "ws://127.0.0.1:8090/ws?ticket=ticket-b")
	assert_true(play.on_open())
	assert_true(play.on_binary(_one_player_snapshot(9, 24)))
	assert_eq(play.follow.tick, 9)
	var pose: Dictionary = play.follow.players[0]
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 24)


func _ready_join() -> MatchJoinSession:
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_true(session.try_quick())
	assert_true(session.accept_http(201, {
		"roomCode": "ABCD23",
		"ticket": "ticket/plus",
		"matchId": "match-1",
		"expiresAt": "2026-08-25T03:00:00.000Z",
		"seats": 2,
		"issued": 1,
		"seat": 0,
		"course": "course_01",
	}))
	return session


func _one_player_snapshot(tick: int, x: int) -> PackedByteArray:
	var players: Array[Dictionary] = [{
		"x": x,
		"y": 0,
		"z": 0,
		"yaw_bam": 0,
		"accepted_count": 0,
		"finish_tick": -1,
	}]
	var crates: Array[Dictionary] = []
	return MatchFrameCodec.encode_snapshot(tick, players, crates)
