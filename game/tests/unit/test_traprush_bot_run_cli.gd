extends GutTest

## 纠偏 C3 第 7 章：BotRunner CLI 的 route / forbid-portal 解析。
## 不跑搜索——官方课搜索在 test_traprush_course_routes.gd 与 `--bot-run`。

const BotRunCli := preload("res://src/games/traprush/bot_run_cli.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const OfficialTraprushCourses := preload("res://src/shared/official_traprush_courses.gd")


func test_default_route_is_any() -> void:
	assert_eq(BotRunCli.resolve_route(PackedStringArray()), BotRunCli.ROUTE_ANY)
	assert_eq(
		BotRunCli.resolve_route(PackedStringArray(["--bot-run"])),
		BotRunCli.ROUTE_ANY
	)


func test_route_safe_and_unknown() -> void:
	assert_eq(
		BotRunCli.resolve_route(PackedStringArray(["--route=safe"])),
		BotRunCli.ROUTE_SAFE
	)
	assert_eq(
		BotRunCli.resolve_route(PackedStringArray(["--route=any"])),
		BotRunCli.ROUTE_ANY
	)
	assert_eq(BotRunCli.resolve_route(PackedStringArray(["--route=fast"])), "")


func test_forbid_portal_parses_unique_ids() -> void:
	var empty: Dictionary = BotRunCli.resolve_forbid_portals(PackedStringArray())
	var empty_ok: bool = empty.get("ok", false)
	assert_true(empty_ok)
	var empty_ids_raw: Variant = empty["ids"]
	assert_eq(typeof(empty_ids_raw), TYPE_PACKED_INT32_ARRAY)
	var empty_ids: PackedInt32Array = empty_ids_raw
	assert_eq(empty_ids.size(), 0)
	var parsed: Dictionary = BotRunCli.resolve_forbid_portals(
		PackedStringArray(["--forbid-portal=10,20,10"])
	)
	var parsed_ok: bool = parsed.get("ok", false)
	assert_true(parsed_ok)
	var ids_raw: Variant = parsed["ids"]
	assert_eq(typeof(ids_raw), TYPE_PACKED_INT32_ARRAY)
	var ids: PackedInt32Array = ids_raw
	assert_eq(ids.size(), 2)
	assert_eq(ids[0], 10)
	assert_eq(ids[1], 20)


func test_forbid_portal_rejects_junk() -> void:
	var letters: Dictionary = BotRunCli.resolve_forbid_portals(
		PackedStringArray(["--forbid-portal=ten"])
	)
	var letters_ok: bool = letters.get("ok", true)
	assert_false(letters_ok)
	var zero: Dictionary = BotRunCli.resolve_forbid_portals(
		PackedStringArray(["--forbid-portal=0"])
	)
	var zero_ok: bool = zero.get("ok", true)
	assert_false(zero_ok)


func test_default_courses_are_the_official_three() -> void:
	assert_eq(
		BotRunCli.resolve_courses(PackedStringArray()),
		PackedStringArray([
			OfficialTraprushCourses.COURSE_01,
			OfficialTraprushCourses.COURSE_02,
			OfficialTraprushCourses.COURSE_03,
		])
	)


func test_safe_route_on_course_02_exits_1_without_searching() -> void:
	var code: int = BotRunCli.run_and_print(PackedStringArray([
		"--bot-run",
		"--course=course_02",
		"--route=safe",
	]))
	assert_eq(code, 1)


func test_unknown_route_exits_1() -> void:
	var code: int = BotRunCli.run_and_print(PackedStringArray([
		"--bot-run",
		"--route=fast",
	]))
	assert_eq(code, 1)


func test_course_01_shortcut_portal_is_entity_10() -> void:
	assert_eq(BotRunCli.COURSE_01_SHORTCUT_PORTAL_ID, 10)
	assert_eq(
		CourseCompletionProbe.SAFE_ROUTE_MAX_TICKS,
		12000
	)
