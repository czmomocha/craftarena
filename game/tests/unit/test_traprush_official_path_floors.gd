extends GutTest

## 纠偏 C3 第 2 章：官方赛道沿路立足固体，±8 出界 AABB 只在走下路面时复位。
## 必经格有固体支撑；停在路上不会掉进坑；从侧面走下路面才会触发出界。
## course_03 地面箱子挡住 +X，−Z 有绕行立足面，不把道具章提前做进来。
## BotRunner 探针三张课都能走通。不锁产品重力、不改 STUB_HALF 数值。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")
const TraprushTopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")

const COURSE_01: String = "res://content/official/traprush/course_01.json"
const COURSE_02: String = "res://content/official/traprush/course_02.json"
const COURSE_03: String = "res://content/official/traprush/course_03.json"
const CELL: int = 65536
const IDLE_TICKS: int = 48
const FALL_TICKS: int = 40


func test_official_courses_have_path_floor_counts() -> void:
	assert_eq(_compile(COURSE_01).solids.size(), 36)
	assert_eq(_compile(COURSE_02).solids.size(), 8)
	assert_eq(_compile(COURSE_03).solids.size(), 14)


func test_required_path_cells_are_supported() -> void:
	_assert_supported(COURSE_01, _course_01_stands())
	_assert_supported(COURSE_02, _course_02_stands())
	_assert_supported(COURSE_03, _course_03_stands())


func test_idle_on_spawn_does_not_out_of_range_reset() -> void:
	## 出生点格子 y=0，立足盒顶在 y=-CELL/2。重力会把胶囊落到盒顶，
	## 但 xz 仍在出生点，±8 不会开火。
	var session: TraprushMatchSession = _match_session(COURSE_01)
	for _tick: int in range(IDLE_TICKS):
		session.commit_tick()
	var pose: Dictionary = session.player_pose(0)
	var pose_y: int = _axis(pose, "y")
	assert_eq(_axis(pose, "x"), 0)
	assert_eq(_axis(pose, "z"), 0)
	assert_gt(pose_y, -CELL)
	assert_true(pose_y <= 0)
	assert_eq(session.player_accepted_count(0), 1)
	for _hold: int in range(8):
		session.commit_tick()
		var held: Dictionary = session.player_pose(0)
		assert_eq(_axis(held, "x"), 0)
		assert_eq(_axis(held, "y"), pose_y)
		assert_eq(_axis(held, "z"), 0)


func test_walking_the_ground_path_stays_supported() -> void:
	var session: TraprushMatchSession = _match_session(COURSE_01)
	assert_true(_move_x(session, CELL))
	session.commit_tick()
	assert_true(_move_x(session, CELL))
	session.commit_tick()
	for _tick: int in range(IDLE_TICKS):
		session.commit_tick()
	var pose: Dictionary = session.player_pose(0)
	var pose_y: int = _axis(pose, "y")
	assert_eq(_axis(pose, "x"), 2 * CELL)
	assert_eq(_axis(pose, "z"), 0)
	assert_gt(pose_y, -CELL)
	assert_true(pose_y <= 0)
	assert_eq(session.player_accepted_count(0), 2)


func test_stepping_off_the_path_falls_and_resets_to_spawn() -> void:
	var session: TraprushMatchSession = _match_session(COURSE_01)
	assert_true(_move_x(session, CELL))
	session.commit_tick()
	assert_true(session.apply_player_intent(0, {
		"intent": PlayerIntentNames.MOVE,
		"dx": 0,
		"dz": CELL,
	}))
	session.commit_tick()
	var saw_fall: bool = false
	var reset: bool = false
	for _tick: int in range(FALL_TICKS):
		session.commit_tick()
		var pose: Dictionary = session.player_pose(0)
		var pose_y: int = _axis(pose, "y")
		if pose_y < 0:
			saw_fall = true
		if (
			saw_fall
			and _axis(pose, "x") == 0
			and pose_y == 0
			and _axis(pose, "z") == 0
		):
			reset = true
			break
	assert_true(saw_fall)
	assert_true(reset)
	assert_eq(session.player_accepted_count(0), 1)


