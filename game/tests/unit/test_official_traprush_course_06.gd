extends GutTest

## Sixth official TRAPRUSH course: seven layers, gap of two cells.
## Climb is three two-way portal hops; lifts recover skipped floors.
## Launch pads cannot land a 4-cell hop onto a same-xz floor. Never settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringReachability := preload("res://src/creator/authoring_reachability.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BuilderGd := preload("res://src/games/traprush/course_06_builder.gd")
const Course06Scripts := preload("res://src/games/traprush/course_06_scripts.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const OfficialCourses := preload("res://src/shared/official_traprush_courses.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushTopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_06_PATH: String = "res://content/official/traprush/course_06.json"
const CELL: int = 65536
const MIN_ENTITIES: int = 350
const MAX_ENTITIES: int = 400


func test_builder_export_matches_the_committed_document() -> void:
	var built: Dictionary = BuilderGd.export_document()
	assert_false(built.is_empty())
	var built_world: AuthoringWorld = AuthoringDocument.decode(built)
	assert_not_null(built_world)
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_06_PATH)
	assert_not_null(loaded)
	assert_eq(built_world.hash_state().hex_encode(), loaded.hash_state().hex_encode())


func test_official_course_06_loads_and_is_publish_ready() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_06_PATH)
	assert_not_null(world)
	assert_eq(world.grid.cell, CELL)
	assert_gte(world.entity_count(), MIN_ENTITIES)
	assert_lte(world.entity_count(), MAX_ENTITIES)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result), str(result.get("issues", [])))
	var issues: Array = result.get("issues", [1])
	assert_eq(issues.size(), 0)


func test_course_06_is_on_the_match_whitelist_unlike_f_playable() -> void:
	assert_true(OfficialCourses.is_id(OfficialCourses.COURSE_06))
	assert_eq(OfficialCourses.document_path(OfficialCourses.COURSE_06), COURSE_06_PATH)
	assert_false(OfficialCourses.is_id(OfficialCourses.COURSE_F_PLAYABLE))
	assert_true(OfficialCourses.all_match_ids().has(OfficialCourses.COURSE_06))


func test_course_06_layout_differs_from_01_and_has_seven_floors() -> void:
	var first: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	var sixth: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_06_PATH)
	assert_not_null(first)
	assert_not_null(sixth)
	assert_ne(first.hash_state().hex_encode(), sixth.hash_state().hex_encode())
	assert_eq(sixth.portal_links().size(), 6)
	var floors: Dictionary = {}
	for entity_id: int in sixth.entity_ids():
		var record: SharedComponentRecord = sixth.get_record(entity_id)
		if record == null or not record.components.has(SharedComponentNames.TRANSFORM):
			continue
		var transform: Dictionary = record.components[SharedComponentNames.TRANSFORM]
		var y: int = transform.get("y", 1)
		if y % CELL != 0:
			continue
		floors[y / CELL] = true
	assert_true(floors.has(-7))
	assert_true(floors.has(-5))
	assert_true(floors.has(-3))
	assert_true(floors.has(-1))
	assert_true(floors.has(1))
	assert_true(floors.has(3))
	assert_true(floors.has(5))


func test_course_06_compiles_portal_lift_and_finish_bags() -> void:
	var bundle: SimulationBundle = _compile()
	assert_not_null(bundle)
	assert_eq(bundle.finish.size(), 1)
	assert_eq(bundle.portals.size(), 6)
	assert_eq(bundle.launches.size(), 0)
	assert_eq(bundle.pads.size(), 1)
	assert_eq(bundle.movers.size(), 3)
	var lift_count: int = 0
	for bag: Dictionary in bundle.movers:
		var entity_id: int = bag.get("entity_id", 0)
		if entity_id == 20 or entity_id == 21 or entity_id == 22:
			lift_count += 1
	assert_eq(lift_count, 3)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_ok(loaded))


func test_climb_script_finishes_via_three_portal_hops() -> void:
	var names: Array = Course06Scripts.climb_names()
	assert_true(names.has("wait"))
	assert_true(names.has("move+x"))
	assert_true(names.has("move-x"))
	assert_false(names.has("use_item"))
	var replay: Dictionary = CourseCompletionProbe.try_replay(_compile(), names)
	assert_true(_ok(replay), str(replay.get("reason", "")))
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)


func test_missing_path_is_rejected() -> void:
	assert_null(AuthoringDocument.load_from_path("res://content/official/traprush/missing_06.json"))


func _compile() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_06_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag
