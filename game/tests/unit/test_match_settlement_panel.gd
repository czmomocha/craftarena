extends GutTest

## F-line FA: settlement table is presentation of an already-built board.

const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const MatchSettlementPanelGd := preload("res://src/shared/match_settlement_panel.gd")
const PlayClockGd := preload("res://src/shared/play_clock.gd")


func test_format_rows_lists_place_slot_and_clock() -> void:
	var text: String = MatchSettlementPanelGd.format_rows({
		"ok": true,
		"mvp_slot": 1,
		"pad_total": 3,
		"rows": [
			{"place": 1, "slot": 1, "finish_tick": 60, "accepted_count": 3},
			{"place": 2, "slot": 0, "finish_tick": 90, "accepted_count": 3},
		],
	})
	assert_true(text.contains("#1  s1  %s" % PlayClockGd.format_clock(60)))
	assert_true(text.contains("#2  s0  %s" % PlayClockGd.format_clock(90)))
	assert_eq(MatchSettlementPanelGd.format_rows({"ok": false}), "")


func test_solo_shows_live_clock_and_hides_panel_until_finished() -> void:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	add_child_autofree(shell)
	assert_true(shell.open())
	assert_eq(shell.clock_label_text(), "")
	assert_false(shell.settlement_panel_visible())
	assert_true(shell.try_solo())
	assert_true(shell.status_label_text().contains("clock="))
	assert_true(shell.clock_label_text().begins_with("0:"))
	assert_false(shell.settlement_panel_visible())
	assert_true(shell.try_cancel())
	assert_eq(shell.clock_label_text(), "")
