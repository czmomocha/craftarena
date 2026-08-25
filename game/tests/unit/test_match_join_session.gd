extends GutTest

## MatchJoinSession: injected HTTP over the locked matchmaking/queue JSON.
## No sockets. Room-code alphabet is the current development placeholder.

const MatchJoinSession := preload("res://src/client/match_join_session.gd")


func test_quick_play_201_becomes_ready_with_ticket() -> void:
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_true(session.try_quick())
	assert_eq(session.pending_method(), "POST")
	assert_eq(session.pending_path(), "/matchmaking/quick")
	assert_true(session.accept_http(201, _join("ABCD23", "ticket-a")))
	assert_eq(session.state, MatchJoinSession.STATE_READY)
	assert_eq(session.ticket, "ticket-a")
	assert_eq(session.room_code, "ABCD23")
	assert_eq(session.match_id, "match-1")
	assert_eq(session.seats, 2)
	assert_eq(session.issued, 1)
	assert_false(session.has_pending())
	assert_false(session.allows_settlement())
	assert_false(session.allows_online_writes())


func test_create_room_202_then_poll_ready() -> void:
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_true(session.try_create_room())
	assert_eq(session.pending_path(), "/matchmaking/rooms")
	assert_true(session.accept_http(202, _waiting("queue-token-aaaaaaaaaaaaaaaa", 1, 30000)))
	assert_eq(session.state, MatchJoinSession.STATE_WAITING)
	assert_eq(session.position, 1)
	assert_eq(session.estimated_wait_ms, 30000)
	assert_true(session.try_poll())
	assert_eq(session.pending_method(), "GET")
	assert_true(session.pending_path().begins_with("/matchmaking/queue/"))
	assert_true(session.accept_http(200, _ready_view("ABCD23", "ticket-b")))
	assert_eq(session.state, MatchJoinSession.STATE_READY)
	assert_eq(session.ticket, "ticket-b")
	assert_eq(session.queue_token, "")


func test_poll_updates_position_while_waiting() -> void:
	var session: MatchJoinSession = _waiting_session()
	assert_true(session.try_poll())
	assert_true(session.accept_http(200, _waiting(session.queue_token, 2, 60000)))
	assert_eq(session.state, MatchJoinSession.STATE_WAITING)
	assert_eq(session.position, 2)
	assert_eq(session.estimated_wait_ms, 60000)


func test_join_room_normalizes_case_and_rejects_invalid() -> void:
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_false(session.try_join_room(""))
	assert_false(session.try_join_room("IIIIII"))
	assert_false(session.try_join_room("ABC"))
	assert_false(session.has_pending())
	assert_true(session.try_join_room("  abcd23  "))
	assert_eq(session.pending_path(), "/matchmaking/rooms/ABCD23/join")
	assert_eq(MatchJoinSession.normalize_room_code("abcd23"), "ABCD23")


func test_join_full_room_fails_without_queue() -> void:
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_true(session.try_join_room("ABCD23"))
	assert_true(session.accept_http(409, {"error": "room_full"}))
	assert_eq(session.state, MatchJoinSession.STATE_FAILED)
	assert_eq(session.error, "room_full")
	assert_eq(session.ticket, "")
	assert_eq(session.queue_token, "")


func test_unknown_and_invalid_room_errors() -> void:
	var missing: MatchJoinSession = MatchJoinSession.create()
	assert_true(missing.try_join_room("ABCD23"))
	assert_true(missing.accept_http(404, {"error": "room_not_found"}))
	assert_eq(missing.error, "room_not_found")
	var invalid: MatchJoinSession = MatchJoinSession.create()
	assert_true(invalid.try_join_room("ABCD23"))
	assert_true(invalid.accept_http(400, {"error": "invalid_room_code"}))
	assert_eq(invalid.error, "invalid_room_code")


func test_cancel_waiting_returns_idle_and_ready_cannot_cancel() -> void:
	var session: MatchJoinSession = _waiting_session()
	assert_true(session.try_cancel())
	assert_eq(session.pending_method(), "DELETE")
	assert_true(session.accept_http(200, {"ok": true}))
	assert_eq(session.state, MatchJoinSession.STATE_IDLE)
	assert_eq(session.queue_token, "")
	assert_false(session.has_pending())
	assert_true(session.try_quick())
	assert_true(session.accept_http(201, _join("ABCD23", "ticket-c")))
	assert_eq(session.state, MatchJoinSession.STATE_READY)
	assert_false(session.try_cancel())
	assert_false(session.try_quick())


