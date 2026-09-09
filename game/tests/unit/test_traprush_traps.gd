extends GutTest

## 可玩性深化第七批：地刺 / 喷火 / 压板。
## 不新增组件、不改协议帧。开合 / 命中都不进快照。

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
const MatchHazardMapGd := preload("res://src/client/match_hazard_map.gd")
const OccupancyGadget := preload("res://src/shared/occupancy_gadget.gd")
const PlaySetbackGd := preload("res://src/shared/play_setback.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const SPIKE_ID: int = 40
const FLAME_ID: int = 41
const CRUSHER_ID: int = 42
const FLOOR_ID: int = 80


func test_traps_compile_into_optional_bags() -> void:
	var bundle: SimulationBundleGd = _all_traps_bundle()
	assert_not_null(bundle)
	assert_eq(bundle.spikes.size(), 1)
	assert_eq(bundle.flames.size(), 1)
	assert_eq(bundle.crushers.size(), 1)
	assert_eq(bundle.hazards.size(), 1)
	assert_eq(bundle.movers.size(), 1)
	assert_eq(PlayClock.dict_int(bundle.spikes[0], "entity_id", 0), SPIKE_ID)
	assert_eq(PlayClock.dict_int(bundle.flames[0], "entity_id", 0), FLAME_ID)
	assert_eq(PlayClock.dict_int(bundle.crushers[0], "entity_id", 0), CRUSHER_ID)


func test_spike_without_solid_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(SPIKE_ID, 0, -1, 1, ["spike"], {})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_flame_without_hazard_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(FLAME_ID, 0, 0, 1, ["flame"], {})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_crusher_without_mover_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(CRUSHER_ID, 0, 0, 1, ["solid", "crusher"], {})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_spike_plus_conveyor_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_tagged_box(SPIKE_ID, 0, -1, 1, ["solid", "spike", "conveyor"], {})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_old_bundles_without_the_keys_still_decode() -> void:
	var bundle: SimulationBundleGd = _all_traps_bundle()
	var body: Dictionary = bundle.to_dictionary()
	body.erase(SimulationBundleGd.FIELD_SPIKES)
	body.erase(SimulationBundleGd.FIELD_FLAMES)
	body.erase(SimulationBundleGd.FIELD_CRUSHERS)
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(body)
	assert_not_null(decoded)
	assert_eq(decoded.spikes.size(), 0)
	assert_eq(decoded.flames.size(), 0)
	assert_eq(decoded.crushers.size(), 0)
	assert_eq(decoded.solids.size(), bundle.solids.size())


func test_a_spike_bag_pointing_at_no_solid_is_refused() -> void:
	var bundle: SimulationBundleGd = _all_traps_bundle()
	var body: Dictionary = bundle.to_dictionary()
	body[SimulationBundleGd.FIELD_SPIKES] = [{"entity_id": 999}]
	assert_null(SimulationBundleGd.from_dictionary(body))


func test_standing_on_a_spike_resets_as_hazard() -> void:
	var session: TraprushMatchSessionGd = _spike_session()
	assert_eq(session.player_setback_reason(0), PlaySetbackGd.NONE)
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	session.commit_tick()
	assert_eq(session.player_setback_reason(0), PlaySetbackGd.HAZARD)


func test_flame_burns_when_the_cycle_is_on() -> void:
	var session: TraprushMatchSessionGd = _flame_session(1)
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	session.commit_tick()
	assert_eq(session.player_setback_reason(0), PlaySetbackGd.HAZARD)


func test_flame_lets_you_walk_through_when_off() -> void:
	var session: TraprushMatchSessionGd = _flame_session(1)
	session.commit_tick()
	assert_eq(session.player_setback_reason(0), PlaySetbackGd.NONE)
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	session.apply_player_falls()
	assert_eq(session.player_setback_reason(0), PlaySetbackGd.NONE)
	var pose: Dictionary = session.player_pose(0)
	assert_gte(PlayClock.dict_int(pose, "z", -1), CELL)


func test_crusher_overlap_that_is_not_riding_resets_as_crushed() -> void:
	var session: TraprushMatchSessionGd = _crusher_session()
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	var saw_crush: bool = false
	for _i: int in 24:
		session.commit_tick()
		if session.player_setback_reason(0) == PlaySetbackGd.CRUSHED:
			saw_crush = true
			break
	assert_true(saw_crush)


func test_place_buttons_compile_into_the_bags() -> void:
	var shell: AuthoringEditorShellGd = AuthoringEditorShellGd.create(
		AuthoringSurfaceNamesGd.INTERNAL_DEV
	)
	add_child_autofree(shell)
	assert_true(shell.open())
	assert_true(shell.tools.place_next_checkpoint())
	shell.tools.cursor.set_cell(1, -1, 0)
	assert_true(shell.tools.place_next_spike())
	shell.tools.cursor.set_cell(2, 0, 0)
	assert_true(shell.tools.place_next_flame())
	shell.tools.cursor.set_cell(3, 0, 0)
	assert_true(shell.tools.place_next_crusher())
	assert_not_null(shell.tools.find_child("PlaceSpike", true, false))
	assert_not_null(shell.tools.find_child("PlaceFlame", true, false))
	assert_not_null(shell.tools.find_child("PlaceCrusher", true, false))
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.spikes.size(), 1)
	assert_eq(bundle.flames.size(), 1)
	assert_eq(bundle.crushers.size(), 1)
	assert_eq(bundle.hazards.size(), 1)
	assert_eq(bundle.movers.size(), 1)


