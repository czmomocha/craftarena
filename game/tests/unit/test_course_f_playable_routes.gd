extends GutTest

## 可玩性深化收口：示范课从侧廊展览改成有路线选择的一局。
## 危险捷径走 z=0 主路（能量墙挡路，须从 −Z 侧 Q 打碎）；安全路走 z=+2，
## 途中下到检查点 1 再绕回。不改协议、不进匹配 HTTP、不新增机关种类。

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringReachabilityGd := preload("res://src/creator/authoring_reachability.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const CourseFPlayableScripts := preload("res://src/games/traprush/course_f_playable_scripts.gd")
const PlayClockGd := preload("res://src/shared/play_clock.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const TraprushOutOfRangeResetGd := preload("res://src/games/traprush/out_of_range_reset.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_F: String = "res://content/official/traprush/course_f_playable.json"
const CELL: int = 65536
const ENERGY_WALL_ID: int = 224
const GATE_ID: int = 223


func test_course_f_playable_is_a_routed_run_not_a_museum() -> void:
	var world: AuthoringWorldGd = AuthoringDocumentGd.load_from_path(COURSE_F)
	assert_not_null(world)
	assert_eq(world.revision, 11)
	var reach: Dictionary = AuthoringReachabilityGd.evaluate(world)
	var reach_ok: bool = reach["ok"]
	assert_true(reach_ok, str(reach.get("issues", [])))
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	var wall: Dictionary = _bag_by_id(bundle.destructibles, ENERGY_WALL_ID)
	assert_false(wall.is_empty())
	assert_eq(PlayClockGd.dict_int(wall, "x", -1), CELL)
	assert_eq(PlayClockGd.dict_int(wall, "y", 1), 0)
	assert_eq(PlayClockGd.dict_int(wall, "z", -1), 0)
	assert_false(_bag_by_id(bundle.energy_walls, ENERGY_WALL_ID).is_empty())
	var gate_solid: Dictionary = _solid_by_id(bundle, GATE_ID)
	assert_eq(PlayClockGd.dict_int(gate_solid, "z", -1), 2 * CELL)
	assert_true(_has_blocking_gadget_on_spine(bundle))
	assert_true(_safe_loop_exists(bundle))
	_assert_inside_stub_half(bundle)


func test_fast_script_is_shorter_than_safe_script_and_both_finish() -> void:
	var world: AuthoringWorldGd = AuthoringDocumentGd.load_from_path(COURSE_F)
	assert_not_null(world)
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	var fast_actions: Array = CourseFPlayableScripts.fast_names()
	var safe_actions: Array = CourseFPlayableScripts.safe_names()
	var fast_replay: Dictionary = CourseCompletionProbe.try_replay(bundle, fast_actions)
	var fast_ok: bool = fast_replay["ok"]
	assert_true(fast_ok, str(fast_replay.get("reason", "")))
	var fast_finish: int = fast_replay["finish_tick"]
	var fast_accepted: int = fast_replay["accepted"]
	var fast_pads: int = fast_replay["checkpoints"]
	assert_gte(fast_finish, 0)
	assert_eq(fast_accepted, fast_pads)
	var safe_replay: Dictionary = CourseCompletionProbe.try_replay(bundle, safe_actions)
	var safe_ok: bool = safe_replay["ok"]
	assert_true(safe_ok, str(safe_replay.get("reason", "")))
	var safe_finish: int = safe_replay["finish_tick"]
	var safe_accepted: int = safe_replay["accepted"]
	var safe_pads: int = safe_replay["checkpoints"]
	assert_gte(safe_finish, 0)
	assert_eq(safe_accepted, safe_pads)
	assert_gt(_move_count(safe_actions), _move_count(fast_actions))


func _move_count(actions: Array) -> int:
	var count: int = 0
	for raw: Variant in actions:
		var name: String = str(raw)
		if name.begins_with("move"):
			count += 1
	return count


func _has_blocking_gadget_on_spine(bundle: SimulationBundleGd) -> bool:
	for bag: Dictionary in bundle.destructibles:
		if PlayClockGd.dict_int(bag, "entity_id", 0) != ENERGY_WALL_ID:
			continue
		if PlayClockGd.dict_int(bag, "z", 1) != 0:
			continue
		var x: int = PlayClockGd.dict_int(bag, "x", -1)
		return x > 0 and x < PlayClockGd.dict_int(bundle.finish[0], "x", 0)
	return false


func _safe_loop_exists(bundle: SimulationBundleGd) -> bool:
	var ice_on_loop: bool = false
	for bag: Dictionary in bundle.ices:
		var solid_bag: Dictionary = _solid_by_id(bundle, PlayClockGd.dict_int(bag, "entity_id", 0))
		if PlayClockGd.dict_int(solid_bag, "z", 0) == 2 * CELL:
			ice_on_loop = true
	var conveyor_on_loop: int = 0
	for bag: Dictionary in bundle.conveyors:
		var solid_bag: Dictionary = _solid_by_id(bundle, PlayClockGd.dict_int(bag, "entity_id", 0))
		if PlayClockGd.dict_int(solid_bag, "z", 0) >= 2 * CELL:
			conveyor_on_loop += 1
	return ice_on_loop and conveyor_on_loop >= 3


func _assert_inside_stub_half(bundle: SimulationBundleGd) -> void:
	var half: int = TraprushOutOfRangeResetGd.STUB_HALF
	for bag: Dictionary in bundle.solids:
		assert_lt(absi(PlayClockGd.dict_int(bag, "x", half + 1)), half + 1)
		assert_lt(absi(PlayClockGd.dict_int(bag, "z", half + 1)), half + 1)
	for bag: Dictionary in bundle.finish:
		assert_lt(absi(PlayClockGd.dict_int(bag, "x", half + 1)), half + 1)
		assert_lt(absi(PlayClockGd.dict_int(bag, "z", half + 1)), half + 1)


func _bag_by_id(bags: Array, entity_id: int) -> Dictionary:
	for bag: Dictionary in bags:
		if PlayClockGd.dict_int(bag, "entity_id", 0) == entity_id:
			return bag
	return {}


func _solid_by_id(bundle: SimulationBundleGd, entity_id: int) -> Dictionary:
	return _bag_by_id(bundle.solids, entity_id)
