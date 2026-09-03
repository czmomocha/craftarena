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
const TraprushEditorPanelCursor := preload("res://src/creator/traprush_editor_panel_cursor.gd")
const TraprushPickupKinds := preload("res://src/ugc/traprush_pickup_kinds.gd")
const TraprushPlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const AuthoringWindowLayout := preload("res://src/creator/authoring_window_layout.gd")
const AuthoringPreviewMapConvert := preload("res://src/creator/authoring_preview_map_convert.gd")
const AuthoringPreviewMapFloor := preload("res://src/creator/authoring_preview_map_floor.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

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
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.PLACE_FINISH_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.PLACE_BOMB_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanel.PLACE_DASH_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanelCursor.CELL_X_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanelCursor.CELL_Y_NAME, true, false))
	assert_not_null(_shell.tools.find_child(TraprushEditorPanelCursor.CELL_Z_NAME, true, false))
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


func test_place_finish_from_panel_maps_gold_box_and_compiles() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_finish())
	assert_true(_shell.session.world.has_entity(1))
	var record: SharedComponentRecord = _shell.session.world.get_record(1)
	assert_true(record.components.has(SharedComponentNames.ZONE))
	var zone: Dictionary = record.components.get(SharedComponentNames.ZONE, {})
	var tags: Array = zone.get("tags", [])
	assert_eq(tags, [TraprushTopologyCompiler.FINISH_ZONE_TAG])
	assert_eq(_placeholder_albedo(1), AuthoringPreviewMap.FINISH_ALBEDO)
	assert_ne(_placeholder_albedo(1), AuthoringPreviewMap.SOLID_ALBEDO)
	var mark: Label3D = _shell.map.finish_node(1)
	assert_not_null(mark)
	assert_eq(mark.text, "finish")
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(_shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.finish.size(), 1)
	var finish_id: int = bundle.finish[0].get("entity_id", 0)
	var finish_x: int = bundle.finish[0].get("x", -1)
	assert_eq(finish_id, 1)
	assert_eq(finish_x, 0)
	assert_eq(bundle.solids.size(), 0)
	assert_false(_shell.allows_settlement())


func test_sandbox_seed_then_place_finish_is_labeled_and_counted() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_true(_shell.tools.place_next_portal())
	assert_eq(_shell.session.world.entity_count(), 2)
	assert_true(_shell.tools.place_next_finish())
	assert_eq(_shell.session.world.entity_count(), 3)
	assert_false(_shell.session.world.has_entity(3))
	assert_true(_shell.session.world.has_entity(4))
	assert_eq(_placeholder_albedo(4), AuthoringPreviewMap.FINISH_ALBEDO)
	var mark: Label3D = _shell.map.finish_node(4)
	assert_not_null(mark)
	assert_eq(mark.text, "finish")
	assert_eq(_shell.map.finish_count(), 1)
	assert_true(_shell.status_label_text().contains("entities=3"))
	assert_false(_shell.allows_settlement())


func test_finish_after_dangling_portal_still_pairs_on_second_portal() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_portal())
	assert_true(_shell.tools.place_next_finish())
	assert_false(_shell.session.world.has_entity(2))
	assert_true(_shell.session.world.has_entity(3))
	assert_eq(_placeholder_albedo(3), AuthoringPreviewMap.FINISH_ALBEDO)
	assert_true(_shell.tools.place_next_portal())
	assert_true(_shell.session.world.has_entity(2))
	var links: Array[Dictionary] = _shell.session.world.portal_links()
	assert_eq(links.size(), 2)
	assert_eq(str(links[0].get("kind", "")), AuthoringPortalKinds.TWO_WAY)
	assert_eq(str(links[1].get("kind", "")), AuthoringPortalKinds.TWO_WAY)
	assert_eq(_shell.map.finish_count(), 1)
	assert_false(_shell.allows_settlement())