func test_maps_hang_gadgets_and_flames_stay_out_of_prediction_solids() -> void:
	var bundle: SimulationBundleGd = _all_traps_bundle()
	var solids: MatchSolidMapGd = MatchSolidMapGd.new()
	add_child_autofree(solids)
	assert_true(solids.apply_bundle(bundle))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(SPIKE_ID)))
	assert_not_null(OccupancyGadget.gadget_node(solids.solid_node(CRUSHER_ID)))
	assert_eq(solids.visual_node(SPIKE_ID), null)
	assert_eq(solids.visual_node(CRUSHER_ID), null)
	var hazards: MatchHazardMapGd = MatchHazardMapGd.new()
	add_child_autofree(hazards)
	assert_true(hazards.apply_bundle(bundle))
	assert_true(hazards.apply_tick(0))
	assert_not_null(OccupancyGadget.gadget_node(hazards.hazard_node(FLAME_ID)))
	assert_eq(hazards.live_solid_boxes().size(), 0)


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


func _spike_record() -> SharedComponentRecordGd:
	return _tagged_box(SPIKE_ID, 0, -1, 1, ["solid", "spike"], {})


func _flame_record(cooldown_ticks: int) -> SharedComponentRecordGd:
	return _tagged_box(FLAME_ID, 0, 0, 1, ["flame"], {
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": cooldown_ticks},
	})


func _crusher_record() -> SharedComponentRecordGd:
	return _tagged_box(CRUSHER_ID, 0, 0, 1, ["solid", "crusher"], {
		"mover": {
			"path": [
				{"x": 0, "y": CELL, "z": CELL},
				{"x": 0, "y": 0, "z": CELL},
			],
			"speed": CELL / 16,
			"loop": true,
		},
	})


func _floor(entity_id: int, cell_x: int, cell_z: int) -> SharedComponentRecordGd:
	return _tagged_box(entity_id, cell_x, -1, cell_z, ["solid"], {})


func _all_traps_world() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_floor(FLOOR_ID, 0, 0)))
	assert_true(world.put(_spike_record()))
	assert_true(world.put(_floor(FLOOR_ID + 1, 1, 0)))
	assert_true(world.put(_tagged_box(FLAME_ID, 1, 0, 0, ["flame"], {
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": 30},
	})))
	assert_true(world.put(_floor(FLOOR_ID + 2, 2, 0)))
	assert_true(world.put(_tagged_box(CRUSHER_ID, 2, 0, 0, ["solid", "crusher"], {
		"mover": {
			"path": [
				{"x": 2 * CELL, "y": CELL, "z": 0},
				{"x": 2 * CELL, "y": 0, "z": 0},
			],
			"speed": CELL / 16,
			"loop": true,
		},
	})))
	return world


func _all_traps_bundle() -> SimulationBundleGd:
	return TraprushTopologyCompilerGd.compile(_all_traps_world())


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


func _spike_session() -> TraprushMatchSessionGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_floor(FLOOR_ID, 0, 0)))
	assert_true(world.put(_spike_record()))
	return _session_from(world)


func _flame_session(cooldown_ticks: int) -> TraprushMatchSessionGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_floor(FLOOR_ID, 0, 0)))
	assert_true(world.put(_floor(FLOOR_ID + 1, 0, 1)))
	assert_true(world.put(_flame_record(cooldown_ticks)))
	return _session_from(world)


func _crusher_session() -> TraprushMatchSessionGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_floor(FLOOR_ID, 0, 0)))
	assert_true(world.put(_floor(FLOOR_ID + 1, 0, 1)))
	assert_true(world.put(_crusher_record()))
	return _session_from(world)


func _move(dx: int, dz: int) -> Dictionary:
	return {"intent": PlayerIntentNamesGd.MOVE, "dx": dx, "dz": dz}
