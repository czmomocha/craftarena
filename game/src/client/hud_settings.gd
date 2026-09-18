class_name HudSettings
extends RefCounted

## Persistent HUD / button font colours. Defaults live on PlaceholderSpec.
## Missing or corrupt files fall back to those defaults. Never writes
## SimulationWorld / hash_state / protocol.

const PATH: String = "user://hud_settings.json"
const KEY_TEXT: String = "text_color"
const KEY_BUTTON: String = "button_color"

var path: String = PATH
var text_color: Color = PlaceholderSpec.HUD_TEXT_COLOR
var button_color: Color = PlaceholderSpec.BUTTON_FONT_COLOR


func _init() -> void:
	reset_defaults()


func reset_defaults() -> void:
	text_color = PlaceholderSpec.HUD_TEXT_COLOR
	button_color = PlaceholderSpec.BUTTON_FONT_COLOR


func load_or_default() -> void:
	reset_defaults()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		reset_defaults()
		return
	var parsed: Variant = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		reset_defaults()
		return
	var data: Dictionary = parsed
	text_color = _color_at(data, KEY_TEXT, PlaceholderSpec.HUD_TEXT_COLOR)
	button_color = _color_at(data, KEY_BUTTON, PlaceholderSpec.BUTTON_FONT_COLOR)


func save() -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		KEY_TEXT: text_color.to_html(false),
		KEY_BUTTON: button_color.to_html(false),
	}))
	return true


func _color_at(body: Dictionary, key: String, fallback: Color) -> Color:
	var raw: Variant = body.get(key, "")
	if typeof(raw) != TYPE_STRING:
		return fallback
	var html: String = raw
	if html == "":
		return fallback
	return Color.from_string(html, fallback)
