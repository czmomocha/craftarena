extends GutTest

## Official TRAPRUSH course_08 benchmark parkour draft.
## On MATCH_IDS unlike course_f_playable. Never settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringReachability := preload("res://src/creator/authoring_reachability.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BuilderGd := preload("res://src/games/traprush/course_08_builder.gd")
const Course08Scripts := preload("res://src/games/traprush/course_08_scripts.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const HumanPaceRunner := preload("res://src/games/traprush/human_pace_runner.gd")
const LayoutGd := preload("res://src/games/traprush/course_08_layout.gd")
const OfficialCourses := preload("res://src/shared/official_traprush_courses.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushTopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")

const COURSE_08_PATH: String = "res://content/official/traprush/course_08.json"
const CELL: int = 65536
const E9_LINE_CAP: int = 400
const BUILDER_PATHS: PackedStringArray = [
	"res://src/games/traprush/course_08_builder.gd",
	"res://src/games/traprush/course_08_builder_place.gd",
	"res://src/games/traprush/course_08_layout.gd",
	"res://src/games/traprush/course_08_scripts.gd",
]


func test_builder_export_matches_the_committed_document() -> void:
	var built: Dictionary = BuilderGd.export_document()
	assert_false(built.is_empty())
	var built_world: AuthoringWorld = AuthoringDocument.decode(built)
	assert_not_null(built_world)
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_08_PATH)
	assert_not_null(loaded)
	assert_eq(built_world.hash_state().hex_encode(), loaded.hash_state().hex_encode())


func test_official_course_08_loads_and_is_publish_ready() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_08_PATH)
	assert_not_null(world)
	assert_eq(world.grid.cell, CELL)
	assert_gte(world.entity_count(), BuilderGd.MIN_ENTITIES)
	assert_lte(world.entity_count(), BuilderGd.MAX_ENTITIES)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result), str(result.get("issues", [])))
	var issues: Array = result.get("issues", [1])
	assert_eq(issues.size(), 0)


func test_course_08_is_on_the_match_whitelist_unlike_f_playable() -> void:
	assert_true(OfficialCourses.is_id(OfficialCourses.COURSE_08))
	assert_true(OfficialCourses.is_document_id("course_08"))
	assert_eq(OfficialCourses.document_path(OfficialCourses.COURSE_08), COURSE_08_PATH)
	assert_eq(OfficialCourses.normalize_id("course_08"), "course_08")
	assert_true(OfficialCourses.all_match_ids().has(OfficialCourses.COURSE_08))
	assert_false(OfficialCourses.is_id(OfficialCourses.COURSE_F_PLAYABLE))


func test_course_08_checkpoint_orders_are_unique_and_dense() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_08_PATH)
	assert_not_null(world)
	var orders: Dictionary = {}
	for entity_id: int in world.entity_ids():
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null or not record.components.has(SharedComponentNames.CHECKPOINT):
			continue
		var body: Dictionary = record.components[SharedComponentNames.CHECKPOINT]
		var order: int = body.get("order", -1)
		assert_false(orders.has(order), "duplicate checkpoint order %d" % order)
		orders[order] = entity_id
	assert_eq(orders.size(), LayoutGd.CHECKPOINT_COUNT)
	var expected: int = 0
	while expected < LayoutGd.CHECKPOINT_COUNT:
		assert_true(orders.has(expected), "missing checkpoint order %d" % expected)
		expected += 1


func test_course_08_compiles_and_start_cannot_finish() -> void:
	var bundle: SimulationBundle = _compile()
	assert_not_null(bundle)
	assert_eq(bundle.finish.size(), 1)
	assert_gte(bundle.pendulums.size(), 5)
	assert_gte(bundle.flames.size(), 9)
	assert_gte(bundle.spikes.size(), 12)
	assert_gte(bundle.rollers.size(), 5)
	assert_eq(bundle.energy_walls.size(), 1)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_ok(loaded))
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle, 1, 1, [{"dx": 0, "dy": 0, "dz": 0}],
		PlayStubs.CAPSULE_RADIUS, PlayStubs.CAPSULE_HEIGHT
	)
	assert_not_null(session)
	PlayStubs.apply_match(session)
	assert_eq(session.checkpoint_count(), LayoutGd.CHECKPOINT_COUNT)
	assert_eq(session.player_accepted_count(0), 1)
	assert_eq(session.player_finish_tick(0), -1)
	session.commit_tick()
	assert_eq(session.player_finish_tick(0), -1)


