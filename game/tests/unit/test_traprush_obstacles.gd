extends GutTest

## 可玩性深化第八批：滚柱 / 碎石 / 障碍核心。
## 不新增组件、不改协议帧。滚柱走已有 hazard 半周期固体；碎石与核心打碎走 UseItem。

const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")
const AuthoringEditorShellGd := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNamesGd := preload("res://src/creator/authoring_surface_names.gd")
const MatchHazardMapGd := preload("res://src/client/match_hazard_map.gd")
const MatchCrateMapGd := preload("res://src/client/match_crate_map.gd")
const OccupancyGadget := preload("res://src/shared/occupancy_gadget.gd")
const PlayHudOverlayGd := preload("res://src/shared/play_hud_overlay.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const ROLLER_ID: int = 50
const RUBBLE_ID: int = 51
const CORE_ID: int = 52
const FLOOR_ID: int = 80


func test_roller_compiles_into_optional_bag() -> void:
	var bundle: SimulationBundleGd = _roller_bundle()
	assert_not_null(bundle)
	assert_eq(bundle.rollers.size(), 1)
	assert_eq(bundle.hazards.size(), 1)
	assert_eq(PlayClock.dict_int(bundle.rollers[0], "entity_id", 0), ROLLER_ID)


func test_roller_without_hazard_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(ROLLER_ID, 0, 0, 1, ["roller"], false, false)))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_roller_plus_flame_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_hazard_record(ROLLER_ID, 0, 0, 1, ["roller", "flame"])))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_rubble_and_core_compile_into_optional_bags() -> void:
	var bundle: SimulationBundleGd = _breakables_bundle()
	assert_not_null(bundle)
	assert_eq(bundle.rubbles.size(), 1)
	assert_eq(bundle.obstacle_cores.size(), 1)
	assert_eq(bundle.destructibles.size(), 2)
	assert_eq(PlayClock.dict_int(bundle.rubbles[0], "entity_id", 0), RUBBLE_ID)
	assert_eq(PlayClock.dict_int(bundle.obstacle_cores[0], "entity_id", 0), CORE_ID)


func test_rubble_plus_energy_wall_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(RUBBLE_ID, 0, 0, 1, ["rubble", "energy_wall"], true, false)))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_use_item_breaks_rubble() -> void:
	var session: TraprushMatchSessionGd = _breakables_session()
	assert_eq(session.destructible_alive_count(), 2)
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	var blocked: Dictionary = session.player_pose(0)
	assert_lt(PlayClock.dict_int(blocked, "z", -1), CELL)
	session.use_item_damage = 1
	session.use_item_reach_dz = CELL
	assert_true(session.apply_player_intent(0, _use_item()))
	assert_eq(session.destructible_alive_count(), 1)
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	var opened: Dictionary = session.player_pose(0)
	assert_gte(PlayClock.dict_int(opened, "z", -1), CELL)


func test_place_buttons_compile_into_bags() -> void:
	var shell: AuthoringEditorShellGd = AuthoringEditorShellGd.create(
		AuthoringSurfaceNamesGd.INTERNAL_DEV
	)
	add_child_autofree(shell)
	assert_true(shell.open())
	assert_true(shell.tools.place_next_roller())
	assert_true(shell.tools.place_next_rubble())
	assert_true(shell.tools.place_next_obstacle_core())
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.rollers.size(), 1)
	assert_eq(bundle.rubbles.size(), 1)
	assert_eq(bundle.obstacle_cores.size(), 1)


func test_old_bundles_without_the_keys_still_decode() -> void:
	var bundle: SimulationBundleGd = _roller_bundle()
	var body: Dictionary = bundle.to_dictionary()
	body.erase(SimulationBundleGd.FIELD_ROLLERS)
	body.erase(SimulationBundleGd.FIELD_RUBBLES)
	body.erase(SimulationBundleGd.FIELD_OBSTACLE_CORES)
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(body)
	assert_not_null(decoded)
	assert_eq(decoded.rollers.size(), 0)
	assert_eq(decoded.rubbles.size(), 0)
	assert_eq(decoded.obstacle_cores.size(), 0)


