class_name MatchLobbyChrome
extends RefCounted

## L4 platform: code-created lobby Window, HUD widgets, focus.
## D4 UI baseline lives on the **main** window stretch. This embedded
## sub-window must not set `content_scale_*` (`gui_embed_subwindows = true`
## applies scale on the input path only — 4K measured hit offset).

const FrameRateMeterGd := preload("res://src/client/frame_rate_meter.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const ServerEndpointGd := preload("res://src/client/server_endpoint.gd")

const TITLE: String = UiCopy.WINDOW_TRAPRUSH
const WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
const WINDOW_MIN_SIZE: Vector2i = Vector2i(960, 540)
const QUICK_NAME: String = "QuickPlay"
const CREATE_NAME: String = "CreateRoom"
const JOIN_NAME: String = "JoinRoom"
const CANCEL_NAME: String = "Cancel"
const SOLO_NAME: String = "SoloPlay"
const POLL_NAME: String = "Poll"
const SPRINT_NAME: String = "Sprint"
const ROOM_NAME: String = "RoomCode"
const COURSE_ID_NAME: String = "CourseId"
const SEATS_NAME: String = "Seats"
const SERVER_NAME: String = "ServerHost"
const APPLY_SERVER_NAME: String = "ApplyServer"
const FPS_NAME: String = "Fps"
const STATUS_NAME: String = "Status"

var window: Window = null
var frame_rate: FrameRateMeterGd = null
var status: Label = null
var room_edit: LineEdit = null
var course_edit: LineEdit = null
var seats_edit: LineEdit = null
var server_edit: LineEdit = null


func attach(parent: Node, handlers: Dictionary) -> Window:
	if window != null:
		return window
	if not Engine.is_editor_hint():
		var host_viewport: Viewport = parent.get_viewport()
		if host_viewport != null:
			host_viewport.gui_embed_subwindows = true
	window = Window.new()
	window.title = UiCopy.text(TITLE)
	window.size = WINDOW_SIZE
	window.min_size = WINDOW_MIN_SIZE
	window.mode = Window.MODE_MAXIMIZED
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
	root.add_child(frame_rate)
	status = Label.new()
	status.name = STATUS_NAME
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_add_button(row, QUICK_NAME, UiCopy.QUICK_PLAY, on_quick)
	_add_button(row, CREATE_NAME, UiCopy.CREATE_ROOM, on_create)
	_add_button(row, JOIN_NAME, UiCopy.JOIN_ROOM, on_join)
	_add_button(row, SOLO_NAME, UiCopy.SOLO_PLAY, on_solo)
	_add_button(row, CANCEL_NAME, UiCopy.CANCEL, on_cancel)
	_add_button(row, POLL_NAME, UiCopy.POLL, on_poll)
	_add_button(row, SPRINT_NAME, UiCopy.SPRINT, on_sprint)
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
	course_edit = _make_edit(
		COURSE_ID_NAME,
		OfficialTraprushCoursesGd.DEFAULT_ID,
		32,
		OfficialTraprushCoursesGd.DEFAULT_ID,
		on_submit
	)
	root.add_child(course_edit)
	seats_edit = _make_edit(
		SEATS_NAME,
		str(OfficialTraprushCoursesGd.DEFAULT_SEATS),
		1,
		str(OfficialTraprushCoursesGd.DEFAULT_SEATS),
		on_submit
	)
	root.add_child(seats_edit)
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
	if course_edit == null:
		return fallback
	return course_edit.text


func set_course_id_text(text: String) -> void:
	if course_edit != null:
		course_edit.text = text


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
	server_edit.text = ServerEndpointGd.host_of(control_plane_base)


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


func handle_window_input(event: InputEvent) -> void:
	if window == null:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT and mouse.button_index != MOUSE_BUTTON_RIGHT:
		return
	if click_hits_line_edit(mouse.position):
		return
	release_focus()


func click_hits_line_edit(point: Vector2) -> bool:
	for edit: LineEdit in [server_edit, room_edit, course_edit, seats_edit]:
		if edit == null:
			continue
		if edit.get_global_rect().has_point(point):
			return true
	return false


func edit_has_focus() -> bool:
	if window == null:
		return false
	return window.gui_get_focus_owner() is LineEdit


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
		button.pressed.connect(handler)
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
