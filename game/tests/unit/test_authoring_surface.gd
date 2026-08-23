extends GutTest

## AuthoringSurface：internal_dev / desktop_full / web_light。文档不含表面名。
## 两端同一套 EDIT op；自由规则图只在桌面与内部开发器。

const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const CELL: int = 65536


func test_surface_whitelist_and_capability_matrix() -> void:
	assert_eq(AuthoringSurfaceNames.ALL.size(), 3)
	assert_true(AuthoringSurfaceNames.contains(AuthoringSurfaceNames.WEB_LIGHT))
	assert_false(AuthoringSurfaceNames.contains("mobile"))
	assert_true(AuthoringSurfaceNames.allows_edit_commands(AuthoringSurfaceNames.WEB_LIGHT))
	assert_true(AuthoringSurfaceNames.allows_rule_templates(AuthoringSurfaceNames.WEB_LIGHT))
	assert_false(AuthoringSurfaceNames.allows_freeform_rule_graph(AuthoringSurfaceNames.WEB_LIGHT))
	assert_false(AuthoringSurfaceNames.allows_advanced_debug(AuthoringSurfaceNames.WEB_LIGHT))
	assert_true(AuthoringSurfaceNames.allows_freeform_rule_graph(AuthoringSurfaceNames.DESKTOP_FULL))
	assert_true(AuthoringSurfaceNames.allows_advanced_debug(AuthoringSurfaceNames.DESKTOP_FULL))
	assert_false(AuthoringSurfaceNames.allows_batch_generate(AuthoringSurfaceNames.DESKTOP_FULL))
	assert_true(AuthoringSurfaceNames.allows_batch_generate(AuthoringSurfaceNames.INTERNAL_DEV))
	assert_true(AuthoringSurfaceNames.allows_performance_analysis(AuthoringSurfaceNames.INTERNAL_DEV))
	assert_true(AuthoringSurfaceNames.allows_validator_details(AuthoringSurfaceNames.INTERNAL_DEV))
	assert_false(AuthoringSurfaceNames.allows_edit_commands("mobile"))


func test_create_rejects_unknown_surface_and_defaults_to_desktop() -> void:
	assert_null(AuthoringSession.create("mobile"))
	assert_null(AuthoringSession.create(""))
	var created: AuthoringSession = AuthoringSession.create(AuthoringSurfaceNames.WEB_LIGHT)
	assert_not_null(created)
	assert_eq(created.surface, AuthoringSurfaceNames.WEB_LIGHT)
	var implicit: AuthoringSession = AuthoringSession.new()
	assert_eq(implicit.surface, AuthoringSurfaceNames.DESKTOP_FULL)


func test_desktop_and_web_share_document_and_edit_ops() -> void:
	var desktop: AuthoringSession = AuthoringSession.create(AuthoringSurfaceNames.DESKTOP_FULL)
	assert_true(desktop.try_apply(_edit(1, 0, _place(1, 0))))
	var snapshot: Dictionary = desktop.export_document()
	assert_false(snapshot.has("surface"))
	var web: AuthoringSession = AuthoringSession.create(AuthoringSurfaceNames.WEB_LIGHT)
	assert_true(web.import_document(snapshot))
	assert_eq(web.surface, AuthoringSurfaceNames.WEB_LIGHT)
	assert_eq(web.world.hash_state(), desktop.world.hash_state())
	assert_true(web.try_apply(_edit(2, 1, _place(2, CELL))))
	assert_true(web.world.has_entity(2))
	assert_false(desktop.world.has_entity(2))


func test_import_clears_undo_and_failed_import_keeps_history() -> void:
	var session: AuthoringSession = AuthoringSession.create(AuthoringSurfaceNames.DESKTOP_FULL)
	assert_true(session.try_apply(_edit(1, 0, _place(1, 0))))
	assert_true(session.can_undo())
	var snapshot: Dictionary = session.export_document()
	assert_false(session.import_document({"surface": "web_light"}))
	assert_true(session.can_undo())
	assert_true(session.world.has_entity(1))
	var web: AuthoringSession = AuthoringSession.create(AuthoringSurfaceNames.WEB_LIGHT)
	assert_true(web.try_apply(_edit(1, 0, _place(8, 0))))
	assert_true(web.can_undo())
	assert_true(web.import_document(snapshot))
	assert_false(web.can_undo())
	assert_false(web.can_redo())
	assert_true(web.world.has_entity(1))
	assert_false(web.world.has_entity(8))
	var stored: SharedComponentRecord = web.world.get_record(1)
	assert_not_null(stored)


func _place(entity_id: int, y: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": 0, "y": y, "z": 0, "yaw_bam": 0},
			},
		},
	}


func _edit(command_id: int, expected_revision: int, payload: Dictionary) -> SharedCommand:
	return SharedCommand.create(
		command_id,
		2,
		command_id,
		0,
		expected_revision,
		"content-v1",
		payload,
		"trace-edit",
		SharedCommand.Kind.EDIT
	)
