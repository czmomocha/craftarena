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
	assert_true(_shell.window.own_world_3d)
	assert_not_null(_shell.map)
	assert_not_null(_shell.course)
	assert_not_null(_shell.crates)
	assert_not_null(_shell.links)
	assert_not_null(_shell.orders)
	assert_not_null(_shell.standings)
	assert_eq(_shell.map.player_count(), 0)
	assert_eq(_shell.course.pad_count(), 3)
	assert_eq(_shell.course.portal_count(), 2)
	assert_eq(_shell.course.finish_count(), 1)
	assert_eq(_shell.course.crate_node_count(), 0)
	assert_eq(_shell.course.link_node_count(), 0)
	assert_eq(_shell.course.checkpoint_node_count(), 0)
	assert_eq(_shell.crates.crate_count(), 1)
	assert_eq(_shell.crates.link_node_count(), 0)
	assert_eq(_shell.crates.checkpoint_node_count(), 0)
	assert_eq(_shell.map.link_node_count(), 0)
	assert_eq(_shell.map.checkpoint_node_count(), 0)
	assert_eq(_shell.map.standing_node_count(), 0)
	assert_eq(_shell.links.link_count(), 2)
	assert_eq(_shell.links.direction_count(), 0)
	assert_eq(_shell.links.checkpoint_node_count(), 0)
	assert_eq(_shell.orders.checkpoint_count(), 3)
	assert_eq(_shell.orders.sequence_count(), 2)
	assert_eq(_shell.orders.link_node_count(), 0)
	assert_eq(_shell.orders.standing_node_count(), 0)
	assert_eq(_shell.course.standing_node_count(), 0)
	assert_eq(_shell.crates.standing_node_count(), 0)
	assert_eq(_shell.links.standing_node_count(), 0)
	assert_eq(_shell.standings.standing_count(), 0)
	assert_eq(_shell.standings.crate_node_count(), 0)
	assert_almost_eq(_shell.course.finish_node(30).position.x, 2.0, 0.0001)
	assert_almost_eq(_shell.course.finish_node(30).position.z, 0.0, 0.0001)
	assert_almost_eq(_shell.crates.crate_node(40).position.z, 1.0, 0.0001)
	assert_almost_eq(_shell.links.link_node(10).position.x, 1.5, 0.0001)
	assert_almost_eq(_shell.links.link_node(10).position.y, 0.5, 0.0001)
	assert_eq(_shell.orders.checkpoint_node(1).text, "0")
	assert_almost_eq(_shell.orders.checkpoint_node(1).position.y, 1.15, 0.0001)
	assert_almost_eq(_shell.orders.sequence_node(1, 2).position.x, 1.0, 0.0001)
	assert_true(_shell.status_label_text().contains("course=3/2/1"))
	assert_true(_shell.status_label_text().contains("crates_mapped=1"))
	assert_true(_shell.status_label_text().contains("links_mapped=2"))
	assert_true(_shell.status_label_text().contains("orders_mapped=3/2"))
	assert_true(_shell.try_quick())
	assert_true(_shell.status_label_text().contains("pending=1"))
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-a")))
	assert_eq(_shell.join.state, MatchJoinSession.STATE_READY)
	assert_eq(_shell.play.state, MatchPlaySession.STATE_CONNECTING)
	assert_eq(_shell.play.websocket_url, "ws://127.0.0.1:8090/ws?ticket=ticket-a")
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(2, 12)))
	assert_eq(_shell.play.follow.tick, 2)
	assert_eq(_shell.map.player_count(), 1)
	assert_eq(_shell.standings.standing_count(), 1)
	var marker: MeshInstance3D = _shell.map.player_node(0)
	assert_not_null(marker)
	assert_almost_eq(marker.position.x, 12.0 / float(Fixed.SCALE), 0.0001)
	var standing_mark: Label3D = _shell.standings.standing_node(0)
	assert_not_null(standing_mark)
	assert_eq(standing_mark.text, "#1 P0 0/3")
	assert_almost_eq(standing_mark.position.x, 12.0 / float(Fixed.SCALE), 0.0001)
	assert_eq(_shell.map.crate_node_count(), 0)
	assert_eq(_shell.map.link_node_count(), 0)
	assert_eq(_shell.course.pad_count(), 3)
	assert_eq(_shell.crates.crate_count(), 0)
	assert_eq(_shell.links.link_count(), 2)
	assert_eq(_shell.orders.checkpoint_count(), 3)
	assert_eq(_shell.orders.sequence_count(), 2)
	assert_true(_shell.status_label_text().contains("tick=2"))
	assert_true(_shell.status_label_text().contains("mapped=1"))
	assert_true(_shell.status_label_text().contains("course=3/2/1"))
	assert_true(_shell.status_label_text().contains("crates_mapped=0"))
	assert_true(_shell.status_label_text().contains("links_mapped=2"))
	assert_true(_shell.status_label_text().contains("orders_mapped=3/2"))
	assert_true(_shell.status_label_text().contains("standings=#1s0 mvp=-"))
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


