class_name MatchJoinCodec
extends RefCounted

## JSON / URL / room-code / key-set helpers for MatchJoinSession.
## No SceneTree. Does not own matchmaking state.

const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")

const ROOM_CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH: int = 6
const JOIN_KEYS: PackedStringArray = [
	"roomCode",
	"ticket",
	"matchId",
	"expiresAt",
	"seats",
	"issued",
	"seat",
	"course",
]
const WAITING_KEYS: PackedStringArray = [
	"status",
	"queueToken",
	"position",
	"estimatedWaitMs",
	"expiresAt",
	"course",
	"seats",
]
const READY_KEYS: PackedStringArray = [
	"status",
	"roomCode",
	"ticket",
	"matchId",
	"expiresAt",
	"seats",
	"issued",
	"seat",
	"course",
]
const QUEUE_FAILED_KEYS: PackedStringArray = ["status", "error"]
const ERROR_KEYS: PackedStringArray = ["error", "message"]
const CANCEL_KEYS: PackedStringArray = ["ok"]
const REISSUE_KEYS: PackedStringArray = [
	"ticket",
	"matchId",
	"expiresAt",
	"seat",
]
const SETTLEMENT_KEYS: PackedStringArray = [
	"matchId",
	"tick",
	"stateHash",
	"padTotal",
	"mvpSlot",
	"rows",
	"createdAt",
]
const SETTLEMENT_ROW_KEYS: PackedStringArray = [
	"slot",
	"place",
	"finishTick",
	"acceptedCount",
]


static func normalize_room_code(raw: String) -> String:
	var normalized: String = raw.strip_edges().to_upper()
	if normalized.length() != ROOM_CODE_LENGTH:
		return ""
	for index: int in range(normalized.length()):
		if ROOM_CODE_ALPHABET.find(normalized.substr(index, 1)) < 0:
			return ""
	return normalized


static func http_url(control_plane_base: String, path: String) -> String:
	var base: String = control_plane_base.strip_edges()
	while base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	if not base.begins_with("http://") and not base.begins_with("https://"):
		return ""
	if not path.begins_with("/"):
		return ""
	if path.contains(" "):
		return ""
	return base + path


static func parse_json_object(text: String) -> Dictionary:
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false}
	var data: Variant = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false}
	return {"ok": true, "body": data}


static func match_body(course_id: String, seat_count: int) -> String:
	var id: String = OfficialTraprushCoursesGd.normalize_id(course_id)
	var seats_value: int = OfficialTraprushCoursesGd.normalize_seats(seat_count)
	if id == "" or seats_value == 0:
		return ""
	return JSON.stringify({"course": id, "seats": seats_value})


static func error_name(body: Dictionary) -> String:
	if not keys_only(body, ERROR_KEYS):
		return ""
	if not body.has("error"):
		return ""
	return str(body.get("error", "")).strip_edges()


static func keys_only(body: Dictionary, allowed: PackedStringArray) -> bool:
	for key: Variant in body.keys():
		if allowed.find(str(key)) < 0:
			return false
	return true


static func read_int(body: Dictionary, key: String) -> Dictionary:
	if not body.has(key):
		return {"ok": false}
	var value: Variant = body[key]
	if typeof(value) == TYPE_INT:
		return {"ok": true, "value": value}
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if number != floor(number):
			return {"ok": false}
		return {"ok": true, "value": int(number)}
	return {"ok": false}


static func parse_settlement_rows(rows: Array, mvp_slot: int) -> Dictionary:
	if rows.is_empty() or rows.size() > 8:
		return {"ok": false}
	var slots: Dictionary = {}
	var places: Dictionary = {}
	var winner_slot: int = -1
	var by_place: Dictionary = {}
	for item: Variant in rows:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false}
		var row: Dictionary = item
		if not keys_only(row, SETTLEMENT_ROW_KEYS):
			return {"ok": false}
		var slot_read: Dictionary = read_int(row, "slot")
		var place_read: Dictionary = read_int(row, "place")
		var finish_read: Dictionary = read_int(row, "finishTick")
		var accepted_read: Dictionary = read_int(row, "acceptedCount")
		if not slot_read.get("ok", false) or not place_read.get("ok", false):
			return {"ok": false}
		if not finish_read.get("ok", false) or not accepted_read.get("ok", false):
			return {"ok": false}
		var slot_value: int = slot_read.get("value", -1)
		var place_value: int = place_read.get("value", 0)
		var finish_value: int = finish_read.get("value", -1)
		var accepted_value: int = accepted_read.get("value", -1)
		if slot_value < 0 or slot_value > 7:
			return {"ok": false}
		if place_value < 1 or place_value > 8:
			return {"ok": false}
		if finish_value < 0 or accepted_value < 0:
			return {"ok": false}
		if slots.has(slot_value) or places.has(place_value):
			return {"ok": false}
		slots[slot_value] = true
		places[place_value] = true
		by_place[place_value] = slot_value
		if place_value == 1:
			winner_slot = slot_value
	if winner_slot < 0 or winner_slot != mvp_slot:
		return {"ok": false}
	var parts: PackedStringArray = PackedStringArray()
	for place_index: int in range(1, rows.size() + 1):
		if not places.has(place_index):
			return {"ok": false}
		var slot_at_place: int = by_place.get(place_index, -1)
		parts.append("#%ds%d" % [place_index, slot_at_place])
	return {"ok": true, "line": "%s mvp=%d" % [",".join(parts), mvp_slot]}
