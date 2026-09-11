extends GutTest

## 可玩性深化第十八批：新机关接到官方 01–03 的侧廊，不挡 +X 捷径 / 安全路脚本。
## 官方课 01/02 不加额外可破坏（出生点 Q 仍只清那一只箱）。匹配 HTTP 认 01–05。
## 不改协议，不接线 InteractIntent。

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringReachabilityGd := preload("res://src/creator/authoring_reachability.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const PlayClockGd := preload("res://src/shared/play_clock.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01: String = "res://content/official/traprush/course_01.json"
const COURSE_02: String = "res://content/official/traprush/course_02.json"
const COURSE_03: String = "res://content/official/traprush/course_03.json"
const CELL: int = 65536


func test_official_courses_compile_new_gadgets_off_the_shortcut() -> void:
	var one: SimulationBundleGd = _compile(COURSE_01)
	var two: SimulationBundleGd = _compile(COURSE_02)
	var three: SimulationBundleGd = _compile(COURSE_03)
	assert_eq(one.energy_walls.size(), 0)
	assert_eq(one.destructibles.size(), 1)
	assert_eq(one.ices.size(), 1)
	assert_eq(one.conveyors.size(), 1)
	assert_eq(one.switches.size(), 1)
	assert_eq(one.gates.size(), 1)
	assert_eq(PlayClockGd.dict_int(_bag_by_id(one.solids, 201), "z", 0), 6 * CELL)
	assert_eq(PlayClockGd.dict_int(_bag_by_id(one.solids, 204), "z", 0), 6 * CELL)
	assert_eq(two.destructibles.size(), 1)
	assert_eq(two.flames.size(), 1)
	assert_eq(two.rollers.size(), 1)
	assert_eq(two.spikes.size(), 1)
	assert_eq(two.rubbles.size(), 0)
	assert_eq(two.obstacle_cores.size(), 0)
	assert_eq(PlayClockGd.dict_int(_bag_by_id(two.hazards, 201), "z", 0), -CELL)
	assert_eq(three.destructibles.size(), 1)
	assert_eq(three.launches.size(), 1)
	assert_eq(three.crushers.size(), 1)
	assert_eq(three.pendulums.size(), 1)
	assert_eq(three.portal_switches.size(), 1)
	assert_true(_has_lift(three))
	assert_eq(PlayClockGd.dict_int(_bag_by_id(three.solids, 200), "z", 0), -2 * CELL)
	assert_false(_spine_blocked_by_new_gadget(one))
	assert_false(_spine_blocked_by_new_gadget(two))


func test_official_courses_stay_publish_ready_and_shortcut_scriptable() -> void:
	for path: String in [COURSE_01, COURSE_02, COURSE_03]:
		var world: AuthoringWorldGd = AuthoringDocumentGd.load_from_path(path)
		assert_not_null(world, path)
		var reach: Dictionary = AuthoringReachabilityGd.evaluate(world)
		var reach_ok: bool = reach["ok"]
		assert_true(reach_ok, "%s %s" % [path, str(reach.get("issues", []))])
	var one: SimulationBundleGd = _compile(COURSE_01)
	var replay: Dictionary = CourseCompletionProbe.try_replay(one, [
		"move+x", "move+x", "move+x", "move+x", "move+x",
	])
	var replay_ok: bool = replay["ok"]
	assert_true(replay_ok, str(replay.get("reason", "")))
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)


func _spine_blocked_by_new_gadget(bundle: SimulationBundleGd) -> bool:
	for bag: Dictionary in bundle.gates:
		var solid_bag: Dictionary = _bag_by_id(bundle.solids, PlayClockGd.dict_int(bag, "entity_id", 0))
		if PlayClockGd.dict_int(solid_bag, "z", 1) == 0:
			var x: int = PlayClockGd.dict_int(solid_bag, "x", -1)
			if x >= 0 and x <= 3 * CELL:
				return true
	for bag: Dictionary in bundle.flames:
		var hazard_bag: Dictionary = _bag_by_id(bundle.hazards, PlayClockGd.dict_int(bag, "entity_id", 0))
		if PlayClockGd.dict_int(hazard_bag, "z", 1) == 0:
			return true
	for bag: Dictionary in bundle.rollers:
		var hazard_bag: Dictionary = _bag_by_id(bundle.hazards, PlayClockGd.dict_int(bag, "entity_id", 0))
		if PlayClockGd.dict_int(hazard_bag, "z", 1) == 0:
			return true
	return false


func _has_lift(bundle: SimulationBundleGd) -> bool:
	for bag: Dictionary in bundle.movers:
		if PlayClockGd.dict_int(bag, "entity_id", 0) == 201:
			return true
	return false


func _compile(path: String) -> SimulationBundleGd:
	var world: AuthoringWorldGd = AuthoringDocumentGd.load_from_path(path)
	assert_not_null(world)
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	return bundle


func _bag_by_id(bags: Array, entity_id: int) -> Dictionary:
	for bag: Dictionary in bags:
		if PlayClockGd.dict_int(bag, "entity_id", 0) == entity_id:
			return bag
	return {}
