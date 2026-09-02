class_name MatchLobbyShell
extends Node

## TRAPRUSH lobby facade (CD-12). L4: chrome / net / sampler / stage / hud / director.

const MatchJoinSessionGd := preload("res://src/client/match_join_session.gd")
const MatchLobbyChromeGd := preload("res://src/client/match_lobby_chrome.gd")
const MatchLobbyHudGd := preload("res://src/client/match_lobby_hud.gd")
const MatchLobbyNetGd := preload("res://src/client/match_lobby_net.gd")
const MatchLobbySamplerGd := preload("res://src/client/match_lobby_sampler.gd")
const MatchLobbyStageGd := preload("res://src/client/match_lobby_stage.gd")
const MatchOfflineSessionGd := preload("res://src/client/match_offline_session.gd")
const MatchPlaySessionGd := preload("res://src/client/match_play_session.gd")
const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const ServerEndpointGd := preload("res://src/client/server_endpoint.gd")

const TITLE: String = MatchLobbyChromeGd.TITLE
const WINDOW_SIZE: Vector2i = MatchLobbyChromeGd.WINDOW_SIZE
const WINDOW_MIN_SIZE: Vector2i = MatchLobbyChromeGd.WINDOW_MIN_SIZE
const DEFAULT_COURSE: String = "res://content/official/traprush/course_01.json"
const DEFAULT_CONTROL_PLANE: String = ServerEndpointGd.DEFAULT_CONTROL_PLANE
const DEFAULT_GATEWAY: String = ServerEndpointGd.DEFAULT_GATEWAY
const DEFAULT_QUEUE_POLL_S: float = 1.0
const QUICK_NAME: String = MatchLobbyChromeGd.QUICK_NAME
const CREATE_NAME: String = MatchLobbyChromeGd.CREATE_NAME
const JOIN_NAME: String = MatchLobbyChromeGd.JOIN_NAME
const CANCEL_NAME: String = MatchLobbyChromeGd.CANCEL_NAME
const SOLO_NAME: String = MatchLobbyChromeGd.SOLO_NAME
const POLL_NAME: String = MatchLobbyChromeGd.POLL_NAME
const SPRINT_NAME: String = MatchLobbyChromeGd.SPRINT_NAME
const ROOM_NAME: String = MatchLobbyChromeGd.ROOM_NAME
const COURSE_ID_NAME: String = MatchLobbyChromeGd.COURSE_ID_NAME
const SEATS_NAME: String = MatchLobbyChromeGd.SEATS_NAME
const SERVER_NAME: String = MatchLobbyChromeGd.SERVER_NAME
const APPLY_SERVER_NAME: String = MatchLobbyChromeGd.APPLY_SERVER_NAME
const FPS_NAME: String = MatchLobbyChromeGd.FPS_NAME

static func floor_index_from_y(y: int) -> int:
	return MatchLobbyHudGd.floor_index_from_y(y)

var join: MatchJoinSessionGd = null
var play: MatchPlaySessionGd = null
var offline: MatchOfflineSessionGd = null
var chrome: MatchLobbyChromeGd = MatchLobbyChromeGd.new()
var stage: MatchLobbyStageGd = MatchLobbyStageGd.new()
var sampler: MatchLobbySamplerGd = MatchLobbySamplerGd.new()
var director: MatchLobbyDirector = MatchLobbyDirector.new()
var net: MatchLobbyNetGd = null
var map: MatchSnapshotMap = null
var course: MatchCourseMap = null
var crates: MatchCrateMap = null
var hazards: MatchHazardMap = null
var solids: MatchSolidMap = null
var links: MatchPortalLinkMap = null
var orders: MatchCheckpointOrderMap = null
var standings: MatchStandingMap = null
var frame_rate: FrameRateMeter = null
var window: Window = null
var live_io: bool = false
var web_platform: bool = false
var endpoint: ServerEndpointGd = null
var control_plane_base: String = DEFAULT_CONTROL_PLANE
var gateway_base: String = DEFAULT_GATEWAY
var course_path: String = DEFAULT_COURSE
var course_id: String = OfficialTraprushCoursesGd.DEFAULT_ID
var play_move_step: int = PlaceholderSpec.MOVE_STEP
var play_interp_step: int = PlaceholderSpec.INTERP_STEP
var queue_poll_s: float = DEFAULT_QUEUE_POLL_S
var last_sent_command: PackedByteArray = PackedByteArray()
var play_anim: PlayAnimState = PlayAnimState.new()
var play_input: PlayInput = PlayInput.new()
func _init() -> void:
	director.bind(self)


