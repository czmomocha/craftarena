extends GutTest

## C3：D5 复活硬直 1.0 s 接到权威复位。不锁 Tick Hz。
## 对局 / Solo 用引擎 physics 占位 60 Hz 换成 60 tick；Preview 仍是 1 次 Advance。

const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushPlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8


func test_one_second_converts_at_placeholder_physics_hz_not_cd43() -> void:
	assert_eq(TraprushPlayStubs.RESPAWN_STUN_MS, 1000)
	assert_eq(TraprushPlayStubs.PHYSICS_TICKS_PER_SECOND_PLACEHOLDER, 60)
	assert_eq(TraprushPlayStubs.RESPAWN_STUN_TICKS, 60)
	assert_eq(TraprushPlayStubs.ticks_from_ms(TraprushPlayStubs.RESPAWN_STUN_MS), TraprushPlayStubs.RESPAWN_STUN_TICKS)
	assert_eq(TraprushPlayStubs.ticks_from_ms(1000), 60)
	assert_eq(TraprushPlayStubs.ticks_from_ms(1), 1)
	assert_eq(TraprushPlayStubs.ticks_from_ms(0), 0)
	assert_eq(TraprushPlayStubs.ticks_from_ms(-1), 0)
	assert_eq(TraprushPlayStubs.PREVIEW_RESPAWN_STUN_TICKS, 1)
	assert_ne(
		TraprushPlayStubs.PREVIEW_RESPAWN_STUN_TICKS,
		TraprushPlayStubs.RESPAWN_STUN_TICKS
	)


func test_apply_match_injects_one_second_in_ticks() -> void:
	var session: TraprushMatchSession = _spawn_session()
	assert_eq(session.respawn_stun_ticks, 0)
	TraprushPlayStubs.apply_match(session)
	assert_eq(session.respawn_stun_ticks, TraprushPlayStubs.RESPAWN_STUN_TICKS)


func test_out_of_range_blocks_move_for_full_one_second_tick_count() -> void:
	var session: TraprushMatchSession = _spawn_session()
	session.respawn_stun_ticks = TraprushPlayStubs.RESPAWN_STUN_TICKS
	session.enable_play_range(PLAY_RADIUS)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	assert_eq(session.player_stun_remaining(0), TraprushPlayStubs.RESPAWN_STUN_TICKS)
	assert_false(session.apply_player_intent(0, _move(CELL, 0)))
	var held: int = TraprushPlayStubs.RESPAWN_STUN_TICKS
	while held > 0:
		session.commit_tick()
		held -= 1
		assert_eq(session.player_stun_remaining(0), held)
		if held > 0:
			assert_false(session.apply_player_intent(0, _move(CELL, 0)))
	assert_true(session.apply_player_intent(0, _move(PLAY_RADIUS, 0)))


func test_preview_stun_stays_one_advance_click() -> void:
	assert_eq(TraprushPlayStubs.PREVIEW_RESPAWN_STUN_TICKS, 1)


func _spawn_session() -> TraprushMatchSession:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(SharedComponentRecord.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"checkpoint": {
			"order": 0,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	return TraprushMatchSession.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)


func _move(dx: int, dz: int) -> Dictionary:
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	}
