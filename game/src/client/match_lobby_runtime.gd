class_name MatchLobbyRuntime
extends RefCounted

## Process loop + BASTION input/snapshot apply so MatchLobbyShell stays
## under E9. The shell Node still owns `_process`; this type does the work.

const MatchGameplayGd := preload("res://src/shared/match_gameplay.gd")
const MatchLobbyHudGd := preload("res://src/client/match_lobby_hud.gd")
const MatchLobbyHomeGd := preload("res://src/client/match_lobby_home.gd")
const OfficialBastionBlueprintsGd := preload("res://src/shared/official_bastion_blueprints.gd")
const RouterGd := preload("res://src/games/bastion/audio_router.gd")
const CatalogGd := preload("res://src/ugc/bastion_prototype_catalog.gd")


static func on_process(shell: MatchLobbyShell, delta: float) -> void:
	shell.director.sync_music()
	if shell.live_io and not shell.offline_playing() and shell.net != null:
		shell.net.poll_queue_clock(delta, shell.queue_poll_s, shell.join, shell.offline_playing(), shell.try_poll)
		var finished: bool = _settlement_ready(shell)
		shell.net.poll_settlement_clock(
			delta, shell.queue_poll_s, shell.join, shell.play, finished, shell.try_fetch_settlement
		)
		shell.last_sent_command = shell.net.poll_gateway(
			shell.play, shell.last_sent_command, shell.on_socket_open, shell.on_binary,
			shell.on_socket_close, shell._send_protocol_probe
		)
	if shell.window == null or not shell.window.visible:
		if shell.frame_rate != null:
			shell.frame_rate.reset()
		return
	if shell.frame_rate != null:
		shell.frame_rate.sample(delta)
	if _bastion_live(shell):
		apply_snapshot(shell)
		return
	if shell.map != null:
		shell.map.advance_camera(delta)
	if shell.offline_playing():
		shell.try_advance_interp()
		apply_snapshot(shell)
		return
	if shell.chrome.edit_has_focus():
		shell.try_advance_interp()
		return
	shell.sampler.drive_keyboard(shell)
	shell.try_advance_interp()


static func on_physics(shell: MatchLobbyShell, _delta: float) -> void:
	if not shell.offline_playing() or shell.window == null or not shell.window.visible:
		return
	shell.offline.try_advance()
	if not shell.chrome.edit_has_focus():
		shell.sampler.drive_keyboard(shell)
	shell.stage.pump_play_audio(shell.offline)


static func apply_snapshot(shell: MatchLobbyShell) -> void:
	if _bastion_live(shell):
		MatchLobbyStageBastion.apply_follow(shell)
		shell.refresh_status()
		_pump_bastion_audio(shell)
		return
	var follow: MatchSnapshotFollow = shell.active_follow()
	shell.stage.sync_interp(follow)
	var session: TraprushMatchSession = null if shell.offline == null else shell.offline.session
	if shell.stage.apply_snapshot(
		follow, shell.stage.interp_t, shell.play, shell.offline_playing(),
		shell.sampler.play_moving, shell.play_anim, session
	):
		shell.refresh_status()


static func ensure_window(shell: MatchLobbyShell) -> void:
	if shell.window != null:
		return
	shell.window = shell.chrome.attach(shell, {
		"quick": shell.try_quick,
		"create": shell.try_create_room,
		"join": shell.try_join_room,
		"solo": shell.try_solo,
		"creator": shell.try_open_creator,
		"plaza": shell.try_open_plaza,
		"account": shell.try_open_account,
		"settings": shell.try_open_settings,
		"cancel": shell.try_cancel,
		"poll": shell.try_poll,
		"sprint": shell._on_sprint,
		"apply_server": shell.try_apply_server_host,
		"edit_submitted": shell._on_edit_submitted,
		"close": shell._on_close_requested,
		"window_input": shell.handle_window_input,
		"camera_zoom": shell.try_camera_zoom,
		"camera_pan": shell.try_camera_pan,
		"copy_invite": shell.try_copy_invite,
		"pick": func(screen: Vector2) -> bool:
			return try_pick(shell, screen),
		"play_key": func(keycode: int) -> bool:
			return try_key(shell, keycode),
	})
	shell.stage.mount(shell.window)
	MatchLobbyStageBastion.mount(shell)
	shell.stage.bind_facade(shell)
	shell.add_child(shell.window)
	MatchLobbyHomeGd.ensure(shell)
	shell.stage.ensure_rig()
	shell.apply_course_document(shell.course_path)
	shell.chrome.sync_server_edit(shell.control_plane_base)
	shell.window.gui_release_focus()


