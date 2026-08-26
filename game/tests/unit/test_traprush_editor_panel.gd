extends GutTest

## TraprushEditorPanel：玩法工具只发已有 EDIT op。
## 检查点/传送门/固体/机关/箱子走格子；楼层改变下一次 place 的 cell_y。
## 删除最后实体不留幽灵盒。不是 BASTION 面板。永不结算。

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringPreviewMap := preload("res://src/creator/authoring_preview_map.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const SharedComponentNames := preload("res://src/shared/schema/component_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const TraprushEditorPanel := preload("res://src/creator/traprush_editor_panel.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

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
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.PLACE_SOLID_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.PLACE_HAZARD_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.PLACE_CRATE_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.REMOVE_LAST_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.FLOOR_UP_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.FLOOR_DOWN_NAME, true, false))
	assert_not_null(_find_named(_shell.window, "Undo"))
	assert_not_null(_find_named(_shell.window, "Preview"))
	var place_btn: Node = _shell.tools.find_child(TraprushEditorPanel.PLACE_CHECKPOINT_NAME, true, false)
	assert_true(_shell.tools.is_ancestor_of(place_btn))


func test_place_solid_from_panel_maps_stone_box_and_compiles() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_solid())
	assert_true(_shell.session.world.has_entity(1))
	var record: SharedComponentRecord = _shell.session.world.get_record(1)
	assert_true(record.components.has(SharedComponentNames.ZONE))
	assert_eq(_placeholder_albedo(1), AuthoringPreviewMap.SOLID_ALBEDO)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(_shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.solids.size(), 1)
	var solid_id: int = bundle.solids[0].get("entity_id", 0)
	var solid_x: int = bundle.solids[0].get("x", -1)
	assert_eq(solid_id, 1)
	assert_eq(solid_x, 0)
	assert_eq(bundle.hazards.size(), 0)
	assert_eq(bundle.destructibles.size(), 0)
	assert_false(_shell.allows_settlement())


func test_place_hazard_from_panel_maps_magenta_box_and_compiles() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_hazard())
	var record: SharedComponentRecord = _shell.session.world.get_record(1)
	var hazard: Dictionary = record.components.get(SharedComponentNames.HAZARD, {})
	var cooldown: int = hazard.get("cooldown_ticks", -1)
	var damage: int = hazard.get("damage", -1)
	assert_eq(cooldown, TraprushEditorPanel.HAZARD_COOLDOWN_STUB)
	assert_eq(damage, 0)
	assert_eq(_placeholder_albedo(1), AuthoringPreviewMap.HAZARD_ALBEDO)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(_shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.hazards.size(), 1)
	var bag_cooldown: int = bundle.hazards[0].get("cooldown_ticks", -1)
	assert_eq(bag_cooldown, TraprushEditorPanel.HAZARD_COOLDOWN_STUB)
	assert_eq(bundle.solids.size(), 0)


func test_place_crate_from_panel_maps_orange_box_and_compiles() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_crate())
	var record: SharedComponentRecord = _shell.session.world.get_record(1)
	var crate: Dictionary = record.components.get(SharedComponentNames.DESTRUCTIBLE, {})
	var durability: int = crate.get("durability", -1)
	var regen: int = crate.get("regen_policy_id", -1)
	assert_eq(durability, TraprushEditorPanel.CRATE_DURABILITY_STUB)
	assert_eq(regen, TraprushEditorPanel.CRATE_REGEN_POLICY_STUB)
	assert_eq(_placeholder_albedo(1), AuthoringPreviewMap.CRATE_ALBEDO)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(_shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.destructibles.size(), 1)
	var bag_durability: int = bundle.destructibles[0].get("durability", -1)
	assert_eq(bag_durability, TraprushEditorPanel.CRATE_DURABILITY_STUB)
	assert_eq(bundle.solids.size(), 0)
	assert_eq(bundle.hazards.size(), 0)


func test_floor_up_places_occupancy_on_next_floor() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.DESKTOP_FULL)
	add_child(_shell)
	assert_true(_shell.open())
	_shell.tools.floor_up()
	assert_true(_shell.tools.place_next_solid())
	var record: SharedComponentRecord = _shell.session.world.get_record(1)
	var pose: Dictionary = record.components.get("transform", {})
	var solid_y: int = pose.get("y", -1)
	assert_eq(solid_y, CELL)
	assert_almost_eq(_shell.map.placeholder_node(1).position.y, 1.0, EPS)


func test_occupancy_places_follow_preview_and_undo() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.open_preview())
	assert_eq(_shell.preview.kind, AuthoringPreviewHostKinds.WINDOW)
	assert_true(_shell.tools.place_next_solid())
	assert_true(_shell.tools.place_next_hazard())
	assert_true(_shell.tools.place_next_crate())
	assert_true(_shell.preview.preview.world.has_entity(1))
	assert_true(_shell.preview.preview.world.has_entity(2))
	assert_true(_shell.preview.preview.world.has_entity(3))
	assert_true(_shell.preview_follows)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(_shell.session.world)
	assert_eq(bundle.solids.size(), 1)
	assert_eq(bundle.hazards.size(), 1)
	assert_eq(bundle.destructibles.size(), 1)
	assert_true(_shell.undo())
	assert_false(_shell.session.world.has_entity(3))
	assert_false(_shell.preview.preview.world.has_entity(3))
	assert_eq(_shell.map.mapped_count(), 2)
	assert_null(_shell.map.placeholder_node(3))
	assert_false(_shell.allows_online_writes())


func _placeholder_albedo(entity_id: int) -> Color:
	var node: MeshInstance3D = _shell.map.placeholder_node(entity_id)
	var box: BoxMesh = node.mesh as BoxMesh
	var material: StandardMaterial3D = box.material as StandardMaterial3D
	return material.albedo_color


func _find_named(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_named(child, node_name)
		if found != null:
			return found
	return null
