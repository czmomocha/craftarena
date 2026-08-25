extends GutTest

## MatchLobbyShell: TRAPRUSH quick play / room code / queue / latest snapshot.
## Injected HTTP and socket events. Close only hides. Never settlement.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchJoinSession := preload("res://src/client/match_join_session.gd")
const MatchLobbyShell := preload("res://src/client/match_lobby_shell.gd")
const MatchPlaySession := preload("res://src/client/match_play_session.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

var _shell: MatchLobbyShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_open_window_quick_play_ready_begins_play() -> void:
	_shell = _open_shell()
	assert_eq(_shell.window.title, MatchLobbyShell.TITLE)
	assert_false(_shell.window.exclusive)
	assert_false(_shell.window.transient)
	assert_true(_shell.try_quick())
	assert_true(_shell.status_label_text().contains("pending=1"))
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-a")))
	assert_eq(_shell.join.state, MatchJoinSession.STATE_READY)
	assert_eq(_shell.play.state, MatchPlaySession.STATE_CONNECTING)
	assert_eq(_shell.play.websocket_url, "ws://127.0.0.1:8090/ws?ticket=ticket-a")
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(2, 12)))
	assert_eq(_shell.play.follow.tick, 2)
	assert_true(_shell.status_label_text().contains("tick=2"))
	assert_true(_shell.status_label_text().contains("room=ABCD23"))
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())


func test_queue_wait_poll_cancel_and_invalid_code() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_create_room())
	assert_true(_shell.accept_http(202, {
		"status": "waiting",
		"queueToken": "queue-token-aaaaaaaaaaaaaaaa",
		"position": 1,
		"estimatedWaitMs": 30000,
		"expiresAt": "2026-08-25T02:10:00.000Z",
	}))
	assert_eq(_shell.join.state, MatchJoinSession.STATE_WAITING)
	assert_true(_shell.status_label_text().contains("pos=1"))
	assert_true(_shell.status_label_text().contains("wait_ms=30000"))
	assert_true(_shell.try_poll())
	assert_true(_shell.accept_http(200, {
		"status": "waiting",
		"queueToken": "queue-token-aaaaaaaaaaaaaaaa",
		"position": 1,
		"estimatedWaitMs": 30000,
		"expiresAt": "2026-08-25T02:10:00.000Z",
	}))
	assert_true(_shell.try_cancel())
	assert_true(_shell.accept_http(200, {"ok": true}))
	assert_eq(_shell.join.state, MatchJoinSession.STATE_IDLE)
	_shell.set_room_code_text("IIIIII")
	assert_false(_shell.try_join_room())
	_shell.set_room_code_text("abcd23")
	assert_true(_shell.try_join_room())
	assert_eq(_shell.join.pending_path(), "/matchmaking/rooms/ABCD23/join")
	assert_true(_shell.accept_http(409, {"error": "room_full"}))
	assert_eq(_shell.join.error, "room_full")
	assert_true(_shell.status_label_text().contains("error=room_full"))


func test_visible_window_encodes_intents_hidden_does_not() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-b")))
	assert_true(_shell.on_socket_open())
	var move: PackedByteArray = _shell.try_sample_play_move(true, false, false, false)
	assert_false(move.is_empty())
	var decoded: Dictionary = MatchFrameCodec.decode_command(move)
	var intent_name: String = decoded.get("intent", "")
	var command_tick: int = decoded.get("tick", -1)
	assert_eq(intent_name, PlayerIntentNames.MOVE)
	assert_eq(command_tick, 0)
	var jump: PackedByteArray = _shell.try_sample_play_jump(true)
	assert_false(jump.is_empty())
	assert_true(_shell.try_sample_play_jump(true).is_empty())
	var reset: PackedByteArray = _shell.try_sample_play_reset(true)
	assert_false(reset.is_empty())
	var use_item: PackedByteArray = _shell.try_sample_play_use_item(true)
	assert_false(use_item.is_empty())
	_shell.window.close_requested.emit()
	assert_false(_shell.is_window_visible())
	assert_eq(_shell.join.state, MatchJoinSession.STATE_READY)
	assert_true(_shell.try_sample_play_move(true, false, false, false).is_empty())
	assert_true(_shell.show_window())
	assert_true(_shell.is_window_visible())


func test_buttons_exist_and_live_io_stays_off_in_tests() -> void:
	_shell = _open_shell()
	assert_false(_shell.live_io)
	assert_not_null(_shell.window.get_node("VBoxContainer/MatchActions/%s" % MatchLobbyShell.QUICK_NAME))
	assert_not_null(_shell.window.get_node("VBoxContainer/MatchActions/%s" % MatchLobbyShell.CREATE_NAME))
	assert_not_null(_shell.window.get_node("VBoxContainer/%s" % MatchLobbyShell.ROOM_NAME))
	assert_eq(_shell.play_move_step, Fixed.SCALE / 16)


func _open_shell() -> MatchLobbyShell:
	var shell: MatchLobbyShell = MatchLobbyShell.create()
	add_child(shell)
	assert_true(shell.open())
	assert_true(shell.is_window_visible())
	return shell


func _join(room_code: String, ticket: String) -> Dictionary:
	return {
		"roomCode": room_code,
		"ticket": ticket,
		"matchId": "match-1",
		"expiresAt": "2026-08-25T03:00:00.000Z",
		"seats": 2,
		"issued": 1,
	}


func _snapshot(tick: int, x: int) -> PackedByteArray:
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
