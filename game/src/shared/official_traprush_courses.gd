class_name OfficialTraprushCourses
extends RefCounted

## Official TRAPRUSH course ids for matchmaking JSON.
## HTTP never accepts res:// paths or UGC documents.

const DEFAULT_ID: String = "course_01"
const COURSE_01: String = "course_01"
const COURSE_02: String = "course_02"
const COURSE_03: String = "course_03"
const DEFAULT_SEATS: int = 2
const MIN_SEATS: int = 1
const MAX_SEATS: int = 8
const _DOCUMENT_DIR: String = "res://content/official/traprush"


static func is_id(value: String) -> bool:
	return value == COURSE_01 or value == COURSE_02 or value == COURSE_03


static func normalize_id(raw: String) -> String:
	var trimmed: String = raw.strip_edges()
	if is_id(trimmed):
		return trimmed
	return ""


static func document_path(course_id: String) -> String:
	var id: String = normalize_id(course_id)
	if id == "":
		return ""
	return "%s/%s.json" % [_DOCUMENT_DIR, id]


static func normalize_seats(value: int) -> int:
	if value < MIN_SEATS or value > MAX_SEATS:
		return 0
	return value
