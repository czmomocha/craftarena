extends GutTest

## In-match chrome: compact fields, FPS/play HUD corners, default black
## type, preview orbit then lock. Smoke only for presentation (CD-53 §1.1).

const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const MatchLobbyChromeGd := preload("res://src/client/match_lobby_chrome.gd")
const OverlayGd := preload("res://src/shared/play_hud_overlay.gd")
const HudSettingsGd := preload("res://src/client/hud_settings.gd")
const FrameRateMeterGd := preload("res://src/client/frame_rate_meter.gd")

var _shell: MatchLobbyShellGd = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_status_leads_vbox_and_fps_docks_bottom_left() -> void:
	_shell = _open()
	var status: Label = _shell.window.get_node("VBoxContainer/%s" % MatchLobbyChromeGd.STATUS_NAME) as Label
	assert_not_null(status)
	assert_eq(status.get_index(), 0)
	assert_eq(status.get_theme_color("font_color"), PlaceholderSpec.HUD_TEXT_COLOR)
	var fps: FrameRateMeterGd = _shell.window.get_node(MatchLobbyChromeGd.FPS_NAME) as FrameRateMeterGd
	assert_not_null(fps)
	assert_eq(fps.get_parent(), _shell.window)
	assert_eq(fps.get_theme_color("font_color"), PlaceholderSpec.HUD_TEXT_COLOR)


func test_server_room_course_seats_invite_share_one_row() -> void:
	_shell = _open()
	var fields: HBoxContainer = _shell.window.get_node(
		"VBoxContainer/%s" % MatchLobbyChromeGd.FIELDS_NAME
	) as HBoxContainer
	assert_not_null(fields)
	assert_eq(fields.get_index(), 2)
	assert_not_null(fields.get_node("ServerActions"))
	assert_not_null(fields.get_node(MatchLobbyChromeGd.ROOM_NAME))
	assert_not_null(fields.get_node(MatchLobbyChromeGd.COURSE_ID_NAME))
	assert_not_null(fields.get_node(MatchLobbyChromeGd.SEATS_NAME))
	assert_not_null(fields.get_node("InviteActions"))


func test_play_hud_docks_bottom_right_and_shows_when_solo() -> void:
	_shell = _open()
	var hud: VBoxContainer = _shell.window.get_node(OverlayGd.ROOT_NAME) as VBoxContainer
	assert_not_null(hud)
	assert_eq(hud.get_parent(), _shell.window)
	assert_eq(_shell.clock_label_text(), "")
	assert_true(_shell.try_solo())
	assert_eq(_shell.countdown_label_text(), "3")
	assert_true(_shell.clock_label_text().begins_with("0:"))
	var countdown: Label = _shell.window.get_node(OverlayGd.COUNTDOWN_NAME) as Label
	assert_not_null(countdown)
	assert_eq(countdown.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(countdown.get_theme_font_size("font_size"), PlaceholderSpec.HUD_COUNTDOWN_FONT_SIZE)
	var clock: Label = hud.get_node(OverlayGd.CLOCK_NAME) as Label
	assert_not_null(clock)
	assert_eq(clock.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
	assert_eq(clock.get_theme_color("font_color"), PlaceholderSpec.HUD_TEXT_COLOR)


func test_preview_orbit_then_solo_resets_and_locks_look() -> void:
	_shell = _open()
	assert_true(_shell.try_camera_orbit(Vector2(80.0, 20.0)))
	assert_ne(_shell.map.camera_yaw_deg, PlaceholderSpec.CAMERA_YAW_DEG)
	assert_true(_shell.try_camera_pan(Vector2(40.0, 0.0)))
	assert_gt(_shell.map.camera_pan.length(), 0.0)
	assert_true(_shell.try_solo())
	assert_almost_eq(_shell.map.camera_yaw_deg, PlaceholderSpec.CAMERA_YAW_DEG, 0.0001)
	assert_almost_eq(_shell.map.camera_pitch_deg, PlaceholderSpec.CAMERA_PITCH_DEG, 0.0001)
	assert_eq(_shell.map.camera_pan, Vector3.ZERO)
	assert_almost_eq(_shell.map.camera_distance, PlaceholderSpec.CAMERA_DISTANCE, 0.0001)
	assert_false(_shell.try_camera_orbit(Vector2(80.0, 0.0)))
	assert_false(_shell.try_camera_pan(Vector2(40.0, 0.0)))
	assert_true(_shell.try_camera_zoom(-2))
	assert_gt(_shell.map.camera_distance, PlaceholderSpec.CAMERA_DISTANCE)


func test_settings_pickers_paint_status_and_buttons() -> void:
	_shell = _open()
	_shell.chrome.hud_settings.path = "user://hud_settings_window_%s.json" % str(Time.get_ticks_usec())
	assert_true(_shell.try_open_settings())
	assert_not_null(_shell.settings.text_picker)
	assert_not_null(_shell.settings.button_picker)
	var painted: Color = Color(0.2, 0.3, 0.4, 1.0)
	_shell.settings._on_text_color(painted)
	var status: Label = _shell.window.get_node("VBoxContainer/%s" % MatchLobbyChromeGd.STATUS_NAME) as Label
	assert_eq(status.get_theme_color("font_color"), painted)
	var button_color: Color = Color(0.1, 0.5, 0.2, 1.0)
	_shell.settings._on_button_color(button_color)
	var quick: Button = _shell.window.get_node(
		"VBoxContainer/MatchActions/%s" % MatchLobbyChromeGd.QUICK_NAME
	) as Button
	assert_eq(quick.get_theme_color("font_color"), button_color)
	assert_true(_shell.try_close_settings())
	var raw: String = FileAccess.get_file_as_string(_shell.chrome.hud_settings.path)
	assert_true(raw.contains(painted.to_html(false)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_shell.chrome.hud_settings.path))


func test_hud_settings_load_falls_back_on_garbage() -> void:
	var settings: HudSettingsGd = HudSettingsGd.new()
	settings.path = "user://hud_settings_garbage_%s.json" % str(Time.get_ticks_usec())
	var file: FileAccess = FileAccess.open(settings.path, FileAccess.WRITE)
	file.store_string("{not-json")
	file.close()
	settings.load_or_default()
	assert_eq(settings.text_color, PlaceholderSpec.HUD_TEXT_COLOR)
	assert_eq(settings.button_color, PlaceholderSpec.BUTTON_FONT_COLOR)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.path))


func _open() -> MatchLobbyShellGd:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	add_child(shell)
	shell.chrome.hud_settings.path = "user://hud_settings_chrome_hud_%s.json" % str(Time.get_ticks_usec())
	assert_true(shell.open())
	return shell
