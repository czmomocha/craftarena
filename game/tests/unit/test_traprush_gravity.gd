extends GutTest

## TraprushGravity：调用方加速度写入胶囊 vy，再按本拍 vy 扫掠。
## 完整位移保留 vy；落地/顶棚 vy=0。Jump 冲量形成上升再下降的弧。
## vy 进入 SimulationWorld.hash_state。不是产品重力或跳跃高度（CD-63）。

const Gravity := preload("res://src/games/traprush/gravity.gd")
const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")
const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const CELL: int = 65536
const COURSE_01: String = "res://content/official/traprush/course_01.json"
const PLAY_RADIUS: int = CELL / 8


func test_integrate_from_rest_first_tick_matches_accel() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0)
	var accel: int = -_whole(2)
	assert_true(Gravity.integrate(world, entity_id, accel))
	_assert_pose(world, entity_id, 0, accel, 0, 0)
	assert_eq(world.get_vy(entity_id), accel)
	assert_eq(world.tick_index, 0)


func test_second_tick_accelerates() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0)
	var accel: int = -_whole(2)
	assert_true(Gravity.integrate(world, entity_id, accel))
	assert_true(Gravity.integrate(world, entity_id, accel))
	_assert_pose(world, entity_id, 0, accel + accel * 2, 0, 0)
	assert_eq(world.get_vy(entity_id), accel * 2)


func test_landing_zeros_vy_and_stops_on_floor() -> void:
	var world: SimulationWorld = _footing_world()
	var entity_id: int = 1
	var stand_y: int = _whole(4)
	assert_true(Gravity.integrate(world, entity_id, -_whole(10)))
	_assert_pose(world, entity_id, 0, stand_y, 0, 0)
	assert_eq(world.get_vy(entity_id), 0)


func test_jump_impulse_then_arc_lands_with_matching_hash() -> void:
	var left: SimulationWorld = _footing_world()
	var right: SimulationWorld = _footing_world()
	var stand_y: int = _whole(4)
	var impulse: int = _whole(2)
	var accel: int = -_whole(1)
	assert_true(Gravity.apply_jump(left, 1, impulse))
	assert_true(Gravity.apply_jump(right, 1, impulse))
	_assert_pose(left, 1, 0, stand_y + impulse, 0, 0)
	assert_eq(left.get_vy(1), impulse)
	var saw_apex: bool = false
	var hops: int = 0
	while hops < 12:
		assert_true(Gravity.integrate(left, 1, accel))
		assert_true(Gravity.integrate(right, 1, accel))
		var pose: Dictionary = left.get_pose(1)
		var pose_y: int = pose.get("y", 0)
		if pose_y > stand_y + impulse:
			saw_apex = true
		if pose_y == stand_y and left.get_vy(1) == 0:
			break
		hops += 1
	assert_true(saw_apex)
	_assert_pose(left, 1, 0, stand_y, 0, 0)
	assert_eq(left.get_vy(1), 0)
	assert_eq(left.hash_state().hex_encode(), right.hash_state().hex_encode())


func test_zero_accel_coasts_at_jump_vy() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0)
	var impulse: int = _whole(3)
	assert_true(Gravity.apply_jump(world, entity_id, impulse))
	assert_true(Gravity.integrate(world, entity_id, 0))
	_assert_pose(world, entity_id, 0, impulse * 2, 0, 0)
	assert_eq(world.get_vy(entity_id), impulse)


func test_set_pose_keeps_vy_set_vy_changes_hash() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, _whole(1), 0, 8)
	assert_true(world.set_vy(entity_id, _whole(2)))
	var hashed: String = world.hash_state().hex_encode()
	assert_true(world.set_pose(entity_id, 0, _whole(1), 0, 16))
	assert_eq(world.get_vy(entity_id), _whole(2))
	assert_ne(world.hash_state().hex_encode(), hashed)
	var twin: SimulationWorld = SimulationWorld.new(1)
	twin.spawn_capsule(0, _whole(1), 0, 16)
	assert_true(twin.set_vy(1, _whole(2)))
	assert_eq(world.hash_state().hex_encode(), twin.hash_state().hex_encode())
	assert_true(twin.set_vy(1, _whole(3)))
	assert_ne(world.hash_state().hex_encode(), twin.hash_state().hex_encode())


func test_integrate_rejects_unknown_and_overflow() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	assert_false(Gravity.integrate(world, 1, -1))
	assert_false(Gravity.apply_jump(null, 1, 1))
	var entity_id: int = world.spawn_capsule(0, FixedClass.INT64_MAX, 0, 0)
	assert_false(Gravity.integrate(world, entity_id, 1))
	assert_eq(world.get_vy(entity_id), 0)
	_assert_pose(world, entity_id, 0, FixedClass.INT64_MAX, 0, 0)


func test_match_session_jump_arc_lands_and_two_tapes_match() -> void:
	var left: TraprushMatchSession = _course_01_session()
	var right: TraprushMatchSession = _course_01_session()
	left.jump_dy = CELL / 4
	left.support_dy = -CELL
	left.fall_dy = -CELL / 16
	right.jump_dy = left.jump_dy
	right.support_dy = left.support_dy
	right.fall_dy = left.fall_dy
	left.commit_tick()
	right.commit_tick()
	var rest: Dictionary = left.player_pose(0)
	var rest_y: int = rest.get("y", 1)
	assert_true(left.apply_player_intent(0, {"intent": PlayerIntentNames.JUMP}))
	assert_true(right.apply_player_intent(0, {"intent": PlayerIntentNames.JUMP}))
	var hopped: Dictionary = left.player_pose(0)
	var hopped_y: int = hopped.get("y", 2)
	assert_eq(hopped_y, rest_y + CELL / 4)
	var hops: int = 0
	while hops < 24:
		left.commit_tick()
		right.commit_tick()
		var pose: Dictionary = left.player_pose(0)
		var pose_y: int = pose.get("y", 3)
		if pose_y == rest_y:
			break
		hops += 1
	var landed: Dictionary = left.player_pose(0)
	var landed_y: int = landed.get("y", 4)
	assert_eq(landed_y, rest_y)
	assert_eq(left.hash_state(), right.hash_state())


func _footing_world() -> SimulationWorld:
	var world: SimulationWorld = SimulationWorld.new(1)
	world.spawn_capsule(0, _whole(4), 0, 0, _whole(1), _whole(2))
	assert_eq(world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	return world


func _course_01_session() -> TraprushMatchSession:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01)
	assert_not_null(world)
	var session: TraprushMatchSession = TraprushMatchSession.create(
		TraprushTopologyCompiler.compile(world),
		1,
		1,
		[{"dx": 0, "dy": 0, "dz": 0}],
		PLAY_RADIUS,
		PLAY_RADIUS
	)
	assert_not_null(session)
	return session


func _assert_pose(world: SimulationWorld, entity_id: int, x: int, y: int, z: int, yaw: int) -> void:
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	var pose_yaw: int = pose.get("yaw", -1)
	assert_eq(pose_x, x)
	assert_eq(pose_y, y)
	assert_eq(pose_z, z)
	assert_eq(pose_yaw, yaw)


func _whole(units: int) -> int:
	return units * 65536
