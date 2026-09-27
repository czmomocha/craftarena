extends GutTest

## Official TRAPRUSH course_07 Terrace Circuit.
## On MATCH_IDS unlike course_f_playable. Never settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringReachability := preload("res://src/creator/authoring_reachability.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BuilderGd := preload("res://src/games/traprush/course_07_builder.gd")
const Course07Scripts := preload("res://src/games/traprush/course_07_scripts.gd")
const LayoutGd := preload("res://src/games/traprush/course_07_layout.gd")
const PlaceOpsGd := preload("res://src/games/traprush/course_07_builder_place.gd")
const OfficialCourses := preload("res://src/shared/official_traprush_courses.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushTopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")

const COURSE_07_PATH: String = "res://content/official/traprush/course_07.json"
const CELL: int = 65536
const E9_LINE_CAP: int = 400
const BUILDER_PATHS: PackedStringArray = [
	"res://src/games/traprush/course_07_builder.gd",
	"res://src/games/traprush/course_07_builder_place.gd",
	"res://src/games/traprush/course_07_layout.gd",
	"res://src/games/traprush/course_07_scripts.gd",
]


func test_builder_export_matches_the_committed_document() -> void:
	var built: Dictionary = BuilderGd.export_document()
	assert_false(built.is_empty())
	var built_world: AuthoringWorld = AuthoringDocument.decode(built)
	assert_not_null(built_world)
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_07_PATH)
	assert_not_null(loaded)
	assert_eq(built_world.hash_state().hex_encode(), loaded.hash_state().hex_encode())


func test_official_course_07_loads_and_is_publish_ready() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_07_PATH)
	assert_not_null(world)
	assert_eq(world.grid.cell, CELL)
	assert_gte(world.entity_count(), BuilderGd.MIN_ENTITIES)
	assert_lte(world.entity_count(), BuilderGd.MAX_ENTITIES)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result), str(result.get("issues", [])))
	var issues: Array = result.get("issues", [1])
	assert_eq(issues.size(), 0)


func test_course_07_is_on_the_match_whitelist_unlike_f_playable() -> void:
	assert_true(OfficialCourses.is_id(OfficialCourses.COURSE_07))
	assert_eq(OfficialCourses.document_path(OfficialCourses.COURSE_07), COURSE_07_PATH)
	assert_false(OfficialCourses.is_id(OfficialCourses.COURSE_F_PLAYABLE))
	assert_true(OfficialCourses.all_match_ids().has(OfficialCourses.COURSE_07))


func test_course_07_has_four_staggered_floors_and_no_xz_overlap() -> void:
	assert_true(PlaceOpsGd.geometry_ok())
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_07_PATH)
	assert_not_null(world)
	var floors: Dictionary = {}
	for entity_id: int in world.entity_ids():
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null or not record.components.has(SharedComponentNames.TRANSFORM):
			continue
		if not record.components.has(SharedComponentNames.ZONE):
			continue
		var transform: Dictionary = record.components[SharedComponentNames.TRANSFORM]
		var y: int = transform.get("y", 1)
		if y % CELL != 0:
			continue
		floors[y / CELL] = true
	assert_true(floors.has(-7))
	assert_true(floors.has(-3))
	assert_true(floors.has(1))
	assert_true(floors.has(5))
	var seen: Dictionary = {}
	var terrace: int = 1
	while terrace < LayoutGd.TERRACE_COUNT:
		for cell: Vector2i in LayoutGd.snake_of(terrace):
			var key: int = cell.x * 1000 + cell.y
			assert_false(seen.has(key), "playable xz overlap %s" % cell)
			seen[key] = true
		terrace += 1


func test_course_07_compiles_circuit_bags() -> void:
	var bundle: SimulationBundle = _compile()
	assert_not_null(bundle)
	assert_eq(bundle.finish.size(), 1)
	assert_eq(bundle.portals.size(), 6)
	assert_eq(bundle.movers.size(), 5)
	assert_eq(bundle.energy_walls.size(), 1)
	assert_gte(bundle.flames.size(), 4)
	assert_gte(bundle.spikes.size(), 4)
	assert_gte(bundle.rollers.size(), 4)
	assert_eq(bundle.pendulums.size(), 1)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_ok(loaded))


func test_fast_hint_has_at_least_480_moves() -> void:
	var packed: PackedByteArray = Course07Scripts.fast_hint()
	assert_gte(Course07Scripts.move_count(packed), 480)
	var terrace: int = 0
	while terrace < LayoutGd.TERRACE_COUNT:
		assert_gte(LayoutGd.wr_move_count(terrace), LayoutGd.MIN_TERRACE_MOVES)
		terrace += 1
	var names: Array = Course07Scripts.fast_names()
	assert_true(names.has("wait"))
	assert_true(names.has("move+x"))
	assert_false(names.has("use_item"))


func test_builder_files_stay_under_e9_line_cap() -> void:
	for path: String in BUILDER_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_missing_path_is_rejected() -> void:
	assert_null(AuthoringDocument.load_from_path("res://content/official/traprush/missing_07.json"))


func _compile() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_07_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()
