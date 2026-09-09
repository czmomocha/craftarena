extends GutTest

## 可玩性深化第二批：电梯。
## 电梯是竖直 `mover`：不新增组件、不另开 bundle 袋。`zone.tags` 的 `lift`
## 只约束路径必须纯 Y——水平往返仍走已有 Place mover。

const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecordGd := preload("res://src/shared/schema/component_record.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushPlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const SimulationBundleBagsGd := preload("res://src/ugc/simulation_bundle_bags.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const LIFT_ID: int = 80
const SPEED: int = CELL / 16


func test_a_vertical_path_is_axial_and_vertical() -> void:
	var path: Array = [
		{"x": 0, "y": -CELL, "z": 0},
		{"x": 0, "y": CELL, "z": 0},
	]
	assert_true(SimulationBundleBagsGd.path_is_axial(path))
	assert_true(SimulationBundleBagsGd.path_is_vertical(path))


func test_a_horizontal_path_is_not_vertical() -> void:
	var path: Array = [
		{"x": 0, "y": -CELL, "z": 0},
		{"x": CELL, "y": -CELL, "z": 0},
	]
	assert_true(SimulationBundleBagsGd.path_is_axial(path))
	assert_false(SimulationBundleBagsGd.path_is_vertical(path))


func test_lift_compiles_into_the_movers_bag() -> void:
	var bundle: SimulationBundleGd = _lift_bundle()
	assert_not_null(bundle)
	assert_eq(bundle.movers.size(), 1)
	var bag: Dictionary = bundle.movers[0]
	var entity_id: int = bag["entity_id"]
	assert_eq(entity_id, LIFT_ID)
	var path: Array = bag["path"]
	assert_true(SimulationBundleBagsGd.path_is_vertical(path))


func test_a_lift_tag_on_a_horizontal_mover_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(SharedComponentRecordGd.create(LIFT_ID, {
		"transform": {"x": 0, "y": -CELL, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid", "lift"],
		},
		"mover": {
			"path": [{"x": 0, "y": -CELL, "z": 0}, {"x": CELL * 2, "y": -CELL, "z": 0}],
			"speed": SPEED,
			"loop": true,
		},
	})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_a_lift_tag_without_a_mover_is_refused() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(SharedComponentRecordGd.create(LIFT_ID, {
		"transform": {"x": 0, "y": -CELL, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid", "lift"],
		},
	})))
	assert_null(TraprushTopologyCompilerGd.compile(world))


func test_a_horizontal_mover_without_the_lift_tag_still_compiles() -> void:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(SharedComponentRecordGd.create(LIFT_ID, {
		"transform": {"x": 0, "y": -CELL, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid"],
		},
		"mover": {
			"path": [{"x": 0, "y": -CELL, "z": 0}, {"x": CELL * 2, "y": -CELL, "z": 0}],
			"speed": SPEED,
			"loop": true,
		},
	})))
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.movers.size(), 1)


func test_riding_a_lift_raises_the_player() -> void:
	var session: TraprushMatchSessionGd = _lift_session()
	var before_y: int = _pose_y(session)
	for _index: int in range(16):
		session.commit_tick()
	assert_eq(_pose_y(session) - before_y, CELL, "速度 SCALE/16、16 tick 走完一格")


func test_two_lift_sessions_match_state_hash() -> void:
	var left: TraprushMatchSessionGd = _lift_session()
	var right: TraprushMatchSessionGd = _lift_session()
	for _index: int in range(8):
		left.commit_tick()
		right.commit_tick()
	assert_eq(left.hash_state(), right.hash_state())


func _pose_y(session: TraprushMatchSessionGd) -> int:
	var pose: Dictionary = session.player_pose(0)
	var y_value: int = pose.get("y", 0)
	return y_value


func _world_with_pad() -> AuthoringWorldGd:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	assert_true(world.put(SharedComponentRecordGd.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	return world


func _lift_bundle() -> SimulationBundleGd:
	var world: AuthoringWorldGd = _world_with_pad()
	assert_true(world.put(SharedComponentRecordGd.create(LIFT_ID, {
		"transform": {"x": 0, "y": -CELL, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": ["solid", "lift"],
		},
		"mover": {
			"path": [{"x": 0, "y": -CELL, "z": 0}, {"x": 0, "y": CELL, "z": 0}],
			"speed": SPEED,
			"loop": true,
		},
	})))
	return TraprushTopologyCompilerGd.compile(world)


func _lift_session() -> TraprushMatchSessionGd:
	var bundle: SimulationBundleGd = _lift_bundle()
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	TraprushPlayStubsGd.apply_match(session)
	session.fall_dy = 0
	return session
