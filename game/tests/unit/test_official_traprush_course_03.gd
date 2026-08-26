extends GutTest

## Third official TRAPRUSH course: one_way ascent + upper two_way pair.
## Distinct from course_01/02 (both are two_way-only with a +Z crate; this one
## puts a destructible crate on the ground lane and a one_way portal upstairs).
## Publish reachability is ok. Tampering is not a write gate. Never settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringReachability := preload("res://src/creator/authoring_reachability.gd")
const AuthoringReachabilityCodes := preload("res://src/creator/authoring_reachability_codes.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushTopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_02_PATH: String = "res://content/official/traprush/course_02.json"
const COURSE_03_PATH: String = "res://content/official/traprush/course_03.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8

var _shell: AuthoringEditorShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_official_course_03_loads_and_is_publish_ready() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_03_PATH)
	assert_not_null(world)
	assert_eq(world.grid.cell, CELL)
	assert_eq(world.revision, 1)
	assert_eq(world.entity_ids(), [1, 2, 3, 4, 10, 11, 12, 30, 40])
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result))
	var issues: Array = result.get("issues", [1])
	assert_eq(issues.size(), 0)


func test_course_03_has_one_way_ascent_unlike_01_02() -> void:
	var first: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	var second: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_02_PATH)
	var third: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_03_PATH)
	assert_not_null(first)
	assert_not_null(second)
	assert_not_null(third)
	assert_ne(first.hash_state().hex_encode(), third.hash_state().hex_encode())
	assert_ne(second.hash_state().hex_encode(), third.hash_state().hex_encode())
	var links: Array[Dictionary] = third.portal_links()
	assert_eq(links.size(), 3)
	var one_way_count: int = 0
	var two_way_count: int = 0
	for item: Dictionary in links:
		var kind: String = _link_str(item, "kind")
		if kind == AuthoringPortalKinds.ONE_WAY:
			one_way_count += 1
			assert_eq(_link_int(item, "source_id"), 10)
			assert_eq(_link_int(item, "dest_id"), 11)
		elif kind == AuthoringPortalKinds.TWO_WAY:
			two_way_count += 1
	assert_eq(one_way_count, 1)
	assert_eq(two_way_count, 2)
	for item: Dictionary in first.portal_links():
		assert_eq(_link_str(item, "kind"), AuthoringPortalKinds.TWO_WAY)
	for item: Dictionary in second.portal_links():
		assert_eq(_link_str(item, "kind"), AuthoringPortalKinds.TWO_WAY)
	assert_eq(_entity_x(third, 40), CELL)
	assert_eq(_entity_y(third, 40), 0)
	assert_eq(_entity_z(third, 40), 0)


func test_course_03_compiles_and_loads() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_03_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.pads.size(), 4)
	assert_eq(bundle.portals.size(), 3)
	assert_eq(bundle.finish.size(), 1)
	assert_eq(bundle.destructibles.size(), 1)
	assert_eq(bundle.hazards.size(), 0)
	assert_eq(bundle.solids.size(), 0)
	var crate: Dictionary = _destructible(bundle, 40)
	var crate_x: int = crate.get("x", -1)
	var crate_durability: int = crate.get("durability", -1)
	assert_eq(crate_x, CELL)
	assert_eq(crate_durability, 1)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	assert_true(_flag(loaded))
	var sim: SimulationWorld = loaded["world"]
	var pad_ids: Dictionary = loaded["pad_ids"]
	var portal_ids: Dictionary = loaded["portal_ids"]
	var finish_ids: Dictionary = loaded["finish_ids"]
	var destructible_ids: Dictionary = loaded["destructible_ids"]
	assert_eq(pad_ids.size(), 4)
	assert_eq(portal_ids.size(), 3)
	assert_eq(finish_ids.size(), 1)
	assert_eq(destructible_ids.size(), 1)
	var hazard_ids: Dictionary = loaded["hazard_ids"]
	assert_eq(hazard_ids.size(), 0)
	var pad_box: int = pad_ids[1]
	assert_false(sim.is_static_box_solid(pad_box))
	var crate_box: int = destructible_ids[40]
	assert_true(sim.is_static_box_solid(crate_box))


