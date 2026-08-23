extends GutTest

## AuthoringPreviewShell：独立 Window；编辑会话保持打开；关闭只隐藏；永不结算。
## 不编 SimulationBundle。无 transform 的袋不画盒。tab 本刀拒绝。

const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringPreviewShell := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const Levels := preload("res://src/creator/preview_patch_levels.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")

var _shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_open_window_keeps_authoring_session() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place_health(1, 3))))
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_shell)
	assert_true(_shell.open_from(session))
	assert_true(_shell.is_window_visible())
	assert_eq(_shell.window.title, AuthoringPreviewShell.TITLE)
	assert_false(_shell.window.exclusive)
	assert_false(_shell.window.transient)
	assert_true(_shell.preview.world.has_entity(1))
	assert_true(session.try_apply(_edit(2, 1, _place_health(2, 4))))
	assert_true(session.world.has_entity(2))
	assert_false(_shell.preview.world.has_entity(2))
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())
	var view: Dictionary = _shell.status_view()
	var entity_count: int = view.get("entity_count", -1)
	var preview_revision: int = view.get("preview_revision", -1)
	assert_eq(entity_count, 1)
	assert_eq(preview_revision, 0)
	assert_true(_shell.window.own_world_3d)
	assert_eq(_shell.map.mapped_count(), 0)


func test_patch_updates_status_without_settlement() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_shell)
	assert_true(_shell.open_from(session))
	assert_true(_shell.try_apply_patch(Levels.P2, _edit(1, 0, _place_health(8, 3))))
	var view: Dictionary = _shell.status_view()
	var entity_count: int = view.get("entity_count", -1)
	var preview_revision: int = view.get("preview_revision", -1)
	var window_visible: bool = view.get("window_visible", false)
	assert_eq(entity_count, 1)
	assert_eq(preview_revision, 1)
	assert_true(window_visible)
	assert_false(_shell.allows_settlement())
	assert_eq(_shell.status_label_text().contains("entities=1"), true)


func test_close_hides_window_and_keeps_preview() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_shell)
	assert_true(_shell.open_from(session))
	assert_true(_shell.try_apply_patch(Levels.P2, _edit(1, 0, _place_health(3, 1))))
	_shell.window.close_requested.emit()
	assert_false(_shell.is_window_visible())
	assert_true(_shell.preview.connected)
	assert_eq(_shell.preview.preview_revision, 1)
	assert_eq(session.world.entity_count(), 0)
	assert_true(_shell.show_window())
	assert_true(_shell.is_window_visible())
	assert_eq(_shell.preview.preview_revision, 1)


func test_tab_kind_is_refused() -> void:
	assert_null(AuthoringPreviewShell.create("mobile"))
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.TAB)
	assert_not_null(_shell)
	add_child(_shell)
	var session: AuthoringSession = AuthoringSession.new()
	assert_false(_shell.open_from(session))
	assert_null(_shell.window)
	assert_false(_shell.is_window_visible())


func test_failed_patch_does_not_write_or_settle() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_shell)
	assert_true(_shell.open_from(session))
	var before: PackedByteArray = _shell.preview.world.hash_state()
	assert_false(_shell.try_apply_patch(Levels.P1, _edit(1, 0, _place_health(1, 1))))
	assert_eq(_shell.preview.world.hash_state(), before)
	assert_eq(_shell.preview.preview_revision, 0)
	assert_false(_shell.allows_settlement())


func _place_health(entity_id: int, current: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"health": {"current": current, "maximum": 10, "invuln_ticks": 0},
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
		"trace-preview-window",
		SharedCommand.Kind.EDIT
	)
