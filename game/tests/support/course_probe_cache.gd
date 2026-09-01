extends RefCounted

## 走路可达探针的进程内记忆化，**只给测试用**。
##
## 存在的理由是墙钟，不是代码整洁。`CourseCompletionProbe.run_path()` 是一次
## A* / 贪心搜索，官方 course_03 单次约 77 秒（README 的 `--bot-run` 观察值）。
## 同一份 `(path, 预算, 禁用传送, 动作集, 脚本提示)` 在整个 GUT 会话里被四个
## 脚本重复求解：`test_traprush_course_completion_probe.gd` 自己就用默认参数搜
## 了 course_01 两遍，`test_traprush_semantic_course.gd` 与
## `test_traprush_official_path_floors.gd` 各再搜一遍——四次搜索，一个答案。
##
## 记忆化是安全的，因为探针是**纯函数**：给定同一份课程 JSON 与同一组预算，
## 搜索没有随机源（`_MATCH_SEED` 是常量）、不读时钟、不写磁盘。这一点是本文件
## 成立的全部前提；哪天探针引入了随机重启或时间预算，这个缓存必须同时废掉。
##
## **不缓存** `SimulationBundle`。它是可变对象，跨用例共享会让「A 用例打碎一个
## 箱子」渗进 B 用例。这里只缓存探针返回的结果字典，且每次 `duplicate(true)`
## 再交出去，调用方怎么改都碰不到缓存里那一份。

const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")

static var _results: Dictionary = {}


## 与 `CourseCompletionProbe.run_path()` 同签名同语义，只是同一组入参只真搜一次。
static func run_path(
	path: String,
	max_ticks: int = CourseCompletionProbe.DEFAULT_MAX_TICKS,
	max_depth: int = CourseCompletionProbe.DEFAULT_MAX_DEPTH,
	forbid_portal_ids: PackedInt32Array = PackedInt32Array(),
	action_count: int = CourseCompletionProbe.ACTION_SET_FULL,
	hint_actions: PackedByteArray = PackedByteArray(),
) -> Dictionary:
	var key: String = _key(
		path, max_ticks, max_depth, forbid_portal_ids, action_count, hint_actions
	)
	var cached: Variant = _results.get(key)
	if typeof(cached) == TYPE_DICTIONARY:
		var hit: Dictionary = cached
		return hit.duplicate(true)
	var fresh: Dictionary = CourseCompletionProbe.run_path(
		path, max_ticks, max_depth, forbid_portal_ids, action_count, hint_actions
	)
	_results[key] = fresh
	return fresh.duplicate(true)


## 已缓存的入参组数。守卫用例读它来证明第二次调用没有再搜。
static func entry_count() -> int:
	return _results.size()


static func clear() -> void:
	_results.clear()


static func _key(
	path: String,
	max_ticks: int,
	max_depth: int,
	forbid_portal_ids: PackedInt32Array,
	action_count: int,
	hint_actions: PackedByteArray,
) -> String:
	return "%s|%d|%d|%s|%d|%s" % [
		path,
		max_ticks,
		max_depth,
		str(forbid_portal_ids),
		action_count,
		str(hint_actions),
	]
