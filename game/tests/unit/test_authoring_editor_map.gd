extends GutTest

## AuthoringEditorShell 3D：按 AuthoringWorld 重建占位盒；失败不留幽灵。
## 编辑窗口跟随写入；Preview 仍是快照。占位盒不是碰撞体。永不结算。

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringPreviewMap := preload("res://src/creator/authoring_preview_map.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")

const CELL: int = 65536
const EPS: float = 0.0001

var _shell: AuthoringEditorShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_place_checkpoint_maps_box_in_editor_window() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.window.own_world_3d)
	assert_eq(_shell.map.mapped_count(), 0)
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_eq(_shell.map.mapped_count(), 1)
	var node: MeshInstance3D = _shell.map.placeholder_node(1)
	assert_not_null(node)
	assert_almost_eq(node.position.x, 0.0, EPS)
	var box: BoxMesh = node.mesh as BoxMesh
	assert_not_null(box)
	assert_almost_eq(box.size.x, 1.0, EPS)
	assert_almost_eq(box.size.y, 1.0, EPS)
	assert_almost_eq(box.size.z, 1.0, EPS)
	var camera: Camera3D = _shell.map.get_node_or_null(AuthoringPreviewMap.CAMERA_NAME) as Camera3D
	assert_not_null(camera)
	assert_true(camera.current)
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())


func test_off_grid_place_leaves_no_ghost_box() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_false(_shell.try_edit(_place_checkpoint_at(2, 1, 1, 0, 0)))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_null(_shell.map.placeholder_node(2))
	assert_eq(_shell.session.world.revision, 1)


func test_undo_redo_rebuilds_editor_map() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.DESKTOP_FULL)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_checkpoint(1, 0, 1, 0, 0))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_almost_eq(_shell.map.placeholder_node(1).position.x, 1.0, EPS)
	assert_true(_shell.undo())
	assert_eq(_shell.map.mapped_count(), 0)
	assert_null(_shell.map.placeholder_node(1))
	assert_true(_shell.redo())
	assert_eq(_shell.map.mapped_count(), 1)
	assert_almost_eq(_shell.map.placeholder_node(1).position.x, 1.0, EPS)


func test_editor_map_follows_edits_preview_does_not() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.open_preview())
	assert_eq(_shell.map.mapped_count(), 1)
	assert_eq(_shell.preview.map.mapped_count(), 1)
	assert_true(_shell.try_place_checkpoint(2, 1, 1, 0, 0))
	assert_eq(_shell.map.mapped_count(), 2)
	assert_not_null(_shell.map.placeholder_node(2))
	assert_eq(_shell.preview.map.mapped_count(), 1)
	assert_null(_shell.preview.map.placeholder_node(2))
	assert_true(_shell.open_preview())
	assert_eq(_shell.preview.map.mapped_count(), 2)


func test_portal_pair_draws_links_on_editor_map() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_portal(10, 11, 0, 0, 0))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_eq(_shell.map.dangle_count(), 1)
	assert_eq(_shell.map.link_count(), 0)
	assert_true(_shell.try_place_portal(11, 10, 2, 0, 0))
	assert_eq(_shell.map.mapped_count(), 2)
	assert_eq(_shell.map.dangle_count(), 0)
	assert_eq(_shell.map.link_count(), 2)
	assert_true(_shell.try_remove(11))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_eq(_shell.map.dangle_count(), 1)
	assert_eq(_shell.map.link_count(), 0)
	assert_null(_shell.map.placeholder_node(11))


func test_failed_import_keeps_mapped_boxes() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.WEB_LIGHT)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_false(_shell.import_document({"surface": "web_light"}))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_not_null(_shell.map.placeholder_node(1))
	assert_true(_shell.session.world.has_entity(1))


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
