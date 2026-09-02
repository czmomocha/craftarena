extends GutTest

## MatchLobbyShell: TRAPRUSH quick play / room code / queue / latest snapshot.
## Injected HTTP and socket events. Close only hides. Never settlement.
## Own-seat SnapshotCamera follows the presentation pose; remotes do not.
## WASD writes discrete 8-way yaw_bam; player boxes show a facing marker.
## Own-seat box uses OWN_ALBEDO; standing labels prefix the own seat with "*".
## Own-seat accepted_count tints course pads done / current / pending.
## Own-seat finish_tick tints the finish zone; HUD shows pads/floor/finish/crates/hazards/result.
## Online matches sample protocol RTT after a pong; HUD then shows rtt= / rtt_n=.
## HUD 第一行是 FrameRateMeter 的帧率读数：可见帧才计，窗口隐藏丢弃半窗。
## Online all-finished GET writes settled=; Solo never GETs. Client never POSTs.
## Reset rising-edge returns to the last accepted pad without dropping progress.
## Online overlay stays off latest live crates, solid hazards, and latest remote capsules.

const FrameRateMeter := preload("res://src/client/frame_rate_meter.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchJoinSession := preload("res://src/client/match_join_session.gd")
const MatchLobbyShell := preload("res://src/client/match_lobby_shell.gd")
const MatchMoveFacing := preload("res://src/client/match_move_facing.gd")
const MatchOfflineSession := preload("res://src/client/match_offline_session.gd")
const MatchPlaySession := preload("res://src/client/match_play_session.gd")
const MatchSnapshotMap := preload("res://src/client/match_snapshot_map.gd")
const MatchStandingMap := preload("res://src/client/match_standing_map.gd")
const MatchCourseMap := preload("res://src/client/match_course_map.gd")
const ServerEndpointGd := preload("res://src/client/server_endpoint.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

var _shell: MatchLobbyShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_open_window_quick_play_ready_begins_play() -> void:
	_shell = _open_shell()
	assert_eq(_shell.window.title, UiCopy.text(MatchLobbyShell.TITLE))
	assert_eq(_shell.window.size, MatchLobbyShell.WINDOW_SIZE)
	assert_eq(_shell.window.min_size, MatchLobbyShell.WINDOW_MIN_SIZE)
	assert_eq(_shell.window.mode, Window.MODE_MAXIMIZED)
	assert_false(_shell.window.exclusive)
	assert_false(_shell.window.transient)
	assert_true(_shell.window.own_world_3d)
	assert_not_null(_shell.map)
	assert_not_null(_shell.course)
	assert_not_null(_shell.crates)
	assert_not_null(_shell.hazards)
	assert_not_null(_shell.solids)
	assert_not_null(_shell.links)
	assert_not_null(_shell.orders)
	assert_not_null(_shell.standings)
	assert_eq(_shell.map.player_count(), 0)
	assert_eq(_shell.course.pad_count(), 3)
	assert_eq(_shell.course.portal_count(), 5)
	assert_eq(_shell.course.finish_count(), 1)
	assert_eq(_shell.course.crate_node_count(), 0)
	assert_eq(_shell.course.link_node_count(), 0)
	assert_eq(_shell.course.checkpoint_node_count(), 0)
	assert_eq(_shell.crates.crate_count(), 1)
	assert_eq(_shell.hazards.hazard_count(), 1)
	assert_eq(_shell.hazards.hazard_total(), 1)
	assert_eq(_shell.solids.solid_count(), 36)
	assert_eq(_shell.solids.solid_total(), 36)
	assert_eq(_shell.course.hazard_node_count(), 0)
	assert_eq(_shell.crates.hazard_node_count(), 0)
	assert_eq(_shell.crates.link_node_count(), 0)
	assert_eq(_shell.crates.checkpoint_node_count(), 0)
	assert_eq(_shell.map.link_node_count(), 0)
	assert_eq(_shell.map.checkpoint_node_count(), 0)
	assert_eq(_shell.map.standing_node_count(), 0)
	assert_eq(_shell.links.link_count(), 5)
	assert_eq(_shell.links.direction_count(), 1)
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
	assert_almost_eq(_shell.course.finish_node(30).position.z, -3.0, 0.0001)
	assert_almost_eq(_shell.crates.crate_node(40).position.z, 1.0, 0.0001)
	assert_almost_eq(_shell.links.link_node(10).position.x, 1.5, 0.0001)
	assert_almost_eq(_shell.links.link_node(10).position.y, 0.5, 0.0001)
	assert_almost_eq(_shell.links.link_node(10).position.z, -1.5, 0.0001)
	assert_eq(_shell.orders.checkpoint_node(1).text, "0")
	assert_almost_eq(_shell.orders.checkpoint_node(1).position.y, 1.15, 0.0001)
	assert_almost_eq(_shell.orders.sequence_node(1, 2).position.x, 1.0, 0.0001)
	assert_true(_shell.status_label_text().contains("course=3/5/1"))
	assert_true(_shell.status_label_text().contains("tls=off"))
	assert_true(_shell.status_label_text().contains("course_id=course_01"))
	var idle_tls: bool = _shell.status_view().get("tls", true)
	assert_false(idle_tls)
	assert_true(_shell.status_label_text().contains("crates_mapped=1"))
	assert_true(_shell.status_label_text().contains("hazards_mapped=1"))
	assert_true(_shell.status_label_text().contains("solids_mapped=36"))
	assert_true(_shell.status_label_text().contains("links_mapped=5"))
	assert_true(_shell.status_label_text().contains("orders_mapped=3/2"))
	assert_true(_shell.try_quick())
	assert_true(_shell.join.pending_body().contains("course_01"))
	assert_true(_shell.join.pending_body().contains("\"seats\":2"))
	assert_true(_shell.status_label_text().contains("seats=2"))
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
	assert_eq(standing_mark.text, "*#1 P0 0/3")
	assert_almost_eq(standing_mark.position.x, 12.0 / float(Fixed.SCALE), 0.0001)
	assert_eq(_shell.map.crate_node_count(), 0)
	assert_eq(_shell.map.link_node_count(), 0)
	assert_eq(_shell.course.pad_count(), 3)
	assert_eq(_shell.crates.crate_count(), 0)
	assert_eq(_shell.links.link_count(), 5)
	assert_eq(_shell.orders.checkpoint_count(), 3)
	assert_eq(_shell.orders.sequence_count(), 2)
	assert_true(_shell.status_label_text().contains("tick=2"))
	assert_true(_shell.status_label_text().contains("mapped=1"))
	assert_true(_shell.status_label_text().contains("course=3/5/1"))
	assert_true(_shell.status_label_text().contains("crates_mapped=0"))
	assert_true(_shell.status_label_text().contains("hazards_mapped=1"))
	assert_true(_shell.status_label_text().contains("solids_mapped=36"))
	assert_true(_shell.status_label_text().contains("links_mapped=5"))
	assert_true(_shell.status_label_text().contains("orders_mapped=3/2"))
	assert_true(_shell.status_label_text().contains("standings=#1s0 mvp=-"))
	assert_true(_shell.status_label_text().contains("room=ABCD23"))
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())


func test_online_pong_shows_rtt_on_status_line() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-rtt")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(2, 12)))
	assert_false(_shell.status_label_text().contains("rtt="))
	var ping: PackedByteArray = _shell.play.try_encode_probe(50)
	assert_false(ping.is_empty())
	assert_true(_shell.on_binary(MatchFrameCodec.echo_pong(ping), 57))
	var view: Dictionary = _shell.status_view()
	var rtt_n: int = view.get("rtt_n", 0)
	var rtt_ms: int = view.get("rtt_ms", -1)
	assert_eq(rtt_n, 1)
	assert_eq(rtt_ms, 7)
	assert_true(_shell.status_label_text().contains("rtt=7"))
	assert_true(_shell.status_label_text().contains("rtt_n=1"))
	assert_eq(_shell.play.follow.tick, 2)


func test_frame_rate_row_counts_visible_frames_only() -> void:
	_shell = _open_shell()
	var fps: FrameRateMeter = _shell.window.find_child(MatchLobbyShell.FPS_NAME, true, false)
	assert_not_null(fps)
	# 帧率是 HUD 的**第一行**，不是状态行的一部分：状态行只在事件发生时重画，
	# 帧率必须每帧累计，掺进去就得每帧重写整行状态。
	assert_eq(fps.get_index(), 0)
	assert_eq(fps.get_parent().name, "VBoxContainer")
	assert_eq(_shell.fps_label_text(), FrameRateMeter.PLACEHOLDER)
	assert_eq(fps.text, FrameRateMeter.PLACEHOLDER)
	# 60 帧 × 0.01 s：第 50 帧满 0.5 s 刷新一次，50 / 0.5 = 100。再喂 10 帧
	# 不该改这个数字——刷新是节流的，不是每帧一次。
	for _i: int in range(60):
		_shell._process(0.01)
	assert_eq(_shell.fps_label_text(), "FPS 100")
	assert_eq(fps.text, "FPS 100")
	assert_false(_shell.status_label_text().contains("FPS"))
	# 窗口隐藏期间不计帧：隐藏时先丢弃半窗，再显示时不会读出一个假的卡顿。
	_shell._process(0.01)
	assert_eq(_shell.fps_label_text(), "FPS 100")
	_shell.hide_window()
	_shell._process(0.01)
	assert_eq(_shell.fps_label_text(), FrameRateMeter.PLACEHOLDER)


func test_hud_buttons_do_not_steal_space_and_window_is_dev_default() -> void:
	_shell = _open_shell()
	assert_eq(_shell.window.size, MatchLobbyShell.WINDOW_SIZE)
	assert_eq(_shell.window.min_size, MatchLobbyShell.WINDOW_MIN_SIZE)
	assert_eq(_shell.window.mode, Window.MODE_MAXIMIZED)
	# C4 第 6 章回归守卫：嵌入子窗口**不得**自己设 content_scale。
	# 设了会让 UI 画的位置与鼠标命中的位置错开 1/factor 倍（实测 4K 屏上点
	# Solo play 命中 Poll），且布局撑到基准宽后右侧被切出可视区。
	# D4 的 1920×1080 基准由主窗口 stretch 承担，见 test_project_contract.gd。
	assert_eq(_shell.window.content_scale_mode, Window.CONTENT_SCALE_MODE_DISABLED)
	assert_eq(_shell.window.content_scale_size, Vector2i(0, 0))
	var solo: Button = _shell.window.find_child(MatchLobbyShell.SOLO_NAME, true, false)
	assert_not_null(solo)
	assert_eq(solo.focus_mode, Control.FOCUS_NONE)
	assert_false(solo.has_focus())
	assert_true(_shell.try_solo())
	assert_false(solo.has_focus())
	var room: LineEdit = _shell.window.find_child(MatchLobbyShell.ROOM_NAME, true, false)
	assert_not_null(room)
	assert_eq(room.focus_mode, Control.FOCUS_CLICK)


func test_line_edit_focus_releases_outside_fields_and_on_play_actions() -> void:
	_shell = _open_shell()
	var seats: LineEdit = _shell.window.find_child(MatchLobbyShell.SEATS_NAME, true, false)
	assert_not_null(seats)
	seats.grab_focus()
	assert_true(seats.has_focus())
	var miss: InputEventMouseButton = InputEventMouseButton.new()
	miss.pressed = true
	miss.button_index = MOUSE_BUTTON_LEFT
	miss.position = Vector2(400, 500)
	_shell.handle_window_input(miss)
	assert_false(seats.has_focus())
	seats.grab_focus()
	assert_true(seats.has_focus())
	var hit: InputEventMouseButton = InputEventMouseButton.new()
	hit.pressed = true
	hit.button_index = MOUSE_BUTTON_LEFT
	hit.position = seats.get_global_rect().get_center()
	_shell.handle_window_input(hit)
	assert_true(seats.has_focus())
	assert_true(_shell.try_solo())
	assert_false(seats.has_focus())
	_shell.try_cancel()
	var course: LineEdit = _shell.window.find_child(MatchLobbyShell.COURSE_ID_NAME, true, false)
	assert_not_null(course)
	course.grab_focus()
	assert_true(course.has_focus())
	_shell._on_edit_submitted(course.text)
	assert_false(course.has_focus())


func test_wss_gateway_base_shows_tls_on() -> void:
	_shell = _open_shell()
	assert_true(_shell.status_label_text().contains("tls=off"))
	_shell.gateway_base = "wss://127.0.0.1:8090"
	var wss_tls: bool = _shell.status_view().get("tls", false)
	assert_true(wss_tls)
	assert_true(_shell.try_quick())
	assert_true(_shell.status_label_text().contains("tls=on"))
	assert_false(_shell.status_label_text().contains("tls=off"))


func test_in_match_close_reconnects_and_follows_new_snapshot() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-a")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(2, 12)))
	assert_eq(_shell.play.follow.tick, 2)
	_shell.on_socket_close()
	assert_eq(_shell.play.state, MatchPlaySession.STATE_CLOSED)
	assert_true(_shell.join.has_pending())
	assert_eq(_shell.join.pending_path(), "/match-sessions/match-1/tickets/reconnect")
	assert_true(_shell.join.pending_body().contains("ticket-a"))
	assert_true(_shell.accept_http(201, {
		"ticket": "ticket-b",
		"matchId": "match-1",
		"expiresAt": "2026-08-25T04:11:00.000Z",
		"seat": 0,
	}))
	assert_eq(_shell.join.ticket, "ticket-b")
	assert_eq(_shell.play.state, MatchPlaySession.STATE_CONNECTING)
	assert_eq(_shell.play.websocket_url, "ws://127.0.0.1:8090/ws?ticket=ticket-b")
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(9, 24)))
	assert_eq(_shell.play.follow.tick, 9)
	var marker: MeshInstance3D = _shell.map.player_node(0)
	assert_almost_eq(marker.position.x, 24.0 / float(Fixed.SCALE), 0.0001)