func test_second_finish_still_writes_and_compile_rejects() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_finish())
	assert_true(_shell.tools.place_next_finish())
	assert_true(_shell.session.world.has_entity(1))
	assert_true(_shell.session.world.has_entity(2))
	assert_eq(_shell.map.mapped_count(), 2)
	assert_null(TraprushTopologyCompiler.compile(_shell.session.world))
	assert_false(_shell.allows_settlement())


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
	assert_true(_shell.tools.place_next_finish())
	assert_true(_shell.preview.preview.world.has_entity(1))
	assert_true(_shell.preview.preview.world.has_entity(2))
	assert_true(_shell.preview.preview.world.has_entity(3))
	assert_true(_shell.preview.preview.world.has_entity(4))
	assert_true(_shell.preview_follows)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(_shell.session.world)
	assert_eq(bundle.solids.size(), 1)
	assert_eq(bundle.hazards.size(), 1)
	assert_eq(bundle.destructibles.size(), 1)
	assert_eq(bundle.finish.size(), 1)
	assert_true(_shell.undo())
	assert_false(_shell.session.world.has_entity(4))
	assert_false(_shell.preview.preview.world.has_entity(4))
	assert_eq(_shell.map.mapped_count(), 3)
	assert_null(_shell.map.placeholder_node(4))
	assert_false(_shell.allows_online_writes())


func test_place_solid_uses_explicit_z_cursor() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	_shell.tools.cell_z = 2
	assert_true(_shell.tools.place_next_solid())
	var record: SharedComponentRecord = _shell.session.world.get_record(1)
	var pose: Dictionary = record.components.get("transform", {})
	var solid_z: int = pose.get("z", -1)
	assert_eq(solid_z, CELL * 2)
	assert_eq(_shell.tools.cell_z, 2)
	assert_eq(_shell.tools.cell_x, 1)


func test_unknown_pickup_kind_is_refused() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_false(_shell.try_place_pickup(1, 0, 0, 0, "shield"))
	assert_false(_shell.session.world.has_entity(1))
	assert_false(_shell.allows_settlement())


func test_place_bomb_from_panel_compiles_to_pickups() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_bomb())
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(_shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.pickups.size(), 1)
	assert_eq(str(bundle.pickups[0].get("kind", "")), TraprushPickupKinds.BOMB)
	assert_eq(_shell.tools.cell_x, 1)
	assert_eq(_shell.tools.cell_z, 0)


func test_place_dash_at_spawn_lets_preview_sprint() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	_shell.tools.cell_x = 0
	assert_true(_shell.tools.place_next_dash())
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(_shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.pickups.size(), 1)
	assert_eq(str(bundle.pickups[0].get("kind", "")), TraprushPickupKinds.DASH)
	assert_true(_shell.open_preview())
	assert_eq(_shell.window.mode, Window.MODE_WINDOWED)
	assert_eq(_shell.preview.window.mode, Window.MODE_WINDOWED)
	var host_size: Vector2i = AuthoringWindowLayout.host_size_of(_shell)
	var editor_r: Rect2i = AuthoringWindowLayout.editor_rect(host_size)
	var preview_r: Rect2i = AuthoringWindowLayout.preview_rect(host_size)
	assert_eq(_shell.window.position, editor_r.position)
	assert_eq(_shell.preview.window.position, preview_r.position)
	assert_eq(_shell.window.size, editor_r.size)
	assert_eq(_shell.preview.window.size, preview_r.size)
	assert_true(editor_r.position.x + editor_r.size.x <= preview_r.position.x)
	assert_true(_shell.window.unresizable)
	assert_false(_shell.window.wrap_controls)
	assert_eq(_shell.window.max_size, editor_r.size)
	assert_eq(_shell.preview.window.max_size, preview_r.size)
	assert_true(_editor_right_of_preview_is_false())
	assert_true(_shell.preview.try_start_play(1, TraprushPlayStubs.CAPSULE_RADIUS, TraprushPlayStubs.CAPSULE_HEIGHT))
	assert_eq(_shell.preview.preview.play_dash_count(), 1)
	assert_true(_shell.preview.try_apply_play_intent({"intent": PlayerIntentNames.SPRINT}))
	assert_eq(_shell.preview.preview.play_dash_count(), 0)
	assert_false(_shell.allows_settlement())


func test_preview_sprint_without_dash_pickup_is_rejected() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	assert_true(_shell.open_preview())
	assert_true(_shell.preview.try_start_play(1, TraprushPlayStubs.CAPSULE_RADIUS, TraprushPlayStubs.CAPSULE_HEIGHT))
	assert_eq(_shell.preview.preview.play_dash_count(), 0)
	assert_false(_shell.preview.try_apply_play_intent({"intent": PlayerIntentNames.SPRINT}))