static func create() -> MatchLobbyShell:
	var shell := new()
	shell.join = MatchJoinSessionGd.create()
	shell.play = MatchPlaySessionGd.new()
	shell.offline = MatchOfflineSessionGd.new()
	shell.endpoint = ServerEndpointGd.new()
	shell.web_platform = OS.has_feature("web")
	return shell
func open() -> bool:
	if join == null:
		return false
	_ensure_window()
	if window == null:
		return false
	if live_io:
		ensure_net()
		net.ensure_http(_on_http_completed)
	window.visible = true
	_refresh_status()
	return true
func show_window() -> bool:
	if window == null:
		return false
	chrome.show_window()
	_refresh_status()
	return true
func hide_window() -> void:
	chrome.hide_window()
func is_window_visible() -> bool:
	return chrome.is_visible()
func room_code_text() -> String:
	return chrome.room_code_text()
func set_room_code_text(text: String) -> void:
	chrome.set_room_code_text(text)
func course_id_text() -> String:
	return chrome.course_id_text(course_id)
func set_course_id_text(text: String) -> void:
	course_id = text
	chrome.set_course_id_text(text)
func selected_course_id() -> String:
	var trimmed: String = course_id_text().strip_edges()
	if trimmed == "":
		return OfficialTraprushCoursesGd.DEFAULT_ID
	return OfficialTraprushCoursesGd.normalize_id(trimmed)
func seats_text() -> String:
	return chrome.seats_text()
func set_seats_text(text: String) -> void:
	chrome.set_seats_text(text)
func selected_seats() -> int:
	var raw: String = seats_text().strip_edges()
	if raw == "":
		return OfficialTraprushCoursesGd.DEFAULT_SEATS
	if not raw.is_valid_int():
		return 0
	return OfficialTraprushCoursesGd.normalize_seats(raw.to_int())
func apply_endpoint(next: ServerEndpointGd) -> bool:
	if next == null:
		return false
	endpoint = next
	control_plane_base = next.control_plane
	gateway_base = next.gateway
	chrome.sync_server_edit(control_plane_base)
	_refresh_status()
	return true
func server_host_text() -> String:
	return chrome.server_host_text(ServerEndpointGd.host_of(control_plane_base))
func set_server_host_text(text: String) -> void:
	chrome.set_server_host_text(text)
func try_apply_server_host(raw_host: String = "") -> bool:
	return director.try_apply_server_host(raw_host)
func try_quick() -> bool:
	return director.try_quick()
func try_create_room() -> bool:
	return director.try_create_room()
func try_join_room(raw_code: String = "") -> bool:
	return director.try_join_room(raw_code)
func try_poll() -> bool:
	return director.try_poll()
func try_solo() -> bool:
	return director.try_solo()
func try_stop_offline() -> bool:
	return director.try_stop_offline()
func try_cancel() -> bool:
	return director.try_cancel()
func try_leave_play() -> bool:
	return director.try_leave_play()
func accept_http(status_code: int, body: Dictionary) -> bool:
	return director.accept_http(status_code, body)
func apply_http_text(status_code: int, text: String) -> bool:
	return director.apply_http_text(status_code, text)
func try_begin_play() -> bool:
	return director.try_begin_play()
func on_socket_open() -> bool:
	return director.on_socket_open()
func on_socket_close() -> void:
	director.on_socket_close()
