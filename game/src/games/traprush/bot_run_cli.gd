class_name TraprushBotRunCli
extends RefCounted

## BotRunner 的引擎侧入口（纠偏 C2）。
##
##     CraftArena.exe --headless -- --bot-run
##     godot --headless --path game -- --bot-run --course=course_03
##
## 每张课打印一行 JSON，最后打印一行汇总，任一张走不通就 exit 1。所以外层
## （`tools/bot-runner`、CI、人）只要看退出码，不用去读一屏日志找结论。
##
## 只接受官方课 id，不接受 res:// 路径：这条命令将来会被自动化调用，路径参数
## 等于给了它读任意文件的口子，而 UGC 永远不可信（宪法第三条）。
##
## 判定强度与动作集的边界写在 TraprushCourseCompletionProbe 的文件头，
## 那里也解释了为什么 not_completable 不等于「人也过不去」。

const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const OfficialTraprushCourses := preload("res://src/shared/official_traprush_courses.gd")

const FLAG: String = "--bot-run"
const COURSE_FLAG: String = "--course"
const MAX_TICKS_FLAG: String = "--max-ticks"
const MAX_DEPTH_FLAG: String = "--max-depth"

const COURSE_EVENT: String = "bot_run_course"
const SUMMARY_EVENT: String = "bot_run_summary"
const ERROR_EVENT: String = "bot_run_error"


static func requested(user_args: PackedStringArray) -> bool:
	return user_args.has(FLAG)


static func run_and_print(user_args: PackedStringArray) -> int:
	var courses: PackedStringArray = resolve_courses(user_args)
	if courses.is_empty():
		print(JSON.stringify({
			"event": ERROR_EVENT,
			"error": "unknown_course",
			"detail": _raw_value(user_args, COURSE_FLAG),
		}))
		return 1
	var max_ticks: int = _int_value(
		user_args, MAX_TICKS_FLAG, CourseCompletionProbe.DEFAULT_MAX_TICKS
	)
	var max_depth: int = _int_value(
		user_args, MAX_DEPTH_FLAG, CourseCompletionProbe.DEFAULT_MAX_DEPTH
	)
	if max_ticks < 1 or max_depth < 1:
		print(JSON.stringify({"event": ERROR_EVENT, "error": "bad_budget"}))
		return 1

	var started: int = Time.get_ticks_msec()
	var completable: int = 0
	for course_id: String in courses:
		var course_started: int = Time.get_ticks_msec()
		var path: String = OfficialTraprushCourses.document_path(course_id)
		var result: Dictionary = CourseCompletionProbe.run_path(path, max_ticks, max_depth)
		var outcome: String = result["outcome"]
		if outcome == CourseCompletionProbe.OUTCOME_COMPLETABLE:
			completable += 1
		var line: Dictionary = result.duplicate()
		line["event"] = COURSE_EVENT
		line["course"] = course_id
		line["wall_ms"] = Time.get_ticks_msec() - course_started
		print(JSON.stringify(line))

	var total: int = courses.size()
	print(JSON.stringify({
		"event": SUMMARY_EVENT,
		"ok": completable == total,
		"total": total,
		"completable": completable,
		"not_completable": total - completable,
		"max_ticks": max_ticks,
		"max_depth": max_depth,
		"wall_ms": Time.get_ticks_msec() - started,
	}))
	return 0 if completable == total else 1


## 缺省跑全部官方课。`--course=` 接一个 id 或逗号分隔的多个；出现任何一个不认识
## 的 id 就整体判非法，而不是悄悄跳过——静默跳过会让「三张全绿」这句话失真。
static func resolve_courses(user_args: PackedStringArray) -> PackedStringArray:
	var raw: String = _raw_value(user_args, COURSE_FLAG)
	if raw == "":
		return PackedStringArray([
			OfficialTraprushCourses.COURSE_01,
			OfficialTraprushCourses.COURSE_02,
			OfficialTraprushCourses.COURSE_03,
		])
	var resolved: PackedStringArray = PackedStringArray()
	for piece: String in raw.split(",", false):
		var course_id: String = OfficialTraprushCourses.normalize_id(piece)
		if course_id == "":
			return PackedStringArray()
		resolved.append(course_id)
	return resolved


static func _raw_value(user_args: PackedStringArray, flag: String) -> String:
	var prefix: String = "%s=" % flag
	for arg: String in user_args:
		if arg.begins_with(prefix):
			return arg.substr(prefix.length()).strip_edges()
	return ""


static func _int_value(user_args: PackedStringArray, flag: String, fallback: int) -> int:
	var raw: String = _raw_value(user_args, flag)
	if raw == "" or not raw.is_valid_int():
		return fallback
	return raw.to_int()
