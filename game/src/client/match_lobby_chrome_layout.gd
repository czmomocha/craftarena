class_name MatchLobbyChromeLayout
extends RefCounted

## Compact lobby fields + overlay docking + chrome colours, kept off
## MatchLobbyChrome so that file stays under E9.

const CourseSelectGd := preload("res://src/client/match_lobby_course_select.gd")
const FIELDS_NAME: String = "LobbyFields"


static func dock_fps(meter: Label, window: Window) -> void:
	if meter == null or window == null:
		return
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	meter.offset_left = 8.0
	meter.offset_top = -28.0
	meter.offset_right = 160.0
	meter.offset_bottom = -8.0
	meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	meter.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var parent: Node = meter.get_parent()
	if parent == window:
		return
	if parent != null:
		parent.remove_child(meter)
	window.add_child(meter)


static func build_fields(
	chrome: MatchLobbyChrome,
	root: BoxContainer,
	handlers: Dictionary,
	on_submit: Callable
) -> void:
	var fields: HBoxContainer = HBoxContainer.new()
	fields.name = FIELDS_NAME
	fields.add_theme_constant_override("separation", 6)
	root.add_child(fields)
	var server_row: HBoxContainer = HBoxContainer.new()
	server_row.name = "ServerActions"
	fields.add_child(server_row)
	chrome.server_edit = chrome._make_edit(
		MatchLobbyChrome.SERVER_NAME,
		UiCopy.text(UiCopy.SERVER_HOST),
		64,
		"",
		on_submit
	)
	chrome.server_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chrome.server_edit.custom_minimum_size = Vector2(112, 0)
	server_row.add_child(chrome.server_edit)
	chrome._add_button(
		server_row,
		MatchLobbyChrome.APPLY_SERVER_NAME,
		UiCopy.APPLY_SERVER,
		chrome._handler(handlers, "apply_server"),
		false
	)
	chrome.room_edit = chrome._make_edit(
		MatchLobbyChrome.ROOM_NAME,
		UiCopy.text(UiCopy.ROOM_CODE),
		6,
		"",
		on_submit
	)
	chrome.room_edit.custom_minimum_size = Vector2(88, 0)
	chrome.room_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fields.add_child(chrome.room_edit)
	chrome.course_select = CourseSelectGd.new()
	chrome.course_select.setup(chrome._handler(handlers, "course_selected"))
	chrome.course_select.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chrome.course_select.custom_minimum_size = Vector2(168, 0)
	fields.add_child(chrome.course_select)
	chrome.seats_edit = chrome._make_edit(
		MatchLobbyChrome.SEATS_NAME,
		str(OfficialTraprushCourses.DEFAULT_SEATS),
		1,
		str(OfficialTraprushCourses.DEFAULT_SEATS),
		on_submit
	)
	chrome.seats_edit.custom_minimum_size = Vector2(40, 0)
	chrome.seats_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fields.add_child(chrome.seats_edit)
	var invite_row: HBoxContainer = HBoxContainer.new()
	invite_row.name = "InviteActions"
	invite_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(invite_row)
	chrome.invite_edit = chrome._make_edit(MatchLobbyChrome.INVITE_NAME, "", 80, "", Callable())
	chrome.invite_edit.editable = false
	chrome.invite_edit.focus_mode = Control.FOCUS_NONE
	chrome.invite_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invite_row.add_child(chrome.invite_edit)
	chrome._add_button(
		invite_row,
		MatchLobbyChrome.COPY_INVITE_NAME,
		UiCopy.COPY_INVITE,
		chrome._handler(handlers, "copy_invite"),
		false
	)


static func apply_colors(chrome: MatchLobbyChrome) -> void:
	if chrome == null or chrome.hud_settings == null:
		return
	var text: Color = chrome.hud_settings.text_color
	var button: Color = chrome.hud_settings.button_color
	_paint_label(chrome.status, text)
	_paint_label(chrome.frame_rate, text)
	chrome.play_hud.apply_text_color(text)
	if chrome.window != null:
		_paint_buttons(chrome.window, button)


static func _paint_label(label: Label, color: Color) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)


static func _paint_buttons(node: Node, color: Color) -> void:
	if node is Button:
		var button: Button = node
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", color)
		button.add_theme_color_override("font_pressed_color", color)
		button.add_theme_color_override("font_focus_color", color)
		button.add_theme_color_override("font_hover_pressed_color", color)
	for child: Node in node.get_children():
		_paint_buttons(child, color)