func test_in_match_cancel_leaves_without_reconnect() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-a")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(2, 12)))
	assert_eq(_shell.map.player_count(), 1)
	assert_eq(_shell.play.follow.tick, 2)
	assert_true(_shell.status_label_text().contains("tick=2"))
	assert_true(_shell.try_cancel())
	assert_eq(_shell.play.state, MatchPlaySession.STATE_IDLE)
	assert_eq(_shell.join.state, MatchJoinSession.STATE_IDLE)
	assert_false(_shell.join.has_pending())
	assert_eq(_shell.map.player_count(), 0)
	assert_eq(_shell.standings.standing_count(), 0)
	assert_false(_shell.status_label_text().contains("tick=2"))
	assert_true(_shell.status_label_text().contains("play=idle"))
	assert_true(_shell.status_label_text().contains("join=idle"))
	assert_true(_shell.try_sample_play_move(false, false, false, true).is_empty())
	assert_false(_shell.on_binary(_snapshot(3, 24)))
	assert_eq(_shell.map.player_count(), 0)
	assert_false(_shell.join.has_pending())
	assert_true(_shell.try_quick())
	assert_true(_shell.join.has_pending())


func test_reconnect_pending_cancel_does_not_reissue() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-a")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(2, 12)))
	_shell.on_socket_close()
	assert_eq(_shell.play.state, MatchPlaySession.STATE_CLOSED)
	assert_true(_shell.join.has_pending())
	assert_true(_shell.try_cancel())
	assert_eq(_shell.play.state, MatchPlaySession.STATE_IDLE)
	assert_eq(_shell.join.state, MatchJoinSession.STATE_IDLE)
	assert_false(_shell.join.has_pending())
	assert_false(_shell.accept_http(201, {
		"ticket": "ticket-b",
		"matchId": "match-1",
		"expiresAt": "2026-08-25T04:11:00.000Z",
		"seat": 0,
	}))
	assert_eq(_shell.play.state, MatchPlaySession.STATE_IDLE)
	assert_eq(_shell.map.player_count(), 0)