func test_gadgets_hang_on_roller_rubble_and_core() -> void:
	var roller_bundle: SimulationBundleGd = _roller_bundle()
	var hazards: MatchHazardMapGd = MatchHazardMapGd.new()
	add_child_autofree(hazards)
	assert_true(hazards.apply_bundle(roller_bundle))
	assert_not_null(OccupancyGadget.gadget_node(hazards.hazard_node(ROLLER_ID)))
	var breakables: SimulationBundleGd = _breakables_bundle()
	var crates: MatchCrateMapGd = MatchCrateMapGd.new()
	add_child_autofree(crates)
	assert_true(crates.apply_bundle(breakables))
	assert_not_null(OccupancyGadget.gadget_node(crates.crate_node(RUBBLE_ID)))
	assert_not_null(OccupancyGadget.gadget_node(crates.crate_node(CORE_ID)))


func test_item_hud_shows_bomb_and_dash_counts() -> void:
	var overlay: PlayHudOverlayGd = PlayHudOverlayGd.new()
	var window: Window = Window.new()
	add_child_autofree(window)
	var toolbar: HBoxContainer = HBoxContainer.new()
	window.add_child(toolbar)
	overlay.attach(window, toolbar)
	overlay.apply({
		"play_hud_active": true,
		"clock_tick": 0,
		"bomb_count": 1,
		"dash_count": 0,
	})
	assert_true(overlay.items_text().contains("1"))
	assert_true(overlay.items_text().contains("0"))
	overlay.apply({"play_hud_active": true, "clock_tick": 0, "bomb_count": -1, "dash_count": -1})
	assert_eq(overlay.items_text(), "")


func _world_with_pad() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	return world


func _tagged_box(
	entity_id: int,
	cell_x: int,
	cell_y: int,
	cell_z: int,
	tags: Array,
	with_destructible: bool,
	with_hazard: bool
) -> SharedComponentRecordGd:
	var components: Dictionary = {
		"transform": {
			"x": cell_x * CELL,
			"y": cell_y * CELL,
			"z": cell_z * CELL,
			"yaw_bam": 0,
		},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": tags,
		},
	}
	if with_destructible:
		components["destructible"] = {"durability": 1, "regen_policy_id": 0}
	if with_hazard:
		components["hazard"] = {"damage": 0, "knockback": 0, "cooldown_ticks": 30}
	return SharedComponentRecordGd.create(entity_id, components)


func _hazard_record(entity_id: int, cell_x: int, cell_y: int, cell_z: int, tags: Array) -> SharedComponentRecordGd:
	return _tagged_box(entity_id, cell_x, cell_y, cell_z, tags, false, true)


func _roller_world() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(FLOOR_ID, 0, -1, 0, ["solid"], false, false)))
	assert_true(world.put(_hazard_record(ROLLER_ID, 0, 0, 1, ["roller"])))
	return world


func _roller_bundle() -> SimulationBundleGd:
	return TraprushTopologyCompilerGd.compile(_roller_world())


func _breakables_world() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(FLOOR_ID, 0, -1, 0, ["solid"], false, false)))
	assert_true(world.put(_tagged_box(FLOOR_ID + 1, 0, -1, 1, ["solid"], false, false)))
	assert_true(world.put(_tagged_box(RUBBLE_ID, 0, 0, 1, ["rubble"], true, false)))
	assert_true(world.put(_tagged_box(CORE_ID, 0, 0, 2, ["obstacle_core"], true, false)))
	assert_true(world.put(SharedComponentRecordGd.create(60, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"inventory": {"item_state": "bomb"},
	})))
	return world


func _breakables_bundle() -> SimulationBundleGd:
	return TraprushTopologyCompilerGd.compile(_breakables_world())


func _breakables_session() -> TraprushMatchSessionGd:
	var bundle: SimulationBundleGd = _breakables_bundle()
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	TraprushPlayStubsGd.apply_match(session)
	session.fall_dy = 0
	return session


func _move(dx: int, dz: int) -> Dictionary:
	return {"intent": PlayerIntentNamesGd.MOVE, "dx": dx, "dz": dz}


func _use_item() -> Dictionary:
	return {"intent": PlayerIntentNamesGd.USE_ITEM}
