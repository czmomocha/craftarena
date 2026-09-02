class_name MatchJoinAccept
extends RefCounted

## Applies control-plane JSON to a MatchJoinSession. The session keeps
## pending HTTP and public fields; this type owns status dispatch.

const MatchJoinCodecGd := preload("res://src/client/match_join_codec.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")


func apply(session: MatchJoinSession, status_code: int, body: Dictionary) -> bool:
	if not session.has_pending():
		return false
	var method: String = session.pending_method()
	var path: String = session.pending_path()
	session.clear_pending()
	if path.ends_with("/settlement"):
		if status_code == 200:
			return _accept_settlement(session, body)
		return true
	if status_code == 201:
		if path.ends_with("/tickets/reconnect"):
			return _accept_reissue(session, body)
		return _accept_join(session, body)
	if status_code == 202:
		return _accept_waiting(session, body)
	if status_code == 200:
		if method == "GET":
			return _accept_queue_view(session, body)
		if method == "DELETE":
			return _accept_cancel(session, body)
		return session.fail_reason("unexpected_status")
	if status_code == 409 and MatchJoinCodecGd.error_name(body) == "queue_already_ready":
		session.error = "queue_already_ready"
		return true
	if status_code == 400 or status_code == 404 or status_code == 409 or status_code == 502 or status_code == 503:
		var name: String = MatchJoinCodecGd.error_name(body)
		if name == "":
			return session.fail_reason("parse_error")
		return session.fail_reason(name)
	return session.fail_reason("unexpected_status")


func _accept_join(session: MatchJoinSession, body: Dictionary) -> bool:
	if not MatchJoinCodecGd.keys_only(body, MatchJoinCodecGd.JOIN_KEYS):
		return session.fail_reason("parse_error")
	if not _copy_join_fields(session, body):
		return session.fail_reason("parse_error")
	session.clear_queue_fields()
	session.error = ""
	session.state = MatchJoinSession.STATE_READY
	return true


func _accept_reissue(session: MatchJoinSession, body: Dictionary) -> bool:
	if not MatchJoinCodecGd.keys_only(body, MatchJoinCodecGd.REISSUE_KEYS):
		return session.fail_reason("parse_error")
	var next_ticket: String = str(body.get("ticket", "")).strip_edges()
	var next_match: String = str(body.get("matchId", "")).strip_edges()
	var next_expires: String = str(body.get("expiresAt", "")).strip_edges()
	if next_ticket == "" or next_match == "" or next_expires == "":
		return session.fail_reason("parse_error")
	if next_match != session.match_id:
		return session.fail_reason("parse_error")
	var next_seat: Dictionary = MatchJoinCodecGd.read_int(body, "seat")
	var seat_ok: bool = next_seat.get("ok", false)
	if not seat_ok:
		return session.fail_reason("parse_error")
	var seat_value: int = next_seat.get("value", -1)
	if seat_value != session.seat:
		return session.fail_reason("parse_error")
	session.ticket = next_ticket
	session.expires_at = next_expires
	session.error = ""
	session.state = MatchJoinSession.STATE_READY
	return true


func _accept_settlement(session: MatchJoinSession, body: Dictionary) -> bool:
	if not MatchJoinCodecGd.keys_only(body, MatchJoinCodecGd.SETTLEMENT_KEYS):
		return true
	var next_match: String = str(body.get("matchId", "")).strip_edges()
	if next_match == "" or next_match != session.match_id:
		return true
	var tick_read: Dictionary = MatchJoinCodecGd.read_int(body, "tick")
	var pad_read: Dictionary = MatchJoinCodecGd.read_int(body, "padTotal")
	var mvp_read: Dictionary = MatchJoinCodecGd.read_int(body, "mvpSlot")
	var tick_ok: bool = tick_read.get("ok", false)
	var pad_ok: bool = pad_read.get("ok", false)
	var mvp_ok: bool = mvp_read.get("ok", false)
	if not tick_ok or not pad_ok or not mvp_ok:
		return true
	var tick_value: int = tick_read.get("value", -1)
	var pad_value: int = pad_read.get("value", -1)
	var mvp_value: int = mvp_read.get("value", -1)
	if tick_value < 0 or pad_value < 0 or mvp_value < 0 or mvp_value > 7:
		return true
	var state_hash: String = str(body.get("stateHash", "")).strip_edges()
	var created_at: String = str(body.get("createdAt", "")).strip_edges()
	if state_hash == "" or created_at == "":
		return true
	var rows_raw: Variant = body.get("rows", null)
	if typeof(rows_raw) != TYPE_ARRAY:
		return true
	var rows: Array = rows_raw
	var parsed: Dictionary = MatchJoinCodecGd.parse_settlement_rows(rows, mvp_value)
	if not parsed.get("ok", false):
		return true
	session.settlement_line = str(parsed.get("line", ""))
	session.has_settlement = session.settlement_line != ""
	session.error = ""
	return true