func test_queue_wait_poll_cancel_and_invalid_code() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_create_room())
	assert_true(_shell.accept_http(202, {
		"status": "waiting",
		"queueToken": "queue-token-aaaaaaaaaaaaaaaa",
		"position": 1,
		"estimatedWaitMs": 30000,
		"expiresAt": "2026-08-25T02:10:00.000Z",
		"course": "course_01",
		"seats": 2,
	}))
	assert_eq(_shell.join.state, MatchJoinSession.STATE_WAITING)
	assert_true(_shell.status_label_text().contains("pos=1"))
	assert_true(_shell.status_label_text().contains("wait_ms=30000"))
	assert_true(_shell.status_label_text().contains("seats=2"))
	assert_true(_shell.try_poll())
	assert_true(_shell.accept_http(200, {
		"status": "waiting",
		"queueToken": "queue-token-aaaaaaaaaaaaaaaa",
		"position": 1,
		"estimatedWaitMs": 30000,
		"expiresAt": "2026-08-25T02:10:00.000Z",
		"course": "course_01",
		"seats": 2,
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
	var shove: PackedByteArray = _shell.try_sample_play_shove(true)
	assert_false(shove.is_empty())
	var shove_decoded: Dictionary = MatchFrameCodec.decode_command(shove)
	var shove_intent: String = shove_decoded.get("intent", "")
	assert_eq(shove_intent, PlayerIntentNames.SHOVE)
	assert_true(_shell.try_sample_play_shove(true).is_empty())
	var sprint: PackedByteArray = _shell.try_sample_play_sprint(true)
	assert_false(sprint.is_empty())
	var sprint_decoded: Dictionary = MatchFrameCodec.decode_command(sprint)
	var sprint_intent: String = sprint_decoded.get("intent", "")
	assert_eq(sprint_intent, PlayerIntentNames.SPRINT)
	assert_true(_shell.try_sample_play_sprint(true).is_empty())
	_shell.window.close_requested.emit()
	assert_false(_shell.is_window_visible())
	assert_eq(_shell.join.state, MatchJoinSession.STATE_READY)
	assert_true(_shell.try_sample_play_move(true, false, false, false).is_empty())
	assert_true(_shell.try_sample_play_shove(false).is_empty())
	assert_true(_shell.try_sample_play_shove(true).is_empty())
	assert_true(_shell.show_window())
	assert_true(_shell.is_window_visible())


func test_vector_move_encodes_the_same_bytes_as_boolean_axes() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-vector")))
	assert_true(_shell.on_socket_open())
	var from_bool: PackedByteArray = _shell.try_sample_play_move(true, false, false, true)
	var from_vector: PackedByteArray = _shell.try_sample_play_vector(1.0, -1.0)
	var weak: PackedByteArray = _shell.try_sample_play_vector(0.3, 0.0)
	var right: PackedByteArray = _shell.try_sample_play_move(false, false, false, true)
	assert_false(from_bool.is_empty())
	assert_eq(from_vector, from_bool)
	assert_eq(weak, right)


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
	assert_almost_eq(_shell.course.finish_node(30).position.z, -3.0, 0.0001)
	assert_eq(_shell.crates.crate_count(), 0)
	assert_eq(_shell.links.link_count(), 5)
	assert_almost_eq(_shell.links.link_node(10).position.x, 1.5, 0.0001)
	assert_eq(_shell.orders.checkpoint_count(), 3)
	assert_almost_eq(_shell.orders.checkpoint_node(3).position.z, -3.0, 0.0001)
	assert_eq(_shell.standings.standing_count(), 1)
	assert_eq(_shell.standings.standing_node(0).text, "*#1 P0 0/3")
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
	assert_eq(_shell.links.link_count(), 5)
	assert_eq(_shell.orders.checkpoint_count(), 3)
	assert_true(_shell.on_binary(_snapshot(4, 2 * Fixed.SCALE, [_crate(40, 0)])))
	assert_eq(_shell.crates.crate_count(), 0)
	assert_eq(_shell.course.pad_count(), 3)
	assert_eq(_shell.links.link_count(), 5)
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
	assert_not_null(_shell.window.get_node("VBoxContainer/MatchActions/%s" % MatchLobbyShell.SOLO_NAME))
	assert_not_null(_shell.window.get_node("VBoxContainer/%s" % MatchLobbyShell.ROOM_NAME))
	assert_eq(_shell.play_move_step, Fixed.SCALE / 16)
	assert_eq(_shell.play_interp_step, Fixed.SCALE / 2)


func test_solo_play_maps_local_authority_without_http() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	assert_eq(_shell.offline.state, MatchOfflineSession.STATE_PLAYING)
	assert_eq(_shell.join.state, MatchJoinSession.STATE_IDLE)
	assert_false(_shell.join.has_pending())
	assert_eq(_shell.play.state, MatchPlaySession.STATE_IDLE)
	assert_eq(_shell.map.player_count(), 1)
	assert_eq(_shell.standings.standing_count(), 1)
	assert_eq(_shell.standings.standing_node(0).text, "*#1 P0 1/3")
	assert_true(_shell.status_label_text().contains(UiCopy.text(MatchOfflineSession.BANNER_KEY)))
	assert_true(_shell.status_label_text().contains("offline=playing"))
	assert_true(_shell.status_label_text().contains("standings=#1s0 mvp=-"))
	assert_false(_shell.try_quick())
	assert_false(_shell.try_create_room())
	assert_false(_shell.join.has_pending())
	var before_x: float = _shell.map.player_node(0).position.x
	var move: PackedByteArray = _shell.try_sample_play_move(false, false, false, true)
	assert_false(move.is_empty())
	assert_gt(_shell.map.player_node(0).position.x, before_x)
	assert_true(_shell.try_cancel())
	assert_eq(_shell.offline.state, MatchOfflineSession.STATE_IDLE)
	assert_eq(_shell.map.player_count(), 0)
	assert_eq(_shell.standings.standing_count(), 0)
	assert_eq(_shell.crates.crate_count(), 1)
	assert_false(_shell.status_label_text().contains(UiCopy.text(MatchOfflineSession.BANNER_KEY)))
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())


func test_solo_refuses_web_and_online_busy() -> void:
	_shell = _open_shell()
	_shell.web_platform = true
	assert_false(_shell.try_solo())
	assert_eq(_shell.offline.last_error, "web_locked")
	assert_eq(_shell.map.player_count(), 0)
	_shell.web_platform = false
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-solo")))
	assert_eq(_shell.play.state, MatchPlaySession.STATE_CONNECTING)
	assert_false(_shell.try_solo())
	assert_eq(_shell.offline.state, MatchOfflineSession.STATE_IDLE)
	assert_eq(_shell.play.websocket_url, "ws://127.0.0.1:8090/ws?ticket=ticket-solo")


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
	assert_eq(_shell.standings.standing_node(0).text, "*#2 P0 1/3")
	assert_eq(_shell.standings.standing_node(1).text, "#1 P1")
	assert_almost_eq(_shell.standings.standing_node(1).position.x, 1.0, 0.0001)
	assert_true(_shell.status_label_text().contains("standings=#1s1,#2s0 mvp=1"))
	assert_eq(_shell.map.standing_node_count(), 0)
	assert_eq(_shell.course.standing_node_count(), 0)
	assert_eq(_shell.crates.standing_node_count(), 0)
	assert_eq(_shell.links.standing_node_count(), 0)
	assert_eq(_shell.orders.standing_node_count(), 0)
	assert_false(_shell.on_binary(PackedByteArray([1, 2, 3])))
	assert_eq(_shell.standings.standing_node(0).text, "*#2 P0 1/3")
	assert_eq(_shell.standings.mvp_slot(), 1)
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())


func test_selected_course_is_sent_and_join_response_remounts_maps() -> void:
	_shell = _open_shell()
	assert_eq(_shell.course_id_text(), "course_01")
	_shell.set_course_id_text("res://content/official/traprush/course_01.json")
	assert_false(_shell.try_quick())
	assert_false(_shell.join.has_pending())
	_shell.set_course_id_text("course_02")
	assert_true(_shell.try_quick())
	assert_true(_shell.join.pending_body().contains("course_02"))
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-course", "course_03")))
	assert_eq(_shell.join.course, "course_03")
	assert_eq(_shell.course.pad_count(), 4)
	assert_eq(_shell.course.portal_count(), 3)
	assert_eq(_shell.course.finish_count(), 1)
	assert_eq(_shell.orders.checkpoint_count(), 4)
	assert_eq(_shell.orders.sequence_count(), 3)
	assert_eq(_shell.links.link_count(), 3)
	assert_true(_shell.status_label_text().contains("course_id=course_03"))
	assert_true(_shell.status_label_text().contains("course=4/3/1"))
	assert_true(_shell.status_label_text().contains("orders_mapped=4/3"))


func test_selected_seats_are_sent_and_invalid_counts_rejected() -> void:
	_shell = _open_shell()
	assert_eq(_shell.seats_text(), "2")
	_shell.set_seats_text("9")
	assert_false(_shell.try_quick())
	assert_false(_shell.join.has_pending())
	_shell.set_seats_text("x")
	assert_false(_shell.try_create_room())
	_shell.set_seats_text("8")
	assert_true(_shell.try_quick())
	assert_true(_shell.join.pending_body().contains("\"seats\":8"))
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-seats", "course_01", 8)))
	assert_eq(_shell.join.seats, 8)
	assert_true(_shell.status_label_text().contains("seats=8"))


func test_solo_uses_selected_official_course() -> void:
	_shell = _open_shell()
	_shell.set_course_id_text("course_03")
	assert_true(_shell.try_solo())
	assert_eq(_shell.offline.state, MatchOfflineSession.STATE_PLAYING)
	assert_eq(_shell.course.pad_count(), 4)
	assert_eq(_shell.orders.checkpoint_count(), 4)
	assert_true(_shell.offline.course_path.ends_with("course_03.json"))
	assert_true(_shell.status_label_text().contains("course=4/3/1"))


func test_sub_cell_snapshot_interpolates_remote_and_own_slot_stays_on_latest() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-interp")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.status_label_text().contains("seat=0"))
	assert_true(_shell.on_binary(_two_player_snapshot(1, 0, 0, [_crate(40, 1)])))
	assert_almost_eq(_shell.map.player_node(0).position.x, 0.0, 0.0001)
	assert_almost_eq(_shell.map.player_node(1).position.x, 0.0, 0.0001)
	assert_eq(_shell.interp_progress(), Fixed.SCALE)
	assert_eq(_shell.crates.crate_count(), 1)
	assert_true(_shell.on_binary(_two_player_snapshot(2, Fixed.SCALE / 2, Fixed.SCALE / 2, [_crate(40, 0)])))
	assert_eq(_shell.interp_progress(), 0)
	assert_almost_eq(_shell.map.player_node(0).position.x, 0.5, 0.0001)
	assert_almost_eq(_shell.map.player_node(1).position.x, 0.0, 0.0001)
	assert_almost_eq(_shell.standings.standing_node(0).position.x, 0.5, 0.0001)
	assert_almost_eq(_shell.standings.standing_node(1).position.x, 0.0, 0.0001)
	assert_eq(_shell.crates.crate_count(), 0)
	_shell.play_interp_step = Fixed.SCALE / 2
	assert_true(_shell.try_advance_interp())
	assert_almost_eq(_shell.map.player_node(0).position.x, 0.5, 0.0001)
	assert_almost_eq(_shell.map.player_node(1).position.x, 0.25, 0.0001)
	assert_eq(_shell.crates.crate_count(), 0)
	assert_true(_shell.try_advance_interp())
	assert_almost_eq(_shell.map.player_node(1).position.x, 0.5, 0.0001)
	assert_eq(_shell.interp_progress(), Fixed.SCALE)
	assert_false(_shell.try_advance_interp())
	_shell.hide_window()
	assert_false(_shell.try_advance_interp())
	assert_almost_eq(_shell.map.player_node(1).position.x, 0.5, 0.0001)
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())


