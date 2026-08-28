extends GutTest

## 纠偏 C3 第 5 章：默认官方课 course_01 补上 CD-61 §4.1 的语义，而不只是条目打勾。
## +X 五步仍是危险捷径（窄石路、两侧是坑、五格冲线）；从 CP1 向 +Z 走一条更长的
## 安全路，经侧向 two_way 到左侧区块，再经 one_way 上楼汇合。走下路面会下落复位。
## 不锁产品重力、不改 STUB_HALF / play_move_step，不加第 4 张官方课。
## 90 秒干净完赛在冻结的 ±8 格与每 tick 1/16 格步长下几何上做不到；本章锁的是
## 路线取舍与落差，不是墙钟秒数。Never settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")
const AuthoringReachability := preload("res://src/creator/authoring_reachability.gd")
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
const CELL: int = 65536
const FALL_TICKS: int = 40
const COURSE_01_SOLIDS: int = 36
const COURSE_01_PORTALS: int = 5
const SHORTCUT_STEPS: int = 5


func test_course_01_keeps_publish_reachability() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01)
	assert_not_null(world)
	assert_eq(world.revision, 14)
	assert_eq(world.entity_ids(), [
		1, 2, 3, 10, 11, 12, 20, 21, 30, 40, 60, 70, 80, 81, 82, 83, 84, 85,
		86, 87, 88, 100, 101, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119,
		120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133,
		134, 135,
	])
	var result: Dictionary = AuthoringReachability.evaluate(world)
	var ok: bool = result.get("ok", false)
	assert_true(ok)
	var issues: Array = result.get("issues", [1])
	assert_eq(issues.size(), 0)


func test_course_01_compiles_shortcut_and_safe_portals() -> void:
	var bundle: SimulationBundle = _compile(COURSE_01)
	assert_not_null(bundle)
	assert_eq(bundle.pads.size(), 3)
	assert_eq(bundle.portals.size(), COURSE_01_PORTALS)
	assert_eq(bundle.finish.size(), 1)
	assert_eq(bundle.destructibles.size(), 1)
	assert_eq(bundle.hazards.size(), 1)
	assert_eq(bundle.solids.size(), COURSE_01_SOLIDS)
	assert_eq(_kind(bundle, 10), AuthoringPortalKinds.TWO_WAY)
	assert_eq(_kind(bundle, 20), AuthoringPortalKinds.TWO_WAY)
	assert_eq(_kind(bundle, 12), AuthoringPortalKinds.ONE_WAY)
	var up_dest_y: int = _portal(bundle, 10).get("dest_y", -1)
	var side_dest_x: int = _portal(bundle, 20).get("dest_x", 0)
	var safe_up: Dictionary = _portal(bundle, 12)
	var safe_up_dest_x: int = safe_up.get("dest_x", 1)
	var safe_up_dest_y: int = safe_up.get("dest_y", -1)
	var safe_up_dest_z: int = safe_up.get("dest_z", 1)
	assert_eq(up_dest_y, CELL)
	assert_eq(side_dest_x, -7 * CELL)
	assert_eq(safe_up_dest_x, 0)
	assert_eq(safe_up_dest_y, CELL)
	assert_eq(safe_up_dest_z, -3 * CELL)


func test_safe_route_has_more_supported_cells_than_the_plus_x_shortcut() -> void:
	_assert_supported(_shortcut_stands())
	_assert_supported(_safe_stands())
	assert_gte(_safe_stands().size(), _shortcut_stands().size() * 2)
	assert_gt(_safe_moves().size(), SHORTCUT_STEPS * 2)


func test_plus_x_shortcut_still_finishes_in_five_cell_moves() -> void:
	var session: TraprushMatchSession = _match_session()
	for _step: int in range(SHORTCUT_STEPS):
		assert_true(_move(session, CELL, 0))
		session.commit_tick()
	assert_eq(session.player_accepted_count(0), 3)
	assert_gte(session.player_finish_tick(0), 0)


func test_safe_route_finishes_without_using_the_plus_x_up_portal() -> void:
	var session: TraprushMatchSession = _match_session()
	var steps: Array[Vector2i] = _safe_moves()
	for step: Vector2i in steps:
		assert_eq(session.player_stun_remaining(0), 0)
		assert_true(_move(session, step.x * CELL, step.y * CELL))
		session.commit_tick()
	assert_eq(session.player_accepted_count(0), 3)
	assert_gte(session.player_finish_tick(0), 0)
	assert_gt(session.player_finish_tick(0), SHORTCUT_STEPS - 1)
	var pose: Dictionary = session.player_pose(0)
	assert_eq(_axis(pose, "x"), 2 * CELL)
	assert_eq(_axis(pose, "z"), -3 * CELL)


