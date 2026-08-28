extends GutTest

## 纠偏 C3 第 7 章：封掉捷径传送源之后，探针必须走另一条路。
## 合成课用贪心证明约束本身。官方 course_01 安全路重放 C3 第 5 章四向序列
## （与语义测试 `_safe_moves` 相同），不把无快照三十步 A* 塞进 GUT。
## 不锁产品重力、不加第 4 张课、不改 STUB_HALF / play_move_step。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BotRunCli := preload("res://src/games/traprush/bot_run_cli.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const SHORTCUT_PORTAL: int = 10
const SAFE_PORTAL: int = 20
const DEST_Z: int = 4 * CELL


func test_synthetic_shortcut_is_shorter_than_the_safe_portal() -> void:
	var bundle: SimulationBundle = _two_portal_islands()
	assert_not_null(bundle)
	var any_route: Dictionary = CourseCompletionProbe.run_bundle(bundle)
	var any_outcome: String = any_route["outcome"]
	var any_reason: String = any_route.get("reason", "")
	assert_eq(any_outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE, any_reason)
	var any_steps: int = any_route["steps"]
	assert_eq(any_steps, 2)
	var forbid: PackedInt32Array = PackedInt32Array([SHORTCUT_PORTAL])
	var safe_route: Dictionary = CourseCompletionProbe.run_bundle(
		bundle, 800, 16, forbid, CourseCompletionProbe.ACTION_SET_CARDINAL
	)
	var safe_outcome: String = safe_route["outcome"]
	var safe_reason: String = safe_route.get("reason", "")
	assert_eq(safe_outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE, safe_reason)
	var safe_steps: int = safe_route["steps"]
	assert_gt(safe_steps, any_steps)
	var forbid_view: Array = safe_route["forbid_portals"]
	assert_eq(forbid_view, [SHORTCUT_PORTAL])
	var safe_actions: Array = safe_route["actions"]
	var replay: Dictionary = CourseCompletionProbe.try_replay(bundle, safe_actions)
	var replay_ok: bool = replay["ok"]
	assert_true(replay_ok, str(replay.get("reason", "")))
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)


func test_without_portals_drops_listed_sources() -> void:
	var bundle: SimulationBundle = _two_portal_islands()
	assert_eq(bundle.portals.size(), 4)
	var filtered: SimulationBundle = CourseCompletionProbe.without_portals(
		bundle, PackedInt32Array([SHORTCUT_PORTAL])
	)
	assert_eq(filtered.portals.size(), 3)
	assert_eq(bundle.portals.size(), 4)
	var remaining: PackedInt32Array = PackedInt32Array()
	for portal: Dictionary in filtered.portals:
		var entity_id: int = portal.get("entity_id", 0)
		remaining.append(entity_id)
		assert_ne(entity_id, SHORTCUT_PORTAL)
	assert_eq(remaining.size(), 3)


func test_course_01_shortcut_portal_matches_cli_constant() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var found: bool = false
	for portal: Dictionary in bundle.portals:
		var entity_id: int = portal.get("entity_id", 0)
		if entity_id == BotRunCli.COURSE_01_SHORTCUT_PORTAL_ID:
			found = true
			break
	assert_true(found)


func test_course_01_safe_script_finishes_without_shortcut_portal() -> void:
	assert_eq(CourseCompletionProbe.COURSE_01_SAFE_CARDINAL.size(), 29)
	var forbid: PackedInt32Array = PackedInt32Array([SHORTCUT_PORTAL])
	var result: Dictionary = CourseCompletionProbe.run_path(
		COURSE_01,
		CourseCompletionProbe.SAFE_ROUTE_MAX_TICKS,
		CourseCompletionProbe.DEFAULT_MAX_DEPTH,
		forbid,
		CourseCompletionProbe.ACTION_SET_CARDINAL,
		CourseCompletionProbe.course_01_safe_cardinal()
	)
	var outcome: String = result["outcome"]
	var reason: String = result.get("reason", "")
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE, reason)
	var steps: int = result["steps"]
	assert_gte(steps, 20)
	var forbid_view: Array = result["forbid_portals"]
	assert_eq(forbid_view, [SHORTCUT_PORTAL])
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var filtered: SimulationBundle = CourseCompletionProbe.without_portals(bundle, forbid)
	var actions: Array = result["actions"]
	var replay: Dictionary = CourseCompletionProbe.try_replay(filtered, actions)
	var replay_ok: bool = replay["ok"]
	assert_true(replay_ok, str(replay.get("reason", "")))
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)


func _two_portal_islands() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0, 0, 0)))
	assert_true(world.put(_portal(SHORTCUT_PORTAL, 11, CELL, 0, 0)))
	assert_true(world.put(_portal(11, SHORTCUT_PORTAL, 0, CELL, DEST_Z)))
	assert_true(world.put(_portal(SAFE_PORTAL, 21, 0, 0, CELL)))
	assert_true(world.put(_portal(21, SAFE_PORTAL, 3 * CELL, CELL, DEST_Z)))
	assert_true(world.put(_finish(30, CELL, CELL, DEST_Z)))
	assert_true(world.put(_solid(80, 0, -CELL, 0)))
	assert_true(world.put(_solid(81, CELL, -CELL, 0)))
	assert_true(world.put(_solid(82, 0, -CELL, CELL)))
	assert_true(world.put(_solid(83, 0, 0, DEST_Z)))
	assert_true(world.put(_solid(84, CELL, 0, DEST_Z)))
	assert_true(world.put(_solid(85, 2 * CELL, 0, DEST_Z)))
	assert_true(world.put(_solid(86, 3 * CELL, 0, DEST_Z)))
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


func _portal(
	entity_id: int, target_id: int, x: int, y: int, z: int
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
	})


func _finish(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return _zone(entity_id, x, y, z, "finish")


func _solid(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return _zone(entity_id, x, y, z, "solid")


func _zone(
	entity_id: int, x: int, y: int, z: int, tag: String
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": [tag],
		},
	})