func test_course_03_preview_play_full_run() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_03_PATH)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 1)
	assert_eq(preview.play_floor_index(), 0)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var blocked: Dictionary = preview.play_world.get_pose(preview.player_id)
	var blocked_x: int = blocked.get("x", -1)
	assert_lt(blocked_x, CELL)
	assert_eq(preview.play_accepted_count(), 1)
	preview.play_use_item_damage = 1
	preview.play_use_item_reach_dx = CELL
	assert_true(preview.try_apply_play_intent(_use_item()))
	assert_eq(preview.play_destructible_alive_count(), 0)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 2)
	assert_eq(preview.play_last_accepted_id(), 2)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var landed: Dictionary = preview.play_world.get_pose(preview.player_id)
	var landed_x: int = landed.get("x", -1)
	var landed_y: int = landed.get("y", -1)
	var landed_z: int = landed.get("z", -1)
	assert_eq(landed_x, 0)
	assert_eq(landed_y, CELL)
	assert_eq(landed_z, CELL)
	assert_eq(preview.play_floor_index(), 1)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 3)
	assert_eq(preview.play_last_accepted_id(), 3)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 4)
	assert_eq(preview.play_last_accepted_id(), 4)
	assert_eq(preview.play_finish_tick(), -1)
	assert_true(preview.try_apply_play_intent(_move(0, CELL)))
	assert_eq(preview.play_finish_tick(), 0)
	assert_eq(preview.play_world.tick_index, 0)
	assert_false(preview.allows_settlement())
	assert_false(preview.allows_online_writes())


func test_course_03_editor_import_shows_zero_issues_and_never_settles() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_03_PATH)
	assert_not_null(loaded)
	assert_true(_shell.import_document(AuthoringDocument.encode(loaded)))
	assert_eq(_shell.validator.reach_ok(), true)
	assert_eq(_shell.validator.issue_count(), 0)
	assert_eq(_shell.status_label_text().contains("reach_ok=true"), true)
	assert_false(_shell.allows_settlement())


func test_dropping_one_way_portal_makes_upper_pads_unreachable() -> void:
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_03_PATH)
	assert_not_null(loaded)
	var data: Dictionary = AuthoringDocument.encode(loaded)
	_drop_entity(data, 10)
	var world: AuthoringWorld = AuthoringDocument.decode(data)
	assert_not_null(world)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_true(_has_code(result, AuthoringReachabilityCodes.UNREACHABLE_CHECKPOINT))


func test_missing_path_is_rejected() -> void:
	assert_null(AuthoringDocument.load_from_path("res://content/official/traprush/missing_03.json"))


func _move(dx: int, dz: int) -> Dictionary:
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	}


func _use_item() -> Dictionary:
	return {
		"intent": PlayerIntentNames.USE_ITEM,
	}


func _entity_x(world: AuthoringWorld, entity_id: int) -> int:
	return _entity_axis(world, entity_id, "x")


func _entity_y(world: AuthoringWorld, entity_id: int) -> int:
	return _entity_axis(world, entity_id, "y")


func _entity_z(world: AuthoringWorld, entity_id: int) -> int:
	return _entity_axis(world, entity_id, "z")


func _entity_axis(world: AuthoringWorld, entity_id: int, axis: String) -> int:
	var record: SharedComponentRecord = world.get_record(entity_id)
	if record == null:
		return -1
	if not record.components.has(SharedComponentNames.TRANSFORM):
		return -1
	var raw: Variant = record.components[SharedComponentNames.TRANSFORM]
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	var body: Dictionary = raw
	if typeof(body.get(axis, null)) != TYPE_INT:
		return -1
	var value: int = body[axis]
	return value


func _destructible(bundle: SimulationBundle, entity_id: int) -> Dictionary:
	for item: Dictionary in bundle.destructibles:
		if item.get("entity_id", 0) == entity_id:
			return item
	return {}


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


func _flag(result: Dictionary) -> bool:
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