func test_course_08_has_throats_choices_and_far_side_rails_only() -> void:
	assert_true(LayoutGd.geometry_ok())
	assert_gte(LayoutGd.throat_xz().size(), 5)
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_08_PATH)
	assert_not_null(world)
	var camera_side_rails: int = 0
	for entity_id: int in world.entity_ids():
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null or not record.components.has(SharedComponentNames.ZONE):
			continue
		if not record.components.has(SharedComponentNames.TRANSFORM):
			continue
		var zone: Dictionary = record.components[SharedComponentNames.ZONE]
		var tags: Array = zone.get("tags", [])
		if not tags.has(TraprushTopologyCompiler.SOLID_ZONE_TAG):
			continue
		if tags.size() != 1:
			continue
		var transform: Dictionary = record.components[SharedComponentNames.TRANSFORM]
		var x: int = transform.get("x", 1)
		var y: int = transform.get("y", 1)
		var z: int = transform.get("z", 1)
		if y % CELL != 0 or x % CELL != 0 or z % CELL != 0:
			continue
		var cell_x: int = x / CELL
		var cell_y: int = y / CELL
		var cell_z: int = z / CELL
		if cell_y == 0 and cell_z == 38 and cell_x >= 8 and cell_x <= 22:
			camera_side_rails += 1
		if cell_y == 2 and cell_x == 5 and cell_z >= 19 and cell_z <= 26:
			camera_side_rails += 1
	assert_eq(camera_side_rails, 0)


func test_builder_files_stay_under_e9_line_cap() -> void:
	for path: String in BUILDER_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_course_08_scripted_safe_edge_is_completable() -> void:
	var hint: PackedByteArray = Course08Scripts.fast_hint()
	assert_gt(Course08Scripts.move_count(hint), 80)
	var result: Dictionary = CourseCompletionProbe.run_path(
		COURSE_08_PATH,
		8000,
		800,
		PackedInt32Array(),
		CourseCompletionProbe.ACTION_SET_FULL,
		hint
	)
	var outcome: String = result["outcome"]
	var reason: String = result.get("reason", "")
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE, reason)
	assert_true(result.has("actions"), reason)
	var actions: Array = result.get("actions", [])
	var replay: Dictionary = CourseCompletionProbe.try_replay(_compile(), actions)
	var ok: bool = replay["ok"]
	assert_true(ok, str(replay.get("reason", "")))
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)


func test_course_08_human_pace_tape_finishes() -> void:
	var tape: PackedByteArray = Course08Scripts.human_tape()
	assert_gt(tape.size(), 80)
	var result: Dictionary = HumanPaceRunner.run_path(COURSE_08_PATH, tape, 12000)
	var outcome: String = result["outcome"]
	var reason: String = result.get("reason", "")
	var total_ticks: int = result["total_ticks"]
	var checkpoint_ticks: Array = result["checkpoint_ticks"]
	print("course_08 human total_ticks=%d sec=%.2f checkpoint_ticks=%s" % [
		total_ticks,
		float(total_ticks) / 60.0,
		str(checkpoint_ticks),
	])
	assert_eq(outcome, HumanPaceRunner.OUTCOME_COMPLETABLE, reason)
	assert_gte(total_ticks, 1)


func test_missing_path_is_rejected() -> void:
	assert_null(AuthoringDocument.load_from_path("res://content/official/traprush/missing_08.json"))


func _compile() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_08_PATH)
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
