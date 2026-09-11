class_name OfficialTraprushCourses
extends RefCounted

## Official TRAPRUSH course ids for matchmaking JSON.
## HTTP never accepts res:// paths or UGC documents.
## Match ids live here and in `backend/contracts/src/official_courses.ts`.

const DEFAULT_ID: String = "course_01"
const COURSE_01: String = "course_01"
const COURSE_02: String = "course_02"
const COURSE_03: String = "course_03"
const COURSE_04: String = "course_04"
const COURSE_05: String = "course_05"
const COURSE_F_PLAYABLE: String = "course_f_playable"
const MATCH_IDS: PackedStringArray = [
	COURSE_01,
	COURSE_02,
	COURSE_03,
	COURSE_04,
	COURSE_05,
]
const DEFAULT_SEATS: int = 2
const MIN_SEATS: int = 1
const MAX_SEATS: int = 8
const _DOCUMENT_DIR: String = "res://content/official/traprush"


static func is_id(value: String) -> bool:
	return MATCH_IDS.has(value)


static func is_document_id(value: String) -> bool:
	return is_id(value) or value == COURSE_F_PLAYABLE


static func all_match_ids() -> PackedStringArray:
	return MATCH_IDS


static func all_document_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for id: String in MATCH_IDS:
		ids.append(id)
	ids.append(COURSE_F_PLAYABLE)
	return ids


static func normalize_id(raw: String) -> String:
	var trimmed: String = raw.strip_edges()
	if is_document_id(trimmed):
		return trimmed
	return ""


static func document_path(course_id: String) -> String:
	var id: String = normalize_id(course_id)
	if id == "":
		return ""
	return "%s/%s.json" % [_DOCUMENT_DIR, id]


static func default_path() -> String:
	return document_path(DEFAULT_ID)


static func normalize_seats(value: int) -> int:
	if value < MIN_SEATS or value > MAX_SEATS:
		return 0
	return value