func test_own_slot_move_predicts_until_newer_snapshot() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-predict")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(1, 0, [_crate(40, 1)])))
	assert_almost_eq(_shell.map.player_node(0).position.x, 0.0, 0.0001)
	var step: float = float(_shell.play_move_step) / float(Fixed.SCALE)
	var move: PackedByteArray = _shell.try_sample_play_move(false, false, false, true)
	assert_false(move.is_empty())
	assert_almost_eq(_shell.map.player_node(0).position.x, step, 0.0001)
	assert_almost_eq(_shell.standings.standing_node(0).position.x, step, 0.0001)
	assert_eq(_shell.crates.crate_count(), 1)
	assert_true(_shell.on_binary(_snapshot(2, 0, [_crate(40, 1)])))
	assert_almost_eq(_shell.map.player_node(0).position.x, 0.0, 0.0001)
	assert_eq(_shell.play.predict.dx, 0)
	assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
	assert_almost_eq(_shell.map.player_node(0).position.x, step, 0.0001)
	assert_true(_shell.on_binary(_snapshot(3, _shell.play_move_step, [_crate(40, 1)])))
	assert_almost_eq(_shell.map.player_node(0).position.x, step, 0.0001)
	assert_eq(_shell.play.predict.dx, 0)
	_shell.play.play_jump_dy = Fixed.SCALE
	assert_false(_shell.try_sample_play_jump(true).is_empty())
	assert_almost_eq(_shell.map.player_node(0).position.y, 1.0, 0.0001)
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())


func test_online_overlay_stops_on_live_crate_then_passes_when_broken() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-crate-solid")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(1, 0, [_crate(40, 1)])))
	assert_eq(_shell.crates.crate_count(), 1)
	assert_eq(_shell.crates.live_solid_boxes().size(), 1)
	var steps: int = 0
	while steps < 20:
		assert_false(_shell.try_sample_play_move(false, true, false, false).is_empty())
		steps += 1
	assert_gt(_shell.play.predict.dz, 0)
	assert_almost_eq(_shell.map.player_node(0).position.z, 0.0, 0.0001)
	assert_true(_shell.on_binary(_snapshot(2, 0, [_crate(40, 0)])))
	assert_eq(_shell.crates.crate_count(), 0)
	assert_eq(_shell.play.predict.dz, 0)
	steps = 0
	while steps < 20:
		assert_false(_shell.try_sample_play_move(false, true, false, false).is_empty())
		steps += 1
	assert_gt(_shell.map.player_node(0).position.z, 1.0)


func test_online_overlay_stops_on_latest_remote_capsule() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-remote-solid")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_two_player_snapshot(1, 0, Fixed.SCALE, [_crate(40, 1)])))
	var remote_steps: int = 0
	while remote_steps < 20:
		assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
		remote_steps += 1
	assert_gt(_shell.play.predict.dx, 0)
	assert_almost_eq(_shell.map.player_node(0).position.x, 0.0, 0.0001)
	assert_almost_eq(_shell.map.player_node(1).position.x, 1.0, 0.0001)


func test_online_overlay_stops_on_solid_hazard_then_passes_when_open() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-hazard-solid")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(0, 0, [_crate(40, 1)])))
	assert_true(_shell.hazards.apply_bundle(_one_hazard_bundle(1)))
	assert_eq(_shell.hazards.hazard_count(), 1)
	assert_eq(_shell.hazards.live_solid_boxes().size(), 1)
	var steps: int = 0
	while steps < 20:
		assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
		steps += 1
	assert_gt(_shell.play.predict.dx, 0)
	assert_almost_eq(_shell.map.player_node(0).position.x, 0.0, 0.0001)
	assert_true(_shell.on_binary(_snapshot(1, 0, [_crate(40, 1)])))
	assert_eq(_shell.hazards.hazard_count(), 0)
	assert_eq(_shell.play.predict.dx, 0)
	steps = 0
	while steps < 20:
		assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
		steps += 1
	assert_gt(_shell.map.player_node(0).position.x, 1.0)


