class_name AudioSettingsEntry
extends Node

## Lobby settings window: five bus sliders + mute. Close applies and
## persists through AudioService. No locale hot-switch, no graphics.

const AudioServiceGd := preload("res://src/audio/audio_service.gd")
const AudioSettingsGd := preload("res://src/audio/audio_settings.gd")
const ClientAudioGd := preload("res://src/client/client_audio.gd")

const WINDOW_NAME: String = "SettingsWindow"
const MUTE_NAME: String = "AudioMute"
const CLOSE_NAME: String = "SettingsClose"
const SLIDER_PREFIX: String = "Bus_"

var window: Window = null
var mute_box: CheckBox = null
var lobby_window: Window = null
var _sliders: Dictionary = {}


static func ensure(shell: MatchLobbyShell, existing: AudioSettingsEntry) -> AudioSettingsEntry:
	if existing != null:
		return existing
	var entry := new()
	entry.lobby_window = shell.window
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
	window.size = Vector2i(520, 420)
	window.min_size = Vector2i(400, 320)
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


func _refresh() -> void:
	var svc: AudioServiceGd = ClientAudioGd.service
	if svc == null:
		return
	if mute_box != null:
		mute_box.set_pressed_no_signal(svc.settings.muted)
	for bus: String in AudioSettingsGd.BUSES:
		if not _sliders.has(bus):
			continue
		var slider: HSlider = _sliders[bus]
		slider.set_value_no_signal(svc.settings.get_bus_db(bus))


func _on_bus(value: float, bus: String) -> void:
	if ClientAudioGd.service == null:
		return
	ClientAudioGd.service.set_bus_db(bus, value)


func _on_mute(pressed: bool) -> void:
	if ClientAudioGd.service == null:
		return
	ClientAudioGd.service.set_muted(pressed)


func _persist() -> void:
	if ClientAudioGd.service == null:
		return
	ClientAudioGd.service.settings.save()


func _on_close() -> void:
	try_close()


func _set_lobby_visible(visible: bool) -> void:
	if lobby_window == null or not is_instance_valid(lobby_window):
		return
	lobby_window.visible = visible