func try_reconnect() -> bool:
	return director.try_reconnect()
func on_binary(bytes: PackedByteArray, now_ms: int = -1) -> bool:
	return director.on_binary(bytes, now_ms)
func try_sample_play_vector(move_x: float, move_z: float) -> PackedByteArray:
	return _take_sample(sampler.try_vector(
		move_x, move_z, is_window_visible(), offline_playing(), offline, play, play_move_step
	))
func try_sample_play_move(forward: bool, back: bool, left: bool, right: bool) -> PackedByteArray:
	return _take_sample(sampler.try_axes(
		forward, back, left, right, is_window_visible(), offline_playing(), offline, play, play_move_step
	))
func try_sample_play_reset(pressed: bool) -> PackedByteArray:
	return _take_sample(sampler.try_reset(pressed, is_window_visible(), offline_playing(), offline, play))
func try_sample_play_use_item(pressed: bool) -> PackedByteArray:
	return _take_sample(sampler.try_use_item(pressed, is_window_visible(), offline_playing(), offline, play))
func try_sample_play_jump(pressed: bool) -> PackedByteArray:
	return _take_sample(sampler.try_jump(pressed, is_window_visible(), offline_playing(), offline, play))
func try_sample_play_shove(pressed: bool) -> PackedByteArray:
	return _take_sample(sampler.try_shove(pressed, is_window_visible(), offline_playing(), offline, play))
func try_sample_play_sprint(pressed: bool) -> PackedByteArray:
	return _take_sample(sampler.try_sprint(pressed, is_window_visible(), offline_playing(), offline, play))
func status_view() -> Dictionary:
	var join_view: Dictionary = {} if join == null else join.status_view()
	var play_view: Dictionary = {} if play == null else play.status_view()
	var offline_view: Dictionary = {} if offline == null else offline.status_view()
	var server_error: String = "" if endpoint == null else endpoint.error_line()
	return MatchLobbyHudGd.build_view(
		join_view, play_view, offline_view, stage.mapped_counts(), active_follow(),
		stage.camera_follow_slot(offline_playing(), play), selected_course_id(), selected_seats(),
		control_plane_base, gateway_base, server_error, is_window_visible(), offline_playing()
	)
func status_label_text() -> String:
	return chrome.status_text()
func fps_label_text() -> String:
	return chrome.fps_text()
func try_advance_interp() -> bool:
	if not stage.try_advance_interp(is_window_visible(), play_interp_step, active_follow()):
		return false
	_apply_snapshot_map()
	return true
func interp_progress() -> int:
	return stage.interp_t
func snapshot_map_apply_count() -> int:
	return stage.apply_count
func try_fetch_settlement() -> bool:
	return director.try_fetch_settlement()
func allows_settlement() -> bool:
	return false
func allows_online_writes() -> bool:
	return false
func handle_window_input(event: InputEvent) -> void:
	chrome.handle_window_input(event)
func refresh_status() -> void:
	_refresh_status()


func _refresh_status() -> void:
	chrome.set_status_text(MatchLobbyHudGd.format_line(status_view()))
func dispatch_pending() -> void:
	if not live_io or net == null or join == null:
		return
	net.dispatch(control_plane_base, join, _refresh_status)
func apply_course_document(path: String) -> void:
	course_path = path
	stage.apply_course(path)
func apply_snapshot_map() -> void:
	_apply_snapshot_map()


func _apply_snapshot_map() -> void:
	var follow: MatchSnapshotFollowGd = active_follow()
	stage.sync_interp(follow)
	var session: TraprushMatchSession = null if offline == null else offline.session
	if stage.apply_snapshot(follow, stage.interp_t, play, offline_playing(), sampler.play_moving, play_anim, session):
		_refresh_status()
func ensure_net() -> void:
	if net != null:
		return
	net = MatchLobbyNetGd.new()
	add_child(net)
func active_follow() -> MatchSnapshotFollowGd:
	if offline_playing():
		return offline.follow
	if play != null:
		return play.follow
	return null