func test_online_overlay_stops_on_always_solid() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-solid-block")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(0, 0, [_crate(40, 1)])))
	assert_true(_shell.solids.apply_bundle(_one_solid_bundle()))
	assert_eq(_shell.solids.solid_count(), 1)
	assert_eq(_shell.solids.live_solid_boxes().size(), 1)
	var steps: int = 0
	while steps < 20:
		assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
		steps += 1
	assert_gt(_shell.play.predict.dx, 0)
	assert_almost_eq(_shell.map.player_node(0).position.x, 0.0, 0.0001)


func test_online_overlay_stops_on_official_solid() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-official-solid")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(0, 0, [_crate(40, 1)])))
	assert_eq(_shell.solids.solid_count(), 36)
	assert_eq(_shell.solids.live_solid_boxes().size(), 36)
	var steps: int = 0
	while steps < 20:
		assert_false(_shell.try_sample_play_move(false, false, true, false).is_empty())
		steps += 1
	assert_lt(_shell.play.predict.dx, 0)
	assert_almost_eq(_shell.map.player_node(0).position.x, 0.0, 0.0001)


func test_offline_solo_does_not_stack_local_predict_overlay() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	assert_eq(_shell.play.state, MatchPlaySession.STATE_IDLE)
	assert_eq(_shell.play.predict.own_slot, -1)
	var origin_x: float = _shell.map.player_node(0).position.x
	var move: PackedByteArray = _shell.try_sample_play_move(false, false, false, true)
	assert_false(move.is_empty())
	assert_eq(_shell.play.predict.dx, 0)
	var moved_x: float = _shell.map.player_node(0).position.x
	var step: float = float(_shell.play_move_step) / float(Fixed.SCALE)
	assert_almost_eq(moved_x - origin_x, step, 0.0001)


func test_solo_camera_follows_local_player_and_cancel_resets() -> void:
	_shell = _open_shell()
	_assert_lobby_camera_at(Vector3.ZERO)
	assert_true(_shell.try_solo())
	_assert_lobby_camera_on(_shell.map.player_node(0))
	assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
	_assert_lobby_camera_on(_shell.map.player_node(0))
	assert_true(_shell.try_cancel())
	assert_eq(_shell.map.follow_slot, -1)
	_assert_lobby_camera_at(Vector3.ZERO)


func test_online_camera_follows_own_slot_not_remote() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-cam")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_two_player_snapshot(1, 0, 2 * Fixed.SCALE)))
	_assert_lobby_camera_on(_shell.map.player_node(0))
	var remote_expected: Vector3 = _shell.map.player_node(1).position + MatchSnapshotMap.CAMERA_OFFSET
	assert_gt(
		_shell.map.camera_node().position.distance_to(remote_expected),
		0.5
	)
	assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
	_assert_lobby_camera_on(_shell.map.player_node(0))


func test_online_camera_follows_seat_one() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-seat1", "course_01", 2, 1)))
	assert_eq(_shell.play.predict.own_slot, 1)
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_two_player_snapshot(1, 0, 2 * Fixed.SCALE)))
	_assert_lobby_camera_on(_shell.map.player_node(1))
	assert_true(_shell.try_cancel())
	assert_eq(_shell.map.follow_slot, -1)
	_assert_lobby_camera_at(Vector3.ZERO)


func test_solo_wasd_turns_facing_marker() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	var player: MeshInstance3D = _shell.map.player_node(0)
	var face: MeshInstance3D = _shell.map.facing_node(0)
	assert_not_null(player)
	assert_not_null(face)
	_assert_player_yaw(player, MatchMoveFacing.YAW_FORWARD)
	assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
	player = _shell.map.player_node(0)
	face = _shell.map.facing_node(0)
	_assert_player_yaw(player, MatchMoveFacing.YAW_RIGHT)
	assert_gt(face.global_position.x - player.global_position.x, 0.4)
	assert_false(_shell.try_sample_play_move(true, false, false, false).is_empty())
	player = _shell.map.player_node(0)
	face = _shell.map.facing_node(0)
	_assert_player_yaw(player, MatchMoveFacing.YAW_FORWARD)
	assert_lt(face.global_position.z - player.global_position.z, -0.4)


func test_online_wasd_overlays_yaw_then_hard_snaps() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-yaw")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(1, 0, [_crate(40, 1)])))
	_assert_player_yaw(_shell.map.player_node(0), MatchMoveFacing.YAW_FORWARD)
	assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
	_assert_player_yaw(_shell.map.player_node(0), MatchMoveFacing.YAW_RIGHT)
	assert_eq(_shell.play.predict.yaw_bam, MatchMoveFacing.YAW_RIGHT)
	assert_true(_shell.on_binary(_snapshot(2, 0, [_crate(40, 1)])))
	assert_eq(_shell.play.predict.yaw_bam, -1)
	_assert_player_yaw(_shell.map.player_node(0), MatchMoveFacing.YAW_FORWARD)


func test_solo_own_slot_tints_box_and_stars_standing() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	assert_eq(_player_albedo(_shell.map.player_node(0)), MatchSnapshotMap.OWN_ALBEDO)
	var mark: Label3D = _shell.standings.standing_node(0)
	assert_not_null(mark)
	assert_true(mark.text.begins_with(MatchStandingMap.OWN_MARK_PREFIX))
	assert_true(_shell.try_cancel())
	assert_eq(_shell.map.follow_slot, -1)
	assert_eq(_shell.standings.follow_slot, -1)


func test_online_own_slot_tints_self_not_remote() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-tint")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_two_player_snapshot(1, 0, 2 * Fixed.SCALE)))
	assert_eq(_player_albedo(_shell.map.player_node(0)), MatchSnapshotMap.OWN_ALBEDO)
	assert_eq(_player_albedo(_shell.map.player_node(1)), MatchSnapshotMap.REMOTE_ALBEDO)
	assert_true(_shell.standings.standing_node(0).text.begins_with("*"))
	assert_false(_shell.standings.standing_node(1).text.begins_with("*"))


func test_online_seat_one_tints_second_box() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-tint1", "course_01", 2, 1)))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_two_player_snapshot(1, 0, 2 * Fixed.SCALE)))
	assert_eq(_player_albedo(_shell.map.player_node(0)), MatchSnapshotMap.REMOTE_ALBEDO)
	assert_eq(_player_albedo(_shell.map.player_node(1)), MatchSnapshotMap.OWN_ALBEDO)
	assert_false(_shell.standings.standing_node(0).text.begins_with("*"))
	assert_true(_shell.standings.standing_node(1).text.begins_with("*"))


