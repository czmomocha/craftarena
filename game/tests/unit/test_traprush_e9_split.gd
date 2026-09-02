extends GutTest

## C5 第 10 章：灰盒课程 + 完成探针按层拆门面。
## 断言的是拆分性质与 E9 行数，不是玩法数值。现有
## test_traprush_graybox_course.gd / test_traprush_course_completion_probe.gd
## 仍覆盖公开 API。

const GrayboxGd := preload("res://src/games/traprush/graybox_course.gd")
const ProbeGd := preload("res://src/games/traprush/course_completion_probe.gd")

const E9_LINE_CAP: int = 400
const GRAYBOX_PATHS: PackedStringArray = [
	"res://src/games/traprush/graybox_course.gd",
	"res://src/games/traprush/graybox_course_layout.gd",
	"res://src/games/traprush/graybox_course_assemble.gd",
	"res://src/games/traprush/graybox_course_play.gd",
]
const PROBE_PATHS: PackedStringArray = [
	"res://src/games/traprush/course_completion_probe.gd",
	"res://src/games/traprush/course_completion_probe_heuristic.gd",
	"res://src/games/traprush/course_completion_probe_search.gd",
]


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func test_graybox_files_stay_under_e9_line_cap() -> void:
	for path: String in GRAYBOX_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_probe_files_stay_under_e9_line_cap() -> void:
	for path: String in PROBE_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_graybox_assemble_stays_on_the_facade() -> void:
	assert_null(GrayboxGd.assemble({}))


func test_probe_run_path_stays_on_the_facade() -> void:
	var result: Dictionary = ProbeGd.run_path("res://does_not_exist.json")
	var outcome_raw: Variant = result.get("outcome", "")
	assert_true(typeof(outcome_raw) == TYPE_STRING)
	var outcome: String = outcome_raw
	assert_eq(outcome, ProbeGd.OUTCOME_INVALID_COURSE)
