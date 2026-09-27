extends GutTest

## 真人节奏跑手：每 tick 一个意图，走 1 格 = SCALE/MOVE_STEP 个 Move tick。
##
## 公式（本夹具，go_tick=0，不开局倒计时，不额外 settle）：
##   开局 tick_index = 0
##   每条磁带意图：apply → commit_tick，tick_index += 1
##   人跑 1 格 = ticks_per_cell() = Fixed.SCALE / PlaceholderSpec.MOVE_STEP
##   total_ticks = session.tick_index() = 磁带长度（本测即 16）
##   终点放在 +2 格：1 格宽终点盒 + 胶囊半径会在 +0.375 格就相交，
##   不能用「冲线 tick」代替「走完 1 格」。
## 探针同一条路仍是 1 action / 格（dx = SCALE，1 次 commit）。

const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const CourseCompletionProbe := preload("res://src/games/traprush/course_completion_probe.gd")
const HumanPaceRunner := preload("res://src/games/traprush/human_pace_runner.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const CELL: int = Fixed.SCALE


func test_ticks_per_cell_is_scale_over_move_step() -> void:
	assert_eq(PlaceholderSpec.MOVE_STEP, Fixed.SCALE / 16)
	assert_eq(HumanPaceRunner.ticks_per_cell(), Fixed.SCALE / PlaceholderSpec.MOVE_STEP)
	assert_eq(HumanPaceRunner.ticks_per_cell(), 16)


func test_expand_cells_repeats_one_cardinal_per_tick() -> void:
	var tape: PackedByteArray = HumanPaceRunner.expand_cells(HumanPaceRunner.ACTION_MOVE_POS_X, 1)
	assert_eq(tape.size(), HumanPaceRunner.ticks_per_cell())
	for action: int in tape:
		assert_eq(action, HumanPaceRunner.ACTION_MOVE_POS_X)
	var two: PackedByteArray = HumanPaceRunner.expand_cells(HumanPaceRunner.ACTION_MOVE_NEG_Z, 2)
	assert_eq(two.size(), HumanPaceRunner.ticks_per_cell() * 2)
	assert_true(HumanPaceRunner.expand_cells(HumanPaceRunner.ACTION_JUMP, 1).is_empty())
	assert_true(HumanPaceRunner.expand_cells(4, 1).is_empty())


func test_expand_probe_actions_rejects_diagonal() -> void:
	var probe: PackedByteArray = PackedByteArray()
	probe.append(0)
	probe.append(4)
	var expanded: Dictionary = HumanPaceRunner.expand_probe_actions(probe)
	var ok: bool = expanded.get("ok", true)
	var reason: String = expanded.get("reason", "")
	assert_false(ok)
	assert_eq(reason, HumanPaceRunner.REASON_DIAGONAL_REJECTED)


func test_one_cell_human_walk_is_sixteen_ticks_probe_is_one_action() -> void:
	var bundle: SimulationBundle = _one_cell_course()
	assert_not_null(bundle)
	var tape: PackedByteArray = HumanPaceRunner.expand_cells(HumanPaceRunner.ACTION_MOVE_POS_X, 1)
	assert_eq(tape.size(), 16)
	var human: Dictionary = HumanPaceRunner.run_bundle(bundle, tape)
	var human_outcome: String = human["outcome"]
	var human_reason: String = human["reason"]
	var total_ticks: int = human["total_ticks"]
	var finish_tick: int = human["finish_tick"]
	var human_x: int = human["x"]
	assert_eq(human_outcome, HumanPaceRunner.OUTCOME_NOT_COMPLETABLE)
	assert_eq(human_reason, HumanPaceRunner.REASON_TAPE_EXHAUSTED)
	assert_eq(total_ticks, 16)
	assert_eq(finish_tick, -1)
	assert_eq(human_x, CELL)
	var probe_session: TraprushMatchSession = TraprushMatchSession.create(
		bundle,
		1,
		1,
		[{"dx": 0, "dy": 0, "dz": 0}],
		PlayStubs.CAPSULE_RADIUS,
		PlayStubs.CAPSULE_HEIGHT
	)
	assert_not_null(probe_session)
	PlayStubs.apply_match(probe_session)
	assert_true(probe_session.apply_player_intent(0, {
		"intent": PlayerIntentNames.MOVE,
		"dx": CELL,
		"dz": 0,
	}))
	probe_session.commit_tick()
	var probe_pose: Dictionary = probe_session.player_pose(0)
	var probe_x: int = probe_pose.get("x", 0)
	assert_eq(probe_session.tick_index(), 1)
	assert_eq(probe_x, CELL)


func test_diagonal_tape_is_rejected_without_running() -> void:
	var bundle: SimulationBundle = _one_cell_course()
	var tape: PackedByteArray = PackedByteArray()
	tape.append(4)
	var result: Dictionary = HumanPaceRunner.run_bundle(bundle, tape)
	var outcome: String = result["outcome"]
	var reason: String = result["reason"]
	var total_ticks: int = result["total_ticks"]
	assert_eq(outcome, HumanPaceRunner.OUTCOME_NOT_COMPLETABLE)
	assert_eq(reason, HumanPaceRunner.REASON_DIAGONAL_REJECTED)
	assert_eq(total_ticks, 0)


func test_empty_tape_is_exhausted() -> void:
	var bundle: SimulationBundle = _one_cell_course()
	var result: Dictionary = HumanPaceRunner.run_bundle(bundle, PackedByteArray())
	var outcome: String = result["outcome"]
	var reason: String = result["reason"]
	var total_ticks: int = result["total_ticks"]
	var finish_tick: int = result["finish_tick"]
	assert_eq(outcome, HumanPaceRunner.OUTCOME_NOT_COMPLETABLE)
	assert_eq(reason, HumanPaceRunner.REASON_TAPE_EXHAUSTED)
	assert_eq(total_ticks, 0)
	assert_eq(finish_tick, -1)


func test_parse_tick_codes_accepts_human_set_and_rejects_diagonal() -> void:
	var parsed: Dictionary = HumanPaceRunner.parse_tick_codes("0,2,8,10")
	var ok: bool = parsed.get("ok", false)
	assert_true(ok)
	var tape_raw: Variant = parsed["tape"]
	assert_eq(typeof(tape_raw), TYPE_PACKED_BYTE_ARRAY)
	var tape: PackedByteArray = tape_raw
	assert_eq(tape.size(), 4)
	assert_eq(tape[2], HumanPaceRunner.ACTION_JUMP)
	var diagonal: Dictionary = HumanPaceRunner.parse_tick_codes("0,4")
	var diagonal_ok: bool = diagonal.get("ok", true)
	var diagonal_reason: String = diagonal.get("reason", "")
	assert_false(diagonal_ok)
	assert_eq(diagonal_reason, HumanPaceRunner.REASON_DIAGONAL_REJECTED)


func _one_cell_course() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0, 0, 0)))
	assert_true(world.put(_finish_zone(30, 2 * CELL, 0, 0)))
	assert_true(world.put(_solid(80, 0, -CELL, 0)))
	assert_true(world.put(_solid(81, CELL, -CELL, 0)))
	assert_true(world.put(_solid(82, 2 * CELL, -CELL, 0)))
	return TraprushTopologyCompiler.compile(world)


func _checkpoint(
	entity_id: int, order: int, x: int, y: int, z: int
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": order,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})


func _finish_zone(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return _zone(entity_id, x, y, z, "finish")


func _solid(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return _zone(entity_id, x, y, z, "solid")


func _zone(entity_id: int, x: int, y: int, z: int, tag: String) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": CELL / 2, "hy": CELL / 2, "hz": CELL / 2},
			"tags": [tag],
		},
	})