func _accept_waiting(session: MatchJoinSession, body: Dictionary) -> bool:
	if not MatchJoinCodecGd.keys_only(body, MatchJoinCodecGd.WAITING_KEYS):
		return session.fail_reason("parse_error")
	if body.get("status", "") != "waiting":
		return session.fail_reason("parse_error")
	if not _copy_waiting_fields(session, body):
		return session.fail_reason("parse_error")
	session.clear_ready_fields()
	session.error = ""
	session.state = MatchJoinSession.STATE_WAITING
	return true


func _accept_queue_view(session: MatchJoinSession, body: Dictionary) -> bool:
	var status_name: String = str(body.get("status", ""))
	if status_name == "waiting":
		return _accept_waiting(session, body)
	if status_name == "ready":
		if not MatchJoinCodecGd.keys_only(body, MatchJoinCodecGd.READY_KEYS):
			return session.fail_reason("parse_error")
		if not _copy_join_fields(session, body):
			return session.fail_reason("parse_error")
		session.clear_queue_fields()
		session.error = ""
		session.state = MatchJoinSession.STATE_READY
		return true
	if status_name == "failed":
		if not MatchJoinCodecGd.keys_only(body, MatchJoinCodecGd.QUEUE_FAILED_KEYS):
			return session.fail_reason("parse_error")
		var failed_error: String = str(body.get("error", "")).strip_edges()
		if failed_error == "":
			return session.fail_reason("parse_error")
		return session.fail_reason(failed_error)
	return session.fail_reason("parse_error")


func _accept_cancel(session: MatchJoinSession, body: Dictionary) -> bool:
	if not MatchJoinCodecGd.keys_only(body, MatchJoinCodecGd.CANCEL_KEYS):
		return session.fail_reason("parse_error")
	var ok_flag: Variant = body.get("ok", false)
	if typeof(ok_flag) != TYPE_BOOL or ok_flag != true:
		return session.fail_reason("parse_error")
	session.reset_match_fields()
	session.error = ""
	session.state = MatchJoinSession.STATE_IDLE
	return true


func _copy_join_fields(session: MatchJoinSession, body: Dictionary) -> bool:
	var next_room: String = str(body.get("roomCode", "")).strip_edges()
	var next_ticket: String = str(body.get("ticket", "")).strip_edges()
	var next_match: String = str(body.get("matchId", "")).strip_edges()
	var next_expires: String = str(body.get("expiresAt", "")).strip_edges()
	var next_seats: Dictionary = MatchJoinCodecGd.read_int(body, "seats")
	var next_issued: Dictionary = MatchJoinCodecGd.read_int(body, "issued")
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
	var next_seat: Dictionary = MatchJoinCodecGd.read_int(body, "seat")
	var seat_ok: bool = next_seat.get("ok", false)
	if not seat_ok:
		return false
	var seat_value: int = next_seat.get("value", -1)
	if seat_value < 0 or seat_value > 7 or seat_value >= seats_value:
		return false
	var next_course: String = OfficialTraprushCoursesGd.normalize_id(str(body.get("course", "")))
	if next_course == "":
		return false
	session.room_code = next_room
	session.ticket = next_ticket
	session.match_id = next_match
	session.expires_at = next_expires
	session.seats = seats_value
	session.issued = issued_value
	session.seat = seat_value
	session.course = next_course
	return true


func _copy_waiting_fields(session: MatchJoinSession, body: Dictionary) -> bool:
	var next_token: String = str(body.get("queueToken", "")).strip_edges()
	var next_expires: String = str(body.get("expiresAt", "")).strip_edges()
	var next_position: Dictionary = MatchJoinCodecGd.read_int(body, "position")
	var next_wait: Dictionary = MatchJoinCodecGd.read_int(body, "estimatedWaitMs")
	var position_ok: bool = next_position.get("ok", false)
	var wait_ok: bool = next_wait.get("ok", false)
	if next_token == "" or next_expires == "" or not position_ok or not wait_ok:
		return false
	var position_value: int = next_position.get("value", 0)
	var wait_value: int = next_wait.get("value", -1)
	if position_value < 1 or wait_value < 0:
		return false
	var next_course: String = OfficialTraprushCoursesGd.normalize_id(str(body.get("course", "")))
	if next_course == "":
		return false
	var next_seats: Dictionary = MatchJoinCodecGd.read_int(body, "seats")
	var seats_ok: bool = next_seats.get("ok", false)
	if not seats_ok:
		return false
	var seats_value: int = next_seats.get("value", 0)
	if OfficialTraprushCoursesGd.normalize_seats(seats_value) == 0:
		return false
	session.queue_token = next_token
	session.queue_expires_at = next_expires
	session.position = position_value
	session.estimated_wait_ms = wait_value
	session.course = next_course
	session.seats = seats_value
	return true
