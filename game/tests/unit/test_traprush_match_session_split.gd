extends GutTest

## C5 第 3 章：TraprushMatchSession 拆成 bootstrap / intents / scan / view。
## 断言的是拆分性质与 E9 行数，不是玩法数值。现有
## test_traprush_match_session.gd 仍覆盖公开 API。

const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")

const E9_LINE_CAP: int = 400
const SESSION_PATHS: PackedStringArray = [
	"res://src/games/traprush/match_session.gd",
	"res://src/games/traprush/match_session_bootstrap.gd",
	"res://src/games/traprush/match_session_intents.gd",
	"res://src/games/traprush/match_session_scan.gd",
	"res://src/games/traprush/match_session_view.gd",
]


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func test_session_files_stay_under_e9_line_cap() -> void:
	for path: String in SESSION_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_new_session_owns_collaborators() -> void:
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.new()
	assert_not_null(session.intents)
	assert_not_null(session.scan)
	assert_not_null(session.view)
	assert_eq(session.player_count(), 0)
	assert_eq(session.tick_index(), 0)


func test_step_caps_stay_on_the_facade() -> void:
	assert_eq(TraprushMatchSessionGd.MOVE_STEP_MAX, Fixed.SCALE)
	assert_eq(TraprushMatchSessionGd.SHOVE_STEP_MAX, Fixed.SCALE)
	assert_eq(TraprushMatchSessionGd.SHOVE_REACH_MAX, Fixed.SCALE)
	assert_eq(TraprushMatchSessionGd.SPRINT_STEP_MAX, Fixed.SCALE)
	assert_true(TraprushMatchSessionGd.move_step_allowed(Fixed.SCALE, 0))
	assert_false(TraprushMatchSessionGd.move_step_allowed(Fixed.SCALE + 1, 0))
	assert_true(TraprushMatchSessionGd.shove_step_allowed(Fixed.SCALE))
	assert_false(TraprushMatchSessionGd.shove_step_allowed(Fixed.SCALE + 1))
	assert_true(TraprushMatchSessionGd.sprint_step_allowed(0))
	assert_false(TraprushMatchSessionGd.sprint_step_allowed(-1))
