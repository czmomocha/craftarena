class_name MatchLobbyChrome
extends RefCounted

## L4 platform: code-created lobby Window, HUD widgets, focus.
## D4 UI baseline lives on the **main** window stretch. This embedded
## sub-window must not set `content_scale_*` (`gui_embed_subwindows = true`
## applies scale on the input path only — 4K measured hit offset).

const FrameRateMeterGd := preload("res://src/client/frame_rate_meter.gd")
const MatchLobbyCourseSelectGd := preload("res://src/client/match_lobby_course_select.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const ServerEndpointGd := preload("res://src/client/server_endpoint.gd")
const ClientAudioGd := preload("res://src/client/client_audio.gd")

const TITLE: String = UiCopy.WINDOW_TRAPRUSH
const WINDOW_SIZE: Vector2i = PlaceholderSpec.UI_BASE_SIZE
const WINDOW_MIN_SIZE: Vector2i = Vector2i(1280, 720)
const HOME_NAME: String = "BackHome"
const QUICK_NAME: String = "QuickPlay"
const CREATE_NAME: String = "CreateRoom"
const JOIN_NAME: String = "JoinRoom"
const CANCEL_NAME: String = "Cancel"
const SOLO_NAME: String = "SoloPlay"
const POLL_NAME: String = "Poll"
const SPRINT_NAME: String = "Sprint"
const CREATOR_NAME: String = "CreateCourse"
const PLAZA_NAME: String = "ContentPlaza"
const ACCOUNT_NAME: String = "Account"
const SETTINGS_NAME: String = "Settings"
const ROOM_NAME: String = "RoomCode"
const COURSE_ID_NAME: String = "CourseId"
const SEATS_NAME: String = "Seats"
const INVITE_NAME: String = "Invite"
const COPY_INVITE_NAME: String = "CopyInvite"
const SERVER_NAME: String = "ServerHost"
const APPLY_SERVER_NAME: String = "ApplyServer"
const FPS_NAME: String = "Fps"
const STATUS_NAME: String = "Status"
const OverlayGd := preload("res://src/shared/play_hud_overlay.gd")
const MatchInviteGd := preload("res://src/client/match_invite.gd")

var window: Window = null
var frame_rate: FrameRateMeterGd = null
var status: Label = null
var room_edit: LineEdit = null
var course_select: MatchLobbyCourseSelectGd = null
var seats_edit: LineEdit = null
var invite_edit: LineEdit = null
var server_edit: LineEdit = null
var play_hud: OverlayGd = OverlayGd.new()
var _on_camera_zoom: Callable = Callable()
var _on_camera_pan: Callable = Callable()
var _on_pick: Callable = Callable()
var _on_play_key: Callable = Callable()


func attach(parent: Node, handlers: Dictionary) -> Window:
	if window != null:
		return window
	_on_camera_zoom = _handler(handlers, "camera_zoom")
	_on_camera_pan = _handler(handlers, "camera_pan")
	_on_pick = _handler(handlers, "pick")
	_on_play_key = _handler(handlers, "play_key")
	if not Engine.is_editor_hint():
		var host_viewport: Viewport = parent.get_viewport()
		if host_viewport != null:
			host_viewport.gui_embed_subwindows = true
	window = Window.new()
	window.title = UiCopy.text(TITLE)
	window.size = WINDOW_SIZE
	window.min_size = WINDOW_MIN_SIZE
	window.mode = Window.MODE_WINDOWED
	window.exclusive = false
	window.transient = false
	window.own_world_3d = true
	var on_close: Callable = _handler(handlers, "close")
	if on_close.is_valid():
		window.close_requested.connect(on_close)
	var on_input: Callable = _handler(handlers, "window_input")
	if on_input.is_valid():
		window.window_input.connect(on_input)
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "VBoxContainer"
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	window.add_child(root)
	frame_rate = FrameRateMeterGd.new()
	frame_rate.name = FPS_NAME
	frame_rate.add_theme_font_size_override("font_size", PlaceholderSpec.HUD_STATUS_FONT_SIZE)
	root.add_child(frame_rate)
	status = Label.new()
	status.name = STATUS_NAME
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", PlaceholderSpec.HUD_STATUS_FONT_SIZE)
	root.add_child(status)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "MatchActions"
	root.add_child(row)
	var on_quick: Callable = _handler(handlers, "quick")
	var on_create: Callable = _handler(handlers, "create")
	var on_join: Callable = _handler(handlers, "join")
	var on_solo: Callable = _handler(handlers, "solo")
	var on_cancel: Callable = _handler(handlers, "cancel")
	var on_poll: Callable = _handler(handlers, "poll")
	var on_sprint: Callable = _handler(handlers, "sprint")
	var on_home: Callable = _handler(handlers, "home")
	_add_button(row, HOME_NAME, UiCopy.BACK_TO_LOBBY, on_home)
	_add_button(row, QUICK_NAME, UiCopy.QUICK_PLAY, on_quick)
	_add_button(row, CREATE_NAME, UiCopy.CREATE_ROOM, on_create)
	_add_button(row, JOIN_NAME, UiCopy.JOIN_ROOM, on_join)
	_add_button(row, SOLO_NAME, UiCopy.SOLO_PLAY, on_solo)
	_add_button(row, CANCEL_NAME, UiCopy.CANCEL, on_cancel)
	_add_button(row, POLL_NAME, UiCopy.POLL, on_poll)
	_add_button(row, SPRINT_NAME, UiCopy.SPRINT, on_sprint)
	# 「创作课程」与「单人试玩」并排，不藏进二级菜单：拿到链接的人要能在同一屏
	# 上看见「能玩」和「能做」两件事，那正是 Web 轻量 Edit 要补的那个洞。
	_add_button(row, CREATOR_NAME, UiCopy.CREATE_COURSE, _handler(handlers, "creator"))
	_add_button(row, PLAZA_NAME, UiCopy.PLAZA, _handler(handlers, "plaza"))
	_add_button(row, ACCOUNT_NAME, UiCopy.ACCOUNT, _handler(handlers, "account"))
	_add_button(row, SETTINGS_NAME, UiCopy.SETTINGS, _handler(handlers, "settings"))
	var server_row: HBoxContainer = HBoxContainer.new()
	server_row.name = "ServerActions"
	root.add_child(server_row)
	var on_submit: Callable = _handler(handlers, "edit_submitted")
	server_edit = _make_edit(SERVER_NAME, UiCopy.text(UiCopy.SERVER_HOST), 64, "", on_submit)
	server_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_row.add_child(server_edit)
	var on_apply: Callable = _handler(handlers, "apply_server")
	_add_button(server_row, APPLY_SERVER_NAME, UiCopy.APPLY_SERVER, on_apply)
	room_edit = _make_edit(ROOM_NAME, UiCopy.text(UiCopy.ROOM_CODE), 6, "", on_submit)
	root.add_child(room_edit)
	course_select = MatchLobbyCourseSelectGd.new()
	course_select.setup(_handler(handlers, "course_selected"))
	root.add_child(course_select)
	seats_edit = _make_edit(
		SEATS_NAME,
		str(OfficialTraprushCoursesGd.DEFAULT_SEATS),
		1,
		str(OfficialTraprushCoursesGd.DEFAULT_SEATS),
		on_submit
	)
	root.add_child(seats_edit)
	var invite_row: HBoxContainer = HBoxContainer.new()
	invite_row.name = "InviteActions"
	root.add_child(invite_row)
	invite_edit = _make_edit(INVITE_NAME, "", 80, "", Callable())
	invite_edit.editable = false
	invite_edit.focus_mode = Control.FOCUS_NONE
	invite_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invite_row.add_child(invite_edit)
	_add_button(invite_row, COPY_INVITE_NAME, UiCopy.COPY_INVITE, _handler(handlers, "copy_invite"))
	play_hud.attach(window, root)
	return window


func is_visible() -> bool:
	return window != null and window.visible


func show_window() -> void:
	if window != null:
		window.visible = true


func hide_window() -> void:
	if window != null:
		window.visible = false


func room_code_text() -> String:
	if room_edit == null:
		return ""
	return room_edit.text


func set_room_code_text(text: String) -> void:
	if room_edit != null:
		room_edit.text = text


func course_id_text(fallback: String) -> String:
	if course_select == null:
		return fallback
	return course_select.selected_id(fallback)


func set_course_id_text(text: String) -> void:
	if course_select != null:
		course_select.set_selected_id(text)


func seats_text() -> String:
	if seats_edit == null:
		return str(OfficialTraprushCoursesGd.DEFAULT_SEATS)
	return seats_edit.text


func set_seats_text(text: String) -> void:
	if seats_edit != null:
		seats_edit.text = text


func server_host_text(fallback: String) -> String:
	if server_edit == null:
		return fallback
	return server_edit.text


func set_server_host_text(text: String) -> void:
	if server_edit != null:
		server_edit.text = text


func sync_server_edit(control_plane_base: String) -> void:
	if server_edit == null:
		return
	server_edit.text = ServerEndpointGd.host_port_of(control_plane_base)


func set_status_text(text: String) -> void:
	if status != null:
		status.text = text


func status_text() -> String:
	if status == null:
		return ""
	return status.text


func fps_text() -> String:
	if frame_rate == null:
		return ""
	return frame_rate.fps_text()


func sync_play_hud(view: Dictionary) -> void:
	play_hud.apply(view)
	sync_invite(view)


func sync_invite(view: Dictionary) -> void:
	if invite_edit == null:
		return
	var room: String = str(view.get("room_code", ""))
	if OS.has_feature("web"):
		invite_edit.text = MatchInviteGd.web_query(room)
	else:
		invite_edit.text = MatchInviteGd.desktop_text(
			str(view.get("server_host", "")),
			room
		)


func try_copy_invite() -> bool:
	if invite_edit == null or invite_edit.text == "":
		return false
	DisplayServer.clipboard_set(invite_edit.text)
	return true


func clock_text() -> String:
	return play_hud.clock_text()


func split_text() -> String:
	return play_hud.split_text()


func guide_text() -> String:
	return play_hud.guide_text()


func setback_text() -> String:
	return play_hud.setback_text()


func settlement_visible() -> bool:
	return play_hud.settlement_visible()


func handle_window_input(event: InputEvent) -> void:
	if window == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if key.pressed and not key.echo and _on_play_key.is_valid():
			_on_play_key.call(key.keycode)
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null:
		_handle_mouse_button(mouse)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_handle_mouse_motion(motion)


func _handle_mouse_button(mouse: InputEventMouseButton) -> void:
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP or mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not mouse.pressed:
			return
		if click_hits_line_edit(mouse.position):
			return
		var steps: int = 1 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else -1
		if _on_camera_zoom.is_valid():
			_on_camera_zoom.call(steps)
		return
	if not mouse.pressed:
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT and mouse.button_index != MOUSE_BUTTON_RIGHT:
		return
	if click_hits_line_edit(mouse.position):
		return
	release_focus()
	if mouse.button_index == MOUSE_BUTTON_LEFT and _on_pick.is_valid():
		_on_pick.call(mouse.position)


func _handle_mouse_motion(motion: InputEventMouseMotion) -> void:
	if (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) == 0:
		return
	if click_hits_line_edit(motion.position):
		return
	if _on_camera_pan.is_valid():
		_on_camera_pan.call(motion.relative)


func click_hits_line_edit(point: Vector2) -> bool:
	for edit: LineEdit in [server_edit, room_edit, seats_edit, invite_edit]:
		if edit == null:
			continue
		if edit.get_global_rect().has_point(point):
			return true
	return course_select != null and course_select.hits(point)


func edit_has_focus() -> bool:
	if window == null:
		return false
	var owner: Control = window.gui_get_focus_owner()
	return owner is LineEdit or owner is OptionButton


func release_focus() -> void:
	if window == null:
		return
	window.gui_release_focus()


func _handler(handlers: Dictionary, key: String) -> Callable:
	var raw: Variant = handlers.get(key, Callable())
	if typeof(raw) != TYPE_CALLABLE:
		return Callable()
	var handler: Callable = raw
	return handler


func _add_button(row: BoxContainer, node_name: String, copy_key: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = UiCopy.text(copy_key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	if handler.is_valid():
		button.pressed.connect(func() -> void:
			ClientAudioGd.post_ui_confirm()
			handler.call()
		)
	row.add_child(button)


func _make_edit(
	node_name: String,
	placeholder: String,
	max_length: int,
	text: String,
	on_submit: Callable
) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.name = node_name
	edit.placeholder_text = placeholder
	edit.max_length = max_length
	edit.focus_mode = Control.FOCUS_CLICK
	if text != "":
		edit.text = text
	if on_submit.is_valid():
		edit.text_submitted.connect(on_submit)
	return edit
