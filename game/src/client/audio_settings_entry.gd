class_name AudioSettingsEntry
extends Node

## Lobby settings window: five bus sliders + mute + HUD / button colours
## + Solo ghost chase. Close applies and persists through AudioService,
## HudSettings, and TraprushGhostSettings.
## No locale hot-switch, no graphics quality, no keybinds.

const AudioServiceGd := preload("res://src/audio/audio_service.gd")
const AudioSettingsGd := preload("res://src/audio/audio_settings.gd")
const ClientAudioGd := preload("res://src/client/client_audio.gd")
const MatchLobbyHomeGd := preload("res://src/client/match_lobby_home.gd")
const HudSettingsGd := preload("res://src/client/hud_settings.gd")
const UiCopyPlayGd := preload("res://src/shared/ui_copy_play.gd")

const WINDOW_NAME: String = "SettingsWindow"
const MUTE_NAME: String = "AudioMute"
const GHOST_NAME: String = "GhostChase"
const CLOSE_NAME: String = "SettingsClose"
const TEXT_COLOR_NAME: String = "HudTextColor"
const BUTTON_COLOR_NAME: String = "ButtonFontColor"
const SLIDER_PREFIX: String = "Bus_"

var window: Window = null
var mute_box: CheckBox = null
var ghost_box: CheckBox = null
var lobby_window: Window = null
var host: MatchLobbyShell = null
var _sliders: Dictionary = {}
var text_picker: ColorPickerButton = null
var button_picker: ColorPickerButton = null


static func ensure(shell: MatchLobbyShell, existing: AudioSettingsEntry) -> AudioSettingsEntry:
	if existing != null:
		return existing
	var entry := new()
	entry.lobby_window = shell.window
	entry.host = shell
	shell.add_child(entry)
	return entry


func is_open() -> bool:
	return window != null and window.visible


func try_open() -> bool:
	_ensure_window()
	if window == null:
		return false
	_refresh()
	window.visible = true
	_set_lobby_visible(false)
	return true


func try_close() -> bool:
	var lobby_hidden: bool = (
		lobby_window != null and is_instance_valid(lobby_window) and not lobby_window.visible
	)
	if not is_open() and not lobby_hidden:
		return false
	_persist()
	if window != null:
		window.visible = false
	_set_lobby_visible(true)
	return true


func _ensure_window() -> void:
	if window != null:
		return
	window = Window.new()
	window.name = WINDOW_NAME
	window.title = UiCopy.text(UiCopy.WINDOW_SETTINGS)
	window.size = Vector2i(520, 560)
	window.min_size = Vector2i(400, 440)
	window.exclusive = false
	window.transient = false
	window.close_requested.connect(_on_close)
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "VBoxContainer"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	window.add_child(root)
	mute_box = CheckBox.new()
	mute_box.name = MUTE_NAME
	mute_box.text = UiCopy.text(UiCopy.AUDIO_MUTE)
	mute_box.focus_mode = Control.FOCUS_CLICK
	mute_box.toggled.connect(_on_mute)
	root.add_child(mute_box)
	_add_slider(root, AudioSettingsGd.BUS_MASTER, UiCopy.AUDIO_MASTER)
	_add_slider(root, AudioSettingsGd.BUS_MUSIC, UiCopy.AUDIO_MUSIC)
	_add_slider(root, AudioSettingsGd.BUS_SFX, UiCopy.AUDIO_SFX)
	_add_slider(root, AudioSettingsGd.BUS_UI, UiCopy.AUDIO_UI)
	_add_slider(root, AudioSettingsGd.BUS_AMBIENCE, UiCopy.AUDIO_AMBIENCE)
	text_picker = _add_color(root, TEXT_COLOR_NAME, UiCopy.HUD_TEXT_COLOR, _on_text_color)
	button_picker = _add_color(root, BUTTON_COLOR_NAME, UiCopy.BUTTON_FONT_COLOR, _on_button_color)
	ghost_box = CheckBox.new()
	ghost_box.name = GHOST_NAME
	ghost_box.text = UiCopy.text(UiCopyPlayGd.GHOST_CHASE)
	ghost_box.focus_mode = Control.FOCUS_CLICK
	ghost_box.toggled.connect(_on_ghost)
	root.add_child(ghost_box)
	var close_btn: Button = Button.new()
	close_btn.name = CLOSE_NAME
	close_btn.text = UiCopy.text(UiCopy.BACK_TO_LOBBY)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(try_close)
	root.add_child(close_btn)
	add_child(window)


func _add_slider(root: BoxContainer, bus: String, copy_key: String) -> void:
	var label: Label = Label.new()
	label.name = "%sLabel" % bus
	label.text = UiCopy.text(copy_key)
	root.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.name = "%s%s" % [SLIDER_PREFIX, bus]
	slider.min_value = AudioSettingsGd.DB_MIN
	slider.max_value = AudioSettingsGd.DB_MAX
	slider.step = 0.5
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_bus.bind(bus))
	root.add_child(slider)
	_sliders[bus] = slider


func _add_color(root: BoxContainer, node_name: String, copy_key: String, handler: Callable) -> ColorPickerButton:
	var label: Label = Label.new()
	label.name = "%sLabel" % node_name
	label.text = UiCopy.text(copy_key)
	root.add_child(label)
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.name = node_name
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(72, 28)
	picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picker.color_changed.connect(handler)
	root.add_child(picker)
	return picker


func _refresh() -> void:
	var svc: AudioServiceGd = ClientAudioGd.service
	if mute_box != null and svc != null:
		mute_box.set_pressed_no_signal(svc.settings.muted)
	if ghost_box != null and host != null and host.offline != null:
		ghost_box.set_pressed_no_signal(host.offline.ghost_settings.enabled)
	if svc != null:
		for bus: String in AudioSettingsGd.BUSES:
			if not _sliders.has(bus):
				continue
			var slider: HSlider = _sliders[bus]
			slider.set_value_no_signal(svc.settings.get_bus_db(bus))
	if host != null and host.chrome != null:
		var hud: HudSettingsGd = host.chrome.hud_settings
		if text_picker != null:
			text_picker.color = hud.text_color
		if button_picker != null:
			button_picker.color = hud.button_color


func _on_bus(value: float, bus: String) -> void:
	if ClientAudioGd.service == null:
		return
	ClientAudioGd.service.set_bus_db(bus, value)


func _on_mute(pressed: bool) -> void:
	if ClientAudioGd.service == null:
		return
	ClientAudioGd.service.set_muted(pressed)


func _on_ghost(pressed: bool) -> void:
	if host == null or host.offline == null:
		return
	host.offline.ghost_settings.enabled = pressed


func _on_text_color(color: Color) -> void:
	if host == null or host.chrome == null:
		return
	host.chrome.hud_settings.text_color = color
	host.chrome.apply_colors()


func _on_button_color(color: Color) -> void:
	if host == null or host.chrome == null:
		return
	host.chrome.hud_settings.button_color = color
	host.chrome.apply_colors()


func _persist() -> void:
	if ClientAudioGd.service != null:
		ClientAudioGd.service.settings.save()
	if host != null and host.chrome != null:
		host.chrome.hud_settings.save()
	if ghost_box != null and host != null and host.offline != null:
		host.offline.ghost_settings.enabled = ghost_box.button_pressed
		host.offline.ghost_settings.save()


func _on_close() -> void:
	try_close()


func _set_lobby_visible(visible: bool) -> void:
	if host != null:
		MatchLobbyHomeGd.set_lobby_visible(host, visible)
		return
	if lobby_window == null or not is_instance_valid(lobby_window):
		return
	lobby_window.visible = visible
