extends GutTest

## C3 第 3 章：服务端裁决的爆破球 + 冲刺。拾取由占用扫描授予；UseItem 无弹拒绝；
## 命中只看调用方 reach，忽略客户端命中断言；Sprint 沿 yaw 8 向位移且不穿固体。
## 冷却与步长是调用方占位桩。灰盒磁带路径仍无背包。Never settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")
const SprintApply := preload("res://src/games/traprush/sprint_apply.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushPlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const YAW_RIGHT: int = 49152


func test_official_course_01_grants_bomb_and_dash_at_spawn() -> void:
	var session: TraprushMatchSession = _course_01_session()
	assert_not_null(session)
	assert_eq(session.player_bomb_count(0), 1)
	assert_eq(session.player_dash_count(0), 1)


func test_use_item_without_bomb_is_rejected() -> void:
	var session: TraprushMatchSession = _crate_only_session()
	assert_not_null(session)
	assert_eq(session.player_bomb_count(0), 0)
	session.use_item_damage = 1
	session.use_item_reach_dz = CELL
	assert_false(session.apply_player_intent(0, _use_item()))
	assert_eq(session.destructible_alive_count(), 1)


func test_use_item_after_pickup_breaks_crate_then_second_q_fails() -> void:
	var session: TraprushMatchSession = _course_01_session()
	assert_eq(session.destructible_alive_count(), 1)
	session.use_item_damage = 1
	session.use_item_reach_dz = CELL
	assert_true(session.apply_player_intent(0, _use_item()))
	assert_eq(session.destructible_alive_count(), 0)
	assert_eq(session.player_bomb_count(0), 0)
	assert_true(session.apply_player_intent(0, _use_item()))
	assert_eq(session.destructible_alive_count(), 0)
	session.advance_sim_tick()
	assert_false(session.apply_player_intent(0, _use_item()))


func test_client_hit_fields_are_ignored_and_server_reach_decides() -> void:
	var session: TraprushMatchSession = _course_01_session()
	session.use_item_damage = 1
	session.use_item_reach_dz = CELL
	assert_true(session.apply_player_intent(0, {
		"intent": PlayerIntentNames.USE_ITEM,
		"destroyed": true,
		"damage": 99,
		"x": 9 * CELL,
		"z": 9 * CELL,
	}))
	assert_eq(session.destructible_alive_count(), 0)


func test_sprint_without_dash_is_rejected() -> void:
	var session: TraprushMatchSession = _crate_only_session()
	session.sprint_step = CELL
	session.item_cooldown_ticks = 1
	var before: Dictionary = session.player_pose(0)
	var before_z: int = before.get("z", 1)
	assert_false(session.apply_player_intent(0, _sprint()))
	var after: Dictionary = session.player_pose(0)
	var after_z: int = after.get("z", 2)
	assert_eq(after_z, before_z)


func test_sprint_after_facing_right_moves_plus_x() -> void:
	var session: TraprushMatchSession = _course_01_session()
	session.sprint_step = CELL
	session.item_cooldown_ticks = 1
	assert_true(session.apply_player_intent(0, _face_right()))
	assert_true(session.apply_player_intent(0, _sprint()))
	assert_eq(session.player_dash_count(0), 0)
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, CELL)


func test_sprint_step_over_scale_is_rejected() -> void:
	var session: TraprushMatchSession = _course_01_session()
	session.sprint_step = CELL + 1
	session.item_cooldown_ticks = 1
	assert_true(session.apply_player_intent(0, _face_right()))
	var before: Dictionary = session.player_pose(0)
	var before_x: int = before.get("x", -1)
	assert_false(session.apply_player_intent(0, _sprint()))
	assert_eq(session.player_dash_count(0), 1)
	var after: Dictionary = session.player_pose(0)
	var after_x: int = after.get("x", -2)
	assert_eq(after_x, before_x)


func test_sprint_stops_before_solid() -> void:
	var session: TraprushMatchSession = _walled_session()
	assert_not_null(session)
	assert_eq(session.player_dash_count(0), 1)
	session.sprint_step = CELL
	session.item_cooldown_ticks = 1
	assert_true(session.apply_player_intent(0, _face_right()))
	assert_true(session.apply_player_intent(0, _sprint()))
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", CELL)
	assert_lt(pose_x, CELL)
	assert_eq(session.player_dash_count(0), 0)


func test_sprint_cooldown_is_ok_without_second_move() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 0)
	var first: Dictionary = SprintApply.apply(
		world,
		entity_id,
		_sprint(),
		0,
		-1,
		1,
		CELL
	)
	assert_true(_ok(first))
	assert_true(_sprinted(first))
	var after_first: Dictionary = world.get_pose(entity_id)
	var first_z: int = after_first.get("z", 1)
	assert_eq(first_z, -CELL)
	var second: Dictionary = SprintApply.apply(
		world,
		entity_id,
		_sprint(),
		0,
		0,
		1,
		CELL
	)
	assert_true(_ok(second))
	assert_false(_sprinted(second))
	var after_second: Dictionary = world.get_pose(entity_id)
	var second_z: int = after_second.get("z", 2)
	assert_eq(second_z, first_z)
	assert_eq(world.tick_index, 0)


