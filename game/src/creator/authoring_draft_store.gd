class_name AuthoringDraftStore
extends RefCounted

## Local crash-recovery for internal-dev authoring (CD-32 §2).
## Latest snapshot after every successful write. Checkpoints every 50
## commands, keep 30. Not a new EDIT op. No cloud upload. Never settlement.

const DEFAULT_PATH: String = "user://authoring_draft.json"
const SCHEMA_VERSION: int = 1
const CHECKPOINT_INTERVAL: int = 50
const MAX_CHECKPOINTS: int = 30
const FIELD_SCHEMA_VERSION: String = "schema_version"
const FIELD_COMMAND_COUNT: String = "command_count"
const FIELD_LATEST: String = "latest"
const FIELD_CHECKPOINTS: String = "checkpoints"

var path: String = DEFAULT_PATH
var checkpoint_interval: int = CHECKPOINT_INTERVAL
var max_checkpoints: int = MAX_CHECKPOINTS
var command_count: int = 0
var latest: Dictionary = {}
var checkpoints: Array[Dictionary] = []


func _init(
	p_path: String = DEFAULT_PATH,
	p_interval: int = CHECKPOINT_INTERVAL,
	p_max: int = MAX_CHECKPOINTS
) -> void:
	path = p_path
	if p_interval < 1:
		checkpoint_interval = 1
	else:
		checkpoint_interval = p_interval
	if p_max < 1:
		max_checkpoints = 1
	else:
		max_checkpoints = p_max


func record(world: AuthoringWorld) -> bool:
	if world == null:
		return false
	if _is_project_content_path(path):
		return false
	var encoded: Dictionary = AuthoringDocument.encode(world)
	if encoded.is_empty():
		return false
	command_count += 1
	latest = encoded
	if command_count == 1 or command_count % checkpoint_interval == 0:
		checkpoints.append(encoded.duplicate(true))
		while checkpoints.size() > max_checkpoints:
			checkpoints.remove_at(0)
	return _flush()


func try_load_latest() -> AuthoringWorld:
	if not _read_file():
		return null
	return AuthoringDocument.decode(latest)


func wipe() -> void:
	command_count = 0
	latest = {}
	checkpoints.clear()
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _flush() -> bool:
	if path.is_empty() or _is_project_content_path(path):
		return false
	var points: Array = []
	for item: Dictionary in checkpoints:
		points.append(item)
	var body: Dictionary = {
		FIELD_SCHEMA_VERSION: SCHEMA_VERSION,
		FIELD_COMMAND_COUNT: command_count,
		FIELD_LATEST: latest,
		FIELD_CHECKPOINTS: points,
	}
	var text: String = JSON.stringify(body)
	if text.is_empty():
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


func _read_file() -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var body: Dictionary = parsed
	if body.size() != 4:
		return false
	if not body.has(FIELD_SCHEMA_VERSION):
		return false
	var version: int = _as_int(body[FIELD_SCHEMA_VERSION])
	if version != SCHEMA_VERSION:
		return false
	if not body.has(FIELD_COMMAND_COUNT):
		return false
	var count: int = _as_int(body[FIELD_COMMAND_COUNT])
	if count < 0:
		return false
	if not body.has(FIELD_LATEST) or typeof(body[FIELD_LATEST]) != TYPE_DICTIONARY:
		return false
	var latest_body: Dictionary = body[FIELD_LATEST]
	if AuthoringDocument.decode(latest_body) == null:
		return false
	if not body.has(FIELD_CHECKPOINTS) or typeof(body[FIELD_CHECKPOINTS]) != TYPE_ARRAY:
		return false
	var raw_points: Array = body[FIELD_CHECKPOINTS]
	var points: Array[Dictionary] = []
	for item: Variant in raw_points:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var point: Dictionary = item
		if AuthoringDocument.decode(point) == null:
			return false
		points.append(point)
	command_count = count
	latest = latest_body
	checkpoints = points
	return true


func _is_project_content_path(target: String) -> bool:
	return target.begins_with("res://")


func _as_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if not is_finite(number):
			return -1
		var as_int: int = int(number)
		if float(as_int) != number:
			return -1
		return as_int
	return -1
