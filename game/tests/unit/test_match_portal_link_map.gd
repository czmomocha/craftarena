extends GutTest

## MatchPortalLinkMap: compiled portal source→dest → bar gizmos.
## two_way / one_way use Preview colors. one_way adds a direction marker.
## Dangling bags are omitted by the compiler and are not drawn.
## A null / missing / malformed bundle keeps the last links.

const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const MatchPortalLinkMap := preload("res://src/client/match_portal_link_map.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_02_PATH: String = "res://content/official/traprush/course_02.json"
const COURSE_03_PATH: String = "res://content/official/traprush/course_03.json"
const EPS: float = 0.0001

var _map: MatchPortalLinkMap = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null


func test_official_course_01_maps_two_way_links() -> void:
	_map = MatchPortalLinkMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_eq(_map.link_count(), 2)
	assert_eq(_map.direction_count(), 0)
	assert_eq(_map.checkpoint_node_count(), 0)
	assert_eq(_map.standing_node_count(), 0)
	var link: MeshInstance3D = _map.link_node(10)
	assert_not_null(link)
	assert_almost_eq(link.position.x, 1.5, EPS)
	assert_almost_eq(link.position.y, 0.5, EPS)
	assert_almost_eq(link.position.z, -1.5, EPS)
	var box: BoxMesh = link.mesh as BoxMesh
	assert_not_null(box)
	assert_almost_eq(box.size.x, 0.08, EPS)
	assert_eq(str(link.get_meta("kind")), AuthoringPortalKinds.TWO_WAY)
	assert_null(_map.direction_node(10))
	assert_null(_map.dangle_node(10))
	assert_false(_map.allows_settlement())
	assert_false(_map.allows_online_writes())


func test_official_courses_map_distinct_layouts_and_one_way_direction() -> void:
	_map = MatchPortalLinkMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_not_null(_map.link_node(10))
	assert_true(_map.apply_path(COURSE_02_PATH))
	assert_eq(_map.link_count(), 2)
	assert_eq(_map.direction_count(), 0)
	assert_null(_map.link_node(10))
	assert_not_null(_map.link_node(20))
	assert_true(_map.apply_path(COURSE_03_PATH))
	assert_eq(_map.link_count(), 3)
	assert_eq(_map.direction_count(), 1)
	var one_way: MeshInstance3D = _map.link_node(10)
	assert_not_null(one_way)
	assert_almost_eq(one_way.position.x, 1.5, EPS)
	assert_almost_eq(one_way.position.y, 0.5, EPS)
	assert_almost_eq(one_way.position.z, 0.5, EPS)
	assert_eq(str(one_way.get_meta("kind")), AuthoringPortalKinds.ONE_WAY)
	var marker: MeshInstance3D = _map.direction_node(10)
	assert_not_null(marker)
	assert_almost_eq(marker.position.x, 0.6, EPS)
	assert_almost_eq(marker.position.y, 0.95, EPS)
	assert_almost_eq(marker.position.z, 0.8, EPS)
	assert_null(_map.direction_node(11))
	assert_null(_map.link_node(20))


func test_empty_bundle_clears_links() -> void:
	_map = MatchPortalLinkMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	var empty: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(empty)
	assert_not_null(bundle)
	assert_true(_map.apply_bundle(bundle))
	assert_eq(_map.link_count(), 0)
	assert_eq(_map.direction_count(), 0)
	assert_null(_map.link_node(10))


func test_null_or_missing_path_keeps_previous_map() -> void:
	_map = MatchPortalLinkMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_false(_map.apply_bundle(null))
	assert_false(_map.apply_path("res://content/official/traprush/missing_course.json"))
	assert_false(_map.apply_path(""))
	assert_eq(_map.link_count(), 2)
	assert_almost_eq(_map.link_node(10).position.x, 1.5, EPS)


func test_malformed_dest_keeps_previous_map() -> void:
	_map = MatchPortalLinkMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	var bundle: SimulationBundle = MatchPortalLinkMap.compile_path(COURSE_01_PATH)
	assert_not_null(bundle)
	bundle.portals[0].erase("dest_x")
	assert_false(_map.apply_bundle(bundle))
	assert_eq(_map.link_count(), 2)
	assert_almost_eq(_map.link_node(10).position.z, -1.5, EPS)