func test_solo_own_progress_tints_pads_and_cancel_restores() -> void:
	_shell = _open_shell()
	assert_eq(_pad_albedo(1), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_PENDING_ALBEDO)
	assert_true(_shell.try_solo())
	assert_eq(_shell.offline.session.player_accepted_count(0), 1)
	assert_eq(_pad_albedo(1), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(2), MatchCourseMap.CURRENT_ALBEDO)
	assert_eq(_pad_albedo(3), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_PENDING_ALBEDO)
	assert_true(_shell.status_label_text().contains("pads=1/3"))
	assert_true(_shell.status_label_text().contains("floor=0"))
	assert_true(_shell.status_label_text().contains("finish=-1"))
	assert_true(_shell.status_label_text().contains("crates=1/1"))
	assert_true(_shell.status_label_text().contains("hazards=1/1"))
	assert_true(_shell.status_label_text().contains("solids=36/36"))
	assert_false(_shell.status_label_text().contains("result="))
	assert_true(_shell.try_cancel())
	assert_eq(_shell.course.own_accepted_count(), -1)
	assert_eq(_shell.course.own_finish_tick(), -1)
	assert_eq(_pad_albedo(1), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(_pad_albedo(2), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_PENDING_ALBEDO)
	assert_false(_shell.status_label_text().contains("pads="))
	assert_false(_shell.status_label_text().contains("floor="))
	assert_false(_shell.status_label_text().contains("crates=1/1"))
	assert_false(_shell.status_label_text().contains("hazards="))
	assert_false(_shell.status_label_text().contains("solids="))
	assert_false(_shell.status_label_text().contains("result="))


func test_solo_walk_accepts_second_pad_and_retints() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	var steps: int = 0
	while steps < 40:
		assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
		if _shell.offline.session.player_accepted_count(0) >= 2:
			break
		steps += 1
	assert_eq(_shell.offline.session.player_accepted_count(0), 2)
	assert_eq(_pad_albedo(1), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(2), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(3), MatchCourseMap.CURRENT_ALBEDO)
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_PENDING_ALBEDO)
	assert_true(_shell.status_label_text().contains("pads=2/3"))
	assert_true(_shell.status_label_text().contains("finish=-1"))


func test_solo_walk_finishes_and_marks_local_result() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	var steps: int = 0
	while steps < 200:
		assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
		if _shell.offline.session.player_finish_tick(0) >= 0:
			break
		steps += 1
	assert_gte(_shell.offline.session.player_finish_tick(0), 0)
	assert_eq(_shell.offline.session.player_accepted_count(0), 3)
	assert_eq(_pad_albedo(1), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(2), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(3), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_ACCEPTED_ALBEDO)
	assert_true(_shell.status_label_text().contains("pads=3/3"))
	assert_false(_shell.status_label_text().contains("finish=-1"))
	assert_true(_shell.status_label_text().contains("result="))
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())
	assert_false(_shell.status_label_text().contains("settled="))
	assert_false(_shell.try_fetch_settlement())
	assert_false(_shell.join.has_pending())
	assert_true(_shell.try_cancel())
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_PENDING_ALBEDO)
	assert_false(_shell.status_label_text().contains("result="))
	assert_false(_shell.status_label_text().contains("pads="))
	assert_false(_shell.status_label_text().contains("floor="))


func test_online_own_progress_follows_seat_accepted_count() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-pads")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_ranked_snapshot(1, [
		_ranked_player(0, 1, -1),
		_ranked_player(2 * Fixed.SCALE, 2, -1),
	])))
	assert_eq(_pad_albedo(1), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(2), MatchCourseMap.CURRENT_ALBEDO)
	assert_eq(_pad_albedo(3), MatchCourseMap.PENDING_ALBEDO)
	assert_true(_shell.try_cancel())
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-pads1", "course_01", 2, 1)))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_ranked_snapshot(1, [
		_ranked_player(0, 1, -1),
		_ranked_player(2 * Fixed.SCALE, 2, -1),
	])))
	assert_eq(_pad_albedo(1), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(2), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(3), MatchCourseMap.CURRENT_ALBEDO)


func test_online_finish_tints_and_result_when_all_done() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-finish")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_ranked_snapshot(1, [
		_ranked_player(0, 3, -1),
		_ranked_player(2 * Fixed.SCALE, 1, -1),
	])))
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_CURRENT_ALBEDO)
	assert_true(_shell.status_label_text().contains("pads=3/3"))
	assert_true(_shell.status_label_text().contains("finish=-1"))
	assert_false(_shell.status_label_text().contains("result="))
	assert_true(_shell.on_binary(_ranked_snapshot(2, [
		_ranked_player(0, 3, 4),
		_ranked_player(2 * Fixed.SCALE, 1, -1),
	])))
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_ACCEPTED_ALBEDO)
	assert_false(_shell.status_label_text().contains("result="))
	assert_false(_shell.try_fetch_settlement())
	assert_true(_shell.on_binary(_ranked_snapshot(3, [
		_ranked_player(0, 3, 4),
		_ranked_player(2 * Fixed.SCALE, 3, 8),
	])))
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_ACCEPTED_ALBEDO)
	assert_true(_shell.status_label_text().contains("result="))
	assert_true(_shell.status_label_text().contains("mvp=0"))
	assert_false(_shell.status_label_text().contains("settled="))
	assert_true(_shell.try_fetch_settlement())
	assert_eq(_shell.join.pending_method(), "GET")
	assert_eq(_shell.join.pending_path(), "/match-sessions/match-1/settlement")
	assert_true(_shell.accept_http(200, _settlement_board()))
	assert_true(_shell.status_label_text().contains("result="))
	assert_true(_shell.status_label_text().contains("settled=#1s0,#2s1 mvp=0"))
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())
	assert_true(_shell.try_cancel())
	assert_false(_shell.status_label_text().contains("settled="))
	assert_false(_shell.status_label_text().contains("result="))


func test_online_finish_404_keeps_local_result_without_settled() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-settle-404")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_ranked_snapshot(3, [
		_ranked_player(0, 3, 4),
		_ranked_player(2 * Fixed.SCALE, 3, 8),
	])))
	assert_true(_shell.status_label_text().contains("result="))
	assert_true(_shell.try_fetch_settlement())
	assert_true(_shell.accept_http(404, {"error": "settlement_not_found"}))
	assert_eq(_shell.join.state, MatchJoinSession.STATE_READY)
	assert_true(_shell.status_label_text().contains("result="))
	assert_false(_shell.status_label_text().contains("settled="))
	assert_false(_shell.join.has_settlement)


func test_solo_use_item_from_spawn_breaks_course_01_crate() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	assert_eq(_shell.crates.crate_count(), 1)
	assert_eq(_shell.crates.crate_total(), 1)
	assert_eq(_shell.offline.session.destructible_alive_count(), 1)
	assert_true(_shell.status_label_text().contains("crates=1/1"))
	var use_item: PackedByteArray = _shell.try_sample_play_use_item(true)
	assert_false(use_item.is_empty())
	assert_eq(_shell.offline.session.destructible_alive_count(), 0)
	assert_eq(_shell.crates.crate_count(), 0)
	assert_eq(_shell.crates.crate_total(), 1)
	assert_true(_shell.status_label_text().contains("crates=0/1"))
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())


func test_solo_shove_has_no_target() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	var before: Dictionary = _shell.offline.session.player_pose(0)
	var before_z: int = before.get("z", -1)
	assert_true(_shell.try_sample_play_shove(true).is_empty())
	var after: Dictionary = _shell.offline.session.player_pose(0)
	var after_z: int = after.get("z", -2)
	assert_eq(after_z, before_z)


func test_solo_jump_hops_on_spawn_footing() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	var before: Dictionary = _shell.offline.session.player_pose(0)
	var before_y: int = before.get("y", 1)
	assert_false(_shell.try_sample_play_jump(true).is_empty())
	var after: Dictionary = _shell.offline.session.player_pose(0)
	var after_y: int = after.get("y", 2)
	assert_eq(after_y, before_y + Fixed.SCALE / 4)
	assert_almost_eq(_shell.map.player_node(0).position.y, 0.25, 0.0001)
	assert_true(_shell.try_sample_play_jump(true).is_empty())
	assert_true(_shell.offline.try_advance())
	var after_arc: Dictionary = _shell.offline.session.player_pose(0)
	var after_arc_y: int = after_arc.get("y", 3)
	assert_ne(after_arc_y, after_y)


func test_solo_anim_starts_idle_then_run() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	assert_eq(_shell.map.anim_state(0), PlayAnimState.IDLE)
	assert_eq(_shell.map.anim_node(0).text, PlayAnimState.IDLE)
	assert_false(_shell.try_sample_play_move(true, false, false, false).is_empty())
	assert_eq(_shell.map.anim_state(0), PlayAnimState.RUN)
	assert_true(_shell.try_sample_play_move(false, false, false, false).is_empty())
	_shell._apply_snapshot_map()
	assert_eq(_shell.map.anim_state(0), PlayAnimState.IDLE)


