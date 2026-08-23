extends GutTest

## AuthoringEditorShell：代码创建编辑窗口；只发已有 EDIT op。
## 编辑会话保持打开；Preview 不自动跟。未知表面拒绝。永不结算。

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const CELL: int = 65536

var _shell: AuthoringEditorShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_place_checkpoint_on_lattice_and_keeps_session() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.is_window_visible())
	assert_eq(_shell.window.title, AuthoringEditorShell.TITLE)
	assert_false(_shell.window.exclusive)
	assert_false(_shell.window.transient)
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.session.world.has_entity(1))
	assert_eq(_shell.session.world.revision, 1)
	var record: SharedComponentRecord = _shell.session.world.get_record(1)
	var pose: Dictionary = record.components.get("transform", {})
	var x: int = pose.get("x", -1)
	assert_eq(x, 0)
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())


func test_off_grid_place_and_unknown_surface_are_refused() -> void:
	assert_null(AuthoringEditorShell.create("mobile"))
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	var before: PackedByteArray = _shell.session.world.hash_state()
	assert_false(_shell.try_edit(_place_checkpoint_at(1, 0, 1, 0, 0)))
	assert_eq(_shell.session.world.hash_state(), before)
	assert_eq(_shell.session.world.revision, 0)


func test_undo_redo_through_shell() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.DESKTOP_FULL)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_checkpoint(1, 0, 1, 0, 0))
	assert_true(_shell.session.world.has_entity(1))
	assert_true(_shell.undo())
	assert_false(_shell.session.world.has_entity(1))
	assert_true(_shell.redo())
	assert_true(_shell.session.world.has_entity(1))
	var pose: Dictionary = _shell.session.world.get_record(1).components.get("transform", {})
	var x: int = pose.get("x", -1)
	assert_eq(x, CELL)


func test_preview_snapshots_and_does_not_follow_later_edits() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.open_preview())
	assert_true(_shell.preview.is_window_visible())
	assert_eq(_shell.preview.kind, AuthoringPreviewHostKinds.WINDOW)
	assert_true(_shell.preview.preview.world.has_entity(1))
	assert_true(_shell.try_place_checkpoint(2, 1, 1, 0, 0))
	assert_true(_shell.session.world.has_entity(2))
	assert_false(_shell.preview.preview.world.has_entity(2))
	assert_true(_shell.open_preview())
	assert_true(_shell.preview.preview.world.has_entity(2))
	assert_false(_shell.allows_settlement())


func test_document_roundtrip_and_failed_import_keeps_history() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.WEB_LIGHT)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.session.can_undo())
	var snapshot: Dictionary = _shell.export_document()
	assert_false(snapshot.has("surface"))
	assert_false(_shell.import_document({"surface": "web_light"}))
	assert_true(_shell.session.can_undo())
	assert_true(_shell.session.world.has_entity(1))
	var other: AuthoringEditorShell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(other)
	assert_true(other.open())
	assert_true(other.import_document(snapshot))
	assert_false(other.session.can_undo())
	assert_true(other.session.world.has_entity(1))
	assert_eq(other.session.surface, AuthoringSurfaceNames.INTERNAL_DEV)
	other.free()


func test_close_hides_window_and_keeps_authoring() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_checkpoint(3, 0, 0, 0, 0))
	_shell.window.close_requested.emit()
	assert_false(_shell.is_window_visible())
	assert_true(_shell.session.world.has_entity(3))
	assert_true(_shell.show_window())
	assert_true(_shell.is_window_visible())
	assert_eq(_shell.status_label_text().contains("entities=1"), true)


func _place_checkpoint_at(entity_id: int, order: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"checkpoint": {"order": order, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
			},
		},
	}
