class_name MatchLobbyShell
extends Node

## TRAPRUSH channel lobby (CD-12): quick play, room code, FIFO wait.
## Code-created Window; close only hides. Injected HTTP/WS in tests;
## live_io uses HTTPRequest + WebSocketPeer. Follows the latest snapshot
## and maps player poses to 1 m boxes. Maps compiled course occupancy
## (pads / portals / finish) to 1 m boxes. Maps compiled destructibles
## to 1 m boxes and hides them when snapshot durability is <= 0 or omitted.
## Maps compiled portal source→dest as bar gizmos; one_way adds a
## direction marker. Dangling bags are omitted by the compiler.
## Maps compiled checkpoint order as labels plus unique-order bars;
## duplicate orders are labeled only. Maps live standings from the latest
## snapshot (finish_tick then accepted_count; slot is the stable key).
## Path distance is not ranked. Solo play starts a local
## TraprushMatchSession (CD-13 §3); the HUD keeps
## "离线试玩，成绩不上传" while it runs. Web is refused.
## Player boxes and standing labels sample MatchSnapshotInterp between
## the last two snapshots. play_interp_step is a presentation stub, not
## an interpolation window. The local seat overlays MatchLocalPredict on
## the latest authority for Move/Jump; remotes still interpolate.
## SnapshotCamera follows the own-seat presentation pose (predicted
## online, local authority offline) with the Preview camera offset.
## The own-seat box uses OWN_ALBEDO; remotes use REMOTE_ALBEDO. Standing
## labels prefix the own seat with "*". Remotes do not pull the camera.
## Own-seat accepted_count tints course pads: done / current / pending.
## Own-seat finish_tick tints the finish zone: pending / current / done.
## HUD shows pads=n/m and finish=n; result= appears when every snapshot
## seat has finished. That line is local presentation, not a settlement write.
## WASD encodes Move plus discrete 8-way yaw_bam; Jump / Reset / Use item
## encode existing intents.
## play_move_step is a presentation stub, not a product speed.
## Unexpected socket close while connecting or in-match reissues the
## consumed ticket and follows the latest snapshot again.
## Cancel stops solo play, cancels a waiting queue, and locally leaves
## connecting / in-match / closed play without reissuing a ticket.
## Quick play / create room send an official course id and seats;
## join-by-code follows the room's course and remounts maps from that response.
## Solo play reuses the course selector only (always one local player).
## No BASTION, accounts, settlement writes, ghosts, or offline writes.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchJoinSessionGd := preload("res://src/client/match_join_session.gd")
const MatchOfflineSessionGd := preload("res://src/client/match_offline_session.gd")
const MatchPlaySessionGd := preload("res://src/client/match_play_session.gd")
const MatchCheckpointOrderMapGd := preload("res://src/client/match_checkpoint_order_map.gd")
const MatchCourseMapGd := preload("res://src/client/match_course_map.gd")
const MatchCrateMapGd := preload("res://src/client/match_crate_map.gd")
const MatchPortalLinkMapGd := preload("res://src/client/match_portal_link_map.gd")
const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")
const MatchSnapshotInterpGd := preload("res://src/client/match_snapshot_interp.gd")
const MatchSnapshotMapGd := preload("res://src/client/match_snapshot_map.gd")
const MatchStandingMapGd := preload("res://src/client/match_standing_map.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const TITLE: String = "Traprush"
const DEFAULT_COURSE: String = "res://content/official/traprush/course_01.json"
const DEFAULT_CONTROL_PLANE: String = "http://127.0.0.1:8080"
const DEFAULT_GATEWAY: String = "ws://127.0.0.1:8090"
const DEFAULT_QUEUE_POLL_S: float = 1.0
const QUICK_NAME: String = "QuickPlay"
const CREATE_NAME: String = "CreateRoom"
const JOIN_NAME: String = "JoinRoom"
const CANCEL_NAME: String = "Cancel"
const SOLO_NAME: String = "SoloPlay"
const POLL_NAME: String = "Poll"
const ROOM_NAME: String = "RoomCode"
const COURSE_ID_NAME: String = "CourseId"
const SEATS_NAME: String = "Seats"
const _STATUS_NAME: String = "Status"
const _MAP_NAME: String = "SnapshotMap"
const _COURSE_NAME: String = "CourseMap"
const _CRATE_NAME: String = "CrateMap"
const _LINK_NAME: String = "PortalLinkMap"
const _ORDER_NAME: String = "CheckpointOrderMap"
const _STANDING_NAME: String = "StandingMap"
const _MOVE_FORWARD: String = "move_forward"
const _MOVE_BACK: String = "move_back"
const _MOVE_LEFT: String = "move_left"
const _MOVE_RIGHT: String = "move_right"
const _USE_ITEM: String = "use_item"
const _JUMP: String = "jump"

var join: MatchJoinSessionGd = null
var play: MatchPlaySessionGd = null
var offline: MatchOfflineSessionGd = null
var map: MatchSnapshotMapGd = null
var course: MatchCourseMapGd = null
var crates: MatchCrateMapGd = null
var links: MatchPortalLinkMapGd = null
var orders: MatchCheckpointOrderMapGd = null
var standings: MatchStandingMapGd = null
var window: Window = null
var live_io: bool = false
var web_platform: bool = false
var control_plane_base: String = DEFAULT_CONTROL_PLANE
var gateway_base: String = DEFAULT_GATEWAY
var course_path: String = DEFAULT_COURSE
var course_id: String = OfficialTraprushCoursesGd.DEFAULT_ID
var play_move_step: int = Fixed.SCALE / 16
var play_interp_step: int = Fixed.SCALE / 2
var queue_poll_s: float = DEFAULT_QUEUE_POLL_S
var last_sent_command: PackedByteArray = PackedByteArray()
var _interp_t: int = 0
var _interp_tick: int = -1

var _status: Label = null
var _room_edit: LineEdit
var _course_edit: LineEdit = null
var _seats_edit: LineEdit = null
var _http: HTTPRequest = null
var _http_busy: bool = false
var _peer: WebSocketPeer = null
var _poll_accum: float = 0.0
var _reset_held: bool = false
var _use_item_held: bool = false
var _jump_held: bool = false
var _opened_socket: bool = false


static func create() -> MatchLobbyShell:
	var shell := new()
	shell.join = MatchJoinSessionGd.create()
	shell.play = MatchPlaySessionGd.new()
	shell.offline = MatchOfflineSessionGd.new()
	shell.web_platform = OS.has_feature("web")
	return shell


func open() -> bool:
	if join == null:
		return false
	_ensure_window()
	if window == null:
		return false
	if live_io:
		_ensure_http()
	window.visible = true
	_refresh_status()
	return true


func show_window() -> bool:
	if window == null:
		return false
	window.visible = true
	_refresh_status()
	return true


func hide_window() -> void:
	if window != null:
		window.visible = false


func is_window_visible() -> bool:
	return window != null and window.visible


func room_code_text() -> String:
	if _room_edit == null:
		return ""
	return _room_edit.text


func set_room_code_text(text: String) -> void:
	if _room_edit != null:
		_room_edit.text = text


func course_id_text() -> String:
	if _course_edit == null:
		return course_id
	return _course_edit.text


func set_course_id_text(text: String) -> void:
	course_id = text
	if _course_edit != null:
		_course_edit.text = text


func selected_course_id() -> String:
	var raw: String = course_id
	if _course_edit != null:
		raw = _course_edit.text
	var trimmed: String = raw.strip_edges()
	if trimmed == "":
		return OfficialTraprushCoursesGd.DEFAULT_ID
	return OfficialTraprushCoursesGd.normalize_id(trimmed)


func seats_text() -> String:
	if _seats_edit == null:
		return str(OfficialTraprushCoursesGd.DEFAULT_SEATS)
	return _seats_edit.text


func set_seats_text(text: String) -> void:
	if _seats_edit != null:
		_seats_edit.text = text


func selected_seats() -> int:
	var raw: String = seats_text().strip_edges()
	if raw == "":
		return OfficialTraprushCoursesGd.DEFAULT_SEATS
	if not raw.is_valid_int():
		return 0
	return OfficialTraprushCoursesGd.normalize_seats(raw.to_int())


func try_quick() -> bool:
	if join == null or _offline_playing():
		return false
	var id: String = selected_course_id()
	var seat_count: int = selected_seats()
	if id == "" or seat_count == 0:
		return false
	if not join.try_quick(id, seat_count):
		return false
	_dispatch_pending()
	_refresh_status()
	return true


func try_create_room() -> bool:
	if join == null or _offline_playing():
		return false
	var id: String = selected_course_id()
	var seat_count: int = selected_seats()
	if id == "" or seat_count == 0:
		return false
	if not join.try_create_room(id, seat_count):
		return false
	_dispatch_pending()
	_refresh_status()
	return true


func try_join_room(raw_code: String = "") -> bool:
	if join == null or _offline_playing():
		return false
	var code: String = raw_code
	if code == "" and _room_edit != null:
		code = _room_edit.text
	if not join.try_join_room(code):
		return false
	_dispatch_pending()
	_refresh_status()
	return true


func try_poll() -> bool:
	if join == null or _offline_playing():
		return false
	if not join.try_poll():
		return false
	_dispatch_pending()
	_refresh_status()
	return true


func try_solo() -> bool:
	if offline == null:
		return false
	if _online_busy():
		return false
	var id: String = selected_course_id()
	if id == "":
		return false
	_prepare_offline_stubs()
	_reset_interp()
	course_path = OfficialTraprushCoursesGd.document_path(id)
	if not offline.try_begin(course_path, web_platform):
		_refresh_status()
		return false
	_apply_course_document(course_path)
	_apply_snapshot_map()
	_refresh_status()
	return true


func try_stop_offline() -> bool:
	if offline == null or not _offline_playing():
		return false
	if not offline.try_stop():
		return false
	_reset_interp()
	if map != null:
		map.follow_slot = -1
		map.apply_players([])
	if standings != null:
		standings.follow_slot = -1
		standings.apply_players([])
	if crates != null:
		crates.apply_path(course_path)
	if course != null:
		course.apply_own_progress(-1)
	_refresh_status()
	return true


func try_cancel() -> bool:
	if _offline_playing():
		return try_stop_offline()
	if try_leave_play():
		return true
	if join == null:
		return false
	if not join.try_cancel():
		return false
	_dispatch_pending()
	_refresh_status()
	return true


func try_leave_play() -> bool:
	var left: bool = false
	if play != null and play.try_leave():
		left = true
	if join != null and join.try_abandon():
		left = true
	if not left:
		return false
	_drop_gateway()
	last_sent_command = PackedByteArray()
	_reset_interp()
	if map != null:
		map.follow_slot = -1
		map.apply_players([])
	if standings != null:
		standings.follow_slot = -1
		standings.apply_players([])
	if crates != null:
		crates.apply_path(course_path)
	if course != null:
		course.apply_own_progress(-1)
	_refresh_status()
	return true


func accept_http(status_code: int, body: Dictionary) -> bool:
	if join == null:
		return false
	var ok: bool = join.accept_http(status_code, body)
	_after_join_http()
	return ok


func apply_http_text(status_code: int, text: String) -> bool:
	if join == null:
		return false
	var ok: bool = join.apply_http_text(status_code, text)
	_after_join_http()
	return ok


func try_begin_play() -> bool:
	if join == null or play == null or _offline_playing():
		return false
	if not play.try_begin(join, gateway_base):
		return false
	_reset_interp()
	_opened_socket = false
	if live_io:
		_connect_gateway()
	_refresh_status()
	return true


func on_socket_open() -> bool:
	if play == null:
		return false
	var ok: bool = play.on_open()
	_refresh_status()
	return ok


func on_socket_close() -> void:
	var should_reconnect: bool = false
	if play != null:
		should_reconnect = (
			play.state == MatchPlaySessionGd.STATE_CONNECTING
			or play.state == MatchPlaySessionGd.STATE_IN_MATCH
		)
		play.on_close()
	if should_reconnect:
		try_reconnect()
	_refresh_status()


func try_reconnect() -> bool:
	if join == null or _offline_playing():
		return false
	if not join.try_reconnect():
		return false
	_dispatch_pending()
	_refresh_status()
	return true


func on_binary(bytes: PackedByteArray) -> bool:
	if play == null:
		return false
	var ok: bool = play.on_binary(bytes)
	if ok:
		_apply_snapshot_map()
	_refresh_status()
	return ok


func try_sample_play_move(forward: bool, back: bool, left: bool, right: bool) -> PackedByteArray:
	if window == null or not window.visible:
		return PackedByteArray()
	if _offline_playing():
		var offline_bytes: PackedByteArray = offline.try_encode_move_axes(
			forward, back, left, right, play_move_step
		)
		_apply_snapshot_map()
		return offline_bytes
	if play == null:
		return PackedByteArray()
	var bytes: PackedByteArray = play.try_encode_move_axes(forward, back, left, right, play_move_step)
	_note_command(bytes)
	if not bytes.is_empty():
		_apply_snapshot_map()
	return bytes


func try_sample_play_reset(pressed: bool) -> PackedByteArray:
	var rising: bool = pressed and not _reset_held
	_reset_held = pressed
	if not rising or window == null or not window.visible:
		return PackedByteArray()
	if _offline_playing():
		var offline_bytes: PackedByteArray = offline.try_encode_intent(
			PlayerIntentNames.RESET_TO_CHECKPOINT, 0, 0, 0
		)
		_apply_snapshot_map()
		return offline_bytes
	if play == null:
		return PackedByteArray()
	var bytes: PackedByteArray = play.try_encode_intent(PlayerIntentNames.RESET_TO_CHECKPOINT, 0, 0, 0)
	_note_command(bytes)
	return bytes


func try_sample_play_use_item(pressed: bool) -> PackedByteArray:
	var rising: bool = pressed and not _use_item_held
	_use_item_held = pressed
	if not rising or window == null or not window.visible:
		return PackedByteArray()
	if _offline_playing():
		var offline_bytes: PackedByteArray = offline.try_encode_intent(
			PlayerIntentNames.USE_ITEM, 0, 0, 0
		)
		_apply_snapshot_map()
		return offline_bytes
	if play == null:
		return PackedByteArray()
	var bytes: PackedByteArray = play.try_encode_intent(PlayerIntentNames.USE_ITEM, 0, 0, 0)
	_note_command(bytes)
	return bytes


func try_sample_play_jump(pressed: bool) -> PackedByteArray:
	var rising: bool = pressed and not _jump_held
	_jump_held = pressed
	if not rising or window == null or not window.visible:
		return PackedByteArray()
	if _offline_playing():
		var offline_bytes: PackedByteArray = offline.try_encode_intent(
			PlayerIntentNames.JUMP, 0, 0, 0
		)
		_apply_snapshot_map()
		return offline_bytes
	if play == null:
		return PackedByteArray()
	var bytes: PackedByteArray = play.try_encode_intent(PlayerIntentNames.JUMP, 0, 0, 0)
	_note_command(bytes)
	if not bytes.is_empty():
		_apply_snapshot_map()
	return bytes


func status_view() -> Dictionary:
	var join_view: Dictionary = {}
	var play_view: Dictionary = {}
	if join != null:
		join_view = join.status_view()
	if play != null:
		play_view = play.status_view()
	var offline_view: Dictionary = {}
	if offline != null:
		offline_view = offline.status_view()
	var mapped_players: int = 0
	var mapped_pads: int = 0
	var mapped_portals: int = 0
	var mapped_finish: int = 0
	var mapped_crates: int = 0
	var mapped_links: int = 0
	var mapped_orders: int = 0
	var mapped_sequences: int = 0
	var mapped_standings: int = 0
	var mvp_slot: int = -1
	var standing_line: String = ""
	var own_accepted_count: int = -1
	var own_finish_tick: int = -1
	var match_finished: bool = false
	if map != null:
		mapped_players = map.player_count()
	if course != null:
		mapped_pads = course.pad_count()
		mapped_portals = course.portal_count()
		mapped_finish = course.finish_count()
	if crates != null:
		mapped_crates = crates.crate_count()
	if links != null:
		mapped_links = links.link_count()
	if orders != null:
		mapped_orders = orders.checkpoint_count()
		mapped_sequences = orders.sequence_count()
	if standings != null:
		mapped_standings = standings.standing_count()
		mvp_slot = standings.mvp_slot()
		standing_line = standings.standing_line()
	var source: Dictionary = play_view
	if _offline_playing():
		source = offline_view
	var follow: MatchSnapshotFollowGd = _active_follow()
	if follow != null and follow.has_snapshot:
		own_accepted_count = _own_accepted_count(follow.players)
		own_finish_tick = _own_finish_tick(follow.players)
		match_finished = _all_players_finished(follow.players)
	return {
		"join_state": join_view.get("state", ""),
		"error": join_view.get("error", ""),
		"pending": join_view.get("pending", false),
		"position": join_view.get("position", 0),
		"estimated_wait_ms": join_view.get("estimated_wait_ms", 0),
		"room_code": join_view.get("room_code", ""),
		"ticket": join_view.get("ticket", ""),
		"course": join_view.get("course", ""),
		"course_id": selected_course_id(),
		"seats": join_view.get("seats", 0),
		"selected_seats": selected_seats(),
		"seat": join_view.get("seat", -1),
		"play_state": play_view.get("state", ""),
		"offline_state": offline_view.get("state", ""),
		"offline_banner": offline_view.get("banner", ""),
		"offline_error": offline_view.get("error", ""),
		"tick": source.get("tick", -1),
		"player_count": source.get("player_count", 0),
		"crate_count": source.get("crate_count", 0),
		"mapped_players": mapped_players,
		"mapped_pads": mapped_pads,
		"mapped_portals": mapped_portals,
		"mapped_finish": mapped_finish,
		"mapped_crates": mapped_crates,
		"mapped_links": mapped_links,
		"mapped_orders": mapped_orders,
		"mapped_sequences": mapped_sequences,
		"mapped_standings": mapped_standings,
		"mvp_slot": mvp_slot,
		"standing_line": standing_line,
		"own_accepted_count": own_accepted_count,
		"own_finish_tick": own_finish_tick,
		"match_finished": match_finished,
		"window_visible": is_window_visible(),
	}


func status_label_text() -> String:
	if _status == null:
		return ""
	return _status.text


func try_advance_interp() -> bool:
	if window == null or not window.visible:
		return false
	if play_interp_step < 1:
		return false
	var follow: MatchSnapshotFollowGd = _active_follow()
	if follow == null or not follow.has_previous:
		return false
	if _interp_t >= Fixed.SCALE:
		return false
	var next_t: int = _interp_t + play_interp_step
	if next_t < _interp_t or next_t > Fixed.SCALE:
		next_t = Fixed.SCALE
	_interp_t = next_t
	_apply_snapshot_map()
	return true


func interp_progress() -> int:
	return _interp_t


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _process(delta: float) -> void:
	if live_io and not _offline_playing():
		_poll_queue_clock(delta)
		_poll_gateway()
	if window == null or not window.visible:
		return
	try_sample_play_move(
		Input.is_action_pressed(_MOVE_FORWARD),
		Input.is_action_pressed(_MOVE_BACK),
		Input.is_action_pressed(_MOVE_LEFT),
		Input.is_action_pressed(_MOVE_RIGHT)
	)
	try_sample_play_reset(Input.is_physical_key_pressed(KEY_R))
	try_sample_play_use_item(Input.is_action_pressed(_USE_ITEM))
	try_sample_play_jump(Input.is_action_pressed(_JUMP))
	if _offline_playing():
		offline.try_advance()
	try_advance_interp()
	if _offline_playing():
		_apply_snapshot_map()
		_refresh_status()


func _ensure_window() -> void:
	if window != null:
		return
	if not Engine.is_editor_hint():
		var host_viewport: Viewport = get_viewport()
		if host_viewport != null:
			host_viewport.gui_embed_subwindows = true
	window = Window.new()
	window.title = TITLE
	window.size = Vector2i(640, 400)
	window.exclusive = false
	window.transient = false
	window.own_world_3d = true
	window.close_requested.connect(_on_close_requested)
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "VBoxContainer"
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	window.add_child(root)
	_status = Label.new()
	_status.name = _STATUS_NAME
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "MatchActions"
	root.add_child(row)
	_add_button(row, QUICK_NAME, "Quick play", try_quick)
	_add_button(row, CREATE_NAME, "Create room", try_create_room)
	_add_button(row, JOIN_NAME, "Join room", try_join_room)
	_add_button(row, SOLO_NAME, "Solo play", try_solo)
	_add_button(row, CANCEL_NAME, "Cancel", try_cancel)
	_add_button(row, POLL_NAME, "Poll", try_poll)
	_room_edit = LineEdit.new()
	_room_edit.name = ROOM_NAME
	_room_edit.placeholder_text = "Room code"
	_room_edit.max_length = 6
	root.add_child(_room_edit)
	_course_edit = LineEdit.new()
	_course_edit.name = COURSE_ID_NAME
	_course_edit.placeholder_text = OfficialTraprushCoursesGd.DEFAULT_ID
	_course_edit.text = OfficialTraprushCoursesGd.DEFAULT_ID
	_course_edit.max_length = 32
	root.add_child(_course_edit)
	_seats_edit = LineEdit.new()
	_seats_edit.name = SEATS_NAME
	_seats_edit.placeholder_text = str(OfficialTraprushCoursesGd.DEFAULT_SEATS)
	_seats_edit.text = str(OfficialTraprushCoursesGd.DEFAULT_SEATS)
	_seats_edit.max_length = 1
	root.add_child(_seats_edit)
	map = MatchSnapshotMapGd.new()
	map.name = _MAP_NAME
	window.add_child(map)
	course = MatchCourseMapGd.new()
	course.name = _COURSE_NAME
	map.add_child(course)
	crates = MatchCrateMapGd.new()
	crates.name = _CRATE_NAME
	map.add_child(crates)
	links = MatchPortalLinkMapGd.new()
	links.name = _LINK_NAME
	map.add_child(links)
	orders = MatchCheckpointOrderMapGd.new()
	orders.name = _ORDER_NAME
	map.add_child(orders)
	standings = MatchStandingMapGd.new()
	standings.name = _STANDING_NAME
	map.add_child(standings)
	add_child(window)
	map.ensure_rig()
	_apply_course_document(course_path)


func _apply_join_course() -> void:
	if join == null:
		return
	var path: String = OfficialTraprushCoursesGd.document_path(join.course)
	if path == "":
		return
	_apply_course_document(path)


func _apply_course_document(path: String) -> void:
	course_path = path
	if course != null:
		course.apply_path(path)
	if crates != null:
		crates.apply_path(path)
	if links != null:
		links.apply_path(path)
	if orders != null:
		orders.apply_path(path)


func _ensure_http() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	_http.request_completed.connect(_on_http_completed)
	add_child(_http)


func _add_button(row: BoxContainer, node_name: String, text: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	row.add_child(button)


func _dispatch_pending() -> void:
	if not live_io or _http == null or join == null or not join.has_pending() or _http_busy:
		return
	var url: String = MatchJoinSessionGd.http_url(control_plane_base, join.pending_path())
	if url == "":
		join.fail_transport()
		_refresh_status()
		return
	var method: String = join.pending_method()
	var err: int = ERR_BUG
	if method == "POST":
		var body: String = join.pending_body()
		var headers: PackedStringArray = PackedStringArray()
		if body != "":
			headers.append("Content-Type: application/json")
		err = _http.request(url, headers, HTTPClient.METHOD_POST, body)
	elif method == "GET":
		err = _http.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	elif method == "DELETE":
		err = _http.request(url, PackedStringArray(), HTTPClient.METHOD_DELETE)
	if err != OK:
		join.fail_transport()
		_refresh_status()
		return
	_http_busy = true


func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http_busy = false
	if join == null:
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		join.fail_transport()
		_refresh_status()
		return
	apply_http_text(response_code, body.get_string_from_utf8())


func _after_join_http() -> void:
	if join != null and join.course != "":
		_apply_join_course()
	if join != null and join.state == MatchJoinSessionGd.STATE_READY and play != null:
		if play.state == MatchPlaySessionGd.STATE_IDLE or play.state == MatchPlaySessionGd.STATE_CLOSED:
			try_begin_play()
	_refresh_status()


func _connect_gateway() -> void:
	if play == null or play.websocket_url == "":
		return
	_drop_gateway()
	_peer = WebSocketPeer.new()
	var err: int = _peer.connect_to_url(play.websocket_url)
	if err != OK:
		play.on_close()
		_peer = null


func _drop_gateway() -> void:
	if _peer == null:
		return
	_peer.close(-1)
	_peer = null
	_opened_socket = false


func _poll_queue_clock(delta: float) -> void:
	if join == null or join.state != MatchJoinSessionGd.STATE_WAITING:
		_poll_accum = 0.0
		return
	if join.has_pending() or _http_busy:
		return
	_poll_accum += delta
	if _poll_accum < queue_poll_s:
		return
	_poll_accum = 0.0
	try_poll()


func _poll_gateway() -> void:
	if _peer == null:
		return
	_peer.poll()
	var ready: int = _peer.get_ready_state()
	if ready == WebSocketPeer.STATE_OPEN:
		if not _opened_socket:
			_opened_socket = true
			on_socket_open()
		while _peer.get_available_packet_count() > 0:
			on_binary(_peer.get_packet())
		if not last_sent_command.is_empty() and play != null and not play.last_command.is_empty():
			if last_sent_command != play.last_command:
				_peer.send(play.last_command, WebSocketPeer.WRITE_MODE_BINARY)
				last_sent_command = play.last_command
	elif ready == WebSocketPeer.STATE_CLOSED:
		_peer = null
		_opened_socket = false
		on_socket_close()


func _note_command(bytes: PackedByteArray) -> void:
	if bytes.is_empty() or _peer == null:
		return
	if _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_peer.send(bytes, WebSocketPeer.WRITE_MODE_BINARY)
	last_sent_command = bytes
	_refresh_status()


func _refresh_status() -> void:
	if _status == null:
		return
	var view: Dictionary = status_view()
	var join_state: String = view.get("join_state", "")
	var play_state: String = view.get("play_state", "")
	var parts: PackedStringArray = PackedStringArray()
	parts.append("join=%s" % join_state)
	if view.get("pending", false):
		parts.append("pending=1")
	if join_state == MatchJoinSessionGd.STATE_WAITING:
		var position: int = view.get("position", 0)
		var wait_ms: int = view.get("estimated_wait_ms", 0)
		parts.append("pos=%d" % position)
		parts.append("wait_ms=%d" % wait_ms)
	var room_code: String = str(view.get("room_code", ""))
	if room_code != "":
		parts.append("room=%s" % room_code)
	var shown_course: String = str(view.get("course", ""))
	if shown_course == "":
		shown_course = str(view.get("course_id", ""))
	if shown_course != "":
		parts.append("course_id=%s" % shown_course)
	var shown_seats: int = view.get("seats", 0)
	if shown_seats < 1:
		shown_seats = view.get("selected_seats", 0)
	if shown_seats >= 1:
		parts.append("seats=%d" % shown_seats)
	var own_seat: int = view.get("seat", -1)
	if own_seat >= 0 and (
		play_state == MatchPlaySessionGd.STATE_IN_MATCH
		or play_state == MatchPlaySessionGd.STATE_CONNECTING
	):
		parts.append("seat=%d" % own_seat)
	var error_text: String = str(view.get("error", ""))
	if error_text != "":
		parts.append("error=%s" % error_text)
	parts.append("play=%s" % play_state)
	var offline_state: String = str(view.get("offline_state", ""))
	if offline_state != "":
		parts.append("offline=%s" % offline_state)
	var offline_banner: String = str(view.get("offline_banner", ""))
	if offline_banner != "":
		parts.append(offline_banner)
	var offline_error: String = str(view.get("offline_error", ""))
	if offline_error != "":
		parts.append("offline_error=%s" % offline_error)
	var mapped_pads: int = view.get("mapped_pads", 0)
	var mapped_portals: int = view.get("mapped_portals", 0)
	var mapped_finish: int = view.get("mapped_finish", 0)
	if play_state == MatchPlaySessionGd.STATE_IN_MATCH or offline_state == MatchOfflineSessionGd.STATE_PLAYING:
		var tick: int = view.get("tick", -1)
		var player_count: int = view.get("player_count", 0)
		var crate_count: int = view.get("crate_count", 0)
		parts.append("tick=%d" % tick)
		parts.append("players=%d" % player_count)
		parts.append("crates=%d" % crate_count)
		var mapped_players: int = view.get("mapped_players", 0)
		parts.append("mapped=%d" % mapped_players)
		var own_accepted_count: int = view.get("own_accepted_count", -1)
		var own_finish_tick: int = view.get("own_finish_tick", -1)
		parts.append("pads=%d/%d" % [own_accepted_count, mapped_pads])
		parts.append("finish=%d" % own_finish_tick)
		if view.get("match_finished", false):
			var result_line: String = str(view.get("standing_line", ""))
			if result_line != "":
				parts.append("result=%s" % result_line)
	parts.append("course=%d/%d/%d" % [mapped_pads, mapped_portals, mapped_finish])
	var mapped_crates: int = view.get("mapped_crates", 0)
	parts.append("crates_mapped=%d" % mapped_crates)
	var mapped_links: int = view.get("mapped_links", 0)
	parts.append("links_mapped=%d" % mapped_links)
	var mapped_orders: int = view.get("mapped_orders", 0)
	var mapped_sequences: int = view.get("mapped_sequences", 0)
	parts.append("orders_mapped=%d/%d" % [mapped_orders, mapped_sequences])
	var standing_line: String = str(view.get("standing_line", ""))
	if standing_line != "":
		parts.append(standing_line)
	_status.text = " ".join(parts)


func _apply_snapshot_map() -> void:
	var follow: MatchSnapshotFollowGd = _active_follow()
	if follow == null or not follow.has_snapshot:
		return
	_sync_interp_t(follow)
	var previous_players: Array = []
	if follow.has_previous:
		previous_players = follow.previous_players
	var sampled: Dictionary = MatchSnapshotInterpGd.try_sample(
		previous_players,
		follow.players,
		_interp_t
	)
	if not sampled.get("ok", false):
		return
	var players_raw: Variant = sampled.get("players", [])
	if typeof(players_raw) != TYPE_ARRAY:
		return
	var players: Array = players_raw
	if play != null and play.state == MatchPlaySessionGd.STATE_IN_MATCH:
		var predicted: Dictionary = play.predict.try_apply(players, follow.players)
		if predicted.get("ok", false):
			var predicted_raw: Variant = predicted.get("players", [])
			if typeof(predicted_raw) == TYPE_ARRAY:
				players = predicted_raw
	if map != null:
		map.follow_slot = _camera_follow_slot()
		map.apply_players(players, follow.crates)
	if crates != null:
		crates.apply_follow(follow)
	if course != null:
		course.apply_own_progress(
			_own_accepted_count(follow.players),
			_own_finish_tick(follow.players)
		)
	if standings != null:
		var pad_total: int = 0
		if course != null:
			pad_total = course.pad_count()
		standings.follow_slot = _camera_follow_slot()
		standings.apply_players(players, pad_total)
	_refresh_status()


func _active_follow() -> MatchSnapshotFollowGd:
	if _offline_playing():
		return offline.follow
	if play != null:
		return play.follow
	return null


func _camera_follow_slot() -> int:
	if _offline_playing():
		return 0
	if play != null and play.state == MatchPlaySessionGd.STATE_IN_MATCH:
		return play.predict.own_slot
	return -1


func _own_accepted_count(players: Array) -> int:
	return _own_player_int(players, "accepted_count", true)


func _own_finish_tick(players: Array) -> int:
	return _own_player_int(players, "finish_tick", false)


func _own_player_int(players: Array, key: String, reject_negative: bool) -> int:
	var slot: int = _camera_follow_slot()
	if slot < 0 or slot >= players.size():
		return -1
	var raw: Variant = players[slot]
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	var body: Dictionary = raw
	var value_raw: Variant = body.get(key, -1)
	if typeof(value_raw) != TYPE_INT:
		return -1
	var value: int = value_raw
	if reject_negative and value < 0:
		return -1
	return value


func _all_players_finished(players: Array) -> bool:
	if players.is_empty():
		return false
	for raw: Variant in players:
		if typeof(raw) != TYPE_DICTIONARY:
			return false
		var body: Dictionary = raw
		var tick_raw: Variant = body.get("finish_tick", -1)
		if typeof(tick_raw) != TYPE_INT:
			return false
		var finish_tick: int = tick_raw
		if finish_tick < 0:
			return false
	return true


func _sync_interp_t(follow: MatchSnapshotFollowGd) -> void:
	if follow == null or not follow.has_snapshot:
		return
	if follow.tick == _interp_tick:
		return
	_interp_tick = follow.tick
	if follow.has_previous:
		_interp_t = 0
	else:
		_interp_t = Fixed.SCALE


func _reset_interp() -> void:
	_interp_t = 0
	_interp_tick = -1


func _offline_playing() -> bool:
	return offline != null and offline.state == MatchOfflineSessionGd.STATE_PLAYING


func _online_busy() -> bool:
	if join != null:
		if join.state == MatchJoinSessionGd.STATE_WAITING:
			return true
		if join.state == MatchJoinSessionGd.STATE_READY:
			return true
	if play == null:
		return false
	if play.state == MatchPlaySessionGd.STATE_CONNECTING:
		return true
	return play.state == MatchPlaySessionGd.STATE_IN_MATCH


func _prepare_offline_stubs() -> void:
	if offline == null:
		return
	offline.play_jump_dy = Fixed.SCALE
	offline.play_support_dy = Fixed.SCALE
	offline.play_use_item_damage = 1
	offline.play_use_item_reach_dx = 0
	offline.play_use_item_reach_dy = 0
	offline.play_use_item_reach_dz = Fixed.SCALE


func _on_close_requested() -> void:
	hide_window()