func test_cancel_already_ready_stays_waiting_so_client_can_poll() -> void:
	var session: MatchJoinSession = _waiting_session()
	assert_true(session.try_cancel())
	assert_true(session.accept_http(409, {"error": "queue_already_ready"}))
	assert_eq(session.state, MatchJoinSession.STATE_WAITING)
	assert_eq(session.error, "queue_already_ready")
	assert_true(session.try_poll())
	assert_true(session.accept_http(200, _ready_view("ABCD23", "ticket-d")))
	assert_eq(session.state, MatchJoinSession.STATE_READY)


func test_queue_failed_and_not_found() -> void:
	var failed: MatchJoinSession = _waiting_session()
	assert_true(failed.try_poll())
	assert_true(failed.accept_http(200, {"status": "failed", "error": "session_launch_failed"}))
	assert_eq(failed.state, MatchJoinSession.STATE_FAILED)
	assert_eq(failed.error, "session_launch_failed")
	var missing: MatchJoinSession = _waiting_session()
	assert_true(missing.try_poll())
	assert_true(missing.accept_http(404, {"error": "queue_not_found"}))
	assert_eq(missing.error, "queue_not_found")


func test_host_unavailable_and_launch_failure() -> void:
	var none: MatchJoinSession = MatchJoinSession.create()
	assert_true(none.try_quick())
	assert_true(none.accept_http(503, {"error": "match_host_unavailable"}))
	assert_eq(none.error, "match_host_unavailable")
	var boom: MatchJoinSession = MatchJoinSession.create()
	assert_true(boom.try_create_room())
	assert_true(boom.accept_http(502, {
		"error": "session_launch_failed",
		"message": "spawn failed",
	}))
	assert_eq(boom.error, "session_launch_failed")


func test_rejects_extra_or_missing_fields() -> void:
	var extra: MatchJoinSession = MatchJoinSession.create()
	assert_true(extra.try_quick())
	var join_body: Dictionary = _join("ABCD23", "ticket-e")
	join_body["extra"] = true
	assert_true(extra.accept_http(201, join_body))
	assert_eq(extra.state, MatchJoinSession.STATE_FAILED)
	assert_eq(extra.error, "parse_error")
	var missing: MatchJoinSession = MatchJoinSession.create()
	assert_true(missing.try_quick())
	assert_true(missing.accept_http(201, {"ticket": "only"}))
	assert_eq(missing.error, "parse_error")
	var cancel_extra: MatchJoinSession = _waiting_session()
	assert_true(cancel_extra.try_cancel())
	assert_true(cancel_extra.accept_http(200, {"ok": true, "extra": 1}))
	assert_eq(cancel_extra.error, "parse_error")


func test_accept_without_pending_is_ignored() -> void:
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_false(session.accept_http(201, _join("ABCD23", "ticket-f")))
	assert_eq(session.state, MatchJoinSession.STATE_IDLE)


func test_neighbor_sessions_do_not_share_tickets() -> void:
	var first: MatchJoinSession = MatchJoinSession.create()
	var second: MatchJoinSession = MatchJoinSession.create()
	assert_true(first.try_quick())
	assert_true(second.try_create_room())
	assert_true(first.accept_http(201, _join("ABCD23", "ticket-g")))
	assert_true(second.accept_http(202, _waiting("queue-token-bbbbbbbbbbbbbbbb", 1, 30000)))
	assert_eq(first.ticket, "ticket-g")
	assert_eq(second.ticket, "")
	assert_eq(second.queue_token, "queue-token-bbbbbbbbbbbbbbbb")
	assert_ne(first.ticket, second.queue_token)


