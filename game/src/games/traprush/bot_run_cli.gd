class_name TraprushBotRunCli
extends RefCounted

## BotRunner 的引擎侧入口（纠偏 C2；C3 第 7 章补上安全路约束）。
##
##     CraftArena.exe --headless -- --bot-run
##     godot --headless --path game -- --bot-run --course=course_03
##     godot --headless --path game -- --bot-run --course=course_01 --route=safe
##
## 每张课打印一行 JSON，最后打印一行汇总，任一张走不通就 exit 1。所以外层
## （`tools/bot-runner`、CI、人）只要看退出码，不用去读一屏日志找结论。
##
## 只接受官方课 id，不接受 res:// 路径：这条命令将来会被自动化调用，路径参数
## 等于给了它读任意文件的口子，而 UGC 永远不可信（宪法第三条）。
##
## `--route=safe` 只对 course_01 有意义：封掉 +X 捷径上楼 two_way（entity 10），
## 再重放 C3 第 5 章已经走通的四向安全路。其它课没有这条语义，带 `--route=safe`
## 就整体拒绝，而不是悄悄当 any 跑。默认不带约束，仍走捷径。
##
## 判定强度与动作集的边界写在 TraprushCourseCompletionProbe 的文件头，
## 那里也解释了为什么 not_completable 不等于「人也过不去」。

const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const OfficialTraprushCourses := preload("res://src/shared/official_traprush_courses.gd")

const FLAG: String = "--bot-run"
const COURSE_FLAG: String = "--course"
const MAX_TICKS_FLAG: String = "--max-ticks"
const MAX_DEPTH_FLAG: String = "--max-depth"
const ROUTE_FLAG: String = "--route"
const FORBID_PORTAL_FLAG: String = "--forbid-portal"

const ROUTE_ANY: String = "any"
const ROUTE_SAFE: String = "safe"
## course_01 危险捷径上楼的 two_way 源。不是产品关卡 id，只是这张课的搜索约束。
const COURSE_01_SHORTCUT_PORTAL_ID: int = 10

const COURSE_EVENT: String = "bot_run_course"
const SUMMARY_EVENT: String = "bot_run_summary"
const ERROR_EVENT: String = "bot_run_error"


static func requested(user_args: PackedStringArray) -> bool:
	return user_args.has(FLAG)


static func run_and_print(user_args: PackedStringArray) -> int:
	var route: String = resolve_route(user_args)
	if route == "":
		print(JSON.stringify({
			"event": ERROR_EVENT,
			"error": "unknown_route",
			"detail": _raw_value(user_args, ROUTE_FLAG),
		}))
		return 1
	var courses: PackedStringArray = resolve_courses(user_args)
	if courses.is_empty():
		print(JSON.stringify({
			"event": ERROR_EVENT,
			"error": "unknown_course",
			"detail": _raw_value(user_args, COURSE_FLAG),
		}))
		return 1
	if route == ROUTE_SAFE:
		for course_id: String in courses:
			if course_id != OfficialTraprushCourses.COURSE_01:
				print(JSON.stringify({
					"event": ERROR_EVENT,
					"error": "safe_route_requires_course_01",
					"detail": course_id,
				}))
				return 1
	var forbid_parsed: Dictionary = resolve_forbid_portals(user_args)
	var forbid_ok: bool = forbid_parsed.get("ok", false)
	if not forbid_ok:
		print(JSON.stringify({
			"event": ERROR_EVENT,
			"error": "bad_forbid_portal",
			"detail": _raw_value(user_args, FORBID_PORTAL_FLAG),
		}))
		return 1
	var forbid_ids_raw: Variant = forbid_parsed["ids"]
	if typeof(forbid_ids_raw) != TYPE_PACKED_INT32_ARRAY:
		print(JSON.stringify({"event": ERROR_EVENT, "error": "bad_forbid_portal"}))
		return 1
	var forbid_portals: PackedInt32Array = forbid_ids_raw
	if route == ROUTE_SAFE:
		forbid_portals = _append_unique(forbid_portals, COURSE_01_SHORTCUT_PORTAL_ID)
	var max_ticks: int = _budget_ticks(user_args, route)
	var max_depth: int = _int_value(
		user_args, MAX_DEPTH_FLAG, CourseCompletionProbe.DEFAULT_MAX_DEPTH
	)
	if max_ticks < 1 or max_depth < 1:
		print(JSON.stringify({"event": ERROR_EVENT, "error": "bad_budget"}))
		return 1
	var action_count: int = CourseCompletionProbe.ACTION_SET_FULL
	var hint_actions: PackedByteArray = PackedByteArray()
	if route == ROUTE_SAFE:
		action_count = CourseCompletionProbe.ACTION_SET_CARDINAL
		hint_actions = CourseCompletionProbe.course_01_safe_cardinal()

	var started: int = Time.get_ticks_msec()
	var completable: int = 0
	for course_id: String in courses:
		var course_started: int = Time.get_ticks_msec()
		var path: String = OfficialTraprushCourses.document_path(course_id)
		var result: Dictionary = CourseCompletionProbe.run_path(
			path, max_ticks, max_depth, forbid_portals, action_count, hint_actions
		)
		var outcome: String = result["outcome"]
		if outcome == CourseCompletionProbe.OUTCOME_COMPLETABLE:
			completable += 1
		var line: Dictionary = result.duplicate()
		line["event"] = COURSE_EVENT
		line["course"] = course_id
		line["route"] = route
		line["action_count"] = action_count
		line["wall_ms"] = Time.get_ticks_msec() - course_started
		print(JSON.stringify(line))

	var total: int = courses.size()
	print(JSON.stringify({
		"event": SUMMARY_EVENT,
		"ok": completable == total,
		"total": total,
		"completable": completable,
		"not_completable": total - completable,
		"route": route,
		"max_ticks": max_ticks,
		"max_depth": max_depth,
		"action_count": action_count,
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


static func resolve_route(user_args: PackedStringArray) -> String:
	var raw: String = _raw_value(user_args, ROUTE_FLAG)
	if raw == "":
		return ROUTE_ANY
	if raw == ROUTE_ANY or raw == ROUTE_SAFE:
		return raw
	return ""


## 解析 `--forbid-portal=`。非法数字返回 `{ok: false}`。
static func resolve_forbid_portals(user_args: PackedStringArray) -> Dictionary:
	var ids: PackedInt32Array = PackedInt32Array()
	var raw: String = _raw_value(user_args, FORBID_PORTAL_FLAG)
	if raw == "":
		return {"ok": true, "ids": ids}
	for piece: String in raw.split(",", false):
		var token: String = piece.strip_edges()
		if not token.is_valid_int():
			return {"ok": false, "ids": PackedInt32Array()}
		var entity_id: int = token.to_int()
		if entity_id < 1:
			return {"ok": false, "ids": PackedInt32Array()}
		ids = _append_unique(ids, entity_id)
	return {"ok": true, "ids": ids}


static func _budget_ticks(user_args: PackedStringArray, route: String) -> int:
	var raw: String = _raw_value(user_args, MAX_TICKS_FLAG)
	if raw == "":
		if route == ROUTE_SAFE:
			return CourseCompletionProbe.SAFE_ROUTE_MAX_TICKS
		return CourseCompletionProbe.DEFAULT_MAX_TICKS
	if not raw.is_valid_int():
		return 0
	return raw.to_int()


static func _append_unique(ids: PackedInt32Array, entity_id: int) -> PackedInt32Array:
	for existing: int in ids:
		if existing == entity_id:
			return ids
	var next: PackedInt32Array = ids.duplicate()
	next.append(entity_id)
	return next


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
