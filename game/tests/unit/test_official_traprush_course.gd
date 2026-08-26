extends GutTest

## First official TRAPRUSH course: AuthoringDocument on disk.
## Publish reachability is ok. Tampering is not a write gate. Never settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringReachability := preload("res://src/creator/authoring_reachability.gd")
const AuthoringReachabilityCodes := preload("res://src/creator/authoring_reachability_codes.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")

const COURSE_PATH: String = "res://content/official/traprush/course_01.json"

var _shell: AuthoringEditorShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_official_course_loads_and_is_publish_ready() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_PATH)
	assert_not_null(world)
	assert_eq(world.grid.cell, 65536)
	assert_eq(world.revision, 9)
	assert_eq(world.entity_ids(), [1, 2, 3, 10, 11, 30, 40, 60, 70, 80])
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result))
	var issues: Array = result.get("issues", [1])
	assert_eq(issues.size(), 0)


func test_missing_path_and_extra_key_are_rejected() -> void:
	assert_null(AuthoringDocument.load_from_path("res://content/official/traprush/missing.json"))
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_PATH)
	assert_not_null(loaded)
	var data: Dictionary = AuthoringDocument.encode(loaded)
	data["surface"] = "internal_dev"
	assert_null(AuthoringDocument.decode(data))


func test_editor_import_shows_zero_issues_and_never_settles() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_PATH)
	assert_not_null(loaded)
	assert_true(_shell.import_document(AuthoringDocument.encode(loaded)))
	assert_eq(_shell.validator.reach_ok(), true)
	assert_eq(_shell.validator.issue_count(), 0)
	assert_eq(_shell.status_label_text().contains("reach_ok=true"), true)
	assert_false(_shell.allows_settlement())


func test_retarget_portal_is_dangling_and_not_a_write_gate() -> void:
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_PATH)
	assert_not_null(loaded)
	var data: Dictionary = AuthoringDocument.encode(loaded)
	_retarget_portal(data, 10, 99)
	var world: AuthoringWorld = AuthoringDocument.decode(data)
	assert_not_null(world)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_true(_has_code(result, AuthoringReachabilityCodes.DANGLING_PORTAL))
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.DESKTOP_FULL)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.import_document(AuthoringDocument.encode(loaded)))
	assert_eq(_shell.validator.reach_ok(), true)
	assert_true(_shell.try_place_portal(20, 99, 5, 0, 0))
	assert_true(_shell.session.world.has_entity(20))
	assert_eq(_shell.validator.has_code(AuthoringReachabilityCodes.DANGLING_PORTAL), true)
	assert_false(_shell.allows_settlement())


func test_cross_floor_without_portals_is_unreachable() -> void:
	var loaded: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_PATH)
	assert_not_null(loaded)
	var data: Dictionary = AuthoringDocument.encode(loaded)
	_drop_portals(data)
	var world: AuthoringWorld = AuthoringDocument.decode(data)
	assert_not_null(world)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_true(_has_code(result, AuthoringReachabilityCodes.UNREACHABLE_CHECKPOINT))


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _retarget_portal(data: Dictionary, entity_id: int, target_id: int) -> void:
	var entities: Array = data.get("entities", [])
	for item: Variant in entities:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var bag: Dictionary = item
		var raw_id: Variant = bag.get("entity_id", 0)
		if typeof(raw_id) != TYPE_INT:
			continue
		var parsed_id: int = raw_id
		if parsed_id != entity_id:
			continue
		var components: Dictionary = bag.get("components", {})
		var portal: Dictionary = components.get("portal", {})
		portal["target_id"] = target_id
		components["portal"] = portal
		bag["components"] = components
		return


func _drop_portals(data: Dictionary) -> void:
	var kept: Array = []
	var entities: Array = data.get("entities", [])
	for item: Variant in entities:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var bag: Dictionary = item
		var components: Dictionary = bag.get("components", {})
		if components.has("portal"):
			continue
		kept.append(bag)
	data["entities"] = kept


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
