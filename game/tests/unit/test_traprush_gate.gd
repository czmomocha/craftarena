extends GutTest

## 可玩性深化第四批：踩区开关门。
## 固体 + `switch`/`gate` 标签 + 已有 `interactable.link_group`。
## 不新增组件、不改协议帧。开合是占用的纯函数。

const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const AuthoringSessionGd := preload("res://src/creator/authoring_session.gd")
const AuthoringPreviewGd := preload("res://src/creator/authoring_preview.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const PlaySetbackGd := preload("res://src/shared/play_setback.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const SWITCH_ID: int = 80
const GATE_ID: int = 81
const FLOOR_ID: int = 82


func test_switch_and_gate_compile_into_optional_bags() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	assert_not_null(bundle)
	assert_eq(bundle.switches.size(), 1)
	assert_eq(bundle.gates.size(), 1)
	var switch_bag: Dictionary = bundle.switches[0]
	var gate_bag: Dictionary = bundle.gates[0]
	var switch_entity_id: int = switch_bag["entity_id"]
	var switch_link: int = switch_bag["link_group"]
	var gate_entity_id: int = gate_bag["entity_id"]
	var gate_link: int = gate_bag["link_group"]
	assert_eq(switch_entity_id, SWITCH_ID)
	assert_eq(switch_link, 1)
	assert_eq(gate_entity_id, GATE_ID)
	assert_eq(gate_link, 1)
	assert_true(_solid_has(bundle, SWITCH_ID))
	assert_true(_solid_has(bundle, GATE_ID))


func test_a_solid_without_tags_is_not_a_switch() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_solid_record(SWITCH_ID, 0, -1, 0, ["solid"], -1)))
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.switches.size(), 0)
	assert_eq(bundle.gates.size(), 0)


func test_a_switch_without_interactable_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_solid_record(SWITCH_ID, 0, -1, 0, ["solid", "switch"], -1)))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_a_switch_that_is_also_a_gate_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_solid_record(SWITCH_ID, 0, -1, 0, ["solid", "switch", "gate"], 1)))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_a_gate_that_also_moves_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(SharedComponentRecordGd.create(GATE_ID, {
		"transform": {"x": CELL, "y": 0, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid", "gate"],
		},
		"interactable": {"state": 0, "link_group": 1},
		"mover": {
			"path": [{"x": CELL, "y": 0, "z": 0}, {"x": CELL, "y": CELL, "z": 0}],
			"speed": CELL / 16,
			"loop": true,
		},
	})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_old_bundles_without_the_keys_still_decode() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	var body: Dictionary = bundle.to_dictionary()
	body.erase(SimulationBundleGd.FIELD_SWITCHES)
	body.erase(SimulationBundleGd.FIELD_GATES)
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(body)
	assert_not_null(decoded)
	assert_eq(decoded.switches.size(), 0)
	assert_eq(decoded.gates.size(), 0)


func test_a_switch_bag_pointing_at_no_solid_is_refused() -> void:
	var bundle: SimulationBundleGd = _puzzle_bundle()
	var body: Dictionary = bundle.to_dictionary()
	body[SimulationBundleGd.FIELD_SWITCHES] = [{"entity_id": 999, "link_group": 1}]
	assert_null(SimulationBundleGd.from_dictionary(body))


func test_standing_on_the_switch_opens_the_gate() -> void:
	var session: TraprushMatchSessionGd = _puzzle_session()
	assert_eq(session.gate_count(), 1)
	assert_true(session.is_gate_solid(GATE_ID))
	session.commit_tick()
	assert_false(session.is_gate_solid(GATE_ID))
	assert_eq(session.open_gate_entity_ids().size(), 1)


func test_leaving_the_switch_and_the_doorway_closes_the_gate() -> void:
	var session: TraprushMatchSessionGd = _puzzle_session()
	session.commit_tick()
	assert_false(session.is_gate_solid(GATE_ID))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	session.commit_tick()
	assert_true(session.is_gate_solid(GATE_ID), "走出开关和门洞后应关上")
	assert_eq(_pose_x(session), CELL * 2)


func test_overlapping_an_open_gate_keeps_it_open() -> void:
	var session: TraprushMatchSessionGd = _puzzle_session()
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	session.commit_tick()
	assert_false(session.is_gate_solid(GATE_ID), "人在门洞里时即使离开踏板也该开着")
	assert_eq(_pose_x(session), CELL)


func test_two_sessions_with_the_same_gate_match_state_hash() -> void:
	var left: TraprushMatchSessionGd = _puzzle_session()
	var right: TraprushMatchSessionGd = _puzzle_session()
	for _index: int in range(4):
		left.commit_tick()
		right.commit_tick()
	assert_eq(left.hash_state(), right.hash_state())
	assert_eq(left.player_setback_reason(0), PlaySetbackGd.NONE)


func test_preview_standing_on_the_switch_opens_the_gate() -> void:
	var session: AuthoringSessionGd = AuthoringSessionGd.new()
	var world: AuthoringWorldGd = _puzzle_world()
	for entity_id: int in world.entity_ids():
		assert_true(session.world.put(world.get_record(entity_id)))
	var preview: AuthoringPreviewGd = AuthoringPreviewGd.new()
	assert_true(preview.connect_from(session))
	preview.play_support_dy = TraprushPlayStubsGd.SUPPORT_DY
	preview.play_fall_dy = 0
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.play_is_gate_solid(GATE_ID))
	assert_true(preview.try_advance_play())
	assert_false(preview.play_is_gate_solid(GATE_ID))


func _move(dx: int, dz: int) -> Dictionary:
	return {"intent": PlayerIntentNamesGd.MOVE, "dx": dx, "dz": dz}


func _pose_x(session: TraprushMatchSessionGd) -> int:
	var pose: Dictionary = session.player_pose(0)
	var x_value: int = pose.get("x", 0)
	return x_value


func _solid_has(bundle: SimulationBundleGd, entity_id: int) -> bool:
	for solid: Dictionary in bundle.solids:
		var solid_id: int = solid["entity_id"]
		if solid_id == entity_id:
			return true
	return false


func _world_with_pad() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	return world


func _solid_record(
	entity_id: int, cell_x: int, cell_y: int, cell_z: int, tags: Array, link_group: int
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
	if link_group >= 0:
		components["interactable"] = {"state": 0, "link_group": link_group}
	return SharedComponentRecordGd.create(entity_id, components)


func _puzzle_world() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(_solid_record(SWITCH_ID, 0, -1, 0, ["solid", "switch"], 1)))
	assert_true(world.put(_solid_record(GATE_ID, 1, 0, 0, ["solid", "gate"], 1)))
	assert_true(world.put(_solid_record(FLOOR_ID, 1, -1, 0, ["solid"], -1)))
	assert_true(world.put(_solid_record(FLOOR_ID + 1, 2, -1, 0, ["solid"], -1)))
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
