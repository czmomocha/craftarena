class_name TraprushGhostSettings
extends RefCounted

## Solo ghost chase toggle. Missing or corrupt file = enabled.

const PATH: String = "user://traprush_ghost_settings.json"
const KEY_ENABLED: String = "enabled"

var path: String = PATH
var enabled: bool = true


func _init() -> void:
	load_or_default()


func load_or_default() -> void:
	enabled = true
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		enabled = true
		return
	var body: Dictionary = parsed
	if not body.has(KEY_ENABLED) or typeof(body.get(KEY_ENABLED)) != TYPE_BOOL:
		enabled = true
		return
	enabled = body[KEY_ENABLED] == true


func save() -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({KEY_ENABLED: enabled}))
	file.close()
	return true