func test_solo_jump_sets_jump_then_land() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	var spawn: Dictionary = _shell.offline.session.player_pose(0)
	var spawn_y: int = spawn.get("y", 0)
	assert_false(_shell.try_sample_play_jump(true).is_empty())
	var hopped: Dictionary = _shell.offline.session.player_pose(0)
	var hopped_y: int = hopped.get("y", 0)
	assert_eq(hopped_y, spawn_y + Fixed.SCALE / 4)
	assert_eq(_shell.map.anim_state(0), PlayAnimState.JUMP)
	var saw_land: bool = false
	for _tick: int in range(24):
		assert_true(_shell.offline.try_advance())
		_shell._apply_snapshot_map()
		var state: String = _shell.map.anim_state(0)
		if state == PlayAnimState.LAND:
			saw_land = true
			break
		assert_eq(state, PlayAnimState.JUMP)
	assert_true(saw_land)
	_shell._apply_snapshot_map()
	assert_eq(_shell.map.anim_state(0), PlayAnimState.IDLE)


func test_solo_walk_off_spawn_footing_drops_y() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	assert_eq(_shell.offline.session.fall_dy, -Fixed.SCALE / 16)
	for _settle: int in range(8):
		assert_true(_shell.offline.try_advance())
	var rest: Dictionary = _shell.offline.session.player_pose(0)
	var rest_y: int = rest.get("y", 1)
	_shell.play_move_step = Fixed.SCALE
	## 出生点 −Z 现在有走到机关的踏板；先 +X 再 +Z 才落到空格。
	assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
	assert_false(_shell.try_sample_play_move(false, true, false, false).is_empty())
	for _drop: int in range(8):
		assert_true(_shell.offline.try_advance())
	var dropped: Dictionary = _shell.offline.session.player_pose(0)
	var dropped_y: int = dropped.get("y", 2)
	assert_lt(dropped_y, rest_y)


func test_solo_opens_eight_cell_range_stub() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	assert_true(_shell.offline.session.range_enabled)
	assert_eq(_shell.offline.session.range_max_x, 8 * Fixed.SCALE)
	_shell.offline.session.enable_play_range(Fixed.SCALE)
	_shell.play_move_step = Fixed.SCALE
	assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
	assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
	var pose: Dictionary = _shell.offline.session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)
	assert_eq(_shell.offline.session.player_accepted_count(0), 1)


func test_solo_reset_after_portal_returns_to_last_pad() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	var steps: int = 0
	while steps < 120:
		assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
		var pose: Dictionary = _shell.offline.session.player_pose(0)
		var pose_y: int = pose.get("y", 0)
		if pose_y >= Fixed.SCALE:
			break
		steps += 1
	var before: Dictionary = _shell.offline.session.player_pose(0)
	var before_y: int = before.get("y", 0)
	assert_gte(before_y, Fixed.SCALE)
	assert_eq(_shell.offline.session.player_accepted_count(0), 2)
	assert_true(_shell.status_label_text().contains("floor=1"))
	assert_true(_shell.status_label_text().contains("pads=2/3"))
	var reset: PackedByteArray = _shell.try_sample_play_reset(true)
	assert_false(reset.is_empty())
	var after: Dictionary = _shell.offline.session.player_pose(0)
	var after_x: int = after.get("x", -1)
	var after_y: int = after.get("y", -1)
	var after_z: int = after.get("z", -1)
	assert_eq(after_x, 2 * Fixed.SCALE)
	assert_eq(after_y, 0)
	assert_eq(after_z, 0)
	assert_eq(_shell.offline.session.player_accepted_count(0), 2)
	assert_true(_shell.status_label_text().contains("floor=0"))
	assert_true(_shell.status_label_text().contains("pads=2/3"))
	assert_true(_shell.status_label_text().contains("finish=-1"))
	assert_almost_eq(_shell.map.player_node(0).position.x, 2.0, 0.0001)
	assert_almost_eq(_shell.map.player_node(0).position.y, 0.0, 0.0001)
	_assert_lobby_camera_on(_shell.map.player_node(0))


func test_online_floor_uses_authority_y_not_interp() -> void:
	_shell = _open_shell()
	assert_eq(MatchLobbyShell.floor_index_from_y(0), 0)
	assert_eq(MatchLobbyShell.floor_index_from_y(Fixed.SCALE), 1)
	assert_eq(MatchLobbyShell.floor_index_from_y(-1), 0)
	assert_eq(MatchLobbyShell.floor_index_from_y(-Fixed.SCALE), -1)
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-floor")))
	assert_true(_shell.on_socket_open())
	assert_true(_shell.on_binary(_snapshot(1, 0, [_crate(40, 1)], Fixed.SCALE - 1)))
	assert_true(_shell.status_label_text().contains("floor=0"))
	assert_true(_shell.status_label_text().contains("crates=1/1"))
	assert_true(_shell.on_binary(_snapshot(2, 0, [_crate(40, 1)], Fixed.SCALE)))
	assert_eq(_shell.interp_progress(), 0)
	assert_true(_shell.status_label_text().contains("floor=1"))
	var floor_raw: Variant = _shell.status_view().get("own_floor_index", -1)
	var floor_index: int = floor_raw
	assert_eq(floor_index, 1)
	assert_true(_shell.try_cancel())
	assert_false(_shell.status_label_text().contains("floor="))
	assert_false(_shell.status_label_text().contains("crates=1/1"))


func test_server_field_retargets_both_bases_while_idle() -> void:
	_shell = _open_shell()
	assert_eq(_shell.control_plane_base, ServerEndpointGd.DEFAULT_CONTROL_PLANE)
	assert_eq(_shell.gateway_base, ServerEndpointGd.DEFAULT_GATEWAY)
	assert_eq(_shell.server_host_text(), "127.0.0.1")
	assert_true(_shell.status_label_text().contains("server=127.0.0.1"))
	assert_false(_shell.status_label_text().contains("gw="))
	_shell.set_server_host_text("203.0.113.9")
	assert_true(_shell.try_apply_server_host())
	assert_eq(_shell.control_plane_base, "http://203.0.113.9:8080")
	assert_eq(_shell.gateway_base, "ws://203.0.113.9:8090")
	assert_true(_shell.status_label_text().contains("server=203.0.113.9"))
	assert_false(_shell.status_label_text().contains("server_error="))


func test_rejected_server_host_keeps_current_bases_and_shows_error() -> void:
	_shell = _open_shell()
	_shell.set_server_host_text("203.0.113.9:9000")
	assert_false(_shell.try_apply_server_host())
	assert_eq(_shell.control_plane_base, ServerEndpointGd.DEFAULT_CONTROL_PLANE)
	assert_eq(_shell.gateway_base, ServerEndpointGd.DEFAULT_GATEWAY)
	assert_true(_shell.status_label_text().contains("server=127.0.0.1"))
	assert_true(_shell.status_label_text().contains("server_error="))
	assert_true(_shell.status_label_text().contains("--control-plane"))
	_shell.set_server_host_text("203.0.113.9")
	assert_true(_shell.try_apply_server_host())
	assert_eq(_shell.control_plane_base, "http://203.0.113.9:8080")
	assert_false(_shell.status_label_text().contains("server_error="))


func test_server_field_refused_mid_session_and_allowed_after_cancel() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	assert_false(_shell.try_apply_server_host("203.0.113.9"))
	assert_eq(_shell.control_plane_base, ServerEndpointGd.DEFAULT_CONTROL_PLANE)
	assert_eq(_shell.gateway_base, ServerEndpointGd.DEFAULT_GATEWAY)
	assert_true(_shell.try_cancel())
	assert_true(_shell.try_apply_server_host("203.0.113.9"))
	assert_eq(_shell.control_plane_base, "http://203.0.113.9:8080")
	assert_eq(_shell.gateway_base, "ws://203.0.113.9:8090")


