class_name TraprushBotRunCli
extends RefCounted

## BotRunner 的引擎侧入口（纠偏 C2；C3 第 7 章补上安全路约束）。
##
##     CraftArena.exe --headless -- --bot-run
##     godot --headless --path game -- --bot-run --course=course_03
##     godot --headless --path game -- --bot-run --course=course_01 --route=safe
##
## 每张课打印一行 JSON，最后打印一行汇总，任一张走不通就 exit 1。产品入口是
## `npm run bot-run`（`tools/bot-runner/` 薄壳）：把这些行收成报告 JSON。外层
## 只要看退出码，不用去读一屏日志找结论。
##
## 只接受官方课 id，不接受 res:// 路径：这条命令将来会被自动化调用，路径参数
## 等于给了它读任意文件的口子，而 UGC 永远不可信（宪法第三条）。
##
## `--route=safe` 只对 course_01 有意义：封掉 +X 捷径上楼 two_way（entity 10），
## 再重放 C3 第 5 章已经走通的四向安全路。其它课没有这条语义，带 `--route=safe`
## 就整体拒绝，而不是悄悄当 any 跑。默认不带约束，仍走捷径。
## `course_05` 默认重放能量墙短路脚本（站其 −Z 侧 Q 打碎）；A* 会抄空中对角绕墙，
## 那不是产品路线，所以不搜索。安全长路存在但不接线 `--route=safe`。
## `course_06` 默认重放三连传送爬楼脚本；探针动作集爬不上一整格，启发式只
## 允许两次传送中转，三跳会把预算耗尽，所以不搜索。
## `course_07` 默认重放四段折返 + 三连传送脚本；A* 两次中转不够三段传送，
## 所以不搜索。
## `course_f_playable` 在 `--route=any` 下重放危险捷径脚本（站在主路能量墙
##
## `--pace=human` 走人跑（TraprushHumanPaceRunner），缺省 / `--pace=probe` /
## 省略仍是探针。未知 pace 整体拒绝，不悄悄当探针。人跑必须有磁带：`--tape=`
## 为人跑每 tick 码，或把本课已有探针脚本展成 1 格 = SCALE/MOVE_STEP 个 Move
## tick。没有可跑磁带的课打 JSON error，不拿探针快路冒充人跑。
##
## 判定强度与动作集的边界写在 TraprushCourseCompletionProbe 的文件头，
## 那里也解释了为什么 not_completable 不等于「人也过不去」。

const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const Course05Scripts := preload("res://src/games/traprush/course_05_scripts.gd")
const Course06Scripts := preload("res://src/games/traprush/course_06_scripts.gd")
const Course07Scripts := preload("res://src/games/traprush/course_07_scripts.gd")
const Course08Scripts := preload("res://src/games/traprush/course_08_scripts.gd")
const CourseFPlayableScripts := preload("res://src/games/traprush/course_f_playable_scripts.gd")
const HumanPaceRunner := preload("res://src/games/traprush/human_pace_runner.gd")
const OfficialTraprushCourses := preload("res://src/shared/official_traprush_courses.gd")

const FLAG: String = "--bot-run"
const COURSE_FLAG: String = "--course"
const MAX_TICKS_FLAG: String = "--max-ticks"
const MAX_DEPTH_FLAG: String = "--max-depth"
const ROUTE_FLAG: String = "--route"
const FORBID_PORTAL_FLAG: String = "--forbid-portal"
const PACE_FLAG: String = "--pace"
const TAPE_FLAG: String = "--tape"