func test_http_url_and_json_helpers() -> void:
	assert_eq(
		MatchJoinSession.http_url("http://127.0.0.1:8080/", "/matchmaking/quick"),
		"http://127.0.0.1:8080/matchmaking/quick"
	)
	assert_eq(MatchJoinSession.http_url("ws://127.0.0.1:8080", "/matchmaking/quick"), "")
	assert_eq(MatchJoinSession.http_url("http://127.0.0.1:8080", "quick"), "")
	var parsed: Dictionary = MatchJoinSession.parse_json_object("{\"ok\":true}")
	var parsed_ok: bool = parsed.get("ok", false)
	assert_true(parsed_ok)
	var bad: Dictionary = MatchJoinSession.parse_json_object("[1]")
	var bad_ok: bool = bad.get("ok", false)
	assert_false(bad_ok)
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_true(session.try_quick())
	assert_true(session.apply_http_text(201, JSON.stringify(_join("ABCD23", "ticket-h"))))
	assert_eq(session.state, MatchJoinSession.STATE_READY)
	assert_eq(session.ticket, "ticket-h")


func test_json_whole_floats_are_accepted() -> void:
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_true(session.try_quick())
	assert_true(session.apply_http_text(202, JSON.stringify(_waiting("queue-token-cccccccccccccccc", 1, 30000))))
	assert_eq(session.state, MatchJoinSession.STATE_WAITING)
	assert_eq(session.position, 1)
	assert_eq(session.estimated_wait_ms, 30000)


func test_reconnect_from_ready_replaces_ticket() -> void:
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_true(session.try_quick())
	assert_true(session.accept_http(201, _join("ABCD23", "ticket-a")))
	assert_false(session.try_quick())
	assert_true(session.try_reconnect())
	assert_eq(session.pending_method(), "POST")
	assert_eq(session.pending_path(), "/match-sessions/match-1/tickets/reconnect")
	assert_true(session.pending_body().contains("ticket-a"))
	assert_true(session.accept_http(201, {
		"ticket": "ticket-b",
		"matchId": "match-1",
		"expiresAt": "2026-08-25T04:11:00.000Z",
	}))
	assert_eq(session.state, MatchJoinSession.STATE_READY)
	assert_eq(session.ticket, "ticket-b")
	assert_eq(session.room_code, "ABCD23")
	assert_eq(session.match_id, "match-1")
	assert_false(session.has_pending())


func test_reconnect_rejects_unconsumed_path_errors_and_idle() -> void:
	var idle: MatchJoinSession = MatchJoinSession.create()
	assert_false(idle.try_reconnect())
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_true(session.try_quick())
	assert_true(session.accept_http(201, _join("ABCD23", "ticket-a")))
	assert_true(session.try_reconnect())
	assert_true(session.accept_http(400, {"error": "ticket_not_consumed"}))
	assert_eq(session.state, MatchJoinSession.STATE_FAILED)
	assert_eq(session.error, "ticket_not_consumed")
	assert_eq(session.ticket, "")
	var extra: MatchJoinSession = MatchJoinSession.create()
	assert_true(extra.try_quick())
	assert_true(extra.accept_http(201, _join("ABCD23", "ticket-c")))
	assert_true(extra.try_reconnect())
	assert_true(extra.accept_http(201, {
		"ticket": "ticket-d",
		"matchId": "match-1",
		"expiresAt": "2026-08-25T04:11:00.000Z",
		"extra": true,
	}))
	assert_eq(extra.error, "parse_error")
	var gone: MatchJoinSession = MatchJoinSession.create()
	assert_true(gone.try_quick())
	assert_true(gone.accept_http(201, _join("ABCD23", "ticket-e")))
	assert_true(gone.try_reconnect())
	assert_true(gone.accept_http(404, {"error": "match_not_found"}))
	assert_eq(gone.error, "match_not_found")


func _waiting_session() -> MatchJoinSession:
	var session: MatchJoinSession = MatchJoinSession.create()
	assert_true(session.try_create_room())
	assert_true(session.accept_http(202, _waiting("queue-token-aaaaaaaaaaaaaaaa", 1, 30000)))
	return session


func _join(room_code: String, ticket: String) -> Dictionary:
	return {
		"roomCode": room_code,
		"ticket": ticket,
		"matchId": "match-1",
		"expiresAt": "2026-08-25T03:00:00.000Z",
		"seats": 2,
		"issued": 1,
	}


func _waiting(token: String, position: int, estimated_wait_ms: int) -> Dictionary:
	return {
		"status": "waiting",
		"queueToken": token,
		"position": position,
		"estimatedWaitMs": estimated_wait_ms,
		"expiresAt": "2026-08-25T02:10:00.000Z",
	}


func _ready_view(room_code: String, ticket: String) -> Dictionary:
	var body: Dictionary = _join(room_code, ticket)
	body["status"] = "ready"
	return body
