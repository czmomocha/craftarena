class_name MatchJoinSession
extends RefCounted

## Client matchmaking session over the control-plane JSON already locked
## in CD-44 §3 / backend/contracts match_room.ts.
## Injected HTTP only: try_* records the next request; accept_http applies
## the status + object. No SceneTree, no sockets. Room-code alphabet and
## length match the current development placeholder (not a product lock).
## Does not bind accounts or write settlement. Reconnect reissues a
## consumed ticket for the same match seat.

const STATE_IDLE: String = "idle"
const STATE_WAITING: String = "waiting"
const STATE_READY: String = "ready"
const STATE_FAILED: String = "failed"

const _ROOM_CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const _ROOM_CODE_LENGTH: int = 6
const _JOIN_KEYS: PackedStringArray = [
	"roomCode",
	"ticket",
	"matchId",
	"expiresAt",
	"seats",
	"issued",
]
const _WAITING_KEYS: PackedStringArray = [
	"status",
	"queueToken",
	"position",
	"estimatedWaitMs",
	"expiresAt",
]
const _READY_KEYS: PackedStringArray = [
	"status",
	"roomCode",
	"ticket",
	"matchId",
	"expiresAt",
	"seats",
	"issued",
]
const _QUEUE_FAILED_KEYS: PackedStringArray = ["status", "error"]
const _ERROR_KEYS: PackedStringArray = ["error", "message"]
const _CANCEL_KEYS: PackedStringArray = ["ok"]

const _REISSUE_KEYS: PackedStringArray = [
	"ticket",
	"matchId",
	"expiresAt",
]

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

var _pending_method: String = ""
var _pending_path: String = ""
var _pending_body: String = ""


static func create() -> MatchJoinSession:
	return new()


static func normalize_room_code(raw: String) -> String:
	var normalized: String = raw.strip_edges().to_upper()
	if normalized.length() != _ROOM_CODE_LENGTH:
		return ""
	for index: int in range(normalized.length()):
		if _ROOM_CODE_ALPHABET.find(normalized.substr(index, 1)) < 0:
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


func has_pending() -> bool:
	return _pending_method != ""


func pending_method() -> String:
	return _pending_method


func pending_path() -> String:
	return _pending_path


func pending_body() -> String:
	return _pending_body


func try_quick() -> bool:
	return _begin_request("POST", "/matchmaking/quick")


func try_create_room() -> bool:
	return _begin_request("POST", "/matchmaking/rooms")


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


func accept_http(status_code: int, body: Dictionary) -> bool:
	if not has_pending():
		return false
	var method: String = _pending_method
	var path: String = _pending_path
	_clear_pending()
	if status_code == 201:
		if path.ends_with("/tickets/reconnect"):
			return _accept_reissue(body)
		return _accept_join(body)
	if status_code == 202:
		return _accept_waiting(body)
	if status_code == 200:
		if method == "GET":
			return _accept_queue_view(body)
		if method == "DELETE":
			return _accept_cancel(body)
		return _fail("unexpected_status")
	if status_code == 409 and _error_name(body) == "queue_already_ready":
		error = "queue_already_ready"
		return true
	if status_code == 400 or status_code == 404 or status_code == 409 or status_code == 502 or status_code == 503:
		var name: String = _error_name(body)
		if name == "":
			return _fail("parse_error")
		return _fail(name)
	return _fail("unexpected_status")


func fail_transport() -> bool:
	if not has_pending():
		return false
	_clear_pending()
	return _fail("transport_error")


func fail_parse() -> bool:
	if not has_pending():
		return false
	_clear_pending()
	return _fail("parse_error")


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
	}


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _begin_request(method: String, path: String, body: String = "") -> bool:
	if has_pending():
		return false
	if state == STATE_READY:
		if method != "POST" or not path.ends_with("/tickets/reconnect"):
			return false
	elif state == STATE_WAITING and method == "POST":
		return false
	elif state == STATE_IDLE or state == STATE_FAILED:
		if method != "POST":
			return false
		_reset_match_fields()
		error = ""
		state = STATE_IDLE
	_pending_method = method
	_pending_path = path
	_pending_body = body
	return true


func _accept_join(body: Dictionary) -> bool:
	if not _keys_only(body, _JOIN_KEYS):
		return _fail("parse_error")
	if not _copy_join_fields(body):
		return _fail("parse_error")
	_clear_queue_fields()
	error = ""
	state = STATE_READY
	return true


func _accept_reissue(body: Dictionary) -> bool:
	if not _keys_only(body, _REISSUE_KEYS):
		return _fail("parse_error")
	var next_ticket: String = str(body.get("ticket", "")).strip_edges()
	var next_match: String = str(body.get("matchId", "")).strip_edges()
	var next_expires: String = str(body.get("expiresAt", "")).strip_edges()
	if next_ticket == "" or next_match == "" or next_expires == "":
		return _fail("parse_error")
	if next_match != match_id:
		return _fail("parse_error")
	ticket = next_ticket
	expires_at = next_expires
	error = ""
	state = STATE_READY
	return true


