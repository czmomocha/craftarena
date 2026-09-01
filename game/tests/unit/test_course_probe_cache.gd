extends GutTest

## 探针记忆化的两条性质：同一组入参只真搜一次，且交出去的永远是副本。
##
## 用不存在的课程路径做夹具，因为本文件要证的是**缓存行为**，不是搜索结果。
## 拿 course_01 来证会把一次真搜索算进这个脚本的耗时，而它恰好是这套缓存想
## 消掉的东西。缺路径在 `AuthoringDocument.load_json` 里直接返回 `{}`，不 push
## 错误，探针立刻回 `invalid_course`——毫秒级且确定。
##
## 断言全部走**增量**，不 `clear()`：缓存是进程内静态的，整场 GUT 共用一份，
## 清掉会让后面的脚本重新搜一遍官方课。

const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const CourseProbeCache := preload("res://tests/support/course_probe_cache.gd")

const MISSING_A: String = "res://tests/support/does_not_exist_a.json"
const MISSING_B: String = "res://tests/support/does_not_exist_b.json"


func test_same_inputs_are_searched_once() -> void:
	var before: int = CourseProbeCache.entry_count()
	var first: Dictionary = CourseProbeCache.run_path(MISSING_A)
	assert_eq(CourseProbeCache.entry_count(), before + 1)
	var second: Dictionary = CourseProbeCache.run_path(MISSING_A)
	assert_eq(CourseProbeCache.entry_count(), before + 1)
	var first_outcome: String = first["outcome"]
	var second_outcome: String = second["outcome"]
	var first_reason: String = first["reason"]
	var second_reason: String = second["reason"]
	assert_eq(first_outcome, CourseCompletionProbe.OUTCOME_INVALID_COURSE)
	assert_eq(second_outcome, first_outcome)
	assert_eq(second_reason, first_reason)


func test_each_input_set_gets_its_own_entry() -> void:
	var before: int = CourseProbeCache.entry_count()
	CourseProbeCache.run_path(MISSING_B)
	CourseProbeCache.run_path(MISSING_B, 12)
	CourseProbeCache.run_path(MISSING_B, 12, 8)
	CourseProbeCache.run_path(MISSING_B, 12, 8, PackedInt32Array([10]))
	assert_eq(CourseProbeCache.entry_count(), before + 4)


func test_callers_get_a_copy_they_cannot_poison() -> void:
	var first: Dictionary = CourseProbeCache.run_path(MISSING_A)
	var forbid: Array = first["forbid_portals"]
	forbid.append(999)
	first["outcome"] = "tampered"
	var second: Dictionary = CourseProbeCache.run_path(MISSING_A)
	var second_outcome: String = second["outcome"]
	assert_eq(second_outcome, CourseCompletionProbe.OUTCOME_INVALID_COURSE)
	var fresh_forbid: Array = second["forbid_portals"]
	assert_eq(fresh_forbid.size(), 0)