func test_server_field_refused_while_online_ticket_is_live() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_quick())
	assert_true(_shell.accept_http(201, _join("ABCD23", "ticket-endpoint")))
	assert_eq(_shell.play.state, MatchPlaySession.STATE_CONNECTING)
	assert_false(_shell.try_apply_server_host("203.0.113.9"))
	assert_eq(_shell.control_plane_base, ServerEndpointGd.DEFAULT_CONTROL_PLANE)
	assert_eq(_shell.play.websocket_url, "ws://127.0.0.1:8090/ws?ticket=ticket-endpoint")


func test_apply_endpoint_syncs_bases_field_and_hud() -> void:
	_shell = _open_shell()
	var resolved: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--server=198.51.100.7"])
	)
	assert_true(_shell.apply_endpoint(resolved))
	assert_eq(_shell.control_plane_base, "http://198.51.100.7:8080")
	assert_eq(_shell.gateway_base, "ws://198.51.100.7:8090")
	assert_eq(_shell.server_host_text(), "198.51.100.7")
	assert_true(_shell.status_label_text().contains("server=198.51.100.7"))
	assert_false(_shell.status_label_text().contains("gw="))
	assert_false(_shell.apply_endpoint(null))


func test_split_endpoint_shows_gateway_host_separately() -> void:
	_shell = _open_shell()
	var resolved: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(
			["--server=198.51.100.7", "--gateway=ws://198.51.100.8:8090"]
		)
	)
	assert_true(_shell.apply_endpoint(resolved))
	assert_eq(_shell.control_plane_base, "http://198.51.100.7:8080")
	assert_eq(_shell.gateway_base, "ws://198.51.100.8:8090")
	assert_true(_shell.status_label_text().contains("server=198.51.100.7"))
	assert_true(_shell.status_label_text().contains("gw=198.51.100.8"))


## 权威节拍与表现节拍分开：`_physics_process` 推 tick（固定 60 Hz，和
## `match_server.gd` 同一节拍），`_process` 只画。绑在一起时帧率就是仿真速度——
## 慢的时候慢放，快的时候两倍速。
func test_only_physics_process_advances_the_offline_tick() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())
	var before: int = _shell.offline.session.tick_index()

	for _frame: int in range(5):
		_shell._process(0.016)

	assert_eq(_shell.offline.session.tick_index(), before, "渲染帧推进了权威 tick")

	_shell._physics_process(0.016)

	assert_eq(_shell.offline.session.tick_index(), before + 1, "固定步长没有推进权威 tick")


## 一帧只重映射一次。原来是三次 `_apply_snapshot_map` 加四次 `_refresh_status`：
## `try_sample_play_move` 的离线分支无条件来一次（在线分支一直有 `is_empty()`
## 保护，两只手不一样）、`try_advance_interp` 一次、`_process` 末尾再显式一次。
func test_one_render_frame_remaps_once_and_idle_input_remaps_never() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_solo())

	var before: int = _shell.snapshot_map_apply_count()
	_shell._process(0.016)
	assert_eq(_shell.snapshot_map_apply_count(), before + 1, "一个渲染帧重映射了不止一次")

	## 没按键 = 什么都没动，不该重映射。
	var idle: int = _shell.snapshot_map_apply_count()
	assert_true(_shell.try_sample_play_move(false, false, false, false).is_empty())
	assert_eq(_shell.snapshot_map_apply_count(), idle, "空手采样也触发了重映射")

	## 真按了键仍然立即反映，否则本席会等到下一渲染帧才动。
	assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
	assert_eq(_shell.snapshot_map_apply_count(), idle + 1)


func _open_shell() -> MatchLobbyShell:
	var shell: MatchLobbyShell = MatchLobbyShell.create()
	add_child(shell)
	assert_true(shell.open())
	assert_true(shell.is_window_visible())
	return shell


func _join(
	room_code: String,
	ticket: String,
	course: String = "course_01",
	seats: int = 2,
	seat: int = 0
) -> Dictionary:
	return {
		"roomCode": room_code,
		"ticket": ticket,
		"matchId": "match-1",
		"expiresAt": "2026-08-25T03:00:00.000Z",
		"seats": seats,
		"issued": 1,
		"seat": seat,
		"course": course,
	}


func _settlement_board() -> Dictionary:
	return {
		"matchId": "match-1",
		"tick": 8,
		"stateHash": "abc123",
		"padTotal": 3,
		"mvpSlot": 0,
		"rows": [
			{"slot": 0, "place": 1, "finishTick": 4, "acceptedCount": 3},
			{"slot": 1, "place": 2, "finishTick": 8, "acceptedCount": 3},
		],
		"createdAt": "2026-08-25T12:00:00.000Z",
	}


func _crate(entity_id: int, durability: int) -> Dictionary:
	return {
		"entity_id": entity_id,
		"durability": durability,
	}


func _one_hazard_bundle(cooldown_ticks: int) -> SimulationBundle:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_hazard_record(50, Fixed.SCALE, 0, 0, cooldown_ticks)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _one_solid_bundle() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_solid_record(70, Fixed.SCALE, 0, 0)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _checkpoint_record(entity_id: int, order: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": order,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})


func _hazard_record(
	entity_id: int,
	x: int,
	y: int,
	z: int,
	cooldown_ticks: int
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": cooldown_ticks},
	})


func _solid_record(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	var half: int = Fixed.SCALE / 2
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": [TraprushTopologyCompiler.SOLID_ZONE_TAG],
		},
	})


func _snapshot(tick: int, x: int, crates: Array[Dictionary] = [], y: int = 0) -> PackedByteArray:
	var players: Array[Dictionary] = [_ranked_player(x, 0, -1, y)]
	return MatchFrameCodec.encode_snapshot(tick, players, crates)


func _two_player_snapshot(
	tick: int,
	own_x: int,
	remote_x: int,
	crates: Array[Dictionary] = []
) -> PackedByteArray:
	var players: Array[Dictionary] = [
		_ranked_player(own_x, 0, -1),
		_ranked_player(remote_x, 0, -1),
	]
	return MatchFrameCodec.encode_snapshot(tick, players, crates)


func _ranked_player(x: int, accepted_count: int, finish_tick: int, y: int = 0) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"z": 0,
		"yaw_bam": 0,
		"accepted_count": accepted_count,
		"finish_tick": finish_tick,
	}


func _ranked_snapshot(tick: int, players: Array[Dictionary]) -> PackedByteArray:
	var crates: Array[Dictionary] = []
	return MatchFrameCodec.encode_snapshot(tick, players, crates)


func _finish_albedo() -> Color:
	return _player_albedo(_shell.course.finish_node(30))


func _pad_albedo(entity_id: int) -> Color:
	return _player_albedo(_shell.course.pad_node(entity_id))


func _player_albedo(node: MeshInstance3D) -> Color:
	assert_not_null(node)
	var box: BoxMesh = node.mesh as BoxMesh
	assert_not_null(box)
	var material: StandardMaterial3D = box.material as StandardMaterial3D
	assert_not_null(material)
	return material.albedo_color


func _assert_player_yaw(node: Node3D, yaw_bam: int) -> void:
	assert_not_null(node)
	var expected: float = MatchSnapshotMap.yaw_radians_from_bam(yaw_bam)
	assert_almost_eq(angle_difference(node.rotation.y, expected), 0.0, 0.0001)


func _assert_lobby_camera_on(node: MeshInstance3D) -> void:
	assert_not_null(node)
	_assert_lobby_camera_at(node.position)


func _assert_lobby_camera_at(target: Vector3) -> void:
	var camera: Camera3D = _shell.map.camera_node()
	assert_not_null(camera)
	var expected: Vector3 = target + MatchSnapshotMap.CAMERA_OFFSET
	assert_almost_eq(camera.position.x, expected.x, 0.0001)
	assert_almost_eq(camera.position.y, expected.y, 0.0001)
	assert_almost_eq(camera.position.z, expected.z, 0.0001)