func _accept_waiting(body: Dictionary) -> bool:
	if not _keys_only(body, _WAITING_KEYS):
		return _fail("parse_error")
	if body.get("status", "") != "waiting":
		return _fail("parse_error")
	if not _copy_waiting_fields(body):
		return _fail("parse_error")
	_clear_ready_fields()
	error = ""
	state = STATE_WAITING
	return true


func _accept_queue_view(body: Dictionary) -> bool:
	var status_name: String = str(body.get("status", ""))
	if status_name == "waiting":
		return _accept_waiting(body)
	if status_name == "ready":
		if not _keys_only(body, _READY_KEYS):
			return _fail("parse_error")
		if not _copy_join_fields(body):
			return _fail("parse_error")
		_clear_queue_fields()
		error = ""
		state = STATE_READY
		return true
	if status_name == "failed":
		if not _keys_only(body, _QUEUE_FAILED_KEYS):
			return _fail("parse_error")
		var failed_error: String = str(body.get("error", "")).strip_edges()
		if failed_error == "":
			return _fail("parse_error")
		return _fail(failed_error)
	return _fail("parse_error")


func _accept_cancel(body: Dictionary) -> bool:
	if not _keys_only(body, _CANCEL_KEYS):
		return _fail("parse_error")
	var ok_flag: Variant = body.get("ok", false)
	if typeof(ok_flag) != TYPE_BOOL or ok_flag != true:
		return _fail("parse_error")
	_reset_match_fields()
	error = ""
	state = STATE_IDLE
	return true


func _copy_join_fields(body: Dictionary) -> bool:
	var next_room: String = str(body.get("roomCode", "")).strip_edges()
	var next_ticket: String = str(body.get("ticket", "")).strip_edges()
	var next_match: String = str(body.get("matchId", "")).strip_edges()
	var next_expires: String = str(body.get("expiresAt", "")).strip_edges()
	var next_seats: Dictionary = _read_int(body, "seats")
	var next_issued: Dictionary = _read_int(body, "issued")
	var seats_ok: bool = next_seats.get("ok", false)
	var issued_ok: bool = next_issued.get("ok", false)
	if next_room == "" or next_ticket == "" or next_match == "" or next_expires == "":
		return false
	if not seats_ok or not issued_ok:
		return false
	var seats_value: int = next_seats.get("value", 0)
	var issued_value: int = next_issued.get("value", 0)
	if seats_value < 1 or issued_value < 1:
		return false
	room_code = next_room
	ticket = next_ticket
	match_id = next_match
	expires_at = next_expires
	seats = seats_value
	issued = issued_value
	return true


func _copy_waiting_fields(body: Dictionary) -> bool:
	var next_token: String = str(body.get("queueToken", "")).strip_edges()
	var next_expires: String = str(body.get("expiresAt", "")).strip_edges()
	var next_position: Dictionary = _read_int(body, "position")
	var next_wait: Dictionary = _read_int(body, "estimatedWaitMs")
	var position_ok: bool = next_position.get("ok", false)
	var wait_ok: bool = next_wait.get("ok", false)
	if next_token == "" or next_expires == "" or not position_ok or not wait_ok:
		return false
	var position_value: int = next_position.get("value", 0)
	var wait_value: int = next_wait.get("value", -1)
	if position_value < 1 or wait_value < 0:
		return false
	queue_token = next_token
	queue_expires_at = next_expires
	position = position_value
	estimated_wait_ms = wait_value
	return true


func _error_name(body: Dictionary) -> String:
	if not _keys_only(body, _ERROR_KEYS):
		return ""
	if not body.has("error"):
		return ""
	var name: String = str(body.get("error", "")).strip_edges()
	return name


func _keys_only(body: Dictionary, allowed: PackedStringArray) -> bool:
	for key: Variant in body.keys():
		if allowed.find(str(key)) < 0:
			return false
	return true


func _read_int(body: Dictionary, key: String) -> Dictionary:
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


func _fail(reason: String) -> bool:
	_reset_match_fields()
	error = reason
	state = STATE_FAILED
	return true


func _reset_match_fields() -> void:
	_clear_queue_fields()
	_clear_ready_fields()


func _clear_queue_fields() -> void:
	queue_token = ""
	position = 0
	estimated_wait_ms = 0
	queue_expires_at = ""


func _clear_ready_fields() -> void:
	ticket = ""
	match_id = ""
	room_code = ""
	expires_at = ""
	seats = 0
	issued = 0


func _clear_pending() -> void:
	_pending_method = ""
	_pending_path = ""
	_pending_body = ""
