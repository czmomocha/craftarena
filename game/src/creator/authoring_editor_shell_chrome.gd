class_name AuthoringEditorShellChrome
extends RefCounted

## Editor platform: code-created Window, tool strip, validator, status.
## D4 UI baseline lives on the **main** window stretch. This embedded
## sub-window must not set `content_scale_*` (same reason as MatchLobbyChrome).

const WINDOW_SIZE: Vector2i = Vector2i(640, 560)
const STATUS_NAME: String = "Status"
const MAP_NAME: String = "EditorMap"
const TOOLS_NAME: String = "TraprushTools"
const VALIDATOR_NAME: String = "ValidatorDetails"
const UNDO_NAME: String = "Undo"
const REDO_NAME: String = "Redo"
const PREVIEW_NAME: String = "Preview"
const TraprushEditorPanelGd := preload("res://src/creator/traprush_editor_panel.gd")
const AuthoringValidatorPanelGd := preload("res://src/creator/authoring_validator_panel.gd")

var window: Window = null
var status: Label = null
var tools: TraprushEditorPanelGd = null
var validator: AuthoringValidatorPanelGd = null
var map: AuthoringPreviewMap = null


func is_alive() -> bool:
	return window != null and is_instance_valid(window)


func is_visible() -> bool:
	return is_alive() and window.visible


func ensure(shell: AuthoringEditorShell, handlers: Dictionary) -> void:
	if is_alive():
		_sync_shell(shell)
		return
	if not Engine.is_editor_hint():
		var host_viewport: Viewport = shell.get_viewport()
		if host_viewport != null:
			host_viewport.gui_embed_subwindows = true
	window = Window.new()
	window.title = UiCopy.text(AuthoringEditorShell.TITLE)
	window.size = WINDOW_SIZE
	window.exclusive = false
	window.transient = false
	window.own_world_3d = true
	var on_close: Callable = _handler(handlers, "close")
	if on_close.is_valid():
		window.close_requested.connect(on_close)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	window.add_child(root)
	status = Label.new()
	status.name = STATUS_NAME
	root.add_child(status)
	tools = TraprushEditorPanelGd.new()
	tools.name = TOOLS_NAME
	root.add_child(tools)
	tools.mount(shell)
	validator = AuthoringValidatorPanelGd.new()
	validator.name = VALIDATOR_NAME
	root.add_child(validator)
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.name = "SharedActions"
	root.add_child(action_row)
	_add_button(action_row, UNDO_NAME, UiCopy.UNDO, _handler(handlers, "undo"))
	_add_button(action_row, REDO_NAME, UiCopy.REDO, _handler(handlers, "redo"))
	_add_button(action_row, PREVIEW_NAME, UiCopy.PREVIEW, _handler(handlers, "preview"))
	map = AuthoringPreviewMap.new()
	map.name = MAP_NAME
	window.add_child(map)
	shell.add_child(window)
	map.ensure_rig()
	if validator != null:
		validator.mount(map)
	_sync_shell(shell)


func hide_window() -> void:
	if is_alive():
		window.visible = false


func raise_window() -> bool:
	if not is_alive():
		return false
	window.visible = true
	return true


func set_status_text(text: String) -> void:
	if status != null and is_instance_valid(status):
		status.text = text


func status_text() -> String:
	if status == null or not is_instance_valid(status):
		return ""
	return status.text


func format_line(shell: AuthoringEditorShell) -> String:
	if shell.session == null or shell.session.world == null:
		return ""
	var floor_index: int = 0
	if tools != null:
		floor_index = tools.floor_index
	var reach_ok_flag: bool = true
	var issue_n: int = 0
	if validator != null:
		reach_ok_flag = validator.reach_ok()
		issue_n = validator.issue_count()
	return "%s revision=%d entities=%d floor=%d undo=%s redo=%s reach_ok=%s issues=%d draft=%s disk=%s follow=%s" % [
		shell.surface,
		shell.session.world.revision,
		shell.session.world.entity_count(),
		floor_index,
		str(shell.session.can_undo()),
		str(shell.session.can_redo()),
		str(reach_ok_flag),
		issue_n,
		str(shell.draft_store != null),
		str(shell.last_draft_ok),
		str(shell.preview_follows),
	]


func _sync_shell(shell: AuthoringEditorShell) -> void:
	shell.window = window
	shell.tools = tools
	shell.validator = validator
	shell.map = map


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
	if handler.is_valid():
		button.pressed.connect(handler)
	row.add_child(button)
