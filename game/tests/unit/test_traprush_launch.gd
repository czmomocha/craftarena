extends GutTest

## 可玩性深化第二批：弹射垫。
## 固体 + `zone.tags` 的 `launch` + `transform.yaw_bam`。不新增组件。
## 支撑上升沿弹一次：竖直走已有 apply_jump，水平沿四向送出一格。

const ConveyorCycleGd := preload("res://src/games/traprush/conveyor_cycle.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const PAD_ID: int = 70
const FLOOR_ID: int = 71


func test_launch_compiles_into_solids_plus_a_direction_bag() -> void:
	var bundle: SimulationBundleGd = _pad_bundle(ConveyorCycleGd.YAW_RIGHT)
	assert_not_null(bundle)
	assert_eq(bundle.launches.size(), 1)
	var bag: Dictionary = bundle.launches[0]
	var entity_id: int = bag["entity_id"]
	var yaw_bam: int = bag["yaw_bam"]
	assert_eq(entity_id, PAD_ID)
	assert_eq(yaw_bam, ConveyorCycleGd.YAW_RIGHT)
	var in_solids: bool = false
	for solid: Dictionary in bundle.solids:
		var solid_id: int = solid["entity_id"]
		if solid_id == PAD_ID:
			in_solids = true
	assert_true(in_solids)


func test_a_solid_without_the_tag_compiles_to_no_launch() -> void:
	var world: AuthoringWorldGd = _world_with_floor()
	assert_true(world.put(_pad_record(PAD_ID, 0, ["solid"], 0)))
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.launches.size(), 0)


func test_a_pad_that_also_moves_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_floor()
	assert_true(world.put(SharedComponentRecordGd.create(PAD_ID, {
		"transform": {"x": 0, "y": -CELL, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid", "launch"],
		},
		"mover": {
			"path": [{"x": 0, "y": -CELL, "z": 0}, {"x": 0, "y": CELL, "z": 0}],
			"speed": CELL / 16,
			"loop": true,
		},
	})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_a_pad_that_is_also_a_conveyor_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_floor()
	assert_true(world.put(_pad_record(PAD_ID, 0, ["solid", "launch", "conveyor"], 0)))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_old_bundles_without_the_key_still_decode() -> void:
	var bundle: SimulationBundleGd = _pad_bundle(ConveyorCycleGd.YAW_RIGHT)
	var body: Dictionary = bundle.to_dictionary()
	body.erase(SimulationBundleGd.FIELD_LAUNCHES)
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(body)
	assert_not_null(decoded)
	assert_eq(decoded.launches.size(), 0)


func test_a_launch_bag_pointing_at_no_solid_is_refused() -> void:
	var bundle: SimulationBundleGd = _pad_bundle(ConveyorCycleGd.YAW_RIGHT)
	var body: Dictionary = bundle.to_dictionary()
	body[SimulationBundleGd.FIELD_LAUNCHES] = [{"entity_id": 999, "yaw_bam": 0}]
	assert_null(SimulationBundleGd.from_dictionary(body))


func test_standing_on_a_pad_launches_once_up_and_forward() -> void:
	var session: TraprushMatchSessionGd = _pad_session(ConveyorCycleGd.YAW_RIGHT)
	assert_eq(session.launch_count(), 1)
	var before_x: int = _pose_x(session)
	var before_y: int = _pose_y(session)
	session.commit_tick()
	assert_eq(_pose_x(session) - before_x, TraprushPlayStubsGd.LAUNCH_XZ)
	assert_eq(_pose_y(session) - before_y, TraprushPlayStubsGd.LAUNCH_DY)
	var after_x: int = _pose_x(session)
	session.commit_tick()
	assert_eq(_pose_x(session), after_x, "水平只在上升沿送出一次")


func test_a_zero_stub_keeps_the_pad_inert() -> void:
	var session: TraprushMatchSessionGd = _pad_session(ConveyorCycleGd.YAW_RIGHT)
	session.launch_dy = 0
	session.launch_xz = 0
	var before_x: int = _pose_x(session)
	var before_y: int = _pose_y(session)
	session.commit_tick()
	assert_eq(_pose_x(session), before_x)
	assert_eq(_pose_y(session), before_y)


func test_the_pad_does_not_launch_a_player_who_is_not_standing_on_it() -> void:
	var session: TraprushMatchSessionGd = _pad_session(ConveyorCycleGd.YAW_RIGHT, 4)
	var before_x: int = _pose_x(session)
	var before_y: int = _pose_y(session)
	session.commit_tick()
	assert_eq(_pose_x(session), before_x)
	assert_eq(_pose_y(session), before_y)


func test_two_sessions_with_the_same_pad_match_state_hash() -> void:
	var left: TraprushMatchSessionGd = _pad_session(ConveyorCycleGd.YAW_RIGHT)
	var right: TraprushMatchSessionGd = _pad_session(ConveyorCycleGd.YAW_RIGHT)
	for _index: int in range(8):
		left.commit_tick()
		right.commit_tick()
	assert_eq(left.hash_state(), right.hash_state())


func _pose_x(session: TraprushMatchSessionGd) -> int:
	var pose: Dictionary = session.player_pose(0)
	var x_value: int = pose.get("x", 0)
	return x_value


func _pose_y(session: TraprushMatchSessionGd) -> int:
	var pose: Dictionary = session.player_pose(0)
	var y_value: int = pose.get("y", 0)
	return y_value


func _world_with_floor() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	return world


func _pad_record(
	entity_id: int, cell_x: int, tags: Array, yaw_bam: int
) -> SharedComponentRecordGd:
	return SharedComponentRecordGd.create(entity_id, {
		"transform": {"x": cell_x * CELL, "y": -CELL, "z": 0, "yaw_bam": yaw_bam},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": tags,
		},
	})


func _pad_bundle(yaw_bam: int, pad_cell_x: int = 0) -> SimulationBundleGd:
	var world: AuthoringWorldGd = _world_with_floor()
	assert_true(world.put(_pad_record(PAD_ID, pad_cell_x, ["solid", "launch"], yaw_bam)))
	return TraprushTopologyCompilerGd.compile(world)


func _pad_session(yaw_bam: int, pad_cell_x: int = 0) -> TraprushMatchSessionGd:
	var bundle: SimulationBundleGd = _pad_bundle(yaw_bam, pad_cell_x)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	TraprushPlayStubsGd.apply_match(session)
	session.fall_dy = 0
	return session