const ROUTE_ANY: String = "any"
const ROUTE_SAFE: String = "safe"
const PACE_PROBE: String = "probe"
const PACE_HUMAN: String = "human"
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
	var pace: String = resolve_pace(user_args)
	if pace == "":
		print(JSON.stringify({
			"event": ERROR_EVENT,
			"error": "unknown_pace",
			"detail": _raw_value(user_args, PACE_FLAG),
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
	if pace == PACE_HUMAN:
		return _run_human_and_print(user_args, courses, route)
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
		var course_hint: PackedByteArray = hint_actions
		if course_id == OfficialTraprushCourses.COURSE_F_PLAYABLE and route == ROUTE_ANY:
			course_hint = CourseFPlayableScripts.fast_hint()
		elif course_id == OfficialTraprushCourses.COURSE_05 and route == ROUTE_ANY:
			course_hint = Course05Scripts.fast_hint()
		elif course_id == OfficialTraprushCourses.COURSE_06 and route == ROUTE_ANY:
			course_hint = Course06Scripts.climb_hint()
		elif course_id == OfficialTraprushCourses.COURSE_07 and route == ROUTE_ANY:
			course_hint = Course07Scripts.fast_hint()
		elif course_id == "course_08" and route == ROUTE_ANY:
			course_hint = Course08Scripts.fast_hint()
		var result: Dictionary = CourseCompletionProbe.run_path(
			path, max_ticks, max_depth, forbid_portals, action_count, course_hint
		)
		var outcome: String = result["outcome"]
		if outcome == CourseCompletionProbe.OUTCOME_COMPLETABLE:
			completable += 1
		var line: Dictionary = result.duplicate()
		line["event"] = COURSE_EVENT
		line["course"] = course_id
		line["route"] = route
		line["action_count"] = action_count
		line["max_ticks"] = max_ticks
		line["max_depth"] = max_depth
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


## 缺省跑全部匹配白名单课。`--course=` 接一个 id 或逗号分隔的多个；出现任何一个
## 不认识的 id 就整体判非法，而不是悄悄跳过——静默跳过会让「官方课全绿」失真。
static func resolve_courses(user_args: PackedStringArray) -> PackedStringArray:
	var raw: String = _raw_value(user_args, COURSE_FLAG)
	if raw == "":
		return OfficialTraprushCourses.all_match_ids()
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


## 缺省与 `--pace=probe` 都是探针。未知值回空，调用方整体拒绝。
static func resolve_pace(user_args: PackedStringArray) -> String:
	var raw: String = _raw_value(user_args, PACE_FLAG)
	if raw == "":
		return PACE_PROBE
	if raw == PACE_PROBE or raw == PACE_HUMAN:
		return raw
	return ""


## `--tape=` 为人跑每 tick 码。缺省 `{present: false}`；非法对角 / 非数字
## `{present: true, ok: false}`。
static func resolve_human_tape(user_args: PackedStringArray) -> Dictionary:
	if not _has_flag(user_args, TAPE_FLAG):
		return {"present": false, "ok": true, "tape": PackedByteArray(), "reason": ""}
	var raw: String = _raw_value(user_args, TAPE_FLAG)
	if raw == "":
		return {"present": true, "ok": false, "tape": PackedByteArray(), "reason": HumanPaceRunner.REASON_BAD_TAPE}
	var parsed: Dictionary = HumanPaceRunner.parse_tick_codes(raw)
	var parsed_ok: bool = parsed.get("ok", false)
	var tape_raw: Variant = parsed.get("tape", PackedByteArray())
	var tape: PackedByteArray = PackedByteArray()
	if typeof(tape_raw) == TYPE_PACKED_BYTE_ARRAY:
		tape = tape_raw
	return {
		"present": true,
		"ok": parsed_ok,
		"tape": tape,
		"reason": parsed.get("reason", HumanPaceRunner.REASON_BAD_TAPE),
	}


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


static func _run_human_and_print(
	user_args: PackedStringArray,
	courses: PackedStringArray,
	route: String
) -> int:
	var tape_parsed: Dictionary = resolve_human_tape(user_args)
	var tape_present: bool = tape_parsed.get("present", false)
	var tape_ok: bool = tape_parsed.get("ok", false)
	if tape_present and not tape_ok:
		print(JSON.stringify({
			"event": ERROR_EVENT,
			"error": "bad_tape",
			"detail": str(tape_parsed.get("reason", HumanPaceRunner.REASON_BAD_TAPE)),
		}))
		return 1
	var max_ticks: int = _human_budget(user_args)
	if max_ticks < 0:
		print(JSON.stringify({"event": ERROR_EVENT, "error": "bad_budget"}))
		return 1
	var explicit_raw: Variant = tape_parsed.get("tape", PackedByteArray())
	var explicit_tape: PackedByteArray = PackedByteArray()
	if typeof(explicit_raw) == TYPE_PACKED_BYTE_ARRAY:
		explicit_tape = explicit_raw
	var started: int = Time.get_ticks_msec()
	var completable: int = 0
	for course_id: String in courses:
		var course_started: int = Time.get_ticks_msec()
		var tape: PackedByteArray = PackedByteArray()
		if tape_present:
			tape = explicit_tape
		else:
			var hint: PackedByteArray = _course_scripted_hint(course_id, route)
			if hint.is_empty():
				print(JSON.stringify({
					"event": ERROR_EVENT,
					"error": "missing_human_tape",
					"detail": course_id,
				}))
				return 1
			var expanded: Dictionary = HumanPaceRunner.expand_probe_actions(hint)
			var expanded_ok: bool = expanded.get("ok", false)
			if not expanded_ok:
				print(JSON.stringify({
					"event": ERROR_EVENT,
					"error": str(expanded.get("reason", HumanPaceRunner.REASON_BAD_TAPE)),
					"detail": course_id,
				}))
				return 1
			var expanded_raw: Variant = expanded.get("tape", PackedByteArray())
			if typeof(expanded_raw) != TYPE_PACKED_BYTE_ARRAY:
				print(JSON.stringify({
					"event": ERROR_EVENT,
					"error": "bad_tape",
					"detail": course_id,
				}))
				return 1
			tape = expanded_raw
		var path: String = OfficialTraprushCourses.document_path(course_id)
		var result: Dictionary = HumanPaceRunner.run_path(path, tape, max_ticks)
		var outcome: String = result["outcome"]
		if outcome == HumanPaceRunner.OUTCOME_COMPLETABLE:
			completable += 1
		var line: Dictionary = result.duplicate()
		line["event"] = COURSE_EVENT
		line["course"] = course_id
		line["route"] = route
		line["pace"] = PACE_HUMAN
		line["max_ticks"] = max_ticks
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
		"pace": PACE_HUMAN,
		"max_ticks": max_ticks,
		"max_depth": 0,
		"action_count": 0,
		"wall_ms": Time.get_ticks_msec() - started,
	}))
	return 0 if completable == total else 1