static func apply_blueprint_document(shell: MatchLobbyShell, blueprint_id: String) -> void:
	var path: String = OfficialBastionBlueprintsGd.document_path(blueprint_id)
	if path == "":
		return
	shell.course_path = path
	MatchLobbyStageBastion.apply_path(shell, path)


static func try_pick(shell: MatchLobbyShell, screen: Vector2) -> bool:
	if not _bastion_live(shell):
		return false
	shell.chrome.release_focus()
	return MatchLobbyStageBastion.try_pick(shell, screen)


static func try_key(shell: MatchLobbyShell, keycode: int) -> bool:
	if not _bastion_live(shell) or shell.chrome.edit_has_focus():
		return false
	var interact: BastionInteract = MatchLobbyStageBastion.interact_of(shell)
	if interact == null:
		return false
	var bytes: PackedByteArray = PackedByteArray()
	match keycode:
		KEY_1:
			bytes = interact.encode_prototype(CatalogGd.TOWER_ARROW if interact.selected_kind != BastionInteract.KIND_OBSTACLE else CatalogGd.OBSTACLE_BARRICADE)
		KEY_2:
			bytes = interact.encode_prototype(CatalogGd.TOWER_CANNON if interact.selected_kind != BastionInteract.KIND_OBSTACLE else CatalogGd.OBSTACLE_SLOW_TILE)
		KEY_3:
			bytes = interact.encode_prototype(CatalogGd.TOWER_FROST if interact.selected_kind != BastionInteract.KIND_OBSTACLE else CatalogGd.OBSTACLE_DIVERTER)
		KEY_L:
			bytes = interact.encode_lock()
		KEY_U:
			bytes = interact.encode_upgrade()
		KEY_X:
			bytes = interact.encode_sell()
		_:
			return false
	return _note_bastion(shell, bytes, interact.last_event)


static func try_zoom(shell: MatchLobbyShell, steps: int) -> bool:
	if _bastion_live(shell):
		return MatchLobbyStageBastion.try_zoom(shell, steps)
	return shell.map != null and shell.map.try_zoom(steps)


static func try_pan(shell: MatchLobbyShell, relative: Vector2) -> bool:
	if _bastion_live(shell):
		return MatchLobbyStageBastion.try_pan(shell, relative)
	return shell.map != null and shell.map.try_pan(relative)


static func _note_bastion(shell: MatchLobbyShell, bytes: PackedByteArray, event: String) -> bool:
	if bytes.is_empty() or shell.play == null:
		return false
	var sent: PackedByteArray = shell.play.try_encode_bastion(bytes)
	if sent.is_empty():
		return false
	shell.last_sent_command = sent
	if event != "":
		ClientAudio.post(RouterGd.cue(event))
	if shell.net != null:
		shell.net.note_command(sent)
	shell.refresh_status()
	return true


static func _pump_bastion_audio(shell: MatchLobbyShell) -> void:
	if shell.play == null or shell.play.bastion == null:
		return
	MatchLobbyStageBastion.pump_audio(shell)


static func _bastion_live(shell: MatchLobbyShell) -> bool:
	return shell.play != null and shell.play.is_bastion() and shell.play.state == shell.play.STATE_IN_MATCH


static func _settlement_ready(shell: MatchLobbyShell) -> bool:
	if shell.play != null and shell.play.is_bastion() and shell.play.bastion != null:
		return shell.play.bastion.has_snapshot and (
			shell.play.bastion.phase == BastionMatchSession.PHASE_SETTLED
			or shell.play.bastion.result != 0
		)
	var follow: MatchSnapshotFollow = shell.active_follow()
	return follow != null and follow.has_snapshot and MatchLobbyHudGd.all_players_finished(follow.players)