func test_official_courses_are_completable_on_the_authority() -> void:
	_assert_completable(COURSE_01)
	_assert_completable(COURSE_02)
	_assert_completable(COURSE_03)


func _assert_completable(path: String) -> void:
	var result: Dictionary = CourseCompletionProbe.run_path(path)
	var outcome: String = result["outcome"]
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE, path)
	var actions: Array = result["actions"]
	var replay: Dictionary = CourseCompletionProbe.try_replay(_compile(path), actions)
	var ok: bool = replay["ok"]
	var reason: String = replay["reason"]
	assert_true(ok, "%s %s" % [path, reason])
	var finish_tick: int = replay["finish_tick"]
	assert_true(finish_tick >= 0, "%s finish_tick=%d" % [path, finish_tick])


func _assert_supported(path: String, stands: Array[Vector3i]) -> void:
	var bundle: SimulationBundle = _compile(path)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	var loaded_ok: bool = loaded.get("ok", false)
	assert_true(loaded_ok, path)
	var world: SimulationWorld = loaded["world"]
	for stand: Vector3i in stands:
		var capsule_id: int = world.spawn_capsule(
			stand.x,
			stand.y,
			stand.z,
			0,
			PlayStubs.CAPSULE_RADIUS,
			PlayStubs.CAPSULE_HEIGHT
		)
		assert_true(capsule_id >= 1, "%s spawn %s" % [path, stand])
		assert_true(
			world.is_supported_by_solid(capsule_id, PlayStubs.SUPPORT_DY),
			"%s unsupported at %s" % [path, stand]
		)


func _course_01_stands() -> Array[Vector3i]:
	return [
		Vector3i(0, 0, 0),
		Vector3i(CELL, 0, 0),
		Vector3i(2 * CELL, 0, 0),
		Vector3i(3 * CELL, 0, 0),
		Vector3i(0, CELL, -3 * CELL),
		Vector3i(CELL, CELL, -3 * CELL),
		Vector3i(2 * CELL, CELL, -3 * CELL),
		Vector3i(2 * CELL, 0, CELL),
		Vector3i(7 * CELL, 0, -2 * CELL),
		Vector3i(-7 * CELL, 0, -2 * CELL),
		Vector3i(-5 * CELL, 0, 4 * CELL),
		Vector3i(6 * CELL, 0, 5 * CELL),
	]


func _course_02_stands() -> Array[Vector3i]:
	return [
		Vector3i(0, 0, 0),
		Vector3i(CELL, 0, 0),
		Vector3i(2 * CELL, 0, 0),
		Vector3i(3 * CELL, 0, 0),
		Vector3i(0, CELL, 2 * CELL),
		Vector3i(CELL, CELL, 2 * CELL),
		Vector3i(2 * CELL, CELL, 2 * CELL),
	]


func _course_03_stands() -> Array[Vector3i]:
	return [
		Vector3i(0, 0, 0),
		Vector3i(0, 0, -CELL),
		Vector3i(CELL, 0, -CELL),
		Vector3i(2 * CELL, 0, -CELL),
		Vector3i(2 * CELL, 0, 0),
		Vector3i(3 * CELL, 0, 0),
		Vector3i(0, CELL, CELL),
		Vector3i(CELL, CELL, CELL),
		Vector3i(2 * CELL, CELL, CELL),
		Vector3i(3 * CELL, CELL, CELL),
		Vector3i(4 * CELL, CELL, CELL),
		Vector3i(3 * CELL, CELL, 2 * CELL),
	]


func _match_session(path: String) -> TraprushMatchSession:
	var session: TraprushMatchSession = TraprushMatchSession.create(
		_compile(path),
		1,
		1,
		[{"dx": 0, "dy": 0, "dz": 0}],
		PlayStubs.CAPSULE_RADIUS,
		PlayStubs.CAPSULE_HEIGHT
	)
	assert_not_null(session)
	PlayStubs.apply_match(session)
	return session


func _compile(path: String) -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _move_x(session: TraprushMatchSession, dx: int) -> bool:
	return session.apply_player_intent(0, {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": 0,
	})


func _axis(pose: Dictionary, name: String) -> int:
	return pose.get(name, 1)