## 与探针默认 hint 同一套接线。空 = 这张课没有可展的人跑磁带。
static func _course_scripted_hint(course_id: String, route: String) -> PackedByteArray:
	if route == ROUTE_SAFE and course_id == OfficialTraprushCourses.COURSE_01:
		return CourseCompletionProbe.course_01_safe_cardinal()
	if route != ROUTE_ANY:
		return PackedByteArray()
	if course_id == OfficialTraprushCourses.COURSE_F_PLAYABLE:
		return CourseFPlayableScripts.fast_hint()
	if course_id == OfficialTraprushCourses.COURSE_05:
		return Course05Scripts.fast_hint()
	if course_id == OfficialTraprushCourses.COURSE_06:
		return Course06Scripts.climb_hint()
	if course_id == OfficialTraprushCourses.COURSE_07:
		return Course07Scripts.fast_hint()
	if course_id == "course_08":
		return Course08Scripts.fast_hint()
	return PackedByteArray()


## 人跑省略 `--max-ticks` 为 0（跑完整磁带）。非法回 -1。
static func _human_budget(user_args: PackedStringArray) -> int:
	var raw: String = _raw_value(user_args, MAX_TICKS_FLAG)
	if raw == "":
		return 0
	if not raw.is_valid_int():
		return -1
	var parsed: int = raw.to_int()
	if parsed < 1:
		return -1
	return parsed


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


static func _has_flag(user_args: PackedStringArray, flag: String) -> bool:
	var prefix: String = "%s=" % flag
	for arg: String in user_args:
		if arg == flag or arg.begins_with(prefix):
			return true
	return false


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
