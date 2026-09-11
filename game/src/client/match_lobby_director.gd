class_name MatchLobbyDirector
extends RefCounted

## L4 coordinator for matchmaking / Solo / leave / settlement. The shell
## Node keeps Window + _process; this type owns the session verbs so the
## facade file stays under the E9 line cap.

const MatchJoinSessionGd := preload("res://src/client/match_join_session.gd")
const MatchLobbyHudGd := preload("res://src/client/match_lobby_hud.gd")
const MatchPlaySessionGd := preload("res://src/client/match_play_session.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const ClientAudioGd := preload("res://src/client/client_audio.gd")
const AudioSettingsEntryGd := preload("res://src/client/audio_settings_entry.gd")
const MatchLobbyDirectorJoinGd := preload("res://src/client/match_lobby_director_join.gd")

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
	if host.offline == null:
		return false
	if host.online_busy():
		host.offline.last_error = "online_busy"
		host.refresh_status()
		return false
	var id: String = host.selected_course_id()
	if id == "":
		host.offline.last_error = "unknown_course"
		host.refresh_status()
		return false
	if host.join != null and (
		host.join.state == MatchJoinSessionGd.STATE_IDLE
		or host.join.state == MatchJoinSessionGd.STATE_FAILED
	):
		host.join.error = ""
		if host.join.state == MatchJoinSessionGd.STATE_FAILED:
			host.join.state = MatchJoinSessionGd.STATE_IDLE
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


func try_open_plaza() -> bool:
	host.chrome.release_focus()
	host.plaza = ContentPlazaEntry.ensure(host, host.plaza)
	if host.plaza == null:
		return false
	host.plaza.on_solo = try_solo_plaza
	host.plaza.on_create_room = try_create_room_plaza
	host.plaza.live_io = host.live_io
	host.plaza.control_plane_base = host.control_plane_base
	return host.plaza.try_open()


func try_close_plaza() -> bool:
	if host.plaza == null:
		return false
	return host.plaza.try_close()


func try_open_account() -> bool:
	host.chrome.release_focus()
	host.account = AccountEntry.ensure(host, host.account)
	if host.account == null:
		return false
	return host.account.try_open()


func try_close_account() -> bool:
	if host.account == null:
		return false
	return host.account.try_close()


func try_open_settings() -> bool:
	host.chrome.release_focus()
	host.settings = AudioSettingsEntryGd.ensure(host, host.settings)
	if host.settings == null:
		return false
	return host.settings.try_open()


func try_close_settings() -> bool:
	if host.settings == null:
		return false
	return host.settings.try_close()


func sync_music() -> void:
	ClientAudioGd.advance_music()
	ClientAudioGd.request_state(_music_state())


func _music_state() -> String:
	if host.creator != null and host.creator.is_open():
		return ClientAudioGd.STATE_EDIT
	if host.offline_playing() or _in_live_match():
		if _own_finished():
			return ClientAudioGd.STATE_RESULT
		return ClientAudioGd.STATE_PLAY
	return ClientAudioGd.STATE_LOBBY


func _in_live_match() -> bool:
	if host.play == null:
		return false
	return host.play.state == MatchPlaySessionGd.STATE_IN_MATCH


func _own_finished() -> bool:
	var follow: MatchSnapshotFollow = host.active_follow()
	if follow == null or not follow.has_snapshot:
		return false
	var slot: int = host.stage.camera_follow_slot(host.offline_playing(), host.play)
	return MatchLobbyHudGd.own_player_int(follow.players, slot, "finish_tick", false) >= 0


func try_solo_plaza(content_id: String = "") -> bool:
	host.chrome.release_focus()
	if host.plaza == null or host.offline == null:
		return false
	if host.online_busy():
		host.offline.last_error = "online_busy"
		host.refresh_status()
		return false
	var id: String = content_id
	if id == "":
		id = host.plaza.selected_content_id()
	var bundle: SimulationBundle = host.plaza.ensure_bundle(id)
	if id == "" or bundle == null:
		host.offline.last_error = "unknown_course"
		host.refresh_status()
		return false
	if host.offline_playing() and not try_stop_offline():
		return false
	if host.join != null and (
		host.join.state == MatchJoinSessionGd.STATE_IDLE
		or host.join.state == MatchJoinSessionGd.STATE_FAILED
	):
		host.join.error = ""
		if host.join.state == MatchJoinSessionGd.STATE_FAILED:
			host.join.state = MatchJoinSessionGd.STATE_IDLE
	host.offline.apply_play_stubs()
	host.stage.reset_interp()
	host.sampler.reset_motion()
	host.play_anim.reset()
	if not host.offline.try_begin_bundle(bundle):
		host.refresh_status()
		return false
	host.stage.apply_bundle(bundle)
	host.plaza.try_close()
	host.apply_snapshot_map()
	host.refresh_status()
	return true


func try_stop_offline() -> bool:
	if host.offline == null or not host.offline_playing():
		return false
	if not host.offline.try_stop():
		return false
	ClientAudioGd.clear_play()
	host.stage.reset_interp()
	host.sampler.reset_motion()
	host.play_anim.reset()
	host.stage.clear_play_overlay()
	var official: String = OfficialTraprushCoursesGd.document_path(host.selected_course_id())
	if official != "":
		host.apply_course_document(official)
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
	ClientAudioGd.clear_play()
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


func try_create_room_plaza(content_id: String = "", version: int = 0) -> bool:
	return MatchLobbyDirectorJoinGd.try_create_room_plaza(host, content_id, version)


func after_join_http() -> void:
	MatchLobbyDirectorJoinGd.after_join_http(host, try_begin_play)


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
	if host.selected_seats() == 0:
		return false
	var id: String = host.selected_course_id()
	if id == "":
		host.join.fail_reason("unknown_course")
		host.refresh_status()
		return false
	if not OfficialTraprushCoursesGd.is_id(id):
		host.join.fail_reason("http_official_only")
		host.refresh_status()
		return false
	if not action.call():
		return false
	host.dispatch_pending()
	host.refresh_status()
	return true
