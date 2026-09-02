class_name MatchLobbyDirector
extends RefCounted

## L4 coordinator for matchmaking / Solo / leave / settlement. The shell
## Node keeps Window + _process; this type owns the session verbs so the
## facade file stays under the E9 line cap.

const MatchJoinSessionGd := preload("res://src/client/match_join_session.gd")
const MatchLobbyHudGd := preload("res://src/client/match_lobby_hud.gd")
const MatchPlaySessionGd := preload("res://src/client/match_play_session.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")

var host: MatchLobbyShell = null


func bind(shell: MatchLobbyShell) -> void:
	host = shell


func try_apply_server_host(raw_host: String) -> bool:
	host.chrome.release_focus()
	if host.endpoint == null:
		return false
	if host.online_busy() or host.offline_playing():
		return false
	var applied_host: String = raw_host
	if applied_host == "":
		applied_host = host.chrome.server_host_text("")
	host.endpoint.clear_errors()
	host.endpoint.control_plane = host.control_plane_base
	host.endpoint.gateway = host.gateway_base
	if not host.endpoint.try_apply_host(applied_host):
		host.refresh_status()
		return false
	host.control_plane_base = host.endpoint.control_plane
	host.gateway_base = host.endpoint.gateway
	host.chrome.sync_server_edit(host.control_plane_base)
	host.refresh_status()
	return true


func try_quick() -> bool:
	return _matchmake(func() -> bool: return host.join.try_quick(host.selected_course_id(), host.selected_seats()))


func try_create_room() -> bool:
	return _matchmake(func() -> bool: return host.join.try_create_room(host.selected_course_id(), host.selected_seats()))


func try_join_room(raw_code: String) -> bool:
	host.chrome.release_focus()
	if host.join == null or host.offline_playing():
		return false
	var code: String = raw_code
	if code == "":
		code = host.chrome.room_code_text()
	if not host.join.try_join_room(code):
		return false
	host.dispatch_pending()
	host.refresh_status()
	return true


func try_poll() -> bool:
	return _join_action(func() -> bool: return host.join.try_poll())


func try_reconnect() -> bool:
	return _join_action(func() -> bool: return host.join.try_reconnect())


func try_solo() -> bool:
	host.chrome.release_focus()
	if host.offline == null or host.online_busy():
		return false
	var id: String = host.selected_course_id()
	if id == "":
		return false
	host.offline.apply_play_stubs()
	host.stage.reset_interp()
	host.sampler.reset_motion()
	host.play_anim.reset()
	host.course_path = OfficialTraprushCoursesGd.document_path(id)
	if not host.offline.try_begin(host.course_path, host.web_platform):
		host.refresh_status()
		return false
	host.apply_course_document(host.course_path)
	host.apply_snapshot_map()
	host.refresh_status()
	return true


func try_stop_offline() -> bool:
	if host.offline == null or not host.offline_playing():
		return false
	if not host.offline.try_stop():
		return false
	host.stage.reset_interp()
	host.sampler.reset_motion()
	host.play_anim.reset()
	host.stage.clear_play_overlay()
	host.refresh_status()
	return true


func try_cancel() -> bool:
	host.chrome.release_focus()
	if host.offline_playing():
		return try_stop_offline()
	if try_leave_play():
		return true
	if host.join == null:
		return false
	if not host.join.try_cancel():
		return false
	host.dispatch_pending()
	host.refresh_status()
	return true


func try_leave_play() -> bool:
	var left: bool = false
	if host.play != null and host.play.try_leave():
		left = true
	if host.join != null and host.join.try_abandon():
		left = true
	if not left:
		return false
	if host.net != null:
		host.net.drop_gateway()
	host.last_sent_command = PackedByteArray()
	host.stage.reset_interp()
	host.stage.clear_play_overlay()
	host.refresh_status()
	return true


func accept_http(status_code: int, body: Dictionary) -> bool:
	if host.join == null:
		return false
	var ok: bool = host.join.accept_http(status_code, body)
	after_join_http()
	return ok


func apply_http_text(status_code: int, text: String) -> bool:
	if host.join == null:
		return false
	var ok: bool = host.join.apply_http_text(status_code, text)
	after_join_http()
	return ok


func try_begin_play() -> bool:
	if host.join == null or host.play == null or host.offline_playing():
		return false
	if not host.play.try_begin(host.join, host.gateway_base):
		return false
	if host.live_io:
		host.play.rtt.log_path = "user://protocol_rtt.jsonl"
	host.stage.reset_interp()
	if host.live_io:
		host.ensure_net()
		host.net.opened_socket = false
		host.net.connect_gateway(host.play)
	host.refresh_status()
	return true


func on_socket_open() -> bool:
	if host.play == null:
		return false
	var ok: bool = host.play.on_open()
	host.refresh_status()
	return ok


func on_socket_close() -> void:
	var should_reconnect: bool = false
	if host.play != null:
		should_reconnect = (
			host.play.state == MatchPlaySessionGd.STATE_CONNECTING
			or host.play.state == MatchPlaySessionGd.STATE_IN_MATCH
		)
		host.play.on_close()
	if should_reconnect:
		try_reconnect()
	host.refresh_status()


func on_binary(bytes: PackedByteArray, now_ms: int) -> bool:
	if host.play == null:
		return false
	var ok: bool = host.play.on_binary(bytes, now_ms)
	if ok:
		host.apply_snapshot_map()
	host.refresh_status()
	return ok


func try_fetch_settlement() -> bool:
	if host.offline_playing() or host.join == null or host.play == null:
		return false
	if host.play.state != MatchPlaySessionGd.STATE_IN_MATCH or host.join.has_settlement:
		return false
	var follow: MatchSnapshotFollow = host.active_follow()
	if follow == null or not follow.has_snapshot:
		return false
	if not MatchLobbyHudGd.all_players_finished(follow.players):
		return false
	if not host.join.try_get_settlement():
		return false
	host.dispatch_pending()
	host.refresh_status()
	return true


func after_join_http() -> void:
	if host.join != null and host.join.course != "":
		var path: String = OfficialTraprushCoursesGd.document_path(host.join.course)
		if path != "":
			host.apply_course_document(path)
	if host.join != null and host.join.state == MatchJoinSessionGd.STATE_READY and host.play != null:
		if host.play.state == MatchPlaySessionGd.STATE_IDLE or host.play.state == MatchPlaySessionGd.STATE_CLOSED:
			try_begin_play()
	host.refresh_status()


func _join_action(action: Callable) -> bool:
	host.chrome.release_focus()
	if host.join == null or host.offline_playing():
		return false
	if not action.call():
		return false
	host.dispatch_pending()
	host.refresh_status()
	return true


func _matchmake(action: Callable) -> bool:
	host.chrome.release_focus()
	if host.join == null or host.offline_playing():
		return false
	if host.selected_course_id() == "" or host.selected_seats() == 0:
		return false
	if not action.call():
		return false
	host.dispatch_pending()
	host.refresh_status()
	return true
