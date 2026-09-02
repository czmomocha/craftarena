class_name MatchJoinSession
extends RefCounted

## Client matchmaking session over the control-plane JSON already locked
## in CD-44 §3 / backend/contracts match_room.ts.
## Injected HTTP only: try_* records the next request; accept_http applies
## the status + object. No SceneTree, no sockets. Room-code alphabet and
## length match the current development placeholder (not a product lock).
## Does not bind accounts or POST settlement. READY may GET the
## control-plane board read-only; 404 keeps READY. Reconnect reissues a
## consumed ticket for the same match seat. try_abandon locally drops a
## ready/failed ticket without a leave-match HTTP API. Queue cancel
## (DELETE) still requires WAITING. Quick play / create room
## send an official course id and seats; join-by-code uses the room's
## course and seats. Ready JSON includes the ticket `seat` (0-based).
## Codec and accept live in MatchJoinCodec / MatchJoinAccept so this
## facade stays under the E9 line cap.

const MatchJoinAcceptGd := preload("res://src/client/match_join_accept.gd")
const MatchJoinCodecGd := preload("res://src/client/match_join_codec.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")

const STATE_IDLE: String = "idle"
const STATE_WAITING: String = "waiting"
const STATE_READY: String = "ready"
const STATE_FAILED: String = "failed"

var state: String = STATE_IDLE
var error: String = ""
var queue_token: String = ""
var position: int = 0
var estimated_wait_ms: int = 0
var queue_expires_at: String = ""
var ticket: String = ""
var match_id: String = ""
var room_code: String = ""
var expires_at: String = ""
var seats: int = 0
var issued: int = 0
var seat: int = -1
var course: String = ""
var settlement_line: String = ""
var has_settlement: bool = false

var _pending_method: String = ""
var _pending_path: String = ""
var _pending_body: String = ""
var accept: MatchJoinAcceptGd = MatchJoinAcceptGd.new()


static func create() -> MatchJoinSession:
	return new()


static func normalize_room_code(raw: String) -> String:
	return MatchJoinCodecGd.normalize_room_code(raw)


static func http_url(control_plane_base: String, path: String) -> String:
	return MatchJoinCodecGd.http_url(control_plane_base, path)


static func parse_json_object(text: String) -> Dictionary:
	return MatchJoinCodecGd.parse_json_object(text)


func has_pending() -> bool:
	return _pending_method != ""


func pending_method() -> String:
	return _pending_method


func pending_path() -> String:
	return _pending_path


func pending_body() -> String:
	return _pending_body


func try_quick(
	course_id: String = OfficialTraprushCoursesGd.DEFAULT_ID,
	seat_count: int = OfficialTraprushCoursesGd.DEFAULT_SEATS
) -> bool:
	var payload: String = MatchJoinCodecGd.match_body(course_id, seat_count)
	if payload == "":
		return false
	return _begin_request("POST", "/matchmaking/quick", payload)


func try_create_room(
	course_id: String = OfficialTraprushCoursesGd.DEFAULT_ID,
	seat_count: int = OfficialTraprushCoursesGd.DEFAULT_SEATS
) -> bool:
	var payload: String = MatchJoinCodecGd.match_body(course_id, seat_count)
	if payload == "":
		return false
	return _begin_request("POST", "/matchmaking/rooms", payload)


func try_join_room(raw_code: String) -> bool:
	var code: String = normalize_room_code(raw_code)
	if code == "":
		return false
	return _begin_request("POST", "/matchmaking/rooms/%s/join" % code)


func try_poll() -> bool:
	if state != STATE_WAITING or queue_token == "" or has_pending():
		return false
	return _begin_request("GET", "/matchmaking/queue/%s" % queue_token.uri_encode())


func try_cancel() -> bool:
	if state != STATE_WAITING or queue_token == "" or has_pending():
		return false
	return _begin_request("DELETE", "/matchmaking/queue/%s" % queue_token.uri_encode())


func try_abandon() -> bool:
	if state == STATE_IDLE or state == STATE_WAITING:
		return false
	clear_pending()
	reset_match_fields()
	error = ""
	state = STATE_IDLE
	return true


func try_reconnect() -> bool:
	if state != STATE_READY or ticket == "" or match_id == "" or has_pending():
		return false
	var payload: String = JSON.stringify({"ticket": ticket})
	if payload == "":
		return false
	return _begin_request(
		"POST",
		"/match-sessions/%s/tickets/reconnect" % match_id.uri_encode(),
		payload
	)


func try_get_settlement() -> bool:
	if state != STATE_READY or match_id == "" or has_pending():
		return false
	return _begin_request("GET", "/match-sessions/%s/settlement" % match_id.uri_encode())


func accept_http(status_code: int, body: Dictionary) -> bool:
	return accept.apply(self, status_code, body)


func fail_transport() -> bool:
	if not has_pending():
		return false
	var keep_ready: bool = _is_settlement_get()
	clear_pending()
	if keep_ready:
		return true
	return fail_reason("transport_error")


func fail_parse() -> bool:
	if not has_pending():
		return false
	var keep_ready: bool = _is_settlement_get()
	clear_pending()
	if keep_ready:
		return true
	return fail_reason("parse_error")


func apply_http_text(status_code: int, text: String) -> bool:
	var parsed: Dictionary = parse_json_object(text)
	var parsed_ok: bool = parsed.get("ok", false)
	if not parsed_ok:
		return fail_parse()
	var body: Dictionary = parsed.get("body", {})
	return accept_http(status_code, body)


func status_view() -> Dictionary:
	return {
		"state": state,
		"error": error,
		"pending": has_pending(),
		"pending_method": _pending_method,
		"pending_path": _pending_path,
		"queue_token": queue_token,
		"position": position,
		"estimated_wait_ms": estimated_wait_ms,
		"queue_expires_at": queue_expires_at,
		"ticket": ticket,
		"match_id": match_id,
		"room_code": room_code,
		"expires_at": expires_at,
		"seats": seats,
		"issued": issued,
		"seat": seat,
		"course": course,
		"settlement_line": settlement_line,
		"has_settlement": has_settlement,
	}


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func fail_reason(reason: String) -> bool:
	reset_match_fields()
	error = reason
	state = STATE_FAILED
	return true


func reset_match_fields() -> void:
	clear_queue_fields()
	clear_ready_fields()
	course = ""
	seats = 0


func clear_queue_fields() -> void:
	queue_token = ""
	position = 0
	estimated_wait_ms = 0
	queue_expires_at = ""


func clear_ready_fields() -> void:
	ticket = ""
	match_id = ""
	room_code = ""
	expires_at = ""
	issued = 0
	seat = -1
	settlement_line = ""
	has_settlement = false


func clear_pending() -> void:
	_pending_method = ""
	_pending_path = ""
	_pending_body = ""


func _begin_request(method: String, path: String, body: String = "") -> bool:
	if has_pending():
		return false
	if state == STATE_READY:
		var reconnect_ok: bool = method == "POST" and path.ends_with("/tickets/reconnect")
		var settlement_ok: bool = method == "GET" and path.ends_with("/settlement")
		if not reconnect_ok and not settlement_ok:
			return false
	elif state == STATE_WAITING and method == "POST":
		return false
	elif state == STATE_IDLE or state == STATE_FAILED:
		if method != "POST":
			return false
		reset_match_fields()
		error = ""
		state = STATE_IDLE
	_pending_method = method
	_pending_path = path
	_pending_body = body
	return true


func _is_settlement_get() -> bool:
	return _pending_method == "GET" and _pending_path.ends_with("/settlement")
