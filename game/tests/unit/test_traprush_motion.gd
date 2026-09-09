extends GutTest

## 可玩性深化第十 / 十一 / 十二批：摆锤 / 冰面 / 失败次数 HUD。
## 不新增组件、不改协议帧。摆锤走已有水平 mover + crush；冰面复用传送带位移。

const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")
const AuthoringEditorShellGd := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNamesGd := preload("res://src/creator/authoring_surface_names.gd")
const MatchSolidMapGd := preload("res://src/client/match_solid_map.gd")
const OccupancyGadget := preload("res://src/shared/occupancy_gadget.gd")
const PlaySetbackGd := preload("res://src/shared/play_setback.gd")
const PlayHudOverlayGd := preload("res://src/shared/play_hud_overlay.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const PENDULUM_ID: int = 60
const ICE_ID: int = 61
const FLOOR_ID: int = 80


func test_pendulum_compiles_into_optional_bag() -> void:
	var bundle: SimulationBundleGd = _pendulum_bundle()
	assert_not_null(bundle)
	assert_eq(bundle.pendulums.size(), 1)
	assert_eq(bundle.movers.size(), 1)
	assert_eq(PlayClock.dict_int(bundle.pendulums[0], "entity_id", 0), PENDULUM_ID)


func test_pendulum_without_mover_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(PENDULUM_ID, 0, 0, 1, ["solid", "pendulum"], {})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_pendulum_vertical_path_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(PENDULUM_ID, 0, 0, 1, ["solid", "pendulum"], {
		"mover": {
			"path": [
				{"x": 0, "y": CELL, "z": CELL},
				{"x": 0, "y": 0, "z": CELL},
			],
			"speed": CELL / 16,
			"loop": true,
		},
	})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_ice_compiles_into_optional_bag() -> void:
	var bundle: SimulationBundleGd = _ice_bundle()
	assert_not_null(bundle)
	assert_eq(bundle.ices.size(), 1)
	assert_eq(PlayClock.dict_int(bundle.ices[0], "entity_id", 0), ICE_ID)
	assert_eq(PlayClock.dict_int(bundle.ices[0], "yaw_bam", -1), Fixed.BAM_TURN / 2)


func test_ice_plus_conveyor_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(
		ICE_ID, 0, -1, 1, ["solid", "ice", "conveyor"], {}
	)))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_old_bundles_without_the_keys_still_decode() -> void:
	var bundle: SimulationBundleGd = _pendulum_bundle()
	var body: Dictionary = bundle.to_dictionary()
	body.erase(SimulationBundleGd.FIELD_PENDULUMS)
	body.erase(SimulationBundleGd.FIELD_ICES)
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(body)
	assert_not_null(decoded)
	assert_eq(decoded.pendulums.size(), 0)
	assert_eq(decoded.ices.size(), 0)


func test_pendulum_overlap_that_is_not_riding_resets_as_crushed() -> void:
	var session: TraprushMatchSessionGd = _pendulum_session()
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	var saw_crush: bool = false
	for _i: int in 24:
		session.commit_tick()
		if session.player_setback_reason(0) == PlaySetbackGd.CRUSHED:
			saw_crush = true
			break
	assert_true(saw_crush)


func test_ice_slides_along_yaw() -> void:
	var session: TraprushMatchSessionGd = _ice_session()
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	session.commit_tick()
	var after: Dictionary = session.player_pose(0)
	assert_gt(PlayClock.dict_int(after, "z", 0), CELL)


func test_place_buttons_compile_into_bags() -> void:
	var shell: AuthoringEditorShellGd = AuthoringEditorShellGd.create(
		AuthoringSurfaceNamesGd.INTERNAL_DEV
	)
	add_child_autofree(shell)
	assert_true(shell.open())
	assert_true(shell.tools.place_next_checkpoint())
	shell.tools.cursor.set_cell(1, 0, 0)
	assert_true(shell.tools.place_next_pendulum())
	shell.tools.cursor.set_cell(4, -1, 0)
	assert_true(shell.tools.place_next_ice())
	assert_not_null(shell.tools.find_child("PlacePendulum", true, false))
	assert_not_null(shell.tools.find_child("PlaceIce", true, false))
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.pendulums.size(), 1)
	assert_eq(bundle.ices.size(), 1)