func test_preview_spawn_grants_bomb_then_breaks_crate() -> void:
	var preview: AuthoringPreview = AuthoringPreview.new()
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	assert_true(preview.connect_from(session))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_bomb_count(), 1)
	assert_eq(preview.play_dash_count(), 1)
	preview.play_use_item_damage = 1
	preview.play_use_item_reach_dz = CELL
	assert_true(preview.try_apply_play_intent(_use_item()))
	assert_eq(preview.play_destructible_alive_count(), 0)
	assert_eq(preview.play_bomb_count(), 0)


func test_each_pickup_is_taken_once_per_player() -> void:
	var session: TraprushMatchSession = _course_01_session()
	assert_eq(session.player_bomb_count(0), 1)
	session.use_item_damage = 1
	session.use_item_reach_dz = CELL
	assert_true(session.apply_player_intent(0, _use_item()))
	assert_eq(session.player_bomb_count(0), 0)
	assert_true(session.apply_player_intent(0, _move(0, 0)))
	assert_eq(session.player_bomb_count(0), 0)


func test_second_bomb_entity_grants_after_first_is_spent() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0, 0, 0)))
	assert_true(world.put(_crate(40, 0, 0, CELL, 1)))
	assert_true(world.put(_pickup(100, 0, 0, 0, "bomb")))
	assert_true(world.put(_pickup(102, CELL, 0, 0, "bomb")))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle,
		1,
		1,
		[{"dx": 0, "dy": 0, "dz": 0}],
		PLAY_RADIUS,
		PLAY_RADIUS
	)
	assert_not_null(session)
	assert_eq(session.player_bomb_count(0), 1)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(session.player_bomb_count(0), 1)
	assert_true(session.apply_player_intent(0, _move(-CELL, 0)))
	session.use_item_damage = 1
	session.use_item_reach_dz = CELL
	assert_true(session.apply_player_intent(0, _use_item()))
	assert_eq(session.player_bomb_count(0), 0)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(session.player_bomb_count(0), 1)


func _course_01_session() -> TraprushMatchSession:
	var bundle: SimulationBundle = _compile_path(COURSE_01_PATH)
	if bundle == null:
		return null
	var created: TraprushMatchSession = TraprushMatchSession.create(
		bundle,
		1,
		1,
		[{"dx": 0, "dy": 0, "dz": 0}],
		PLAY_RADIUS,
		PLAY_RADIUS
	)
	if created == null:
		return null
	TraprushPlayStubs.apply_match(created)
	return created


func _crate_only_session() -> TraprushMatchSession:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0, 0, 0)))
	assert_true(world.put(_crate(40, 0, 0, CELL, 1)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	if bundle == null:
		return null
	return TraprushMatchSession.create(
		bundle,
		1,
		1,
		[{"dx": 0, "dy": 0, "dz": 0}],
		PLAY_RADIUS,
		PLAY_RADIUS
	)


func _walled_session() -> TraprushMatchSession:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0, 0, 0)))
	assert_true(world.put(_pickup(101, 0, 0, 0, "dash")))
	assert_true(world.put(_solid(70, CELL, 0, 0)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	if bundle == null:
		return null
	var created: TraprushMatchSession = TraprushMatchSession.create(
		bundle,
		1,
		1,
		[{"dx": 0, "dy": 0, "dz": 0}],
		PLAY_RADIUS,
		PLAY_RADIUS
	)
	if created == null:
		return null
	created.sprint_step = CELL
	created.item_cooldown_ticks = 1
	return created


func _compile_path(path: String) -> SimulationBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	if world == null:
		return null
	return TraprushTopologyCompiler.compile(world)


func _use_item() -> Dictionary:
	return {"intent": PlayerIntentNames.USE_ITEM}


func _sprint() -> Dictionary:
	return {"intent": PlayerIntentNames.SPRINT}


func _face_right() -> Dictionary:
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": 0,
		"dz": 0,
		"yaw_bam": YAW_RIGHT,
	}


func _move(dx: int, dz: int) -> Dictionary:
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	}


func _checkpoint(entity_id: int, order: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": order,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})


func _crate(entity_id: int, x: int, y: int, z: int, durability: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"destructible": {
			"durability": durability,
			"regen_policy_id": 0,
		},
	})


func _pickup(entity_id: int, x: int, y: int, z: int, kind: String) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"inventory": {"item_state": kind},
	})


func _solid(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	var half: int = CELL / 2
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": ["solid"],
		},
	})


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _sprinted(result: Dictionary) -> bool:
	var flag: bool = result.get("sprinted", false)
	return flag
