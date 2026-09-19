class_name TraprushGhostStore
extends RefCounted

## One fastest Solo tape per official course_id. Not the R2 ring of 50.

const TapeGd := preload("res://src/games/traprush/replay_tape.gd")

const DEFAULT_PATH: String = "user://traprush_solo_ghosts.json"
const KEY_BEST: String = "best"

var path: String = DEFAULT_PATH


func best_for(course_id: String) -> Dictionary:
	if course_id == "":
		return {}
	var rows: Dictionary = _load_best()
	var raw: Variant = rows.get(course_id, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var tape: Dictionary = raw
	var parsed: Dictionary = TapeGd.parse(tape)
	var parsed_ok: bool = parsed.get("ok", false)
	if not parsed_ok:
		return {}
	parsed.erase("ok")
	return parsed


func put_if_faster(tape: Dictionary) -> bool:
	var parsed: Dictionary = TapeGd.parse(tape)
	var parsed_ok: bool = parsed.get("ok", false)
	if not parsed_ok:
		return false
	parsed.erase("ok")
	if TapeGd.as_int(parsed.get("seats", 0), 0) != 1:
		return false
	var course_id: String = str(parsed.get("course_id", ""))
	if course_id == "":
		return false
	var finish_raw: Variant = parsed.get("finish_ticks", [])
	if typeof(finish_raw) != TYPE_ARRAY:
		return false
	var finish_ticks: Array = finish_raw
	if finish_ticks.is_empty():
		return false
	var finish: int = TapeGd.as_int(finish_ticks[0], -1)
	if finish < 0:
		return false
	var existing: Dictionary = best_for(course_id)
	if not existing.is_empty():
		var old_raw: Variant = existing.get("finish_ticks", [])
		if typeof(old_raw) == TYPE_ARRAY:
			var old_ticks: Array = old_raw
			if not old_ticks.is_empty():
				var old_finish: int = TapeGd.as_int(old_ticks[0], -1)
				if old_finish >= 0 and finish >= old_finish:
					return false
	var rows: Dictionary = _load_best()
	rows[course_id] = parsed
	return _write(rows)


func _load_best() -> Dictionary:
	var rows: Dictionary = {}
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
	var raw: Variant = body.get(KEY_BEST, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return rows
	var bag: Dictionary = raw
	for course_id: Variant in bag.keys():
		var item: Variant = bag.get(course_id, {})
		if typeof(item) != TYPE_DICTIONARY:
			continue
		rows[str(course_id)] = item
	return rows


func _write(rows: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"schema_version": TapeGd.SCHEMA_VERSION,
		KEY_BEST: rows,
	}))
	file.close()
	return true