func test_maps_hang_gadgets_on_pendulum_and_ice() -> void:
	var bundle: SimulationBundleGd = _motion_bundle()
	var solids: MatchSolidMapGd = MatchSolidMapGd.new()
	add_child_autofree(solids)
	assert_true(solids.apply_bundle(bundle))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(PENDULUM_ID)))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(ICE_ID)))
	assert_eq(solids.visual_node(PENDULUM_ID), null)
	assert_eq(solids.visual_node(ICE_ID), null)


func test_fail_hud_counts_setbacks() -> void:
	var session: TraprushMatchSessionGd = _pendulum_session()
	assert_eq(session.player_setback_count(0), 0)
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	for _i: int in 24:
		session.commit_tick()
		if session.player_setback_count(0) > 0:
			break
	assert_gt(session.player_setback_count(0), 0)
	var overlay: PlayHudOverlayGd = PlayHudOverlayGd.new()
	var window: Window = Window.new()
	add_child_autofree(window)
	var toolbar: HBoxContainer = HBoxContainer.new()
	window.add_child(toolbar)
	overlay.attach(window, toolbar)
	overlay.apply({
		"play_hud_active": true,
		"clock_tick": 0,
		"bomb_count": 0,
		"dash_count": 0,
		"fails_count": session.player_setback_count(0),
	})
	assert_true(overlay.items_text().contains(str(session.player_setback_count(0))))


func _world_with_pad() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	return world


func _tagged_box(
	entity_id: int, cell_x: int, cell_y: int, cell_z: int, tags: Array, extra: Dictionary
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
	for key: Variant in extra.keys():
		components[key] = extra[key]
	return SharedComponentRecordGd.create(entity_id, components)


func _pendulum_record() -> SharedComponentRecordGd:
	return _tagged_box(PENDULUM_ID, 0, 0, 1, ["solid", "pendulum"], {
		"mover": {
			"path": [
				{"x": 2 * CELL, "y": 0, "z": CELL},
				{"x": 0, "y": 0, "z": CELL},
			],
			"speed": CELL / 16,
			"loop": true,
		},
	})


func _ice_record() -> SharedComponentRecordGd:
	return _tagged_box(ICE_ID, 0, -1, 1, ["solid", "ice"], {
		"transform": {"x": 0, "y": -CELL, "z": CELL, "yaw_bam": Fixed.BAM_TURN / 2},
	})


func _floor(entity_id: int, cell_x: int, cell_z: int) -> SharedComponentRecordGd:
	return _tagged_box(entity_id, cell_x, -1, cell_z, ["solid"], {})


func _pendulum_bundle() -> SimulationBundleGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_floor(FLOOR_ID, 0, 0)))
	assert_true(world.put(_pendulum_record()))
	return TraprushTopologyCompilerGd.compile(world)


func _ice_bundle() -> SimulationBundleGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_floor(FLOOR_ID, 0, 0)))
	assert_true(world.put(_ice_record()))
	assert_true(world.put(_floor(FLOOR_ID + 1, 0, 2)))
	return TraprushTopologyCompilerGd.compile(world)


func _motion_bundle() -> SimulationBundleGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_floor(FLOOR_ID, 0, 0)))
	assert_true(world.put(_pendulum_record()))
	assert_true(world.put(_ice_record()))
	return TraprushTopologyCompilerGd.compile(world)


func _session_from(world: AuthoringWorldGd) -> TraprushMatchSessionGd:
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	TraprushPlayStubsGd.apply_match(session)
	session.fall_dy = 0
	session.respawn_stun_ticks = 0
	return session


func _pendulum_session() -> TraprushMatchSessionGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_floor(FLOOR_ID, 0, 0)))
	assert_true(world.put(_floor(FLOOR_ID + 1, 0, 1)))
	assert_true(world.put(_pendulum_record()))
	return _session_from(world)


func _ice_session() -> TraprushMatchSessionGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_floor(FLOOR_ID, 0, 0)))
	assert_true(world.put(_ice_record()))
	assert_true(world.put(_floor(FLOOR_ID + 1, 0, 2)))
	return _session_from(world)


func _move(dx: int, dz: int) -> Dictionary:
	return {"intent": PlayerIntentNamesGd.MOVE, "dx": dx, "dz": dz}
