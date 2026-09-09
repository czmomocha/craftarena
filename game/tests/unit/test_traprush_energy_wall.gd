extends GutTest

## 可玩性深化第五批：能量墙。
## 可破坏占用 + `zone.tags` 的 `energy_wall`。不新增组件、不改协议帧。
## 打碎走已有 UseItem。权威碰撞仍是一格盒。

const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")
const AuthoringEditorShellGd := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNamesGd := preload("res://src/creator/authoring_surface_names.gd")
const MatchCrateMapGd := preload("res://src/client/match_crate_map.gd")
const OccupancyGadget := preload("res://src/shared/occupancy_gadget.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const WALL_ID: int = 40
const FLOOR_ID: int = 80


func test_energy_wall_compiles_into_optional_bag() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	assert_not_null(bundle)
	assert_eq(bundle.energy_walls.size(), 1)
	assert_eq(bundle.destructibles.size(), 1)
	var wall: Dictionary = bundle.energy_walls[0]
	var wall_id: int = wall["entity_id"]
	assert_eq(wall_id, WALL_ID)
	assert_true(_destructible_has(bundle, WALL_ID))


func test_energy_wall_without_destructible_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_wall_record(WALL_ID, 0, 0, 1, false)))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_energy_wall_plus_solid_is_rejected() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_solid_record(FLOOR_ID, 0, 0, 1, ["solid", "energy_wall"])))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_use_item_breaks_energy_wall_and_opens_the_cell() -> void:
	var session: TraprushMatchSessionGd = _puzzle_session()
	assert_eq(session.destructible_alive_count(), 1)
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	var blocked: Dictionary = session.player_pose(0)
	var blocked_z: int = blocked.get("z", -1)
	assert_lt(blocked_z, CELL)
	session.use_item_damage = 1
	session.use_item_reach_dz = CELL
	assert_true(session.apply_player_intent(0, _use_item()))
	assert_eq(session.destructible_alive_count(), 0)
	assert_true(session.apply_player_intent(0, _move(0, CELL)))
	var opened: Dictionary = session.player_pose(0)
	var opened_z: int = opened.get("z", -1)
	assert_gte(opened_z, CELL)


func test_place_energy_wall_compiles_into_energy_walls_bag() -> void:
	var shell: AuthoringEditorShellGd = AuthoringEditorShellGd.create(
		AuthoringSurfaceNamesGd.INTERNAL_DEV
	)
	add_child_autofree(shell)
	assert_true(shell.open())
	assert_true(shell.tools.place_next_energy_wall())
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(shell.session.world)
	assert_not_null(bundle)
	assert_eq(bundle.energy_walls.size(), 1)
	assert_eq(bundle.destructibles.size(), 1)
	assert_eq(bundle.solids.size(), 0)


func test_old_bundles_without_the_key_still_decode() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	var body: Dictionary = bundle.to_dictionary()
	body.erase(SimulationBundleGd.FIELD_ENERGY_WALLS)
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(body)
	assert_not_null(decoded)
	assert_eq(decoded.energy_walls.size(), 0)
	assert_eq(decoded.destructibles.size(), 1)


func test_an_energy_wall_bag_pointing_at_no_destructible_is_refused() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	var body: Dictionary = bundle.to_dictionary()
	body[SimulationBundleGd.FIELD_ENERGY_WALLS] = [{"entity_id": 999}]
	assert_null(SimulationBundleGd.from_dictionary(body))


func test_crate_map_hangs_a_gadget_on_energy_walls() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	var crates: MatchCrateMapGd = MatchCrateMapGd.new()
	add_child_autofree(crates)
	assert_true(crates.apply_bundle(bundle))
	var node: MeshInstance3D = crates.crate_node(WALL_ID)
	assert_not_null(node)
	assert_not_null(OccupancyGadget.gadget_node(node))
	assert_eq(crates.visual_node(WALL_ID), null)


func _destructible_has(bundle: SimulationBundleGd, entity_id: int) -> bool:
	for bag: Dictionary in bundle.destructibles:
		if bag.get("entity_id", 0) == entity_id:
			return true
	return false


func _world_with_pad() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	return world


func _solid_record(entity_id: int, cell_x: int, cell_y: int, cell_z: int, tags: Array) -> SharedComponentRecordGd:
	return SharedComponentRecordGd.create(entity_id, {
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
	})


func _wall_record(entity_id: int, cell_x: int, cell_y: int, cell_z: int, with_destructible: bool) -> SharedComponentRecordGd:
	var components: Dictionary = {
		"transform": {
			"x": cell_x * CELL,
			"y": cell_y * CELL,
			"z": cell_z * CELL,
			"yaw_bam": 0,
		},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["energy_wall"],
		},
	}
	if with_destructible:
		components["destructible"] = {"durability": 1, "regen_policy_id": 0}
	return SharedComponentRecordGd.create(entity_id, components)


func _puzzle_world() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_solid_record(FLOOR_ID, 0, -1, 0, ["solid"])))
	assert_true(world.put(_solid_record(FLOOR_ID + 1, 0, -1, 1, ["solid"])))
	assert_true(world.put(_solid_record(FLOOR_ID + 2, 0, -1, 2, ["solid"])))
	assert_true(world.put(_wall_record(WALL_ID, 0, 0, 1, true)))
	assert_true(world.put(SharedComponentRecordGd.create(60, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"inventory": {"item_state": "bomb"},
	})))
	return world


func _puzzle_bundle() -> SimulationBundleGd:
	return TraprushTopologyCompilerGd.compile(_puzzle_world())


func _puzzle_session() -> TraprushMatchSessionGd:
	var bundle: SimulationBundleGd = _puzzle_bundle()
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
