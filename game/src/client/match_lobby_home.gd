class_name MatchLobbyHome
extends RefCounted

## S1 landing vs the existing match Window. MatchLobbyShell keeps the public
## verbs; this type owns surface state so the facade stays under E9.

const MatchGameplayGd := preload("res://src/shared/match_gameplay.gd")
const MatchLobbyChromeGd := preload("res://src/client/match_lobby_chrome.gd")
const OfficialBastionBlueprintsGd := preload("res://src/shared/official_bastion_blueprints.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const ClientAudioGd := preload("res://src/client/client_audio.gd")

const SCREEN_NAME: StringName = &"S1Lobby"
const SURFACE_HOME: String = "home"
const SURFACE_CHANNEL: String = "channel"
const SCENE_PATH: String = "res://src/client/ui/scenes/s1_lobby.tscn"

const _ACTIONS := "VBoxContainer/MatchActions"


static func ensure(shell: MatchLobbyShell) -> void:
	if shell.home_screen != null:
		return
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		return
	var screen: Control = packed.instantiate() as Control
	if screen == null:
		return
	screen.name = String(SCREEN_NAME)
	screen.visible = false
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_child(screen)
	shell.home_screen = screen
	if shell.home_surface == "":
		shell.home_surface = SURFACE_CHANNEL
	screen.connect("channel_requested", func(gameplay: String) -> void:
		try_enter_channel(shell, gameplay)
	)
	screen.connect("plaza_requested", func() -> void:
		shell.try_open_plaza()
	)
	screen.connect("settings_requested", func() -> void:
		shell.try_open_settings()
	)
	screen.connect("account_requested", func() -> void:
		shell.try_open_account()
	)


static func note_channel_shown(shell: MatchLobbyShell) -> void:
	shell.home_surface = SURFACE_CHANNEL
	if shell.home_screen != null:
		shell.home_screen.visible = false


static func try_show_home(shell: MatchLobbyShell) -> bool:
	ensure(shell)
	if shell.home_screen == null:
		return false
	shell.home_surface = SURFACE_HOME
	if shell.window != null:
		shell.window.visible = false
	shell.home_screen.visible = true
	return true


static func try_enter_channel(shell: MatchLobbyShell, gameplay: String) -> bool:
	if not MatchGameplayGd.is_id(gameplay):
		return false
	ensure(shell)
	ClientAudioGd.post_ui_confirm()
	shell.home_surface = SURFACE_CHANNEL
	if shell.home_screen != null:
		shell.home_screen.visible = false
	if gameplay == MatchGameplayGd.BASTION:
		if shell.chrome.course_select != null:
			shell.chrome.course_select.populate_bastion(OfficialBastionBlueprintsGd.DEFAULT_ID)
		shell.set_course_id_text(OfficialBastionBlueprintsGd.DEFAULT_ID)
		shell.set_seats_text(str(MatchGameplayGd.BASTION_SEATS))
		shell.apply_blueprint_document(OfficialBastionBlueprintsGd.DEFAULT_ID)
	else:
		if shell.chrome.course_select != null:
			shell.chrome.course_select.populate_traprush(OfficialTraprushCoursesGd.DEFAULT_ID)
		shell.set_course_id_text(OfficialTraprushCoursesGd.DEFAULT_ID)
		shell.apply_course_document(OfficialTraprushCoursesGd.default_path())
	var traprush: bool = gameplay == MatchGameplayGd.TRAPRUSH
	_set_action_visible(shell, MatchLobbyChromeGd.SOLO_NAME, traprush)
	_set_action_visible(shell, MatchLobbyChromeGd.CREATOR_NAME, traprush)
	_set_action_visible(shell, MatchLobbyChromeGd.SPRINT_NAME, traprush)
	if shell.window != null:
		shell.window.visible = true
	shell.refresh_status()
	return true


static func hide_for_overlay(shell: MatchLobbyShell) -> void:
	if shell.home_screen != null:
		shell.home_screen.visible = false
	if shell.window != null:
		shell.window.visible = false


static func restore_from_overlay(shell: MatchLobbyShell) -> void:
	if shell.home_surface == SURFACE_HOME:
		try_show_home(shell)
		return
	if shell.home_screen != null:
		shell.home_screen.visible = false
	if shell.window != null:
		shell.window.visible = true


static func set_lobby_visible(shell: MatchLobbyShell, visible: bool) -> void:
	if visible:
		restore_from_overlay(shell)
	else:
		hide_for_overlay(shell)


static func is_home_visible(shell: MatchLobbyShell) -> bool:
	return shell.home_screen != null and shell.home_screen.visible


static func _set_action_visible(shell: MatchLobbyShell, node_name: String, shown: bool) -> void:
	if shell.window == null:
		return
	var button: Button = shell.window.get_node_or_null("%s/%s" % [_ACTIONS, node_name]) as Button
	if button != null:
		button.visible = shown
