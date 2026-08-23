extends GutTest

## TraprushEditorPanel：玩法工具只发已有 EDIT op。
## 检查点/传送门走格子；楼层改变下一次 place 的 cell_y。
## 删除最后实体不留幽灵盒。不是 BASTION 面板。永不结算。

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const TraprushEditorPanel := preload("res://src/creator/traprush_editor_panel.gd")

const CELL: int = 65536
const EPS: float = 0.0001

var _shell: AuthoringEditorShell = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_place_checkpoint_from_panel_maps_box() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_not_null(_shell.tools)
	assert_true(_shell.tools.place_next_checkpoint())
	assert_true(_shell.session.world.has_entity(1))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_eq(_shell.tools.floor_index, 0)
	assert_false(_shell.allows_settlement())


func test_portal_pair_becomes_two_way_on_editor_map() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_portal())
	assert_eq(_shell.map.dangle_count(), 1)
	assert_eq(_shell.map.link_count(), 0)
	var links: Array[Dictionary] = _shell.session.world.portal_links()
	assert_eq(links.size(), 1)
	assert_eq(str(links[0].get("kind", "")), AuthoringPortalKinds.DANGLING)
	assert_true(_shell.tools.place_next_portal())
	assert_eq(_shell.map.dangle_count(), 0)
	assert_eq(_shell.map.link_count(), 2)
	assert_eq(_shell.map.mapped_count(), 2)
	links = _shell.session.world.portal_links()
	assert_eq(links.size(), 2)
	assert_eq(str(links[0].get("kind", "")), AuthoringPortalKinds.TWO_WAY)
	assert_eq(str(links[1].get("kind", "")), AuthoringPortalKinds.TWO_WAY)


func test_floor_up_places_checkpoint_on_next_floor() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.DESKTOP_FULL)
	add_child(_shell)
	assert_true(_shell.open())
	_shell.tools.floor_up()
	assert_eq(_shell.tools.floor_index, 1)
	assert_true(_shell.tools.place_next_checkpoint())
	var record: SharedComponentRecord = _shell.session.world.get_record(1)
	var pose: Dictionary = record.components.get("transform", {})
	var y: int = pose.get("y", -1)
	assert_eq(y, CELL)
	var on_floor: Array[int] = _shell.session.world.entity_ids_on_floor(1)
	assert_eq(on_floor.size(), 1)
	assert_eq(on_floor[0], 1)
	assert_almost_eq(_shell.map.placeholder_node(1).position.y, 1.0, EPS)


func test_remove_last_clears_map_without_ghost() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_false(_shell.tools.remove_last())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_eq(_shell.map.mapped_count(), 2)
	assert_true(_shell.tools.remove_last())
	assert_false(_shell.session.world.has_entity(2))
	assert_true(_shell.session.world.has_entity(1))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_null(_shell.map.placeholder_node(2))
	assert_false(_shell.allows_online_writes())


func test_floor_down_then_portal_uses_cell_y() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.WEB_LIGHT)
	add_child(_shell)
	assert_true(_shell.open())
	_shell.tools.floor_down()
	assert_eq(_shell.tools.floor_index, -1)
	assert_true(_shell.tools.place_next_portal())
	var record: SharedComponentRecord = _shell.session.world.get_record(1)
	var pose: Dictionary = record.components.get("transform", {})
	var portal_y: int = pose.get("y", 1)
	assert_eq(portal_y, -CELL)
	assert_eq(_shell.status_label_text().contains("floor=-1"), true)


func test_panel_buttons_exist_and_shared_shell_keeps_undo_preview() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.PLACE_CHECKPOINT_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.PLACE_PORTAL_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.REMOVE_LAST_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.FLOOR_UP_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.FLOOR_DOWN_NAME, true, false))
	assert_not_null(_find_named(_shell.window, "Undo"))
	assert_not_null(_find_named(_shell.window, "Preview"))
	var place_btn: Node = _shell.tools.find_child(TraprushEditorPanel.PLACE_CHECKPOINT_NAME, true, false)
	assert_true(_shell.tools.is_ancestor_of(place_btn))


func _find_named(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_named(child, node_name)
		if found != null:
			return found
	return null
