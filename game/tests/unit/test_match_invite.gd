extends GutTest

## Shareable invites: room code only. Content id never goes in the URL.

const MatchInviteGd := preload("res://src/client/match_invite.gd")
const MatchLobbyChromeGd := preload("res://src/client/match_lobby_chrome.gd")
const MatchLobbyHudGd := preload("res://src/client/match_lobby_hud.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")


var _shell: MatchLobbyShellGd = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_web_query_is_room_only() -> void:
	assert_eq(MatchInviteGd.web_query("  abcd23  "), "?room=ABCD23")
	assert_eq(MatchInviteGd.web_query("IIIIII"), "")
	assert_eq(MatchInviteGd.web_query(""), "")
	var query: String = MatchInviteGd.web_query("ABCD23")
	assert_false(query.contains("content"))
	assert_eq(
		MatchInviteGd.web_url("https://play.example.test/", "ABCD23"),
		"https://play.example.test?room=ABCD23"
	)


func test_desktop_text_and_parse_round_trip() -> void:
	assert_eq(
		MatchInviteGd.desktop_text("127.0.0.1:8080", "abcd23"),
		"127.0.0.1:8080 ABCD23"
	)
	assert_eq(MatchInviteGd.parse_room("127.0.0.1:8080 ABCD23"), "ABCD23")
	assert_eq(MatchInviteGd.parse_room("?room=ABCD23"), "ABCD23")
	assert_eq(MatchInviteGd.parse_room("ABCD23"), "ABCD23")
	assert_eq(MatchInviteGd.parse_room(""), "")


func test_lobby_invite_box_is_host_and_code() -> void:
	_shell = MatchLobbyShellGd.create()
	add_child(_shell)
	assert_true(_shell.open())
	var invite: LineEdit = _shell.window.get_node("VBoxContainer/InviteActions/%s" % MatchLobbyChromeGd.INVITE_NAME) as LineEdit
	assert_not_null(invite)
	assert_false(invite.editable)
	var copy: Button = _shell.window.get_node("VBoxContainer/InviteActions/%s" % MatchLobbyChromeGd.COPY_INVITE_NAME) as Button
	assert_not_null(copy)
	assert_eq(copy.text, UiCopy.text(UiCopy.COPY_INVITE))
	assert_true(_shell.join.try_quick())
	assert_true(_shell.join.accept_http(201, {
		"roomCode": "ABCD23",
		"ticket": "ticket-invite",
		"matchId": "match-1",
		"expiresAt": "2026-09-11T14:00:00.000Z",
		"seats": 2,
		"issued": 1,
		"seat": 0,
		"course": "course_01",
	}))
	_shell.refresh_status()
	assert_eq(invite.text, "127.0.0.1:8080 ABCD23")
	assert_false(invite.text.contains("content"))


func test_hud_shows_content_not_selected_official_course() -> void:
	var line: String = MatchLobbyHudGd.format_line({
		"course": "",
		"course_id": "course_01",
		"content_id": "ugc_aabbccddeeff00112233445566778899",
		"join_state": "ready",
	})
	assert_true(line.contains("content=ugc_aabbccddeeff00112233445566778899"))
	assert_false(line.contains("course_id=course_01"))
