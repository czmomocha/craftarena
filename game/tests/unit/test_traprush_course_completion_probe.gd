extends GutTest

## 走路可达探针的**反例形状**：没有终点、检查点够不到、预算先耗尽，以及重放
## 拒绝未知动作名。全部走合成 bundle 或紧预算，不做完整搜索。
##
## 「预算耗尽」是本组测试的重点。探针的价值在于它**不谎报**：预算用完时必须说
## budget_exhausted，而不是把「没搜完」说成「走不通」。
##
## 正例（官方 course_01 能走通、给出的路线可独立重放）需要一次完整搜索，已移到
## `tests/slow/test_traprush_official_course_completability.gd`。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const UNREACHABLE_Y: int = 5 * CELL


func test_course_without_finish_is_not_completable() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0, 0, 0)))
	assert_true(world.put(_solid(80, 0, -CELL, 0)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var result: Dictionary = CourseCompletionProbe.run_bundle(bundle)
	var outcome: String = result["outcome"]
	var reason: String = result["reason"]
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_NOT_COMPLETABLE)
	assert_eq(reason, CourseCompletionProbe.REASON_NO_FINISH)


func test_unreachable_checkpoint_reports_where_it_got_stuck() -> void:
	var bundle: SimulationBundle = _unreachable_course()
	assert_not_null(bundle)
	var result: Dictionary = CourseCompletionProbe.run_bundle(bundle, 120, 8)
	var outcome: String = result["outcome"]
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_NOT_COMPLETABLE)
	var stuck: Dictionary = result["stuck"]
	var target_kind: String = stuck["target_kind"]
	var target_y: int = stuck["target_y"]
	var reached_y: int = stuck["y"]
	assert_eq(target_kind, CourseCompletionProbe.TARGET_CHECKPOINT)
	assert_eq(target_y, UNREACHABLE_Y)
	assert_lt(reached_y, UNREACHABLE_Y)


func test_tight_budget_says_budget_not_a_verdict() -> void:
	var bundle: SimulationBundle = _compile_path(COURSE_01_PATH)
	assert_not_null(bundle)
	var result: Dictionary = CourseCompletionProbe.run_bundle(bundle, 12, 8)
	var outcome: String = result["outcome"]
	var reason: String = result["reason"]
	var search_ticks: int = result["search_ticks"]
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_NOT_COMPLETABLE)
	assert_eq(reason, CourseCompletionProbe.REASON_BUDGET_EXHAUSTED)
	assert_true(search_ticks <= 12, "search_ticks=%d" % search_ticks)


func test_replay_rejects_an_unknown_action_name() -> void:
	var bundle: SimulationBundle = _compile_path(COURSE_01_PATH)
	assert_not_null(bundle)
	var replay: Dictionary = CourseCompletionProbe.try_replay(bundle, ["fly"])
	var ok: bool = replay["ok"]
	var reason: String = replay["reason"]
	assert_false(ok)
	assert_string_contains(reason, "unknown_action")


func _unreachable_course() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0, 0, 0)))
	## 悬在五格高，没有传送门也没有可踩的支撑：占位跳跃只有四分之一格。
	assert_true(world.put(_checkpoint(2, 1, 0, UNREACHABLE_Y, 0)))
	assert_true(world.put(_finish_zone(30, CELL, UNREACHABLE_Y, 0)))
	assert_true(world.put(_solid(80, 0, -CELL, 0)))
	return TraprushTopologyCompiler.compile(world)


func _compile_path(path: String) -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	if world == null:
		return null
	return TraprushTopologyCompiler.compile(world)


func _checkpoint(
	entity_id: int, order: int, x: int, y: int, z: int
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": order,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})


func _finish_zone(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return _zone(entity_id, x, y, z, "finish")


func _solid(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return _zone(entity_id, x, y, z, "solid")


func _zone(entity_id: int, x: int, y: int, z: int, tag: String) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": [tag],
		},
	})
