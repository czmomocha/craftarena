class_name AuthoringPreviewShellChrome
extends RefCounted

## Preview platform: code-created Window, Play HUD buttons, FOCUS_NONE.
## D4 UI baseline lives on the **main** window stretch. This embedded
## sub-window must not set `content_scale_*` (same reason as MatchLobbyChrome).

const TITLE: String = UiCopy.WINDOW_PREVIEW
const LayoutGd := preload("res://src/creator/authoring_window_layout.gd")
const WINDOW_SIZE: Vector2i = LayoutGd.FALLBACK_PANE_SIZE
const WINDOW_MIN_SIZE: Vector2i = LayoutGd.PANE_MIN_SIZE
const PLAY_NAME: String = "Play"
const STOP_NAME: String = "Stop"
const RESET_NAME: String = "Reset"
const USE_ITEM_NAME: String = "UseItem"
const SPRINT_NAME: String = "Sprint"
const JUMP_NAME: String = "Jump"
const ADVANCE_TICK_NAME: String = "AdvanceTick"
const AUTO_TICK_NAME: String = "AutoTick"
const STATUS_NAME: String = "Status"
const OVERLAY_NAME: String = "Overlay"
const PlayHudGd := preload("res://src/shared/play_hud_overlay.gd")

var window: Window = null
var status: Label = null
var play_hud: PlayHudGd = PlayHudGd.new()


func is_alive() -> bool:
	return window != null and is_instance_valid(window)


func is_visible() -> bool:
	return is_alive() and window.visible


func attach(parent: Node, handlers: Dictionary) -> Window:
	if is_alive():
		return window
	window = null
	status = null
	play_hud = PlayHudGd.new()
	var host_viewport: Viewport = parent.get_viewport()
	if host_viewport != null:
		host_viewport.gui_embed_subwindows = true
	window = Window.new()
	window.title = UiCopy.text(TITLE)
	window.exclusive = false
	window.transient = false
	window.own_world_3d = true
	var on_close: Callable = _handler(handlers, "close")
	if on_close.is_valid():
		window.close_requested.connect(on_close)
	var overlay: VBoxContainer = VBoxContainer.new()
	overlay.name = OVERLAY_NAME
	overlay.set_anchors_preset(Control.PRESET_TOP_WIDE)
	overlay.offset_left = 8
	overlay.offset_top = 8
	overlay.offset_right = -8
	window.add_child(overlay)
	status = Label.new()
	status.name = STATUS_NAME
	overlay.add_child(status)
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.name = "PlayActions"
	overlay.add_child(action_row)
	_add_button(action_row, PLAY_NAME, UiCopy.PLAY, _handler(handlers, "play"))
	_add_button(action_row, STOP_NAME, UiCopy.STOP, _handler(handlers, "stop"))
	_add_button(action_row, RESET_NAME, UiCopy.RESET, _handler(handlers, "reset"))
	_add_button(action_row, USE_ITEM_NAME, UiCopy.USE_ITEM, _handler(handlers, "use_item"))
	_add_button(action_row, SPRINT_NAME, UiCopy.SPRINT, _handler(handlers, "sprint"))
	_add_button(action_row, JUMP_NAME, UiCopy.JUMP, _handler(handlers, "jump"))
	_add_button(action_row, ADVANCE_TICK_NAME, UiCopy.ADVANCE_TICK, _handler(handlers, "advance"))
	_add_auto_tick(action_row, _handler(handlers, "auto_tick"))
	play_hud.attach(window, overlay)
	LayoutGd.apply_preview(window, parent)
	return window


func raise_window() -> bool:
	if not is_alive():
		return false
	LayoutGd.apply_preview(window, window.get_parent())
	window.visible = true
	if window.is_inside_tree():
		window.grab_focus()
	return true


func hide_window() -> void:
	if is_alive():
		window.visible = false


func set_status_text(text: String) -> void:
	if status != null and is_instance_valid(status):
		status.text = text


func status_text() -> String:
	if status == null or not is_instance_valid(status):
		return ""
	return status.text


func sync_play_hud(view: Dictionary) -> void:
	play_hud.apply(view)


func clock_text() -> String:
	return play_hud.clock_text()


func settlement_visible() -> bool:
	return play_hud.settlement_visible()


func release_focus() -> void:
	if is_alive():
		window.gui_release_focus()


func _handler(handlers: Dictionary, key: String) -> Callable:
	var raw: Variant = handlers.get(key, Callable())
	if typeof(raw) != TYPE_CALLABLE:
		return Callable()
	var handler: Callable = raw
	return handler


func auto_tick_button() -> CheckButton:
	if not is_alive():
		return null
	return window.get_node_or_null("%s/PlayActions/%s" % [OVERLAY_NAME, AUTO_TICK_NAME]) as CheckButton


## 「自动推进」。默认开：`Advance tick` 那颗按钮是给单步调试用的，让外人靠点它
## 走完一张课不是试玩，是折磨。默认连续跑，需要逐拍看时再关掉。
func _add_auto_tick(row: BoxContainer, handler: Callable) -> void:
	var toggle: CheckButton = CheckButton.new()
	toggle.name = AUTO_TICK_NAME
	toggle.text = UiCopy.text(UiCopy.AUTO_TICK)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.button_pressed = true
	if handler.is_valid():
		toggle.toggled.connect(handler)
	row.add_child(toggle)


func _add_button(row: BoxContainer, node_name: String, copy_key: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = UiCopy.text(copy_key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	if handler.is_valid():
		button.pressed.connect(handler)
	row.add_child(button)
