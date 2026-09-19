class_name TraprushReplayStore
extends RefCounted

## Local Solo TRAPRUSH replay ring (50). Web uses the same user:// path.

const TapeGd := preload("res://src/games/traprush/replay_tape.gd")

const DEFAULT_PATH: String = "user://traprush_replays.json"
const KEY_ITEMS: String = "items"

var path: String = DEFAULT_PATH


func load_items() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return rows
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return rows
	var body: Dictionary = parsed
	var raw: Variant = body.get(KEY_ITEMS, [])
	if typeof(raw) != TYPE_ARRAY:
		return rows
	for item: Variant in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var tape_raw: Variant = row.get("tape", {})
		if typeof(tape_raw) != TYPE_DICTIONARY:
			continue
		var tape: Dictionary = tape_raw
		var parsed_tape: Dictionary = TapeGd.parse(tape)
		var parsed_ok: bool = parsed_tape.get("ok", false)
		if not parsed_ok:
			continue
		parsed_tape.erase("ok")
		rows.append({
			"replay_id": str(row.get("replay_id", "")),
			"created_at": str(row.get("created_at", "")),
			"source": "local",
			"tape": parsed_tape,
		})
	return rows


func append_tape(tape: Dictionary) -> bool:
	var parsed: Dictionary = TapeGd.parse(tape)
	var parsed_ok: bool = parsed.get("ok", false)
	if not parsed_ok:
		return false
	parsed.erase("ok")
	var rows: Array[Dictionary] = load_items()
	rows.push_front({
		"replay_id": "loc_%d" % Time.get_ticks_usec(),
		"created_at": Time.get_datetime_string_from_system(true, true),
		"source": "local",
		"tape": parsed,
	})
	while rows.size() > TapeGd.LOCAL_RING:
		rows.pop_back()
	return _write(rows)


func _write(rows: Array[Dictionary]) -> bool:
	var items: Array = []
	for row: Dictionary in rows:
		items.append({
			"replay_id": str(row.get("replay_id", "")),
			"created_at": str(row.get("created_at", "")),
			"tape": row.get("tape", {}),
		})
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"schema_version": TapeGd.SCHEMA_VERSION,
		KEY_ITEMS: items,
	}))
	file.close()
	return true
