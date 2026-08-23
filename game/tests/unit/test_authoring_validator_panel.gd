extends GutTest

## AuthoringValidatorPanel：只读已有 evaluate_reachability；不是写入门禁。
## 有 transform 的问题可对焦相机。无实体问题只进列表。永不结算。

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringPreviewMap := preload("res://src/creator/authoring_preview_map.gd")
const AuthoringReachabilityCodes := preload("res://src/creator/authoring_reachability_codes.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const AuthoringValidatorPanel := preload("res://src/creator/authoring_validator_panel.gd")

const EPS: float = 0.0001

var _shell: AuthoringEditorShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_empty_world_lists_missing_path_and_focus_is_noop() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_not_null(_shell.validator)
	assert_eq(_shell.validator.reach_ok(), false)
	assert_eq(_shell.validator.issue_count(), 1)
	assert_eq(_shell.validator.issue_code_at(0), AuthoringReachabilityCodes.MISSING_MANDATORY_PATH)
	assert_false(_shell.validator.focus_selected())
	assert_false(_shell.allows_settlement())


func test_single_checkpoint_clears_issues() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.DESKTOP_FULL)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_eq(_shell.validator.reach_ok(), true)
	assert_eq(_shell.validator.issue_count(), 0)
	assert_eq(_shell.status_label_text().contains("reach_ok=true"), true)


func test_dangling_portal_lists_code_and_is_not_a_write_gate() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_true(_shell.tools.place_next_portal())
	assert_true(_shell.session.world.has_entity(2))
	assert_eq(_shell.validator.reach_ok(), false)
	assert_eq(_shell.validator.has_code(AuthoringReachabilityCodes.DANGLING_PORTAL), true)
	assert_eq(_shell.map.dangle_count(), 1)


func test_focus_moves_camera_to_entity_with_transform() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_true(_shell.tools.place_next_portal())
	var camera: Camera3D = _shell.map.get_node_or_null(AuthoringPreviewMap.CAMERA_NAME) as Camera3D
	assert_not_null(camera)
	var before: Vector3 = camera.position
	assert_true(_shell.validator.focus_code(AuthoringReachabilityCodes.DANGLING_PORTAL))
	assert_gt(camera.position.distance_to(before), EPS)
	assert_false(_shell.allows_online_writes())


func test_remove_last_refreshes_details() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.WEB_LIGHT)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_true(_shell.tools.place_next_portal())
	assert_eq(_shell.validator.has_code(AuthoringReachabilityCodes.DANGLING_PORTAL), true)
	assert_true(_shell.tools.remove_last())
	assert_eq(_shell.validator.has_code(AuthoringReachabilityCodes.DANGLING_PORTAL), false)
	assert_eq(_shell.validator.reach_ok(), true)


func test_editor_list_follows_edits_preview_does_not() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_true(_shell.tools.place_next_portal())
	assert_true(_shell.open_preview())
	assert_eq(_shell.preview.map.dangle_count(), 1)
	assert_true(_shell.tools.remove_last())
	assert_eq(_shell.validator.has_code(AuthoringReachabilityCodes.DANGLING_PORTAL), false)
	assert_eq(_shell.preview.map.dangle_count(), 1)


func test_panel_widgets_exist_on_shared_shell() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_not_null(_shell.validator.find_child(AuthoringValidatorPanel.LIST_NAME, true, false))
	assert_not_null(_shell.validator.find_child(AuthoringValidatorPanel.FOCUS_NAME, true, false))
	assert_true(_shell.validator.get_parent() != _shell.tools)