func test_floor_plane_ray_picks_cell_xz() -> void:
	var hit: Dictionary = AuthoringPreviewMapConvert.try_cell_xz_from_ray(
		Vector3(3.4, 8.0, -1.6),
		Vector3(0.0, -1.0, 0.0),
		0.0
	)
	assert_eq(_dict_bool(hit, "ok", false), true)
	assert_eq(_dict_int(hit, "x", -99), 3)
	assert_eq(_dict_int(hit, "z", -99), -2)
	var miss: Dictionary = AuthoringPreviewMapConvert.try_cell_xz_from_ray(
		Vector3(0.0, 2.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		0.0
	)
	assert_eq(_dict_bool(miss, "ok", true), false)


func test_layout_panes_do_not_overlap() -> void:
	assert_false(AuthoringWindowLayout.panes_overlap(Vector2i(1920, 1080)))
	assert_false(AuthoringWindowLayout.panes_overlap(Vector2i(1600, 900)))
	assert_eq(AuthoringWindowLayout.pane_size(Vector2i(1920, 1080)), Vector2i(948, 1064))
	assert_true(AuthoringPreviewMapFloor.is_guide_name("EditGuide_Floor"))
	assert_false(AuthoringPreviewMapFloor.is_guide_name("entity_1"))


func test_editor_floor_guides_exist_after_open() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_not_null(_shell.map.get_node_or_null(AuthoringPreviewMapFloor.FLOOR_NAME))
	assert_not_null(_shell.map.get_node_or_null(AuthoringPreviewMapFloor.GRID_NAME))
	assert_not_null(_shell.map.get_node_or_null(AuthoringPreviewMapFloor.CURSOR_NAME))
	assert_true(_shell.tools.place_next_checkpoint())
	assert_not_null(_shell.map.get_node_or_null(AuthoringPreviewMapFloor.FLOOR_NAME))
	assert_eq(_shell.chrome.selected_id, 1)
	assert_eq(_shell.map.mapped_count(), 1)


func test_try_move_entity_rewrites_transform_and_same_cell_is_noop() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	var revision_before: int = _shell.session.world.revision
	assert_true(_shell.try_move_entity(1, 0, 0, 0))
	assert_eq(_shell.session.world.revision, revision_before)
	assert_true(_shell.try_move_entity(1, 2, 0, 3))
	var record: SharedComponentRecord = _shell.session.world.get_record(1)
	var pose: Dictionary = record.components.get("transform", {})
	var x: int = pose.get("x", -1)
	var y: int = pose.get("y", -1)
	var z: int = pose.get("z", -1)
	assert_eq(x, CELL * 2)
	assert_eq(y, 0)
	assert_eq(z, CELL * 3)
	assert_almost_eq(_shell.map.placeholder_node(1).position.x, 2.0, EPS)
	assert_almost_eq(_shell.map.placeholder_node(1).position.z, 3.0, EPS)
	assert_false(_shell.try_move_entity(99, 1, 0, 0))
	assert_false(_shell.allows_settlement())


func test_ray_picks_placeholder_and_misses_empty() -> void:
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.tools.place_next_checkpoint())
	var half: Vector3 = Vector3(0.5, 0.5, 0.5)
	var hit: Dictionary = AuthoringPreviewMapConvert.try_entity_from_ray(
		_shell.map,
		Vector3(0.0, 8.0, 0.0),
		Vector3(0.0, -1.0, 0.0),
		half
	)
	assert_eq(_dict_bool(hit, "ok", false), true)
	assert_eq(_dict_int(hit, "id", 0), 1)
	var miss: Dictionary = AuthoringPreviewMapConvert.try_entity_from_ray(
		_shell.map,
		Vector3(20.0, 8.0, 20.0),
		Vector3(0.0, -1.0, 0.0),
		half
	)
	assert_eq(_dict_bool(miss, "ok", true), false)


func _dict_bool(bag: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = bag.get(key, fallback)
	if typeof(raw) != TYPE_BOOL:
		return fallback
	var flag: bool = raw
	return flag


func _dict_int(bag: Dictionary, key: String, fallback: int) -> int:
	var raw: Variant = bag.get(key, fallback)
	if typeof(raw) != TYPE_INT:
		return fallback
	var value: int = raw
	return value


func _editor_right_of_preview_is_false() -> bool:
	var editor_right: int = _shell.window.position.x + _shell.window.size.x
	return editor_right <= _shell.preview.window.position.x


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