func test_stepping_off_the_safe_route_falls_and_resets() -> void:
	var session: TraprushMatchSession = _match_session()
	assert_true(_move(session, CELL, 0))
	session.commit_tick()
	assert_true(_move(session, CELL, 0))
	session.commit_tick()
	assert_true(_move(session, 0, CELL))
	session.commit_tick()
	assert_eq(_axis(session.player_pose(0), "x"), 2 * CELL)
	assert_eq(_axis(session.player_pose(0), "z"), CELL)
	assert_true(_move(session, -CELL, 0))
	session.commit_tick()
	var saw_fall: bool = false
	var reset: bool = false
	for _tick: int in range(FALL_TICKS):
		session.commit_tick()
		var pose: Dictionary = session.player_pose(0)
		if _axis(pose, "y") < 0:
			saw_fall = true
		if (
			saw_fall
			and _axis(pose, "x") == 2 * CELL
			and _axis(pose, "y") == 0
			and _axis(pose, "z") == 0
		):
			reset = true
			break
	assert_true(saw_fall)
	assert_true(reset)
	assert_eq(session.player_accepted_count(0), 2)


func test_bot_still_completes_on_the_authority() -> void:
	var result: Dictionary = CourseCompletionProbe.run_path(COURSE_01)
	var outcome: String = result["outcome"]
	assert_eq(outcome, CourseCompletionProbe.OUTCOME_COMPLETABLE)
	var actions: Array = result["actions"]
	var replay: Dictionary = CourseCompletionProbe.try_replay(_compile(COURSE_01), actions)
	var ok: bool = replay["ok"]
	var reason: String = replay["reason"]
	assert_true(ok, reason)
	var finish_tick: int = replay["finish_tick"]
	assert_gte(finish_tick, 0)
	assert_lte(actions.size(), 12)


func _safe_moves() -> Array[Vector2i]:
	var steps: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(1, 0),
	]
	for _z: int in range(5):
		steps.append(Vector2i(0, 1))
	for _x: int in range(4):
		steps.append(Vector2i(1, 0))
	for _z2: int in range(5):
		steps.append(Vector2i(0, -1))
	steps.append(Vector2i(1, 0))
	steps.append(Vector2i(0, -1))
	steps.append(Vector2i(0, -1))
	for _z3: int in range(6):
		steps.append(Vector2i(0, 1))
	steps.append(Vector2i(1, 0))
	steps.append(Vector2i(1, 0))
	steps.append(Vector2i(1, 0))
	steps.append(Vector2i(1, 0))
	return steps


func _shortcut_stands() -> Array[Vector3i]:
	return [
		Vector3i(0, 0, 0),
		Vector3i(CELL, 0, 0),
		Vector3i(2 * CELL, 0, 0),
		Vector3i(3 * CELL, 0, 0),
		Vector3i(0, CELL, -3 * CELL),
		Vector3i(CELL, CELL, -3 * CELL),
		Vector3i(2 * CELL, CELL, -3 * CELL),
	]


func _safe_stands() -> Array[Vector3i]:
	var stands: Array[Vector3i] = []
	for z: int in range(1, 6):
		stands.append(Vector3i(2 * CELL, 0, z * CELL))
	for x: int in range(3, 7):
		stands.append(Vector3i(x * CELL, 0, 5 * CELL))
	for z2: int in range(4, -1, -1):
		stands.append(Vector3i(6 * CELL, 0, z2 * CELL))
	stands.append(Vector3i(7 * CELL, 0, 0))
	stands.append(Vector3i(7 * CELL, 0, -CELL))
	stands.append(Vector3i(7 * CELL, 0, -2 * CELL))
	for z3: int in range(-2, 5):
		stands.append(Vector3i(-7 * CELL, 0, z3 * CELL))
	stands.append(Vector3i(-6 * CELL, 0, 4 * CELL))
	stands.append(Vector3i(-5 * CELL, 0, 4 * CELL))
	stands.append(Vector3i(0, CELL, -3 * CELL))
	return stands


func _assert_supported(stands: Array[Vector3i]) -> void:
	var bundle: SimulationBundle = _compile(COURSE_01)
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, 1)
	var loaded_ok: bool = loaded.get("ok", false)
	assert_true(loaded_ok)
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
		assert_true(capsule_id >= 1, "spawn %s" % stand)
		assert_true(
			world.is_supported_by_solid(capsule_id, PlayStubs.SUPPORT_DY),
			"unsupported at %s" % stand
		)


func _match_session() -> TraprushMatchSession:
	var session: TraprushMatchSession = TraprushMatchSession.create(
		_compile(COURSE_01),
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


func _move(session: TraprushMatchSession, dx: int, dz: int) -> bool:
	return session.apply_player_intent(0, {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	})


func _portal(bundle: SimulationBundle, entity_id: int) -> Dictionary:
	for item: Dictionary in bundle.portals:
		if item.get("entity_id", 0) == entity_id:
			return item
	return {}


func _kind(bundle: SimulationBundle, entity_id: int) -> String:
	return str(_portal(bundle, entity_id).get("kind", ""))


func _axis(pose: Dictionary, name: String) -> int:
	var value: int = pose.get(name, 1)
	return value
