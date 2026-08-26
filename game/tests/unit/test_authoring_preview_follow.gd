extends GutTest

## 编辑写入自动进已连接 Preview：成功写入 / Undo / Redo 把同一条 EDIT op
## 按分类等级在安全点转发。分类按 Preview 世界算，不是写入后的编辑世界。
## 失败写入不转发；转发被拒只掉跟随，不回滚编辑；整份导入须重新连接。

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const Levels := preload("res://src/creator/preview_patch_levels.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")

var _shell: AuthoringEditorShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_place_and_remove_reach_connected_preview() -> void:
	_open_shell()
	assert_true(_shell.open_preview())
	assert_true(_shell.preview_follows)
	assert_eq(_shell.preview.preview.preview_revision, 0)
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.preview.preview.world.has_entity(1))
	assert_eq(_shell.preview.preview.preview_revision, 1)
	assert_true(_shell.try_place_portal(2, 3, 1, 0, 0))
	assert_true(_shell.preview.preview.world.has_entity(2))
	assert_true(_shell.try_remove(1))
	assert_false(_shell.preview.preview.world.has_entity(1))
	assert_eq(_shell.preview.preview.preview_revision, 3)
	assert_eq(_shell.preview.preview.world.revision, _shell.session.world.revision)
	assert_true(_shell.preview_follows)
	assert_false(_shell.preview.allows_settlement())


func test_set_component_level_comes_from_preview_world_not_authoring_world() -> void:
	_open_shell()
	assert_true(_shell.try_edit(_place(1, _health(4))))
	assert_true(_shell.open_preview())
	assert_true(_shell.try_edit(_set_component(1, _replication(2))))
	assert_true(_shell.preview_follows)
	var bag: Dictionary = _shell.preview.preview.world.get_record(1).components
	assert_false(bag.has("health"))
	assert_true(bag.has("replication"))


func test_undo_and_redo_reach_connected_preview() -> void:
	_open_shell()
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.open_preview())
	assert_true(_shell.try_place_checkpoint(2, 1, 1, 0, 0))
	assert_true(_shell.undo())
	assert_false(_shell.preview.preview.world.has_entity(2))
	assert_true(_shell.preview.preview.world.has_entity(1))
	assert_true(_shell.redo())
	assert_true(_shell.preview.preview.world.has_entity(2))
	assert_true(_shell.preview_follows)
	assert_eq(_shell.preview.preview.world.revision, _shell.session.world.revision)


func test_refused_edit_forwards_nothing_and_keeps_follow() -> void:
	_open_shell()
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.open_preview())
	var before: PackedByteArray = _shell.preview.preview.world.hash_state()
	assert_false(_shell.try_edit(_place_off_lattice(9)))
	assert_false(_shell.try_place_checkpoint(1, 0, 2, 0, 0))
	assert_eq(_shell.preview.preview.world.hash_state(), before)
	assert_eq(_shell.preview.preview.preview_revision, 0)
	assert_true(_shell.preview_follows)


func test_import_document_drops_follow_until_preview_reconnects() -> void:
	_open_shell()
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.open_preview())
	var snapshot: Dictionary = _shell.export_document()
	assert_true(_shell.import_document(snapshot))
	assert_false(_shell.preview_follows)
	assert_true(_shell.try_place_checkpoint(2, 1, 1, 0, 0))
	assert_false(_shell.preview.preview.world.has_entity(2))
	assert_true(_shell.open_preview())
	assert_true(_shell.preview_follows)
	assert_true(_shell.preview.preview.world.has_entity(2))


func test_out_of_band_preview_patch_desyncs_follow_without_rolling_back_edits() -> void:
	_open_shell()
	assert_true(_shell.open_preview())
	var stray: SharedCommand = SharedCommand.create(
		90, 2, 90, 0, _shell.preview.preview.world.revision, "content-v1", _place(7, _health(1)),
		"trace-stray", SharedCommand.Kind.EDIT
	)
	assert_true(_shell.preview.try_apply_patch(Levels.P2, stray))
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_false(_shell.preview_follows)
	assert_true(_shell.session.world.has_entity(1))
	assert_false(_shell.preview.preview.world.has_entity(1))
	assert_true(_shell.preview.preview.world.has_entity(7))
	assert_true(_shell.try_place_checkpoint(2, 1, 1, 0, 0))
	assert_false(_shell.preview.preview.world.has_entity(2))


func test_edits_without_preview_never_claim_follow() -> void:
	_open_shell()
	assert_false(_shell.preview_follows)
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.undo())
	assert_true(_shell.redo())
	assert_null(_shell.preview)
	var view: Dictionary = _shell.status_view()
	var follows: bool = view["preview_follows"]
	assert_false(follows)


func test_hidden_preview_window_keeps_following() -> void:
	_open_shell()
	assert_true(_shell.open_preview())
	_shell.preview.window.close_requested.emit()
	assert_false(_shell.preview.is_window_visible())
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.preview.preview.world.has_entity(1))
	assert_true(_shell.preview.preview.connected)
	assert_true(_shell.preview_follows)


func test_open_preview_after_hide_shows_window_again() -> void:
	_open_shell()
	assert_true(_shell.open_preview())
	_shell.preview.window.close_requested.emit()
	assert_false(_shell.preview.is_window_visible())
	assert_true(_shell.preview_follows)
	assert_true(_shell.open_preview())
	assert_true(_shell.preview.is_window_visible())
	assert_true(_shell.preview_follows)


func test_open_preview_rebuilds_freed_window() -> void:
	_open_shell()
	assert_true(_shell.open_preview())
	_shell.preview.window.free()
	assert_true(_shell.open_preview())
	assert_true(_shell.preview.is_window_visible())
	assert_true(is_instance_valid(_shell.preview.window))
	assert_true(_shell.preview_follows)


func test_status_label_reports_follow_state() -> void:
	_open_shell()
	assert_true(_shell.status_label_text().contains("follow=false"))
	assert_true(_shell.open_preview())
	assert_true(_shell.status_label_text().contains("follow=true"))


func _open_shell() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())


func _health(current: int) -> Dictionary:
	return {"health": {"current": current, "maximum": 10, "invuln_ticks": 0}}


func _replication(policy_id: int) -> Dictionary:
	return {"replication": {"policy_id": policy_id}}


func _place(entity_id: int, components: Dictionary) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": components,
		},
	}


func _set_component(entity_id: int, components: Dictionary) -> Dictionary:
	return {
		"op": "set_component",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": components,
		},
	}


func _place_off_lattice(entity_id: int) -> Dictionary:
	return _place(entity_id, {"transform": {"x": 1, "y": 0, "z": 0, "yaw_bam": 0}})
