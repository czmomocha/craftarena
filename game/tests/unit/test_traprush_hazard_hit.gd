extends GutTest

## C3 第 4 章：服务端裁决的机关伤害 / 击退。固体半周期占用重叠才命中；
## 不读客户端命中断言，不读 Authoring damage/knockback 字段。击退与硬直
## 从调用方占位桩注入，不是 D5 产品秒数。灰盒磁带路径仍不接伤害。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const HazardHit := preload("res://src/games/traprush/hazard_hit.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushCheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const TraprushCheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushPlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const HAZARD_ID: int = 50


func test_null_world_is_rejected() -> void:
	var spawn: TraprushCheckpointSpawn = TraprushCheckpointSpawn.new({
		"x": 0, "y": 0, "z": 0, "yaw_bam": 0,
	}, [])
	var track: TraprushCheckpointTrack = TraprushCheckpointTrack.new(PackedInt32Array([1]))
	var result: Dictionary = HazardHit.try_apply(null, 1, [], CELL, spawn, track)
	var result_ok: bool = result.get("ok", true)
	assert_false(result_ok)


func test_open_hazard_overlap_is_not_a_hit() -> void:
	var session: TraprushMatchSession = _hazard_session(1)
	assert_not_null(session)
	session.commit_tick()
	assert_false(session.is_hazard_solid(HAZARD_ID))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_gte(pose_x, CELL)
	assert_eq(session.player_stun_remaining(0), 0)


func test_zero_knockback_crush_resets_to_spawn() -> void:
	var session: TraprushMatchSession = _hazard_session(1)
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	session.commit_tick()
	assert_true(session.is_hazard_solid(HAZARD_ID))
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)
	assert_eq(session.player_stun_remaining(0), 0)


func test_knockback_clears_center_overlap_toward_plus_z() -> void:
	var session: TraprushMatchSession = _hazard_session(1)
	session.hazard_knockback_step = CELL
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var entered: Dictionary = session.player_pose(0)
	var entered_x: int = entered.get("x", -1)
	assert_eq(entered_x, CELL)
	session.commit_tick()
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	var pose_z: int = pose.get("z", 1)
	assert_eq(pose_x, CELL)
	assert_eq(pose_z, CELL)
	assert_eq(session.player_stun_remaining(0), 0)


func test_oversize_knockback_is_skipped_and_still_resets() -> void:
	var session: TraprushMatchSession = _hazard_session(1)
	session.hazard_knockback_step = CELL + 1
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	session.commit_tick()
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)


func test_stun_rejects_move_until_next_advance() -> void:
	var session: TraprushMatchSession = _hazard_session(1)
	session.respawn_stun_ticks = 1
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	session.commit_tick()
	assert_eq(session.player_stun_remaining(0), 1)
	assert_false(session.apply_player_intent(0, _move(CELL, 0)))
	var stunned: Dictionary = session.player_pose(0)
	var stunned_x: int = stunned.get("x", -1)
	assert_eq(stunned_x, 0)
	session.advance_sim_tick()
	assert_eq(session.player_stun_remaining(0), 0)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))


func test_reset_intent_is_allowed_during_stun() -> void:
	var session: TraprushMatchSession = _hazard_session(1)
	session.respawn_stun_ticks = 1
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	session.commit_tick()
	assert_eq(session.player_stun_remaining(0), 1)
	assert_true(session.apply_player_intent(0, {
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
	}))


func test_out_of_range_reset_applies_injected_stun() -> void:
	var session: TraprushMatchSession = _hazard_session(1)
	session.respawn_stun_ticks = 1
	session.enable_play_range(CELL / 8)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", CELL)
	assert_eq(pose_x, 0)
	assert_eq(session.player_stun_remaining(0), 1)


func test_client_hit_fields_do_not_cancel_server_occupancy() -> void:
	var session: TraprushMatchSession = _hazard_session(1)
	session.respawn_stun_ticks = 1
	session.commit_tick()
	assert_true(session.apply_player_intent(0, {
		"intent": PlayerIntentNames.MOVE,
		"dx": CELL,
		"dz": 0,
		"hit": false,
		"damage": 0,
		"knockback": 0,
	}))
	session.commit_tick()
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)
	assert_eq(session.player_stun_remaining(0), 1)


func test_preview_crush_resets_on_advance() -> void:
	var preview: AuthoringPreview = _connected_hazard(1)
	preview.play_respawn_stun_ticks = 1
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_advance_play())
	assert_false(preview.play_is_hazard_solid(HAZARD_ID))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_advance_play())
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)
	assert_eq(preview.play_stun_remaining(), 1)


func test_two_sessions_same_crush_match_hash() -> void:
	var left: TraprushMatchSession = _hazard_session(1)
	var right: TraprushMatchSession = _hazard_session(1)
	left.respawn_stun_ticks = 1
	right.respawn_stun_ticks = 1
	left.commit_tick()
	right.commit_tick()
	assert_true(left.apply_player_intent(0, _move(CELL, 0)))
	assert_true(right.apply_player_intent(0, _move(CELL, 0)))
	left.commit_tick()
	right.commit_tick()
	assert_eq(left.hash_state(), right.hash_state())


func test_official_course_01_has_hazard_approach_floors() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.solids.size(), 10)
	assert_eq(bundle.hazards.size(), 1)
	var hazard: Dictionary = bundle.hazards[0]
	var hazard_z: int = hazard.get("z", 1)
	assert_eq(hazard_z, -2 * CELL)


func test_official_course_01_walk_minus_z_then_crush_resets() -> void:
	var session: TraprushMatchSession = _course_01_session()
	assert_not_null(session)
	TraprushPlayStubs.apply_match(session)
	assert_true(session.apply_player_intent(0, _move(0, -CELL)))
	session.commit_tick()
	assert_true(session.apply_player_intent(0, _move(0, -CELL)))
	session.commit_tick()
	var pose: Dictionary = session.player_pose(0)
	var pose_z: int = pose.get("z", 1)
	assert_eq(pose_z, 0)
	assert_eq(session.player_stun_remaining(0), TraprushPlayStubs.RESPAWN_STUN_TICKS)


func _course_01_session() -> TraprushMatchSession:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	return TraprushMatchSession.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)


func _hazard_session(cooldown_ticks: int) -> TraprushMatchSession:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_hazard_record(HAZARD_ID, CELL, 0, 0, cooldown_ticks)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	return TraprushMatchSession.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)


func _connected_hazard(cooldown_ticks: int) -> AuthoringPreview:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(session.world.put(_hazard_record(HAZARD_ID, CELL, 0, 0, cooldown_ticks)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	return preview


func _checkpoint_record(entity_id: int, order: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": order,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})


func _hazard_record(
	entity_id: int,
	x: int,
	y: int,
	z: int,
	cooldown_ticks: int
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": cooldown_ticks},
	})


func _move(dx: int, dz: int) -> Dictionary:
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	}
