extends GutTest

## Fifth official TRAPRUSH course: dual-route racing.
## Danger shortcut = break the spine energy wall (UseItem reach is +Z).
## Safe road = +Z then +X then back to the ascent portal. No item needed.
## Publish reachability is floor-graph via portals. Lifts are not in that graph.
## Never settlement. Distinct from 01–04 layouts.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")
const AuthoringReachability := preload("res://src/creator/authoring_reachability.gd")
const AuthoringReachabilityCodes := preload("res://src/creator/authoring_reachability_codes.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const Course05Scripts := preload("res://src/games/traprush/course_05_scripts.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const OfficialCourses := preload("res://src/shared/official_traprush_courses.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushTopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_04_PATH: String = "res://content/official/traprush/course_04.json"
const COURSE_05_PATH: String = "res://content/official/traprush/course_05.json"
const CELL: int = 65536
const ENERGY_WALL_ID: int = 50


func test_official_course_05_loads_and_is_publish_ready() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_05_PATH)
	assert_not_null(world)
	assert_eq(world.grid.cell, CELL)
	assert_eq(world.revision, 1)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result))
	var issues: Array = result.get("issues", [1])
	assert_eq(issues.size(), 0)


func test_course_05_is_on_the_match_whitelist_unlike_f_playable() -> void:
	assert_true(OfficialCourses.is_id(OfficialCourses.COURSE_05))
	assert_eq(OfficialCourses.document_path(OfficialCourses.COURSE_05), COURSE_05_PATH)
	assert_false(OfficialCourses.is_id(OfficialCourses.COURSE_F_PLAYABLE))
	assert_true(OfficialCourses.all_match_ids().has(OfficialCourses.COURSE_05))


func test_course_05_layout_differs_from_01_and_04() -> void:
	var first: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	var fourth: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_04_PATH)
	var fifth: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_05_PATH)
	assert_not_null(first)
	assert_not_null(fourth)
	assert_not_null(fifth)
	assert_ne(first.hash_state().hex_encode(), fifth.hash_state().hex_encode())
	assert_ne(fourth.hash_state().hex_encode(), fifth.hash_state().hex_encode())
	var links: Array[Dictionary] = fifth.portal_links()
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


func test_course_05_compiles_energy_wall_and_fixture_bags() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_05_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.pads.size(), 3)
	assert_eq(bundle.portals.size(), 4)
	assert_eq(bundle.finish.size(), 1)
	assert_eq(bundle.destructibles.size(), 1)
	assert_eq(bundle.energy_walls.size(), 1)
	assert_eq(bundle.hazards.size(), 1)
	assert_eq(bundle.pickups.size(), 2)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_ok(loaded))
	var pad_ids: Dictionary = loaded["pad_ids"]
	var finish_ids: Dictionary = loaded["finish_ids"]
	var destructible_ids: Dictionary = loaded["destructible_ids"]
	assert_eq(pad_ids.size(), 3)
	assert_eq(finish_ids.size(), 1)
	assert_eq(destructible_ids.size(), 1)
	assert_true(destructible_ids.has(ENERGY_WALL_ID))


func test_energy_wall_blocks_the_spine_until_broken() -> void:
	var session: TraprushMatchSession = _match_session()
	assert_true(_move_x(session, CELL))
	session.commit_tick()
	assert_true(_move_x(session, CELL))
	session.commit_tick()
	var blocked: Dictionary = session.player_pose(0)
	assert_gt(_axis(blocked, "x"), 0)
	assert_lt(_axis(blocked, "x"), 2 * CELL)
	assert_eq(_axis(blocked, "z"), 0)
	var states: Array[Dictionary] = session.destructible_states()
	assert_eq(states.size(), 1)
	var durability: int = states[0].get("durability", 0)
	assert_eq(durability, 1)


func test_shortcut_script_breaks_the_wall_and_finishes() -> void:
	var names: Array = Course05Scripts.fast_names()
	assert_true(names.has("use_item"))
	var replay: Dictionary = CourseCompletionProbe.try_replay(_compile(), names)
	assert_true(_ok(replay), str(replay.get("reason", "")))
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)


func test_safe_script_finishes_without_use_item() -> void:
	var names: Array = Course05Scripts.safe_names()
	assert_false(names.has("use_item"))
	var replay: Dictionary = CourseCompletionProbe.try_replay(_compile(), names)
	assert_true(_ok(replay), str(replay.get("reason", "")))
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)


func test_dropping_ascent_portal_makes_upper_pads_unreachable() -> void:
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_05_PATH)
	assert_not_null(loaded)
	var data: Dictionary = AuthoringDocument.encode(loaded)
	_drop_entity(data, 10)
	var world: AuthoringWorld = AuthoringDocument.decode(data)
	assert_not_null(world)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_true(_has_code(result, AuthoringReachabilityCodes.UNREACHABLE_CHECKPOINT))


func test_missing_path_is_rejected() -> void:
	assert_null(AuthoringDocument.load_from_path("res://content/official/traprush/missing_05.json"))


func _match_session() -> TraprushMatchSession:
	var session: TraprushMatchSession = TraprushMatchSession.create(
		_compile(),
		1,
		1,
		[{"dx": 0, "dy": 0, "dz": 0}],
		PlayStubs.CAPSULE_RADIUS,
		PlayStubs.CAPSULE_HEIGHT
	)
	assert_not_null(session)
	PlayStubs.apply_match(session)
	return session


func _compile() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_05_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _move_x(session: TraprushMatchSession, dx: int) -> bool:
	return session.apply_player_intent(0, {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": 0,
	})


func _axis(pose: Dictionary, name: String) -> int:
	return pose.get(name, 1)


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