func test_stale_or_bad_snapshot_keeps_mapped_pose() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-c")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(5, Fixed.SCALE)))
	assert_almost_eq(_shell.map.player_node(0).position.x, 1.0, 0.0001)
	assert_false(_shell.on_binary(_snapshot(4, 8 * Fixed.SCALE)))
	assert_almost_eq(_shell.map.player_node(0).position.x, 1.0, 0.0001)
	assert_false(_shell.on_binary(PackedByteArray([1, 2, 3])))
	assert_almost_eq(_shell.map.player_node(0).position.x, 1.0, 0.0001)
	assert_true(_shell.on_binary(_snapshot(6, 2 * Fixed.SCALE)))
	assert_almost_eq(_shell.map.player_node(0).position.x, 2.0, 0.0001)
	assert_eq(_shell.course.pad_count(), 3)
	assert_almost_eq(_shell.course.finish_node(30).position.z, 0.0, 0.0001)
	assert_eq(_shell.crates.crate_count(), 0)
	assert_eq(_shell.links.link_count(), 2)
	assert_almost_eq(_shell.links.link_node(10).position.x, 1.5, 0.0001)
	assert_eq(_shell.orders.checkpoint_count(), 3)
	assert_almost_eq(_shell.orders.checkpoint_node(3).position.z, 0.0, 0.0001)
	assert_eq(_shell.standings.standing_count(), 1)
	assert_eq(_shell.standings.standing_node(0).text, "#1 P0 0/3")
	assert_almost_eq(_shell.standings.standing_node(0).position.x, 2.0, 0.0001)


func test_snapshot_crate_durability_hides_without_moving_or_redrawing_course() -> void:
	_shell = _open_shell()
	assert_eq(_shell.crates.crate_count(), 1)
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-d")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(3, Fixed.SCALE, [_crate(40, 1)])))
	assert_eq(_shell.crates.crate_count(), 1)
	assert_almost_eq(_shell.crates.crate_node(40).position.z, 1.0, 0.0001)
	assert_eq(_shell.course.pad_count(), 3)
	assert_eq(_shell.links.link_count(), 2)
	assert_eq(_shell.orders.checkpoint_count(), 3)
	assert_true(_shell.on_binary(_snapshot(4, 2 * Fixed.SCALE, [_crate(40, 0)])))
	assert_eq(_shell.crates.crate_count(), 0)
	assert_eq(_shell.course.pad_count(), 3)
	assert_eq(_shell.links.link_count(), 2)
	assert_eq(_shell.orders.checkpoint_count(), 3)
	assert_almost_eq(_shell.orders.sequence_node(1, 2).position.x, 1.0, 0.0001)
	assert_almost_eq(_shell.links.link_node(10).position.x, 1.5, 0.0001)
	assert_almost_eq(_shell.map.player_node(0).position.x, 2.0, 0.0001)
	assert_false(_shell.on_binary(PackedByteArray([1, 2, 3])))
	assert_eq(_shell.crates.crate_count(), 0)
	assert_true(_shell.on_binary(_snapshot(5, 3 * Fixed.SCALE, [_crate(40, 1)])))
	assert_eq(_shell.crates.crate_count(), 1)
	assert_almost_eq(_shell.crates.crate_node(40).position.z, 1.0, 0.0001)
	assert_almost_eq(_shell.map.player_node(0).position.x, 3.0, 0.0001)


func test_buttons_exist_and_live_io_stays_off_in_tests() -> void:
	_shell = _open_shell()
	assert_false(_shell.live_io)
	assert_not_null(_shell.window.get_node("VBoxContainer/MatchActions/%s" % MatchLobbyShell.QUICK_NAME))
	assert_not_null(_shell.window.get_node("VBoxContainer/MatchActions/%s" % MatchLobbyShell.CREATE_NAME))
	assert_not_null(_shell.window.get_node("VBoxContainer/%s" % MatchLobbyShell.ROOM_NAME))
	assert_eq(_shell.play_move_step, Fixed.SCALE / 16)


func test_snapshot_standings_rank_finished_first_without_settlement() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-e")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_ranked_snapshot(7, [
		_ranked_player(0, 1, -1),
		_ranked_player(Fixed.SCALE, 3, 4),
	])))
	assert_eq(_shell.standings.standing_count(), 2)
	assert_eq(_shell.standings.mvp_slot(), 1)
	assert_eq(_shell.standings.standing_node(0).text, "#2 P0 1/3")
	assert_eq(_shell.standings.standing_node(1).text, "#1 P1")
	assert_almost_eq(_shell.standings.standing_node(1).position.x, 1.0, 0.0001)
	assert_true(_shell.status_label_text().contains("standings=#1s1,#2s0 mvp=1"))
	assert_eq(_shell.map.standing_node_count(), 0)
	assert_eq(_shell.course.standing_node_count(), 0)
	assert_eq(_shell.crates.standing_node_count(), 0)
	assert_eq(_shell.links.standing_node_count(), 0)
	assert_eq(_shell.orders.standing_node_count(), 0)
	assert_false(_shell.on_binary(PackedByteArray([1, 2, 3])))
	assert_eq(_shell.standings.standing_node(0).text, "#2 P0 1/3")
	assert_eq(_shell.standings.mvp_slot(), 1)
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())


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


func _crate(entity_id: int, durability: int) -> Dictionary:
	return {
		"entity_id": entity_id,
		"durability": durability,
	}


func _snapshot(tick: int, x: int, crates: Array[Dictionary] = []) -> PackedByteArray:
	var players: Array[Dictionary] = [_ranked_player(x, 0, -1)]
	return MatchFrameCodec.encode_snapshot(tick, players, crates)


func _ranked_player(x: int, accepted_count: int, finish_tick: int) -> Dictionary:
	return {
		"x": x,
		"y": 0,
		"z": 0,
		"yaw_bam": 0,
		"accepted_count": accepted_count,
		"finish_tick": finish_tick,
	}


func _ranked_snapshot(tick: int, players: Array[Dictionary]) -> PackedByteArray:
	var crates: Array[Dictionary] = []
	return MatchFrameCodec.encode_snapshot(tick, players, crates)
