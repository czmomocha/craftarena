extends GutTest

## Fourth official TRAPRUSH course: vertical tower.
## Lift + launch + crusher; upstairs two_way; lateral two_way.
## Publish reachability is ok. Lifts are not in that graph.
## Never settlement. Distinct from 01–03 layouts.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")
const AuthoringReachability := preload("res://src/creator/authoring_reachability.gd")
const AuthoringReachabilityCodes := preload("res://src/creator/authoring_reachability_codes.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const OfficialCourses := preload("res://src/shared/official_traprush_courses.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushTopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_04_PATH: String = "res://content/official/traprush/course_04.json"
const CELL: int = 65536


func test_official_course_04_loads_and_is_publish_ready() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_04_PATH)
	assert_not_null(world)
	assert_eq(world.grid.cell, CELL)
	assert_eq(world.revision, 1)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result))
	var issues: Array = result.get("issues", [1])
	assert_eq(issues.size(), 0)


func test_course_04_is_on_the_match_whitelist_unlike_f_playable() -> void:
	assert_true(OfficialCourses.is_id(OfficialCourses.COURSE_04))
	assert_eq(OfficialCourses.document_path(OfficialCourses.COURSE_04), COURSE_04_PATH)
	assert_false(OfficialCourses.is_id(OfficialCourses.COURSE_F_PLAYABLE))
	assert_true(OfficialCourses.all_match_ids().has(OfficialCourses.COURSE_04))


func test_course_04_layout_differs_from_01_and_has_tower_fixtures() -> void:
	var first: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	var fourth: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_04_PATH)
	assert_not_null(first)
	assert_not_null(fourth)
	assert_ne(first.hash_state().hex_encode(), fourth.hash_state().hex_encode())
	var links: Array[Dictionary] = fourth.portal_links()
	assert_eq(links.size(), 4)
	var two_way_count: int = 0
	var saw_ascent: bool = false
	var saw_lateral: bool = false
	for item: Dictionary in links:
		assert_eq(_link_str(item, "kind"), AuthoringPortalKinds.TWO_WAY)
		two_way_count += 1
		var source_id: int = _link_int(item, "source_id")
		var dest_id: int = _link_int(item, "dest_id")
		if source_id == 10 and dest_id == 11:
			saw_ascent = true
		if source_id == 20 and dest_id == 21:
			saw_lateral = true
	assert_eq(two_way_count, 4)
	assert_true(saw_ascent)
	assert_true(saw_lateral)


func test_course_04_compiles_lift_launch_crusher_and_fixture_bags() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_04_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.pads.size(), 3)
	assert_eq(bundle.portals.size(), 4)
	assert_eq(bundle.finish.size(), 1)
	assert_eq(bundle.destructibles.size(), 1)
	assert_eq(bundle.hazards.size(), 1)
	assert_eq(bundle.launches.size(), 1)
	assert_eq(bundle.crushers.size(), 1)
	assert_eq(bundle.movers.size(), 2)
	assert_true(_has_lift(bundle))
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_ok(loaded))
	var pad_ids: Dictionary = loaded["pad_ids"]
	var finish_ids: Dictionary = loaded["finish_ids"]
	var destructible_ids: Dictionary = loaded["destructible_ids"]
	assert_eq(pad_ids.size(), 3)
	assert_eq(finish_ids.size(), 1)
	assert_eq(destructible_ids.size(), 1)


func test_dropping_ascent_portal_makes_upper_pads_unreachable() -> void:
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_04_PATH)
	assert_not_null(loaded)
	var data: Dictionary = AuthoringDocument.encode(loaded)
	_drop_entity(data, 10)
	var world: AuthoringWorld = AuthoringDocument.decode(data)
	assert_not_null(world)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_true(_has_code(result, AuthoringReachabilityCodes.UNREACHABLE_CHECKPOINT))


func test_missing_path_is_rejected() -> void:
	assert_null(AuthoringDocument.load_from_path("res://content/official/traprush/missing_04.json"))


func _has_lift(bundle: SimulationBundle) -> bool:
	for bag: Dictionary in bundle.movers:
		var entity_id: int = bag.get("entity_id", 0)
		if entity_id == 200:
			return true
	return false


func _drop_entity(data: Dictionary, entity_id: int) -> void:
	var kept: Array = []
	var entities: Array = data.get("entities", [])
	for item: Variant in entities:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var bag: Dictionary = item
		var raw_id: Variant = bag.get("entity_id", 0)
		if typeof(raw_id) != TYPE_INT:
			continue
		var parsed_id: int = raw_id
		if parsed_id == entity_id:
			continue
		kept.append(bag)
	data["entities"] = kept


func _link_int(link: Dictionary, key: String) -> int:
	var value: int = link.get(key, 0)
	return value


func _link_str(link: Dictionary, key: String) -> String:
	var value: String = link.get(key, "")
	return value


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _has_code(result: Dictionary, code: String) -> bool:
	var issues: Array = result.get("issues", [])
	for item: Variant in issues:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var issue: Dictionary = item
		var issue_code: String = issue.get("code", "")
		if issue_code == code:
			return true
	return false