func offline_playing() -> bool:
	return offline != null and offline.state == MatchOfflineSessionGd.STATE_PLAYING
func online_busy() -> bool:
	if join != null and (join.state == MatchJoinSessionGd.STATE_WAITING or join.state == MatchJoinSessionGd.STATE_READY):
		return true
	if play == null:
		return false
	return play.state == MatchPlaySessionGd.STATE_CONNECTING or play.state == MatchPlaySessionGd.STATE_IN_MATCH
func _process(delta: float) -> void:
	if live_io and not offline_playing() and net != null:
		net.poll_queue_clock(delta, queue_poll_s, join, offline_playing(), try_poll)
		var follow: MatchSnapshotFollowGd = active_follow()
		var finished: bool = follow != null and follow.has_snapshot and MatchLobbyHudGd.all_players_finished(follow.players)
		net.poll_settlement_clock(delta, queue_poll_s, join, play, finished, try_fetch_settlement)
		last_sent_command = net.poll_gateway(
			play, last_sent_command, on_socket_open, on_binary, on_socket_close, _send_protocol_probe
		)
	if window == null or not window.visible:
		if frame_rate != null:
			frame_rate.reset()
		return
	if frame_rate != null:
		frame_rate.sample(delta)
	if offline_playing():
		try_advance_interp()
		_apply_snapshot_map()
		return
	if chrome.edit_has_focus():
		try_advance_interp()
		return
	sampler.drive_keyboard(self)
	try_advance_interp()
func _physics_process(_delta: float) -> void:
	if not offline_playing() or window == null or not window.visible:
		return
	offline.try_advance()
	if chrome.edit_has_focus():
		return
	sampler.drive_keyboard(self)
func _take_sample(sample: Dictionary) -> PackedByteArray:
	var bytes_raw: Variant = sample.get("bytes", PackedByteArray())
	var bytes: PackedByteArray = PackedByteArray()
	if typeof(bytes_raw) == TYPE_PACKED_BYTE_ARRAY:
		bytes = bytes_raw
	var note_raw: Variant = sample.get("note", false)
	if typeof(note_raw) == TYPE_BOOL:
		var note: bool = note_raw
		if note:
			_note_command(bytes)
	var remap_raw: Variant = sample.get("remap", false)
	if typeof(remap_raw) == TYPE_BOOL:
		var remap: bool = remap_raw
		if remap:
			_apply_snapshot_map()
	return bytes
func _ensure_window() -> void:
	if window != null:
		return
	window = chrome.attach(self, {
		"quick": try_quick,
		"create": try_create_room,
		"join": try_join_room,
		"solo": try_solo,
		"cancel": try_cancel,
		"poll": try_poll,
		"sprint": _on_sprint,
		"apply_server": try_apply_server_host,
		"edit_submitted": _on_edit_submitted,
		"close": _on_close_requested,
		"window_input": handle_window_input,
	})
	stage.mount(window)
	stage.bind_facade(self)
	add_child(window)
	stage.ensure_rig()
	apply_course_document(course_path)
	chrome.sync_server_edit(control_plane_base)
	window.gui_release_focus()
func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if net == null:
		return
	net.on_http_completed(result, response_code, body, join, apply_http_text, _refresh_status)
func _note_command(bytes: PackedByteArray) -> void:
	if net == null:
		return
	var sent: PackedByteArray = net.note_command(bytes)
	if sent.is_empty():
		return
	last_sent_command = sent
	_refresh_status()
func _send_protocol_probe() -> void:
	if net == null or play == null:
		return
	net.send_probe(play.try_encode_probe(Time.get_ticks_msec()))
func _on_close_requested() -> void:
	hide_window()
func _on_edit_submitted(_text: String) -> void:
	chrome.release_focus()
func _on_sprint() -> void:
	chrome.release_focus()
	try_sample_play_sprint(true)
	try_sample_play_sprint(false)
