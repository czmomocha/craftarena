extends GutTest

## MatchCheckpointOrderMap: compiled pad order → labels + sequence bars.
## Unique orders draw ascending bars (Preview colors / lifts). Duplicate
## orders are labeled only. A null / missing / malformed bundle keeps
## the last gizmos.

const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const MatchCheckpointOrderMap := preload("res://src/client/match_checkpoint_order_map.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_02_PATH: String = "res://content/official/traprush/course_02.json"
const COURSE_03_PATH: String = "res://content/official/traprush/course_03.json"
const EPS: float = 0.0001

var _map: MatchCheckpointOrderMap = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null


func test_official_course_01_maps_unique_orders() -> void:
	_map = MatchCheckpointOrderMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_eq(_map.checkpoint_count(), 3)
	assert_eq(_map.sequence_count(), 2)
	assert_eq(_map.crate_node_count(), 0)
	assert_eq(_map.link_node_count(), 0)
	var first: Label3D = _map.checkpoint_node(1)
	var second: Label3D = _map.checkpoint_node(2)
	var third: Label3D = _map.checkpoint_node(3)
	assert_not_null(first)
	assert_not_null(second)
	assert_not_null(third)
	assert_eq(first.text, "0")
	assert_eq(second.text, "1")
	assert_eq(third.text, "2")
	assert_eq(first.modulate, Color(0.35, 0.9, 0.4))
	assert_almost_eq(first.position.x, 0.0, EPS)
	assert_almost_eq(first.position.y, 1.15, EPS)
	assert_almost_eq(first.position.z, 0.0, EPS)
	assert_almost_eq(third.position.x, 1.0, EPS)
	assert_almost_eq(third.position.y, 2.15, EPS)
	assert_almost_eq(third.position.z, 0.0, EPS)
	var seq: MeshInstance3D = _map.sequence_node(1, 2)
	assert_not_null(seq)
	assert_almost_eq(seq.position.x, 1.0, EPS)
	assert_almost_eq(seq.position.y, 0.25, EPS)
	assert_almost_eq(seq.position.z, 0.0, EPS)
	var box: BoxMesh = seq.mesh as BoxMesh
	assert_not_null(box)
	assert_almost_eq(box.size.x, 0.08, EPS)
	assert_not_null(_map.sequence_node(2, 3))
	assert_almost_eq(_map.sequence_node(2, 3).position.x, 1.5, EPS)
	assert_almost_eq(_map.sequence_node(2, 3).position.y, 0.75, EPS)
	assert_false(_map.allows_settlement())
	assert_false(_map.allows_online_writes())


func test_official_courses_map_distinct_layouts_and_no_ghosts() -> void:
	_map = MatchCheckpointOrderMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_almost_eq(_map.checkpoint_node(3).position.z, 0.0, EPS)
	assert_almost_eq(_map.sequence_node(2, 3).position.z, 0.0, EPS)
	assert_true(_map.apply_path(COURSE_02_PATH))
	assert_eq(_map.checkpoint_count(), 3)
	assert_eq(_map.sequence_count(), 2)
	assert_eq(_map.checkpoint_node(3).text, "2")
	assert_almost_eq(_map.checkpoint_node(3).position.z, 2.0, EPS)
	assert_almost_eq(_map.sequence_node(2, 3).position.z, 1.0, EPS)
	assert_null(_map.checkpoint_node(4))
	assert_true(_map.apply_path(COURSE_03_PATH))
	assert_eq(_map.checkpoint_count(), 4)
	assert_eq(_map.sequence_count(), 3)
	assert_eq(_map.checkpoint_node(4).text, "3")
	assert_almost_eq(_map.checkpoint_node(3).position.z, 1.0, EPS)
	assert_almost_eq(_map.checkpoint_node(4).position.x, 3.0, EPS)
	assert_almost_eq(_map.checkpoint_node(4).position.y, 2.15, EPS)
	assert_almost_eq(_map.checkpoint_node(4).position.z, 1.0, EPS)
	assert_not_null(_map.sequence_node(3, 4))
	assert_almost_eq(_map.sequence_node(3, 4).position.x, 2.0, EPS)
	assert_almost_eq(_map.sequence_node(3, 4).position.y, 1.25, EPS)


func test_empty_bundle_clears_orders() -> void:
	_map = MatchCheckpointOrderMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	var empty: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(empty)
	assert_not_null(bundle)
	assert_true(_map.apply_bundle(bundle))
	assert_eq(_map.checkpoint_count(), 0)
	assert_eq(_map.sequence_count(), 0)
	assert_null(_map.checkpoint_node(1))
	assert_null(_map.sequence_node(1, 2))


func test_null_or_missing_path_keeps_previous_map() -> void:
	_map = MatchCheckpointOrderMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_false(_map.apply_bundle(null))
	assert_false(_map.apply_path("res://content/official/traprush/missing_course.json"))
	assert_false(_map.apply_path(""))
	assert_eq(_map.checkpoint_count(), 3)
	assert_eq(_map.sequence_count(), 2)
	assert_almost_eq(_map.checkpoint_node(3).position.z, 0.0, EPS)


func test_malformed_order_keeps_previous_map() -> void:
	_map = MatchCheckpointOrderMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	var bundle: SimulationBundle = MatchCheckpointOrderMap.compile_path(COURSE_01_PATH)
	assert_not_null(bundle)
	bundle.pads[0].erase("order")
	assert_false(_map.apply_bundle(bundle))
	assert_eq(_map.checkpoint_count(), 3)
	assert_almost_eq(_map.checkpoint_node(1).position.y, 1.15, EPS)
	bundle = MatchCheckpointOrderMap.compile_path(COURSE_01_PATH)
	assert_not_null(bundle)
	bundle.pads[2]["order"] = -1
	assert_false(_map.apply_bundle(bundle))
	assert_eq(_map.sequence_count(), 2)
	assert_almost_eq(_map.sequence_node(2, 3).position.z, 0.0, EPS)


func test_duplicate_order_marks_without_sequence() -> void:
	_map = MatchCheckpointOrderMap.new()
	add_child(_map)
	var bundle: SimulationBundle = MatchCheckpointOrderMap.compile_path(COURSE_01_PATH)
	assert_not_null(bundle)
	bundle.pads[1]["order"] = 0
	assert_true(_map.apply_bundle(bundle))
	assert_eq(_map.checkpoint_count(), 3)
	assert_eq(_map.sequence_count(), 0)
	assert_eq(_map.checkpoint_node(1).text, "0")
	assert_eq(_map.checkpoint_node(2).text, "0")
	assert_eq(_map.checkpoint_node(3).text, "2")
	assert_eq(_map.checkpoint_node(1).modulate, Color(0.95, 0.3, 0.85))
	assert_eq(_map.checkpoint_node(2).modulate, Color(0.95, 0.3, 0.85))
	assert_eq(_map.checkpoint_node(3).modulate, Color(0.35, 0.9, 0.4))
	assert_null(_map.sequence_node(1, 2))
	assert_null(_map.sequence_node(2, 3))
