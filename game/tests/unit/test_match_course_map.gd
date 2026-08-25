extends GutTest

## MatchCourseMap: compiled topology occupancy poses → 1 m boxes.
## Pads, portals, and finish are drawn. Destructibles are not.
## A null / missing / malformed bundle keeps the last course.
## apply_own_progress tints pads from own-seat accepted_count
## and the finish zone from accepted_count plus finish_tick.

const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const MatchCourseMap := preload("res://src/client/match_course_map.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_02_PATH: String = "res://content/official/traprush/course_02.json"
const EPS: float = 0.0001

var _map: MatchCourseMap = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null


func test_official_course_01_maps_occupancy_and_skips_crates() -> void:
	_map = MatchCourseMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_eq(_map.pad_count(), 3)
	assert_eq(_map.portal_count(), 2)
	assert_eq(_map.finish_count(), 1)
	assert_eq(_map.crate_node_count(), 0)
	assert_eq(_map.link_node_count(), 0)
	assert_eq(_map.checkpoint_node_count(), 0)
	assert_eq(_map.standing_node_count(), 0)
	var pad: MeshInstance3D = _map.pad_node(1)
	var finish: MeshInstance3D = _map.finish_node(30)
	assert_not_null(pad)
	assert_not_null(finish)
	assert_almost_eq(pad.position.x, 0.0, EPS)
	assert_almost_eq(pad.position.z, 0.0, EPS)
	assert_almost_eq(finish.position.x, 2.0, EPS)
	assert_almost_eq(finish.position.y, 1.0, EPS)
	assert_almost_eq(finish.position.z, 0.0, EPS)
	var box: BoxMesh = pad.mesh as BoxMesh
	assert_not_null(box)
	assert_almost_eq(box.size.x, 1.0, EPS)
	assert_null(_map.get_node_or_null("crate_40"))
	assert_eq(_pad_albedo(1), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_PENDING_ALBEDO)
	assert_eq(_map.own_accepted_count(), -1)
	assert_eq(_map.own_finish_tick(), -1)
	assert_false(_map.allows_settlement())
	assert_false(_map.allows_online_writes())


func test_own_progress_tints_done_current_and_pending() -> void:
	_map = MatchCourseMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_eq(MatchCourseMap.pad_albedo(0, 1), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(MatchCourseMap.pad_albedo(1, 1), MatchCourseMap.CURRENT_ALBEDO)
	assert_eq(MatchCourseMap.pad_albedo(2, 1), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(MatchCourseMap.pad_albedo(0, -1), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(MatchCourseMap.finish_albedo(1, 3, -1), MatchCourseMap.FINISH_PENDING_ALBEDO)
	assert_eq(MatchCourseMap.finish_albedo(3, 3, -1), MatchCourseMap.FINISH_CURRENT_ALBEDO)
	assert_eq(MatchCourseMap.finish_albedo(3, 3, 0), MatchCourseMap.FINISH_ACCEPTED_ALBEDO)
	assert_eq(MatchCourseMap.finish_albedo(-1, 3, -1), MatchCourseMap.FINISH_PENDING_ALBEDO)
	_map.apply_own_progress(1)
	assert_eq(_pad_albedo(1), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(2), MatchCourseMap.CURRENT_ALBEDO)
	assert_eq(_pad_albedo(3), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_PENDING_ALBEDO)
	_map.apply_own_progress(3)
	assert_eq(_pad_albedo(1), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(2), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_pad_albedo(3), MatchCourseMap.ACCEPTED_ALBEDO)
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_CURRENT_ALBEDO)
	_map.apply_own_progress(3, 0)
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_ACCEPTED_ALBEDO)
	assert_eq(_map.own_finish_tick(), 0)
	_map.apply_own_progress(-1)
	assert_eq(_pad_albedo(1), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(_pad_albedo(2), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(_pad_albedo(3), MatchCourseMap.PENDING_ALBEDO)
	assert_eq(_finish_albedo(), MatchCourseMap.FINISH_PENDING_ALBEDO)
	assert_eq(_map.own_accepted_count(), -1)
	assert_eq(_map.own_finish_tick(), -1)


func test_official_courses_map_distinct_layouts() -> void:
	_map = MatchCourseMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_not_null(_map.portal_node(10))
	assert_true(_map.apply_path(COURSE_02_PATH))
	assert_eq(_map.pad_count(), 3)
	assert_eq(_map.portal_count(), 2)
	assert_eq(_map.finish_count(), 1)
	assert_null(_map.portal_node(10))
	assert_not_null(_map.portal_node(20))
	var finish: MeshInstance3D = _map.finish_node(30)
	var pad: MeshInstance3D = _map.pad_node(3)
	assert_almost_eq(finish.position.z, 2.0, EPS)
	assert_almost_eq(pad.position.z, 2.0, EPS)


func test_empty_bundle_clears_markers() -> void:
	_map = MatchCourseMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	var empty: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(empty)
	assert_not_null(bundle)
	assert_true(_map.apply_bundle(bundle))
	assert_eq(_map.pad_count(), 0)
	assert_eq(_map.portal_count(), 0)
	assert_eq(_map.finish_count(), 0)
	assert_null(_map.pad_node(1))
	assert_null(_map.finish_node(30))


func test_null_or_missing_path_keeps_previous_map() -> void:
	_map = MatchCourseMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_false(_map.apply_bundle(null))
	assert_false(_map.apply_path("res://content/official/traprush/missing_course.json"))
	assert_false(_map.apply_path(""))
	assert_eq(_map.pad_count(), 3)
	assert_almost_eq(_map.finish_node(30).position.x, 2.0, EPS)


func test_malformed_pad_keeps_previous_map() -> void:
	_map = MatchCourseMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	var bundle: SimulationBundle = MatchCourseMap.compile_path(COURSE_01_PATH)
	assert_not_null(bundle)
	bundle.pads[0].erase("x")
	assert_false(_map.apply_bundle(bundle))
	assert_eq(_map.pad_count(), 3)
	assert_almost_eq(_map.pad_node(1).position.z, 0.0, EPS)


func _finish_albedo() -> Color:
	return _box_albedo(_map.finish_node(30))


func _pad_albedo(entity_id: int) -> Color:
	return _box_albedo(_map.pad_node(entity_id))


func _box_albedo(node: MeshInstance3D) -> Color:
	assert_not_null(node)
	var box: BoxMesh = node.mesh as BoxMesh
	assert_not_null(box)
	var material: StandardMaterial3D = box.material as StandardMaterial3D
	assert_not_null(material)
	return material.albedo_color
