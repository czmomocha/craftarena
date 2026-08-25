extends GutTest

## TraprushStanding: live board from snapshot accepted_count / finish_tick.
## CD-21 §6.1 items 1–2 plus slot as a stable key. Path distance and
## pad-arrival time stay deferred. Never settlement.

const TraprushStanding := preload("res://src/games/traprush/standing.gd")


func test_empty_players_are_ok_without_mvp() -> void:
	var standing: Dictionary = TraprushStanding.from_players([])
	var ok: bool = standing.get("ok", false)
	assert_true(ok)
	var rows: Array = _rows_of(standing)
	assert_eq(rows.size(), 0)
	var mvp_slot: int = standing.get("mvp_slot", 0)
	assert_eq(mvp_slot, -1)
	assert_eq(TraprushStanding.format_line(standing), "standings=- mvp=-")


func test_finished_players_rank_by_finish_tick_then_slot() -> void:
	var standing: Dictionary = TraprushStanding.from_players([
		_player(1, 12),
		_player(1, 4),
		_player(1, 4),
	])
	var ok: bool = standing.get("ok", false)
	assert_true(ok)
	var rows: Array = _rows_of(standing)
	assert_eq(rows.size(), 3)
	_assert_row(rows[0], 1, 1, 4, true)
	_assert_row(rows[1], 2, 2, 4, true)
	_assert_row(rows[2], 0, 3, 12, true)
	var mvp_slot: int = standing.get("mvp_slot", -2)
	assert_eq(mvp_slot, 1)
	assert_eq(TraprushStanding.format_line(standing), "standings=#1s1,#2s2,#3s0 mvp=1")


func test_unfinished_follow_finishers_by_accepted_count() -> void:
	var standing: Dictionary = TraprushStanding.from_players([
		_player(1, -1),
		_player(3, 9),
		_player(2, -1),
		_player(2, -1),
	], 3)
	var ok: bool = standing.get("ok", false)
	assert_true(ok)
	var rows: Array = _rows_of(standing)
	assert_eq(rows.size(), 4)
	_assert_row(rows[0], 1, 1, 9, true)
	_assert_row(rows[1], 2, 2, -1, false)
	_assert_row(rows[2], 3, 3, -1, false)
	_assert_row(rows[3], 0, 4, -1, false)
	var second: Dictionary = rows[1]
	var accepted_count: int = second.get("accepted_count", -1)
	var pad_total: int = second.get("pad_total", -1)
	assert_eq(accepted_count, 2)
	assert_eq(pad_total, 3)
	var mvp_slot: int = standing.get("mvp_slot", -2)
	assert_eq(mvp_slot, 1)


func test_rejects_malformed_players_and_negative_pad_total() -> void:
	assert_false(_ok_of(TraprushStanding.from_players([{"finish_tick": 1}])))
	assert_false(_ok_of(TraprushStanding.from_players([{"accepted_count": 1}])))
	assert_false(_ok_of(TraprushStanding.from_players([_player(-1, -1)])))
	assert_false(_ok_of(TraprushStanding.from_players([_player(0, -2)])))
	assert_false(_ok_of(TraprushStanding.from_players([_player(0, -1)], -1)))
	assert_false(_ok_of(TraprushStanding.from_players(["nope"])))
	assert_eq(TraprushStanding.format_line({"ok": false}), "")


func _player(accepted_count: int, finish_tick: int) -> Dictionary:
	return {
		"accepted_count": accepted_count,
		"finish_tick": finish_tick,
	}


func _ok_of(standing: Dictionary) -> bool:
	var ok: bool = standing.get("ok", true)
	return ok


func _rows_of(standing: Dictionary) -> Array:
	var rows_raw: Variant = standing.get("rows", [1])
	assert_eq(typeof(rows_raw), TYPE_ARRAY)
	var rows: Array = rows_raw
	return rows


func _assert_row(raw: Variant, slot: int, place: int, finish_tick: int, finished: bool) -> void:
	assert_eq(typeof(raw), TYPE_DICTIONARY)
	var row: Dictionary = raw
	var row_slot: int = row.get("slot", -3)
	var row_place: int = row.get("place", -3)
	var row_finish: int = row.get("finish_tick", -3)
	var row_finished: bool = row.get("finished", not finished)
	assert_eq(row_slot, slot)
	assert_eq(row_place, place)
	assert_eq(row_finish, finish_tick)
	assert_eq(row_finished, finished)
