extends GutTest

## TraprushGrayboxCourse：单人灰盒跑道夹具。几何、位移、jump_dy、support_dy、fall_dy、范围边界、max_hops、max_health、period、capacity、interact/use-item damage 与 reach 只由调用方传入。
## CD-21 §4.2 / §5.2 / §8 与 CD-61 M1：有序检查点、占用垫盒、上下/侧向传送、墙阻挡、打掉箱子后开路、周期 hazard stub、爆破道具 stub。
## Move / Jump 经 IntentStepper 走直到阻挡：撞墙/箱/天花停在最后未阻挡样本，不是整段拒绝。
## 成功 PLAYER 意图写入 SimReplayBuffer（CD-43）；成功占用写入 SYSTEM。PLAYER + SYSTEM 磁带由 TraprushGrayboxTapeReplay 回放到新 course。
## assemble 记录 tick 0 关键快照；try_commit_tick(fall_dy) 先 fall 再 tick，再按调用方周期切换 hazard 阻挡。
## try_step_intent(payload, jump_dy, support_dy) 把 support_dy 传给 apply；成功 PLAYER 意图入带。
## try_apply_fall(fall_dy) 委托 try_move_y_until_blocked；不 tick、不 record、不入带。
## try_reset_if_out_of_range 用调用方边界；出界回到最近检查点落点，成功复位入 SYSTEM 带，不 tick，不计数 N。
## try_interact / try_use_item 成功入 PLAYER 带；try_place_pose / 成功检查点 / 成功落地传送 / 首次冲线 / 成功出界复位 / 成功 try_break_crate 入 SYSTEM 带。
## 失败传送、等待未落地、冲线失败、world.set_pose、下落、范围内复位、零伤害 try_break_crate 不入带。
## try_interact 要求 overlapping_static_boxes 含 crate；测试用 world.set_pose 挪到箱心，course API 不自动传送。
## try_use_item 用当前姿态加调用方 reach 做 overlapping_static_boxes_at；测试站在起点，reach 指向 _crate_z，不 set_pose 到箱上。
## 终点垫与起点不重合；冲线用 set_pose 到终点盒心。finish_tick 未冲线为 -1，不入 hash_state。
## TraprushGrayboxAcceptance.try_run 用同一套调用方数值跑完 CD-61 §4.1 M1 切片；try_place_pose 入 SYSTEM 带。
## TraprushGrayboxTapeReplay.try_replay 把 PLAYER 与 SYSTEM 磁带经 course API 回放到 tick 0 的新 course。
## 不读客户端最终位置、障碍死亡、道具命中、冲线结果或完成标志；不覆盖道具栏、2p。

const GrayboxCourse := preload("res://src/games/traprush/graybox_course.gd")
const GrayboxAcceptance := preload("res://src/games/traprush/graybox_acceptance.gd")
const GrayboxTapeReplay := preload("res://src/games/traprush/graybox_tape_replay.gd")
const SystemOps := preload("res://src/games/traprush/graybox_system_ops.gd")
const SimReplayBuffer := preload("res://src/simulation/replay_buffer.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const FixedResultClass := preload("res://src/shared/fixed/fixed_result.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const CHECKPOINT_A: int = 10
const CHECKPOINT_B: int = 20
const CHECKPOINT_C: int = 30
const UP_SOURCE_ID: int = 1
const SIDE_SOURCE_ID: int = 3
const CRATE_MAX_HEALTH: int = 4
const MAX_HOPS: int = 1
const START_YAW: int = 8
const ACTOR_ID: int = 9
const CONTENT_VERSION: String = "content-v1"
const TRACE_ID: String = "trace-1"
const SNAPSHOT_CAPACITY: int = 4
const HAZARD_PERIOD_TICKS: int = 1
const ACCEPTANCE_TAPE_SIZE: int = 21


func test_assemble_rejects_missing_fields_bad_health_and_failed_spawn() -> void:
	assert_eq(GrayboxCourse.assemble({}), null)
	var missing_seed: Dictionary = _valid_layout()
	missing_seed.erase("seed")
	assert_eq(GrayboxCourse.assemble(missing_seed), null)
	var zero_health: Dictionary = _valid_layout()
	zero_health["crate_max_health"] = 0
	assert_eq(GrayboxCourse.assemble(zero_health), null)
	var negative_health: Dictionary = _valid_layout()
	negative_health["crate_max_health"] = -1
	assert_eq(GrayboxCourse.assemble(negative_health), null)
	var bad_wall: Dictionary = _valid_layout()
	var wall: Dictionary = _dup_dict(bad_wall["wall"])
	wall["half_x"] = -1
	bad_wall["wall"] = wall
	assert_eq(GrayboxCourse.assemble(bad_wall), null)
	var bad_spawn: Dictionary = _valid_layout()
	var spawn_start: Dictionary = _dup_dict(bad_spawn["spawn_start"])
	spawn_start.erase("yaw_bam")
	bad_spawn["spawn_start"] = spawn_start
	assert_eq(GrayboxCourse.assemble(bad_spawn), null)
	var float_start: Dictionary = _valid_layout()
	float_start["start_x"] = 1.0
	assert_eq(GrayboxCourse.assemble(float_start), null)
	var missing_pads: Dictionary = _valid_layout()
	missing_pads.erase("checkpoint_pads")
	assert_eq(GrayboxCourse.assemble(missing_pads), null)
	var short_pads: Dictionary = _valid_layout()
	var short_list: Array = short_pads["checkpoint_pads"]
	short_list.remove_at(short_list.size() - 1)
	short_pads["checkpoint_pads"] = short_list
	assert_eq(GrayboxCourse.assemble(short_pads), null)
	var long_pads: Dictionary = _valid_layout()
	var long_list: Array = long_pads["checkpoint_pads"]
	long_list.append(_pad_box(_start_x(), 0, 0))
	long_pads["checkpoint_pads"] = long_list
	assert_eq(GrayboxCourse.assemble(long_pads), null)
	var missing_pad_field: Dictionary = _valid_layout()
	var pads_missing_field: Array = missing_pad_field["checkpoint_pads"]
	var first_pad: Dictionary = _dup_dict(pads_missing_field[0])
	first_pad.erase("half_x")
	pads_missing_field[0] = first_pad
	missing_pad_field["checkpoint_pads"] = pads_missing_field
	assert_eq(GrayboxCourse.assemble(missing_pad_field), null)
	var bad_pad_spawn: Dictionary = _valid_layout()
	var pads_bad_spawn: Array = bad_pad_spawn["checkpoint_pads"]
	var failing_pad: Dictionary = _dup_dict(pads_bad_spawn[1])
	failing_pad["half_x"] = -1
	pads_bad_spawn[1] = failing_pad
	bad_pad_spawn["checkpoint_pads"] = pads_bad_spawn
	assert_eq(GrayboxCourse.assemble(bad_pad_spawn), null)
	var missing_finish: Dictionary = _valid_layout()
	missing_finish.erase("finish")
	assert_eq(GrayboxCourse.assemble(missing_finish), null)
	var bad_finish: Dictionary = _valid_layout()
	var finish_box: Dictionary = _dup_dict(bad_finish["finish"])
	finish_box["half_x"] = -1
	bad_finish["finish"] = finish_box
	assert_eq(GrayboxCourse.assemble(bad_finish), null)


func test_assemble_exposes_world_ids_track_and_crate() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_not_null(course)
	assert_eq(course.entity_id, 1)
	assert_eq(course.wall_box_id, 1)
	assert_eq(course.crate_box_id, 2)
	assert_eq(course.hazard_box_id, 3)
	assert_eq(course.pad_box_ids.size(), 3)
	assert_eq(course.pad_box_ids[0], 4)
	assert_eq(course.pad_box_ids[1], 5)
	assert_eq(course.pad_box_ids[2], 6)
	assert_eq(course.finish_box_id, 7)
	assert_eq(course.finish_tick, -1)
	assert_false(course.world.is_static_box_solid(course.finish_box_id))
	assert_false(course.world.overlaps_static_box(course.entity_id, course.finish_box_id))
	assert_eq(course.crate.max_health(), CRATE_MAX_HEALTH)
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_false(course.crate.is_destroyed())
	assert_false(course.track.is_finished())
	assert_eq(course.world.tick_index, 0)
	assert_not_null(course.tape)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.tape.get_seed(), 1)
	assert_not_null(course.snapshots)
	assert_eq(course.snapshots.capacity(), SNAPSHOT_CAPACITY)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_wall_blocks_forward_then_same_crate_displacement_passes_after_break() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var oracle: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var contrast: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var wall_dx: int = _wall_dx()
	var crate_dz: int = _crate_dz()
	assert_false(contrast.world.try_move_xz(contrast.entity_id, wall_dx, 0))
	_assert_pose(contrast, _start_x(), 0, 0, START_YAW)
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, wall_dx, 0))
	var wall_move: Dictionary = _step_intent(course, _move_payload(wall_dx, 0), 0)
	assert_true(_ok(wall_move))
	_assert_course_matches(course, oracle)
	assert_false(oracle.world.try_move_xz(oracle.entity_id, 0, crate_dz))
	_assert_course_matches(course, oracle)
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, 0, crate_dz))
	var crate_blocked: Dictionary = _step_intent(
		course,
		_move_payload(0, crate_dz, 999, 888, 777),
		0
	)
	assert_true(_ok(crate_blocked))
	_assert_course_matches(course, oracle)
	var zero_damage: Dictionary = course.try_break_crate(0)
	assert_false(_ok(zero_damage))
	assert_false(zero_damage.has("destroyed"))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_false(oracle.world.try_move_xz(oracle.entity_id, 0, crate_dz))
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, 0, crate_dz))
	var still_blocked: Dictionary = _step_intent(course, _move_payload(0, crate_dz), 0)
	assert_true(_ok(still_blocked))
	_assert_course_matches(course, oracle)
	var nick: Dictionary = course.try_break_crate(1)
	assert_true(_ok(nick))
	assert_false(_destroyed(nick))
	assert_eq(_health(nick), CRATE_MAX_HEALTH - 1)
	assert_false(course.crate.is_destroyed())
	assert_false(oracle.world.try_move_xz(oracle.entity_id, 0, crate_dz))
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, 0, crate_dz))
	var nicked_blocked: Dictionary = _step_intent(course, _move_payload(0, crate_dz), 0)
	assert_true(_ok(nicked_blocked))
	_assert_course_matches(course, oracle)
	var broken: Dictionary = course.try_break_crate(CRATE_MAX_HEALTH - 1)
	assert_true(_ok(broken))
	assert_true(_destroyed(broken))
	assert_eq(course.crate.current_health(), 0)
	assert_true(course.crate.is_destroyed())
	assert_true(oracle.world.set_static_box_solid(oracle.crate_box_id, false))
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, 0, crate_dz))
	var passed: Dictionary = _step_intent(
		course,
		_move_payload(0, crate_dz, 999, 888, 777),
		0
	)
	assert_true(_ok(passed))
	_assert_course_matches(course, oracle)
	assert_false(oracle.world.try_move_xz(oracle.entity_id, wall_dx, 0))
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, wall_dx, 0))
	var wall_still: Dictionary = _step_intent(course, _move_payload(wall_dx, 0), 0)
	assert_true(_ok(wall_still))
	_assert_course_matches(course, oracle)
	assert_eq(course.world.tick_index, 0)


func test_portal_fails_until_checkpoint_then_up_changes_y_and_side_changes_z() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var gated: Dictionary = course.try_land_portal(UP_SOURCE_ID, CHECKPOINT_B, MAX_HOPS)
	assert_false(_ok(gated))
	assert_false(gated.has("landed"))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_A))
	var up: Dictionary = course.try_land_portal(UP_SOURCE_ID, CHECKPOINT_B, MAX_HOPS)
	assert_true(_ok(up))
	assert_true(_landed(up))
	_assert_pose(course, _start_x(), _up_dest_y(), 0, 0)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_B))
	var side: Dictionary = course.try_land_portal(SIDE_SOURCE_ID, CHECKPOINT_C, MAX_HOPS)
	assert_true(_ok(side))
	assert_true(_landed(side))
	_assert_pose(course, _start_x(), 0, _side_dest_z(), START_YAW)
	assert_eq(course.world.tick_index, 0)


func test_ordered_checkpoints_finish_and_out_of_order_try_accept_fails() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_false(course.try_accept_checkpoint(99))
	_set_pose(course, _start_x(), _up_dest_y(), 0, 0)
	assert_false(course.try_accept_checkpoint(CHECKPOINT_B))
	_set_pose(course, _start_x(), 0, _side_dest_z(), START_YAW)
	assert_false(course.try_accept_checkpoint(CHECKPOINT_C))
	_set_pose(course, _start_x(), 0, 0, START_YAW)
	assert_false(course.track.is_finished())
	assert_true(course.try_accept_checkpoint(CHECKPOINT_A))
	assert_false(course.try_accept_checkpoint(CHECKPOINT_C))
	assert_false(course.track.is_finished())
	_set_pose(course, _start_x(), _up_dest_y(), 0, 0)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_B))
	_set_pose(course, _start_x(), 0, _side_dest_z(), START_YAW)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_C))
	assert_true(course.track.is_finished())
	assert_false(course.try_accept_checkpoint(CHECKPOINT_A))
	assert_true(course.track.is_finished())


func test_accept_b_fails_when_not_overlapping_pad_b() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(course.try_accept_checkpoint(CHECKPOINT_A))
	assert_false(course.try_accept_checkpoint(CHECKPOINT_B))
	assert_false(course.track.is_finished())
	assert_eq(course.world.tick_index, 0)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_identical_inputs_on_two_worlds_match_hash_finished_and_health() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	_run_shared_sequence(left)
	_run_shared_sequence(right)
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.tape.hash_tape().hex_encode(), right.tape.hash_tape().hex_encode())
	assert_true(left.track.is_finished())
	assert_true(right.track.is_finished())
	assert_eq(left.crate.current_health(), 0)
	assert_eq(right.crate.current_health(), 0)
	assert_eq(left.world.tick_index, 0)
	assert_eq(right.world.tick_index, 0)
	assert_eq(left.crate.current_health(), right.crate.current_health())
	assert_eq(left.track.is_finished(), right.track.is_finished())


func test_assemble_rejects_missing_or_invalid_tape_envelope() -> void:
	var missing_actor: Dictionary = _valid_layout()
	missing_actor.erase("actor_id")
	assert_eq(GrayboxCourse.assemble(missing_actor), null)
	var missing_version: Dictionary = _valid_layout()
	missing_version.erase("content_version")
	assert_eq(GrayboxCourse.assemble(missing_version), null)
	var missing_trace: Dictionary = _valid_layout()
	missing_trace.erase("trace_id")
	assert_eq(GrayboxCourse.assemble(missing_trace), null)
	var zero_actor: Dictionary = _valid_layout()
	zero_actor["actor_id"] = 0
	assert_eq(GrayboxCourse.assemble(zero_actor), null)
	var negative_actor: Dictionary = _valid_layout()
	negative_actor["actor_id"] = -1
	assert_eq(GrayboxCourse.assemble(negative_actor), null)
	var float_actor: Dictionary = _valid_layout()
	float_actor["actor_id"] = 1.0
	assert_eq(GrayboxCourse.assemble(float_actor), null)
	var empty_version: Dictionary = _valid_layout()
	empty_version["content_version"] = ""
	assert_eq(GrayboxCourse.assemble(empty_version), null)
	var empty_trace: Dictionary = _valid_layout()
	empty_trace["trace_id"] = ""
	assert_eq(GrayboxCourse.assemble(empty_trace), null)
	var int_version: Dictionary = _valid_layout()
	int_version["content_version"] = 1
	assert_eq(GrayboxCourse.assemble(int_version), null)
	var int_trace: Dictionary = _valid_layout()
	int_trace["trace_id"] = 1
	assert_eq(GrayboxCourse.assemble(int_trace), null)


func test_failed_intent_does_not_append_to_tape() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_eq(course.tape.size(), 0)
	assert_false(_ok(_step_intent(course, {}, 0)))
	assert_eq(course.tape.size(), 0)
	assert_false(_ok(_step_intent(course, {"intent": PlayerIntentNames.MOVE}, 0)))
	assert_eq(course.tape.size(), 0)
	assert_false(_ok(_step_intent(course, {"intent": PlayerIntentNames.SHOVE}, 0)))
	assert_eq(course.tape.size(), 0)
	assert_true(_ok(_step_intent(course, _move_payload(0, 0), 0)))
	assert_eq(course.tape.size(), 1)
	var recorded: SharedCommand = course.tape.command_at(0)
	assert_not_null(recorded)
	assert_eq(recorded.command_id, 1)
	assert_eq(recorded.sequence, 1)
	assert_eq(recorded.actor_id, ACTOR_ID)
	assert_eq(recorded.kind, SharedCommand.Kind.PLAYER)
	assert_eq(course.world.tick_index, 0)


func test_break_crate_appends_system_failed_portal_stays_off_tape() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(_step_intent(course, _move_payload(_wall_dx(), 0), 0)))
	assert_eq(course.tape.size(), 1)
	assert_true(_ok(course.try_break_crate(1)))
	assert_eq(course.tape.size(), 2)
	_assert_system_command(course.tape.command_at(1), SystemOps.BREAK_CRATE)
	assert_false(_ok(course.try_land_portal(UP_SOURCE_ID, CHECKPOINT_B, MAX_HOPS)))
	assert_eq(course.tape.size(), 2)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_A))
	assert_eq(course.tape.size(), 3)
	_assert_system_command(course.tape.command_at(2), SystemOps.ACCEPT_CHECKPOINT)
	assert_true(_ok(course.try_land_portal(UP_SOURCE_ID, CHECKPOINT_B, MAX_HOPS)))
	assert_eq(course.tape.size(), 4)
	_assert_system_command(course.tape.command_at(3), SystemOps.LAND_PORTAL)
	assert_eq(course.world.tick_index, 0)


func test_try_place_pose_appends_system_world_set_pose_does_not() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_set_pose(course, _start_x(), 0, 0, START_YAW)
	assert_eq(course.tape.size(), 0)
	assert_true(course.try_place_pose(_start_x(), 0, 0, START_YAW))
	assert_eq(course.tape.size(), 1)
	_assert_system_command(course.tape.command_at(0), SystemOps.PLACE_POSE)
	var placed: SharedCommand = course.tape.command_at(0)
	var placed_x: int = placed.payload.get("x", -1)
	var placed_y: int = placed.payload.get("y", -1)
	var placed_z: int = placed.payload.get("z", -1)
	var placed_yaw: int = placed.payload.get("yaw_bam", -1)
	assert_eq(placed_x, _start_x())
	assert_eq(placed_y, 0)
	assert_eq(placed_z, 0)
	assert_eq(placed_yaw, START_YAW)
	assert_eq(course.world.tick_index, 0)


func test_two_courses_same_intents_match_tape_and_state_hash() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	_run_tape_hash_sequence(left)
	_run_tape_hash_sequence(right)
	assert_eq(left.tape.size(), 2)
	assert_eq(right.tape.size(), 2)
	var layout_seed: int = layout.get("seed", 0)
	assert_eq(left.tape.get_seed(), layout_seed)
	assert_eq(right.tape.get_seed(), layout_seed)
	assert_eq(left.tape.hash_tape().hex_encode(), right.tape.hash_tape().hex_encode())
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.world.tick_index, 0)
	assert_eq(right.world.tick_index, 0)


func test_try_step_intent_does_not_call_tick() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_eq(course.world.tick_index, 0)
	assert_true(_ok(_step_intent(course, _move_payload(0, 0), 0)))
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 1)
	var jump_dy: int = _whole(1)
	var support_dy: int = -_whole(1)
	assert_true(_ok(_step_intent(course, {"intent": PlayerIntentNames.JUMP}, jump_dy, support_dy)))
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 2)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_airborne_jump_keeps_pose_and_appends_tape() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var jump_dy: int = _whole(2)
	var support_dy: int = -_whole(1)
	assert_false(course.world.is_supported_by_solid(course.entity_id, support_dy))
	var jumped: Dictionary = _step_intent(
		course, {"intent": PlayerIntentNames.JUMP}, jump_dy, support_dy
	)
	assert_true(_ok(jumped))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 1)
	assert_eq(course.snapshots.size(), 1)


func test_grounded_jump_uses_caller_support_dy() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var stand_y: int = _whole(4)
	var support_dy: int = -_whole(1)
	var jump_dy: int = _whole(1)
	_set_pose(course, _start_x(), stand_y, 0, START_YAW)
	assert_eq(
		course.world.spawn_static_box(_start_x(), 0, 0, _whole(1), _whole(1), _whole(1)),
		8
	)
	assert_true(course.world.is_supported_by_solid(course.entity_id, support_dy))
	var jumped: Dictionary = _step_intent(
		course, {"intent": PlayerIntentNames.JUMP}, jump_dy, support_dy
	)
	assert_true(_ok(jumped))
	_assert_pose(course, _start_x(), stand_y + jump_dy, 0, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 1)
	assert_eq(course.snapshots.size(), 1)


func test_try_apply_fall_rejects_null_world_or_unknown_entity() -> void:
	var empty: GrayboxCourse = GrayboxCourse.new()
	assert_false(empty.try_apply_fall(-_whole(1)))
	var missing_world: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	missing_world.world = null
	assert_false(missing_world.try_apply_fall(-_whole(1)))
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var original_id: int = course.entity_id
	course.entity_id = 99
	assert_false(course.try_apply_fall(-_whole(1)))
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 1)
	var pose: Dictionary = course.world.get_pose(original_id)
	var pose_y: int = pose.get("y", -1)
	assert_eq(pose_y, 0)


func test_try_apply_fall_zero_keeps_pose_tick_tape_and_snapshots() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var before_hex: String = course.world.hash_state().hex_encode()
	var fall_dy: int = 0
	assert_true(course.try_apply_fall(fall_dy))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 1)
	assert_eq(course.world.hash_state().hex_encode(), before_hex)


func test_try_apply_fall_open_space_drops_y_without_tick_tape_or_snapshot() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var fall_dy: int = -_whole(2)
	var dest_y_res: FixedResultClass = FixedClass.try_add(0, fall_dy)
	assert_true(dest_y_res.ok)
	var dest_y: int = dest_y_res.value
	assert_true(course.try_apply_fall(fall_dy))
	_assert_pose(course, _start_x(), dest_y, 0, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 1)


func test_try_apply_fall_stops_on_floor_then_commit_advances_tick_only() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var start_y: int = _whole(10)
	var fall_dy: int = -_whole(10)
	var last_free_y: int = _whole(4)
	var blocked_y: int = _whole(3)
	_set_pose(course, _start_x(), start_y, 0, START_YAW)
	assert_eq(
		course.world.spawn_static_box(_start_x(), 0, 0, _whole(1), _whole(1), _whole(1)),
		8
	)
	assert_false(course.world.is_pose_blocked(course.entity_id, _start_x(), last_free_y, 0))
	assert_true(course.world.is_pose_blocked(course.entity_id, _start_x(), blocked_y, 0))
	assert_false(course.world.try_move_y(course.entity_id, fall_dy))
	_assert_pose(course, _start_x(), start_y, 0, START_YAW)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 1)
	assert_true(course.try_apply_fall(fall_dy))
	_assert_pose(course, _start_x(), last_free_y, 0, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 1)
	assert_true(course.world.is_supported_by_solid(course.entity_id, -_whole(1)))
	assert_true(course.try_commit_tick(0))
	assert_eq(course.world.tick_index, 1)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 2)
	_assert_pose(course, _start_x(), last_free_y, 0, START_YAW)


func test_two_courses_same_fall_match_hash_state() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	var fall_dy: int = -_whole(2)
	assert_true(left.try_apply_fall(fall_dy))
	assert_true(right.try_apply_fall(fall_dy))
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.world.tick_index, 0)
	assert_eq(right.world.tick_index, 0)
	assert_eq(left.tape.size(), 0)
	assert_eq(right.tape.size(), 0)
	assert_eq(left.snapshots.size(), 1)
	assert_eq(right.snapshots.size(), 1)


func test_assemble_rejects_missing_or_invalid_snapshot_hazard_and_period() -> void:
	var missing_capacity: Dictionary = _valid_layout()
	missing_capacity.erase("snapshot_capacity")
	assert_eq(GrayboxCourse.assemble(missing_capacity), null)
	var zero_capacity: Dictionary = _valid_layout()
	zero_capacity["snapshot_capacity"] = 0
	assert_eq(GrayboxCourse.assemble(zero_capacity), null)
	var negative_capacity: Dictionary = _valid_layout()
	negative_capacity["snapshot_capacity"] = -1
	assert_eq(GrayboxCourse.assemble(negative_capacity), null)
	var float_capacity: Dictionary = _valid_layout()
	float_capacity["snapshot_capacity"] = 1.0
	assert_eq(GrayboxCourse.assemble(float_capacity), null)
	var missing_hazard: Dictionary = _valid_layout()
	missing_hazard.erase("hazard")
	assert_eq(GrayboxCourse.assemble(missing_hazard), null)
	var bad_hazard: Dictionary = _valid_layout()
	var hazard: Dictionary = _dup_dict(bad_hazard["hazard"])
	hazard["half_x"] = -1
	bad_hazard["hazard"] = hazard
	assert_eq(GrayboxCourse.assemble(bad_hazard), null)
	var missing_period: Dictionary = _valid_layout()
	missing_period.erase("hazard_period_ticks")
	assert_eq(GrayboxCourse.assemble(missing_period), null)
	var zero_period: Dictionary = _valid_layout()
	zero_period["hazard_period_ticks"] = 0
	assert_eq(GrayboxCourse.assemble(zero_period), null)
	var negative_period: Dictionary = _valid_layout()
	negative_period["hazard_period_ticks"] = -2
	assert_eq(GrayboxCourse.assemble(negative_period), null)
	var float_period: Dictionary = _valid_layout()
	float_period["hazard_period_ticks"] = 1.0
	assert_eq(GrayboxCourse.assemble(float_period), null)


func test_assemble_records_tick_zero_snapshot_try_step_does_not_record() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_not_null(course)
	assert_eq(course.snapshots.size(), 1)
	var tick0_hex: String = course.snapshots.hash_at_tick(0).hex_encode()
	assert_eq(tick0_hex, course.world.hash_state().hex_encode())
	assert_eq(course.world.tick_index, 0)
	assert_true(_ok(_step_intent(course, _move_payload(_whole(1), 0), 0)))
	_assert_pose(course, _start_x() + _whole(1), 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	assert_ne(course.world.hash_state().hex_encode(), tick0_hex)
	assert_eq(course.snapshots.hash_at_tick(0).hex_encode(), tick0_hex)


func test_period_one_hazard_toggles_plus_x_blocking_on_commit() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var oracle: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var contrast: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var dx: int = _hazard_dx()
	var tape_before: int = course.tape.size()
	assert_false(contrast.world.try_move_xz(contrast.entity_id, dx, 0))
	_assert_pose(contrast, _start_x(), 0, 0, START_YAW)
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, dx, 0))
	var blocked: Dictionary = _step_intent(course, _move_payload(dx, 0), 0)
	assert_true(_ok(blocked))
	_assert_course_matches(course, oracle)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), tape_before + 1)
	assert_true(course.try_commit_tick(0))
	assert_eq(course.world.tick_index, 1)
	assert_eq(course.tape.size(), tape_before + 1)
	assert_eq(course.snapshots.size(), 2)
	_set_pose(course, _start_x(), 0, 0, START_YAW)
	var opened: Dictionary = _step_intent(course, _move_payload(dx, 0), 0)
	assert_true(_ok(opened))
	_assert_pose(course, _start_x() + dx, 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 1)
	assert_true(course.try_commit_tick(0))
	assert_eq(course.world.tick_index, 2)
	assert_eq(course.tape.size(), tape_before + 2)
	var reblocked: Dictionary = _step_intent(course, _move_payload(dx, 0), 0)
	assert_true(_ok(reblocked))
	_assert_pose(course, _start_x() + dx, 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 2)


func test_two_courses_same_move_and_commit_match_tape_state_and_snapshots() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	_run_move_and_commit_sequence(left)
	_run_move_and_commit_sequence(right)
	assert_eq(left.tape.hash_tape().hex_encode(), right.tape.hash_tape().hex_encode())
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.world.tick_index, right.world.tick_index)
	assert_eq(left.snapshots.size(), right.snapshots.size())
	for tick: int in range(left.world.tick_index + 1):
		assert_eq(
			left.snapshots.hash_at_tick(tick).hex_encode(),
			right.snapshots.hash_at_tick(tick).hex_encode()
		)


func test_snapshot_capacity_two_drops_oldest_tick() -> void:
	var layout: Dictionary = _valid_layout()
	layout["snapshot_capacity"] = 2
	var course: GrayboxCourse = GrayboxCourse.assemble(layout)
	assert_eq(course.snapshots.capacity(), 2)
	assert_eq(course.snapshots.size(), 1)
	assert_ne(course.snapshots.hash_at_tick(0).size(), 0)
	assert_true(course.try_commit_tick(0))
	assert_true(course.try_commit_tick(0))
	assert_eq(course.world.tick_index, 2)
	assert_eq(course.snapshots.size(), 2)
	assert_eq(course.snapshots.hash_at_tick(0).size(), 0)
	assert_ne(course.snapshots.hash_at_tick(1).size(), 0)
	assert_ne(course.snapshots.hash_at_tick(2).size(), 0)
	assert_true(course.try_commit_tick(0))
	assert_eq(course.world.tick_index, 3)
	assert_eq(course.snapshots.size(), 2)
	assert_eq(course.snapshots.hash_at_tick(0).size(), 0)
	assert_eq(course.snapshots.hash_at_tick(1).size(), 0)
	assert_ne(course.snapshots.hash_at_tick(2).size(), 0)
	assert_ne(course.snapshots.hash_at_tick(3).size(), 0)


func test_interact_outside_crate_is_rejected_without_damage_or_tape() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_eq(course.tape.size(), 0)
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	var rejected: Dictionary = course.try_interact(_interact_payload(999, 888, 777, true), 1)
	assert_false(_ok(rejected))
	assert_false(rejected.has("health"))
	assert_false(rejected.has("destroyed"))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_false(course.crate.is_destroyed())
	assert_eq(course.tape.size(), 0)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_interact_decode_failure_on_crate_does_not_damage_or_append() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_set_pose_on_crate(course)
	assert_false(_ok(course.try_interact({}, 1)))
	assert_false(_ok(course.try_interact({"intent": PlayerIntentNames.JUMP}, 1)))
	assert_false(_ok(course.try_interact({"intent": 1}, 1)))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)


func test_interact_on_crate_rejects_zero_damage_without_tape() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_set_pose_on_crate(course)
	var rejected: Dictionary = course.try_interact(_interact_payload(), 0)
	assert_false(_ok(rejected))
	assert_false(rejected.has("health"))
	assert_false(rejected.has("destroyed"))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_false(course.crate.is_destroyed())
	assert_eq(course.tape.size(), 0)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)


func test_interact_on_crate_applies_damage_and_appends_player_command() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(_step_intent(course, _move_payload(0, 0), 0)))
	assert_eq(course.tape.size(), 1)
	_set_pose_on_crate(course)
	var payload: Dictionary = _interact_payload(999, 888, 777, true)
	var nicked: Dictionary = course.try_interact(payload, 1)
	assert_true(_ok(nicked))
	assert_false(_destroyed(nicked))
	assert_eq(_health(nicked), CRATE_MAX_HEALTH - 1)
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH - 1)
	assert_false(course.crate.is_destroyed())
	assert_eq(course.tape.size(), 2)
	var recorded: SharedCommand = course.tape.command_at(1)
	assert_not_null(recorded)
	assert_eq(recorded.command_id, 2)
	assert_eq(recorded.sequence, 2)
	assert_eq(recorded.actor_id, ACTOR_ID)
	assert_eq(recorded.kind, SharedCommand.Kind.PLAYER)
	assert_eq(recorded.target_tick, 0)
	var stored_intent: String = recorded.payload.get("intent", "")
	var stored_x: int = recorded.payload.get("x", -1)
	var stored_destroyed: bool = recorded.payload.get("destroyed", false)
	assert_eq(stored_intent, PlayerIntentNames.INTERACT)
	assert_eq(stored_x, 999)
	assert_eq(stored_destroyed, true)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)


func test_interact_destroy_opens_crate_path_without_tick() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var oracle: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var contrast: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var crate_dz: int = _crate_dz()
	assert_false(contrast.world.try_move_xz(contrast.entity_id, 0, crate_dz))
	_assert_pose(contrast, _start_x(), 0, 0, START_YAW)
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, 0, crate_dz))
	var blocked: Dictionary = _step_intent(course, _move_payload(0, crate_dz), 0)
	assert_true(_ok(blocked))
	_assert_course_matches(course, oracle)
	assert_false(_ok(course.try_interact(_interact_payload(), CRATE_MAX_HEALTH)))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_eq(course.tape.size(), 1)
	_set_pose_on_crate(course)
	var broken: Dictionary = course.try_interact(_interact_payload(), CRATE_MAX_HEALTH)
	assert_true(_ok(broken))
	assert_true(_destroyed(broken))
	assert_eq(course.crate.current_health(), 0)
	assert_true(course.crate.is_destroyed())
	assert_eq(course.tape.size(), 2)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_set_pose(course, _start_x(), 0, 0, START_YAW)
	var passed: Dictionary = _step_intent(course, _move_payload(0, crate_dz), 0)
	assert_true(_ok(passed))
	_assert_pose(course, _start_x(), 0, crate_dz, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	assert_eq(course.tape.size(), 3)


func test_try_break_crate_still_ignores_overlap_and_appends_system() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_false(_ok(course.try_break_crate(0)))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_eq(course.tape.size(), 0)
	var nicked: Dictionary = course.try_break_crate(1)
	assert_true(_ok(nicked))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH - 1)
	assert_eq(course.tape.size(), 1)
	_assert_system_command(course.tape.command_at(0), SystemOps.BREAK_CRATE)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)


func test_two_courses_same_interact_match_tape_and_state_hash() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	_run_interact_on_crate(left)
	_run_interact_on_crate(right)
	assert_eq(left.tape.size(), 1)
	assert_eq(right.tape.size(), 1)
	assert_eq(left.tape.hash_tape().hex_encode(), right.tape.hash_tape().hex_encode())
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.crate.current_health(), 0)
	assert_eq(right.crate.current_health(), 0)
	assert_eq(left.world.tick_index, 0)
	assert_eq(right.world.tick_index, 0)
	assert_eq(left.snapshots.size(), 1)
	assert_eq(right.snapshots.size(), 1)


func test_use_item_decode_failure_does_not_damage_or_append() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_false(_ok(course.try_use_item({}, 1, 0, 0, _crate_z())))
	assert_false(_ok(course.try_use_item({"intent": PlayerIntentNames.JUMP}, 1, 0, 0, _crate_z())))
	assert_false(_ok(course.try_use_item({"intent": 1}, 1, 0, 0, _crate_z())))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_use_item_pose_add_overflow_does_not_damage_or_append() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var rejected: Dictionary = course.try_use_item(
		_use_item_payload(),
		CRATE_MAX_HEALTH,
		FixedClass.INT64_MAX,
		0,
		0
	)
	assert_false(_ok(rejected))
	assert_false(rejected.has("health"))
	assert_false(rejected.has("destroyed"))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_use_item_zero_reach_from_start_is_rejected_without_damage_or_tape() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var rejected: Dictionary = course.try_use_item(_use_item_payload(999, 888, 777, 42, true, true, 99), 1, 0, 0, 0)
	assert_false(_ok(rejected))
	assert_false(rejected.has("health"))
	assert_false(rejected.has("destroyed"))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_false(course.crate.is_destroyed())
	assert_eq(course.tape.size(), 0)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_use_item_in_reach_rejects_zero_damage_without_tape() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var rejected: Dictionary = course.try_use_item(_use_item_payload(), 0, 0, 0, _crate_z())
	assert_false(_ok(rejected))
	assert_false(rejected.has("health"))
	assert_false(rejected.has("destroyed"))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_false(course.crate.is_destroyed())
	assert_eq(course.tape.size(), 0)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_use_item_from_start_with_crate_reach_applies_damage_and_appends_player_command() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(_step_intent(course, _move_payload(0, 0), 0)))
	assert_eq(course.tape.size(), 1)
	var payload: Dictionary = _use_item_payload(999, 888, 777, 42, true, true, 99)
	var nicked: Dictionary = course.try_use_item(payload, 1, 0, 0, _crate_z())
	assert_true(_ok(nicked))
	assert_false(_destroyed(nicked))
	assert_eq(_health(nicked), CRATE_MAX_HEALTH - 1)
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH - 1)
	assert_false(course.crate.is_destroyed())
	assert_eq(course.tape.size(), 2)
	var recorded: SharedCommand = course.tape.command_at(1)
	assert_not_null(recorded)
	assert_eq(recorded.command_id, 2)
	assert_eq(recorded.sequence, 2)
	assert_eq(recorded.actor_id, ACTOR_ID)
	assert_eq(recorded.kind, SharedCommand.Kind.PLAYER)
	assert_eq(recorded.target_tick, 0)
	var stored_intent: String = recorded.payload.get("intent", "")
	var stored_x: int = recorded.payload.get("x", -1)
	var stored_item_id: int = recorded.payload.get("item_id", -1)
	var stored_hit: bool = recorded.payload.get("hit", false)
	var stored_destroyed: bool = recorded.payload.get("destroyed", false)
	assert_eq(stored_intent, PlayerIntentNames.USE_ITEM)
	assert_eq(stored_x, 999)
	assert_eq(stored_item_id, 42)
	assert_eq(stored_hit, true)
	assert_eq(stored_destroyed, true)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_use_item_destroy_from_start_opens_crate_path_without_tick_or_move() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var oracle: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var contrast: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var crate_dz: int = _crate_dz()
	assert_false(contrast.world.try_move_xz(contrast.entity_id, 0, crate_dz))
	_assert_pose(contrast, _start_x(), 0, 0, START_YAW)
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, 0, crate_dz))
	var blocked: Dictionary = _step_intent(course, _move_payload(0, crate_dz), 0)
	assert_true(_ok(blocked))
	_assert_course_matches(course, oracle)
	_set_pose(course, _start_x(), 0, 0, START_YAW)
	assert_false(_ok(course.try_use_item(_use_item_payload(), CRATE_MAX_HEALTH, 0, 0, 0)))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_eq(course.tape.size(), 1)
	var broken: Dictionary = course.try_use_item(_use_item_payload(), CRATE_MAX_HEALTH, 0, 0, _crate_z())
	assert_true(_ok(broken))
	assert_true(_destroyed(broken))
	assert_eq(course.crate.current_health(), 0)
	assert_true(course.crate.is_destroyed())
	assert_eq(course.tape.size(), 2)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	var passed: Dictionary = _step_intent(course, _move_payload(0, crate_dz), 0)
	assert_true(_ok(passed))
	_assert_pose(course, _start_x(), 0, crate_dz, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	assert_eq(course.tape.size(), 3)


func test_try_interact_still_requires_current_crate_occupancy() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_false(_ok(course.try_interact(_interact_payload(), 1)))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_eq(course.tape.size(), 0)
	var nicked: Dictionary = course.try_use_item(_use_item_payload(), 1, 0, 0, _crate_z())
	assert_true(_ok(nicked))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH - 1)
	assert_eq(course.tape.size(), 1)
	assert_false(_ok(course.try_interact(_interact_payload(), 1)))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH - 1)
	assert_eq(course.tape.size(), 1)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_two_courses_same_use_item_destroy_match_tape_and_state_hash() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	_run_use_item_destroy_from_start(left)
	_run_use_item_destroy_from_start(right)
	assert_eq(left.tape.size(), 1)
	assert_eq(right.tape.size(), 1)
	assert_eq(left.tape.hash_tape().hex_encode(), right.tape.hash_tape().hex_encode())
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.crate.current_health(), 0)
	assert_eq(right.crate.current_health(), 0)
	assert_eq(left.world.tick_index, 0)
	assert_eq(right.world.tick_index, 0)
	assert_eq(left.snapshots.size(), 1)
	assert_eq(right.snapshots.size(), 1)
	_assert_pose(left, _start_x(), 0, 0, START_YAW)
	_assert_pose(right, _start_x(), 0, 0, START_YAW)


func test_try_commit_tick_rejects_null_world_or_snapshots() -> void:
	var empty: GrayboxCourse = GrayboxCourse.new()
	assert_false(empty.try_commit_tick(0))
	var missing_world: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	missing_world.world = null
	assert_false(missing_world.try_commit_tick(-_whole(1)))
	assert_eq(missing_world.tape.size(), 0)
	assert_eq(missing_world.snapshots.size(), 1)
	var missing_ring: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	missing_ring.snapshots = null
	assert_false(missing_ring.try_commit_tick(-_whole(1)))
	assert_eq(missing_ring.world.tick_index, 0)
	assert_eq(missing_ring.tape.size(), 0)
	_assert_pose(missing_ring, _start_x(), 0, 0, START_YAW)


func test_try_commit_tick_zero_keeps_pose_and_advances_tick() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var tick0_hex: String = course.snapshots.hash_at_tick(0).hex_encode()
	var fall_dy: int = 0
	assert_true(course.try_commit_tick(fall_dy))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 1)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 2)
	assert_eq(course.snapshots.hash_at_tick(0).hex_encode(), tick0_hex)
	assert_eq(course.snapshots.hash_at_tick(1).hex_encode(), course.world.hash_state().hex_encode())


func test_try_commit_tick_open_space_falls_then_ticks_and_records() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var tick0_hex: String = course.snapshots.hash_at_tick(0).hex_encode()
	var fall_dy: int = -_whole(2)
	var dest_y_res: FixedResultClass = FixedClass.try_add(0, fall_dy)
	assert_true(dest_y_res.ok)
	var dest_y: int = dest_y_res.value
	assert_true(course.try_commit_tick(fall_dy))
	_assert_pose(course, _start_x(), dest_y, 0, START_YAW)
	assert_eq(course.world.tick_index, 1)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 2)
	assert_eq(course.snapshots.hash_at_tick(0).hex_encode(), tick0_hex)
	assert_eq(course.snapshots.hash_at_tick(1).hex_encode(), course.world.hash_state().hex_encode())
	assert_ne(course.snapshots.hash_at_tick(1).hex_encode(), tick0_hex)


func test_try_commit_tick_stops_on_floor_then_ticks() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var start_y: int = _whole(10)
	var fall_dy: int = -_whole(10)
	var last_free_y: int = _whole(4)
	var blocked_y: int = _whole(3)
	_set_pose(course, _start_x(), start_y, 0, START_YAW)
	assert_eq(
		course.world.spawn_static_box(_start_x(), 0, 0, _whole(1), _whole(1), _whole(1)),
		8
	)
	assert_false(course.world.is_pose_blocked(course.entity_id, _start_x(), last_free_y, 0))
	assert_true(course.world.is_pose_blocked(course.entity_id, _start_x(), blocked_y, 0))
	assert_true(course.try_commit_tick(fall_dy))
	_assert_pose(course, _start_x(), last_free_y, 0, START_YAW)
	assert_eq(course.world.tick_index, 1)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 2)
	assert_true(course.world.is_supported_by_solid(course.entity_id, -_whole(1)))
	assert_eq(course.snapshots.hash_at_tick(1).hex_encode(), course.world.hash_state().hex_encode())


func test_try_commit_tick_fall_failure_does_not_tick() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var original_id: int = course.entity_id
	course.entity_id = 99
	assert_false(course.try_commit_tick(-_whole(1)))
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 1)
	var pose: Dictionary = course.world.get_pose(original_id)
	var pose_y: int = pose.get("y", -1)
	assert_eq(pose_y, 0)
	var overflow: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_set_pose(overflow, _start_x(), FixedClass.INT64_MAX, 0, START_YAW)
	assert_false(overflow.try_commit_tick(1))
	assert_eq(overflow.world.tick_index, 0)
	assert_eq(overflow.tape.size(), 0)
	assert_eq(overflow.snapshots.size(), 1)
	_assert_pose(overflow, _start_x(), FixedClass.INT64_MAX, 0, START_YAW)


func test_two_courses_same_commit_fall_match_hash_state_and_tick() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	var fall_dy: int = -_whole(2)
	assert_true(left.try_commit_tick(fall_dy))
	assert_true(right.try_commit_tick(fall_dy))
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.world.tick_index, right.world.tick_index)
	assert_eq(left.world.tick_index, 1)
	assert_eq(left.tape.size(), 0)
	assert_eq(right.tape.size(), 0)
	assert_eq(left.snapshots.size(), 2)
	assert_eq(right.snapshots.size(), 2)
	assert_eq(
		left.snapshots.hash_at_tick(1).hex_encode(),
		right.snapshots.hash_at_tick(1).hex_encode()
	)
	var dest_y_res: FixedResultClass = FixedClass.try_add(0, fall_dy)
	assert_true(dest_y_res.ok)
	_assert_pose(left, _start_x(), dest_y_res.value, 0, START_YAW)
	_assert_pose(right, _start_x(), dest_y_res.value, 0, START_YAW)


func test_try_reset_if_out_of_range_rejects_null_world_or_unknown_entity() -> void:
	var empty: GrayboxCourse = GrayboxCourse.new()
	assert_false(_ok(_reset_wide(empty)))
	var missing_world: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	missing_world.world = null
	assert_false(_ok(_reset_wide(missing_world)))
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var original_id: int = course.entity_id
	course.entity_id = 99
	assert_false(_ok(_reset_wide(course)))
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 1)
	var pose: Dictionary = course.world.get_pose(original_id)
	var pose_y: int = pose.get("y", -1)
	assert_eq(pose_y, 0)


func test_in_range_pose_does_not_reset() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var before_hex: String = course.world.hash_state().hex_encode()
	var result: Dictionary = _reset_wide(course)
	assert_true(_ok(result))
	assert_false(_reset_flag(result))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.snapshots.size(), 1)
	assert_eq(course.world.hash_state().hex_encode(), before_hex)


func test_on_min_y_and_xz_edge_does_not_reset() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var result: Dictionary = course.try_reset_if_out_of_range(
		0,
		_wide_max(),
		_start_x(),
		_start_x(),
		0,
		0
	)
	assert_true(_ok(result))
	assert_false(_reset_flag(result))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.world.tick_index, 0)


func test_below_min_y_resets_to_start_without_tick() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_set_pose(course, _start_x(), -_whole(2), 0, START_YAW)
	var result: Dictionary = course.try_reset_if_out_of_range(
		0,
		_wide_max(),
		_wide_min(),
		_wide_max(),
		_wide_min(),
		_wide_max()
	)
	assert_true(_ok(result))
	assert_true(_reset_flag(result))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 1)
	_assert_system_command(course.tape.command_at(0), SystemOps.RESET_IF_OUT_OF_RANGE)
	assert_eq(course.snapshots.size(), 1)
	assert_eq(course.finish_tick, -1)


func test_above_max_y_resets_to_start() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_set_pose(course, _start_x(), _whole(20), 0, START_YAW)
	var result: Dictionary = course.try_reset_if_out_of_range(
		_wide_min(),
		_whole(10),
		_wide_min(),
		_wide_max(),
		_wide_min(),
		_wide_max()
	)
	assert_true(_ok(result))
	assert_true(_reset_flag(result))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	assert_eq(course.tape.size(), 1)
	assert_eq(course.world.tick_index, 0)


func test_outside_xz_resets_to_start() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_set_pose(course, _start_x(), 0, _whole(50), START_YAW)
	var result: Dictionary = course.try_reset_if_out_of_range(
		_wide_min(),
		_wide_max(),
		_wide_min(),
		_wide_max(),
		0,
		_whole(10)
	)
	assert_true(_ok(result))
	assert_true(_reset_flag(result))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	assert_eq(course.tape.size(), 1)
	_assert_system_command(course.tape.command_at(0), SystemOps.RESET_IF_OUT_OF_RANGE)


func test_out_of_range_after_checkpoint_b_resets_to_checkpoint_pose() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_set_pose(course, _start_x(), 0, 0, START_YAW)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_A))
	_set_pose(course, _start_x(), _up_dest_y(), 0, 0)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_B))
	_set_pose(course, _start_x(), -_whole(2), 0, START_YAW)
	var result: Dictionary = course.try_reset_if_out_of_range(
		0,
		_wide_max(),
		_wide_min(),
		_wide_max(),
		_wide_min(),
		_wide_max()
	)
	assert_true(_ok(result))
	assert_true(_reset_flag(result))
	_assert_pose(course, _start_x(), _up_dest_y(), 0, 0)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 3)
	_assert_system_command(course.tape.command_at(2), SystemOps.RESET_IF_OUT_OF_RANGE)
	assert_eq(course.track.last_accepted_id(), CHECKPOINT_B)


func test_two_courses_same_out_of_range_reset_match_hash_state() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	_set_pose(left, _start_x(), -_whole(2), 0, START_YAW)
	_set_pose(right, _start_x(), -_whole(2), 0, START_YAW)
	var left_result: Dictionary = left.try_reset_if_out_of_range(
		0,
		_wide_max(),
		_wide_min(),
		_wide_max(),
		_wide_min(),
		_wide_max()
	)
	var right_result: Dictionary = right.try_reset_if_out_of_range(
		0,
		_wide_max(),
		_wide_min(),
		_wide_max(),
		_wide_min(),
		_wide_max()
	)
	assert_true(_ok(left_result))
	assert_true(_ok(right_result))
	assert_true(_reset_flag(left_result))
	assert_true(_reset_flag(right_result))
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.tape.hash_tape().hex_encode(), right.tape.hash_tape().hex_encode())
	assert_eq(left.world.tick_index, 0)
	assert_eq(right.world.tick_index, 0)
	_assert_pose(left, _start_x(), 0, 0, START_YAW)
	_assert_pose(right, _start_x(), 0, 0, START_YAW)
	assert_eq(left.tape.size(), 1)
	assert_eq(right.tape.size(), 1)


func test_start_pose_does_not_cross_finish() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_eq(course.finish_tick, -1)
	assert_false(course.world.overlaps_static_box(course.entity_id, course.finish_box_id))
	var rejected: Dictionary = course.try_cross_finish()
	assert_false(_ok(rejected))
	assert_false(rejected.has("finish_tick"))
	assert_eq(course.finish_tick, -1)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func test_finish_occupancy_without_all_checkpoints_fails() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_set_pose_on_finish(course)
	assert_true(course.world.overlaps_static_box(course.entity_id, course.finish_box_id))
	assert_false(course.track.is_finished())
	var rejected: Dictionary = course.try_cross_finish()
	assert_false(_ok(rejected))
	assert_eq(course.finish_tick, -1)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, _finish_z(), START_YAW)


func test_all_checkpoints_without_finish_occupancy_fails() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_accept_ordered_checkpoints(course)
	assert_true(course.track.is_finished())
	assert_false(course.world.overlaps_static_box(course.entity_id, course.finish_box_id))
	var rejected: Dictionary = course.try_cross_finish()
	assert_false(_ok(rejected))
	assert_eq(course.finish_tick, -1)
	assert_eq(course.tape.size(), 3)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)


func test_all_checkpoints_and_finish_occupancy_records_tick_index() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_accept_ordered_checkpoints(course)
	_set_pose_on_finish(course)
	var crossed: Dictionary = course.try_cross_finish()
	assert_true(_ok(crossed))
	assert_eq(_finish_tick(crossed), 0)
	assert_eq(course.finish_tick, 0)
	assert_eq(course.finish_tick, course.world.tick_index)
	assert_eq(course.tape.size(), 4)
	_assert_system_command(course.tape.command_at(3), SystemOps.CROSS_FINISH)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	_assert_pose(course, _start_x(), 0, _finish_z(), START_YAW)


func test_cross_finish_after_commit_uses_world_tick_and_is_idempotent() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_accept_ordered_checkpoints(course)
	assert_true(course.try_commit_tick(0))
	assert_eq(course.world.tick_index, 1)
	assert_eq(course.snapshots.size(), 2)
	_set_pose_on_finish(course)
	var crossed: Dictionary = course.try_cross_finish()
	assert_true(_ok(crossed))
	assert_eq(_finish_tick(crossed), 1)
	assert_eq(course.finish_tick, 1)
	assert_eq(course.tape.size(), 4)
	assert_eq(course.world.tick_index, 1)
	assert_eq(course.snapshots.size(), 2)
	assert_true(course.try_commit_tick(0))
	assert_eq(course.world.tick_index, 2)
	_set_pose(course, _start_x(), 0, 0, START_YAW)
	assert_false(course.world.overlaps_static_box(course.entity_id, course.finish_box_id))
	var again: Dictionary = course.try_cross_finish()
	assert_true(_ok(again))
	assert_eq(_finish_tick(again), 1)
	assert_eq(course.finish_tick, 1)
	assert_eq(course.tape.size(), 4)
	assert_eq(course.world.tick_index, 2)
	assert_eq(course.snapshots.size(), 3)


func test_two_courses_same_finish_match_tick_tape_and_state() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	_run_finish_after_commit(left)
	_run_finish_after_commit(right)
	assert_eq(left.finish_tick, 1)
	assert_eq(right.finish_tick, 1)
	assert_eq(left.finish_tick, right.finish_tick)
	assert_eq(left.tape.hash_tape().hex_encode(), right.tape.hash_tape().hex_encode())
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.world.tick_index, right.world.tick_index)
	assert_eq(left.tape.size(), 4)
	assert_eq(right.tape.size(), 4)


func test_acceptance_rejects_incomplete_script() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_false(_ok(GrayboxAcceptance.try_run(course, {})))
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), 0)
	assert_eq(course.finish_tick, -1)
	var missing_item: Dictionary = _acceptance_script()
	missing_item.erase("use_item")
	assert_false(_ok(GrayboxAcceptance.try_run(course, missing_item)))
	assert_eq(course.finish_tick, -1)
	assert_false(course.track.is_finished())


func test_acceptance_fails_when_blast_does_not_destroy() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var script: Dictionary = _acceptance_script()
	script["blast_damage"] = 0
	assert_false(_ok(GrayboxAcceptance.try_run(course, script)))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_true(course.world.is_static_box_solid(course.crate_box_id))
	assert_eq(course.finish_tick, -1)
	assert_false(course.track.is_finished())


func test_acceptance_full_run_covers_m1_slice() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var result: Dictionary = GrayboxAcceptance.try_run(course, _acceptance_script())
	assert_true(_ok(result))
	assert_eq(_finish_tick(result), 1)
	assert_eq(course.finish_tick, 1)
	assert_eq(course.finish_tick, course.world.tick_index)
	assert_true(course.track.is_finished())
	assert_true(course.crate.is_destroyed())
	assert_false(course.world.is_static_box_solid(course.crate_box_id))
	assert_false(course.world.is_static_box_solid(course.hazard_box_id))
	assert_eq(course.tape.size(), ACCEPTANCE_TAPE_SIZE)
	assert_eq(course.snapshots.size(), 2)
	assert_eq(course.world.tick_index, 1)
	_assert_system_command(course.tape.command_at(0), SystemOps.PLACE_POSE)
	var wall_cmd: SharedCommand = course.tape.command_at(1)
	var blast_cmd: SharedCommand = course.tape.command_at(5)
	assert_not_null(wall_cmd)
	assert_not_null(blast_cmd)
	var wall_intent: String = wall_cmd.payload.get("intent", "")
	var blast_intent: String = blast_cmd.payload.get("intent", "")
	assert_eq(wall_cmd.kind, SharedCommand.Kind.PLAYER)
	assert_eq(wall_intent, PlayerIntentNames.MOVE)
	assert_eq(blast_intent, PlayerIntentNames.USE_ITEM)
	_assert_system_command(course.tape.command_at(14), SystemOps.ACCEPT_CHECKPOINT)
	_assert_system_command(course.tape.command_at(20), SystemOps.CROSS_FINISH)


func test_two_courses_same_acceptance_match_tape_state_snapshots_and_finish() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	var script: Dictionary = _acceptance_script()
	assert_true(_ok(GrayboxAcceptance.try_run(left, script)))
	assert_true(_ok(GrayboxAcceptance.try_run(right, script)))
	assert_eq(left.finish_tick, right.finish_tick)
	assert_eq(left.finish_tick, 1)
	assert_eq(left.tape.hash_tape().hex_encode(), right.tape.hash_tape().hex_encode())
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.world.tick_index, right.world.tick_index)
	assert_eq(left.snapshots.size(), right.snapshots.size())
	assert_eq(
		left.snapshots.hash_at_tick(0).hex_encode(),
		right.snapshots.hash_at_tick(0).hex_encode()
	)
	assert_eq(
		left.snapshots.hash_at_tick(1).hex_encode(),
		right.snapshots.hash_at_tick(1).hex_encode()
	)
	assert_eq(left.tape.size(), ACCEPTANCE_TAPE_SIZE)
	assert_eq(right.tape.size(), ACCEPTANCE_TAPE_SIZE)


func test_tape_replay_rejects_incomplete_script_dirty_course_and_bad_until() -> void:
	var source: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_run_move_and_commit_sequence(source)
	var dest: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_false(_ok(GrayboxTapeReplay.try_replay(dest, source.tape, {})))
	assert_eq(dest.world.tick_index, 0)
	assert_eq(dest.tape.size(), 0)
	var missing_until: Dictionary = _replay_script(2)
	missing_until.erase("until_tick")
	assert_false(_ok(GrayboxTapeReplay.try_replay(dest, source.tape, missing_until)))
	var negative: Dictionary = _replay_script(-1)
	assert_false(_ok(GrayboxTapeReplay.try_replay(dest, source.tape, negative)))
	assert_true(_ok(_step_intent(dest, _move_payload(_whole(1), 0), 0)))
	assert_false(_ok(GrayboxTapeReplay.try_replay(dest, source.tape, _replay_script(2))))


func test_tape_replay_rejects_shove_and_seed_mismatch() -> void:
	var dest: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var shove_tape: SimReplayBuffer = SimReplayBuffer.new(dest.tape.get_seed())
	var shoved: SharedCommand = SharedCommand.create(
		1,
		ACTOR_ID,
		1,
		0,
		0,
		CONTENT_VERSION,
		{"intent": PlayerIntentNames.SHOVE},
		TRACE_ID,
		SharedCommand.Kind.PLAYER
	)
	assert_not_null(shoved)
	assert_true(shove_tape.append(shoved))
	assert_false(_ok(GrayboxTapeReplay.try_replay(dest, shove_tape, _replay_script(0))))
	assert_eq(dest.tape.size(), 0)
	assert_eq(dest.world.tick_index, 0)
	var source: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_run_move_and_commit_sequence(source)
	var other_layout: Dictionary = _valid_layout()
	other_layout["seed"] = 2
	var other: GrayboxCourse = GrayboxCourse.assemble(other_layout)
	assert_false(_ok(GrayboxTapeReplay.try_replay(other, source.tape, _replay_script(2))))
	assert_eq(other.tape.size(), 0)
	assert_eq(other.world.tick_index, 0)


func test_tape_replay_move_and_commit_matches_source_hashes() -> void:
	var source: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_run_move_and_commit_sequence(source)
	var dest: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(GrayboxTapeReplay.try_replay(dest, source.tape, _replay_script(2))))
	_assert_replay_matches(source, dest)
	assert_eq(dest.tape.size(), 2)
	assert_eq(dest.world.tick_index, 2)
	assert_eq(dest.snapshots.size(), 3)


func test_tape_replay_use_item_destroy_matches_source_hashes() -> void:
	var source: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_run_use_item_destroy_from_start(source)
	var dest: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(GrayboxTapeReplay.try_replay(dest, source.tape, _replay_script(0))))
	_assert_replay_matches(source, dest)
	assert_true(dest.crate.is_destroyed())
	assert_false(dest.world.is_static_box_solid(dest.crate_box_id))
	assert_eq(dest.world.tick_index, 0)
	assert_eq(dest.tape.size(), 1)


func test_two_replays_of_same_tape_match_each_other() -> void:
	var source: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	_run_move_and_commit_sequence(source)
	var left: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var right: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(GrayboxTapeReplay.try_replay(left, source.tape, _replay_script(2))))
	assert_true(_ok(GrayboxTapeReplay.try_replay(right, source.tape, _replay_script(2))))
	_assert_replay_matches(left, right)
	_assert_replay_matches(source, left)


func test_tape_replay_rejects_edit_and_admin() -> void:
	var dest: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var edit_tape: SimReplayBuffer = SimReplayBuffer.new(dest.tape.get_seed())
	var edited: SharedCommand = SharedCommand.create(
		1,
		ACTOR_ID,
		1,
		0,
		0,
		CONTENT_VERSION,
		{"op": SystemOps.PLACE_POSE, "x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		TRACE_ID,
		SharedCommand.Kind.EDIT
	)
	assert_not_null(edited)
	assert_true(edit_tape.append(edited))
	assert_false(_ok(GrayboxTapeReplay.try_replay(dest, edit_tape, _replay_script(0))))
	assert_eq(dest.tape.size(), 0)
	var admin_tape: SimReplayBuffer = SimReplayBuffer.new(dest.tape.get_seed())
	var admined: SharedCommand = SharedCommand.create(
		1,
		ACTOR_ID,
		1,
		0,
		0,
		CONTENT_VERSION,
		{"op": SystemOps.CROSS_FINISH},
		TRACE_ID,
		SharedCommand.Kind.ADMIN
	)
	assert_not_null(admined)
	assert_true(admin_tape.append(admined))
	assert_false(_ok(GrayboxTapeReplay.try_replay(dest, admin_tape, _replay_script(0))))
	assert_eq(dest.tape.size(), 0)
	assert_eq(dest.world.tick_index, 0)


func test_tape_replay_acceptance_matches_source_hashes() -> void:
	var source: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(GrayboxAcceptance.try_run(source, _acceptance_script())))
	assert_eq(source.tape.size(), ACCEPTANCE_TAPE_SIZE)
	var dest: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(GrayboxTapeReplay.try_replay(dest, source.tape, _replay_script(1))))
	_assert_replay_matches(source, dest)
	assert_eq(dest.finish_tick, source.finish_tick)
	assert_eq(dest.finish_tick, 1)
	assert_eq(dest.tape.size(), ACCEPTANCE_TAPE_SIZE)
	assert_eq(dest.world.tick_index, 1)
	assert_true(dest.track.is_finished())
	assert_true(dest.crate.is_destroyed())
	assert_false(dest.world.is_static_box_solid(dest.crate_box_id))
	assert_false(dest.world.is_static_box_solid(dest.hazard_box_id))


func test_tape_replay_break_crate_matches_source_hashes() -> void:
	var source: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(source.try_break_crate(CRATE_MAX_HEALTH)))
	assert_eq(source.tape.size(), 1)
	_assert_system_command(source.tape.command_at(0), SystemOps.BREAK_CRATE)
	var dest: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(GrayboxTapeReplay.try_replay(dest, source.tape, _replay_script(0))))
	_assert_replay_matches(source, dest)
	assert_true(dest.crate.is_destroyed())
	assert_false(dest.world.is_static_box_solid(dest.crate_box_id))
	assert_eq(dest.tape.size(), 1)
	assert_eq(dest.world.tick_index, 0)


func test_tape_replay_out_of_range_reset_matches_source_hashes() -> void:
	var source: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(source.try_place_pose(_start_x(), -_whole(2), 0, START_YAW))
	var reset_result: Dictionary = source.try_reset_if_out_of_range(
		0,
		_wide_max(),
		_wide_min(),
		_wide_max(),
		_wide_min(),
		_wide_max()
	)
	assert_true(_ok(reset_result))
	assert_true(_reset_flag(reset_result))
	assert_eq(source.tape.size(), 2)
	_assert_system_command(source.tape.command_at(0), SystemOps.PLACE_POSE)
	_assert_system_command(source.tape.command_at(1), SystemOps.RESET_IF_OUT_OF_RANGE)
	_assert_pose(source, _start_x(), 0, 0, START_YAW)
	var dest: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(GrayboxTapeReplay.try_replay(dest, source.tape, _replay_script(0))))
	_assert_replay_matches(source, dest)
	_assert_pose(dest, _start_x(), 0, 0, START_YAW)
	assert_eq(dest.tape.size(), 2)
	assert_eq(dest.world.tick_index, 0)


func _run_finish_after_commit(course: GrayboxCourse) -> void:
	_accept_ordered_checkpoints(course)
	assert_true(course.try_commit_tick(0))
	_set_pose_on_finish(course)
	var crossed: Dictionary = course.try_cross_finish()
	assert_true(_ok(crossed))
	assert_eq(_finish_tick(crossed), 1)
	assert_eq(course.finish_tick, 1)
	assert_eq(course.finish_tick, course.world.tick_index)
	assert_eq(course.tape.size(), 4)
	assert_eq(course.world.tick_index, 1)
	assert_eq(course.snapshots.size(), 2)


func _run_move_and_commit_sequence(course: GrayboxCourse) -> void:
	assert_true(_ok(_step_intent(course, _move_payload(_whole(1), 0), 0)))
	_assert_pose(course, _start_x() + _whole(1), 0, 0, START_YAW)
	assert_true(course.try_commit_tick(0))
	assert_true(_ok(_step_intent(course, _move_payload(_whole(1), 0), 0)))
	_assert_pose(course, _start_x() + _whole(2), 0, 0, START_YAW)
	assert_true(course.try_commit_tick(0))
	assert_eq(course.world.tick_index, 2)
	assert_eq(course.tape.size(), 2)
	assert_eq(course.snapshots.size(), 3)


func _run_tape_hash_sequence(course: GrayboxCourse) -> void:
	var oracle: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var contrast: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var wall_dx: int = _wall_dx()
	var open_dx: int = _whole(1)
	assert_false(contrast.world.try_move_xz(contrast.entity_id, wall_dx, 0))
	_assert_pose(contrast, _start_x(), 0, 0, START_YAW)
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, wall_dx, 0))
	var blocked: Dictionary = _step_intent(course, _move_payload(wall_dx, 0), 0)
	assert_true(_ok(blocked))
	_assert_course_matches(course, oracle)
	assert_true(oracle.world.try_move_xz_until_blocked(oracle.entity_id, open_dx, 0))
	var passed: Dictionary = _step_intent(course, _move_payload(open_dx, 0), 0)
	assert_true(_ok(passed))
	_assert_course_matches(course, oracle)


func _run_interact_on_crate(course: GrayboxCourse) -> void:
	_set_pose_on_crate(course)
	var broken: Dictionary = course.try_interact(_interact_payload(), CRATE_MAX_HEALTH)
	assert_true(_ok(broken))
	assert_true(_destroyed(broken))
	assert_eq(course.crate.current_health(), 0)


func _run_use_item_destroy_from_start(course: GrayboxCourse) -> void:
	var broken: Dictionary = course.try_use_item(_use_item_payload(), CRATE_MAX_HEALTH, 0, 0, _crate_z())
	assert_true(_ok(broken))
	assert_true(_destroyed(broken))
	assert_eq(course.crate.current_health(), 0)
	_assert_pose(course, _start_x(), 0, 0, START_YAW)


func _acceptance_script() -> Dictionary:
	return {
		"jump_dy": 0,
		"support_dy": 0,
		"fall_dy": 0,
		"blast_damage": CRATE_MAX_HEALTH,
		"reach_dx": 0,
		"reach_dy": 0,
		"reach_dz": _crate_z(),
		"max_hops": MAX_HOPS,
		"up_portal_id": UP_SOURCE_ID,
		"side_portal_id": SIDE_SOURCE_ID,
		"checkpoint_a": CHECKPOINT_A,
		"checkpoint_b": CHECKPOINT_B,
		"checkpoint_c": CHECKPOINT_C,
		"wall_move": _move_payload(_wall_dx(), 0),
		"crate_move": _move_payload(0, _crate_dz()),
		"hazard_move": _move_payload(_hazard_dx(), 0),
		"use_item": _use_item_payload(),
		"start_pose": {
			"x": _start_x(),
			"y": 0,
			"z": 0,
			"yaw_bam": START_YAW,
		},
		"finish_pose": {
			"x": _start_x(),
			"y": 0,
			"z": _finish_z(),
			"yaw_bam": START_YAW,
		},
	}


func _replay_script(until_tick: int) -> Dictionary:
	return {
		"jump_dy": 0,
		"support_dy": 0,
		"fall_dy": 0,
		"interact_damage": CRATE_MAX_HEALTH,
		"use_item_damage": CRATE_MAX_HEALTH,
		"reach_dx": 0,
		"reach_dy": 0,
		"reach_dz": _crate_z(),
		"until_tick": until_tick,
	}


func _assert_replay_matches(left: GrayboxCourse, right: GrayboxCourse) -> void:
	assert_eq(left.tape.hash_tape().hex_encode(), right.tape.hash_tape().hex_encode())
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_eq(left.world.tick_index, right.world.tick_index)
	assert_eq(left.snapshots.size(), right.snapshots.size())
	var tick: int = 0
	while tick <= left.world.tick_index:
		assert_eq(
			left.snapshots.hash_at_tick(tick).hex_encode(),
			right.snapshots.hash_at_tick(tick).hex_encode()
		)
		tick += 1


func _run_shared_sequence(course: GrayboxCourse) -> void:
	assert_true(_ok(_step_intent(course, _move_payload(_wall_dx(), 0), 0)))
	assert_true(_ok(_step_intent(course, _move_payload(0, _crate_dz()), 0)))
	assert_true(_ok(course.try_break_crate(CRATE_MAX_HEALTH)))
	assert_true(_ok(_step_intent(course, _move_payload(0, _crate_dz()), 0)))
	assert_false(course.try_accept_checkpoint(CHECKPOINT_B))
	assert_false(_ok(course.try_land_portal(UP_SOURCE_ID, CHECKPOINT_B, MAX_HOPS)))
	_set_pose(course, _start_x(), 0, 0, START_YAW)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_A))
	assert_true(_ok(course.try_land_portal(UP_SOURCE_ID, CHECKPOINT_B, MAX_HOPS)))
	assert_true(course.try_accept_checkpoint(CHECKPOINT_B))
	assert_true(_ok(course.try_land_portal(SIDE_SOURCE_ID, CHECKPOINT_C, MAX_HOPS)))
	assert_true(course.try_accept_checkpoint(CHECKPOINT_C))


func _valid_layout() -> Dictionary:
	var start_x: int = _start_x()
	var start_y: int = 0
	var start_z: int = 0
	var radius: int = _whole(1)
	var cylinder_height: int = _whole(2)
	var half: int = _whole(1)
	return {
		"seed": 1,
		"actor_id": ACTOR_ID,
		"content_version": CONTENT_VERSION,
		"trace_id": TRACE_ID,
		"snapshot_capacity": SNAPSHOT_CAPACITY,
		"start_x": start_x,
		"start_y": start_y,
		"start_z": start_z,
		"start_yaw": START_YAW,
		"radius": radius,
		"cylinder_height": cylinder_height,
		"wall": {
			"x": 0,
			"y": 0,
			"z": 0,
			"half_x": half,
			"half_y": half,
			"half_z": _whole(20),
		},
		"crate": {
			"x": start_x,
			"y": 0,
			"z": _crate_z(),
			"half_x": half,
			"half_y": half,
			"half_z": half,
		},
		"hazard": {
			"x": start_x + _hazard_dx(),
			"y": 0,
			"z": 0,
			"half_x": half,
			"half_y": half,
			"half_z": half,
		},
		"hazard_period_ticks": HAZARD_PERIOD_TICKS,
		"crate_max_health": CRATE_MAX_HEALTH,
		"finish": _pad_box(start_x, 0, _finish_z()),
		"checkpoint_ids": [CHECKPOINT_A, CHECKPOINT_B, CHECKPOINT_C],
		"checkpoint_pads": [
			_pad_box(start_x, 0, 0),
			_pad_box(start_x, _up_dest_y(), 0),
			_pad_box(start_x, 0, _side_dest_z()),
		],
		"spawn_start": {
			"x": start_x,
			"y": start_y,
			"z": start_z,
			"yaw_bam": START_YAW,
		},
		"checkpoint_poses": [
			{"x": start_x, "y": 0, "z": 0, "yaw_bam": START_YAW},
			{"x": start_x, "y": _up_dest_y(), "z": 0, "yaw_bam": 0},
			{"x": start_x, "y": 0, "z": _side_dest_z(), "yaw_bam": START_YAW},
		],
		"up_portal": {
			"source_id": UP_SOURCE_ID,
			"dest_id": 2,
			"x": start_x,
			"y": _up_dest_y(),
			"z": 0,
			"dest_yaw_bam": 0,
		},
		"side_portal": {
			"source_id": SIDE_SOURCE_ID,
			"dest_id": 4,
			"x": start_x,
			"y": 0,
			"z": _side_dest_z(),
			"dest_yaw_bam": START_YAW,
		},
	}


func _interact_payload(
	decoy_x: int = 0,
	decoy_y: int = 0,
	decoy_z: int = 0,
	destroyed: bool = false
) -> Dictionary:
	return {
		"intent": PlayerIntentNames.INTERACT,
		"x": decoy_x,
		"y": decoy_y,
		"z": decoy_z,
		"destroyed": destroyed,
	}


func _use_item_payload(
	decoy_x: int = 0,
	decoy_y: int = 0,
	decoy_z: int = 0,
	item_id: int = 0,
	hit: bool = false,
	destroyed: bool = false,
	damage: int = 0
) -> Dictionary:
	return {
		"intent": PlayerIntentNames.USE_ITEM,
		"item_id": item_id,
		"x": decoy_x,
		"y": decoy_y,
		"z": decoy_z,
		"hit": hit,
		"destroyed": destroyed,
		"damage": damage,
	}


func _move_payload(dx: int, dz: int, decoy_x: int = 0, decoy_y: int = 0, decoy_z: int = 0) -> Dictionary:
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
		"x": decoy_x,
		"y": decoy_y,
		"z": decoy_z,
	}


func _start_x() -> int:
	return _whole(4)


func _wall_dx() -> int:
	return -_whole(2)


func _crate_dz() -> int:
	return _whole(10)


func _crate_z() -> int:
	return _whole(5)


func _hazard_dx() -> int:
	return _whole(6)


func _up_dest_y() -> int:
	return _whole(8)


func _side_dest_z() -> int:
	return _whole(20)


func _finish_z() -> int:
	return _whole(30)


func _pad_box(x: int, y: int, z: int) -> Dictionary:
	var half: int = _whole(1)
	return {
		"x": x,
		"y": y,
		"z": z,
		"half_x": half,
		"half_y": half,
		"half_z": half,
	}


func _set_pose_on_crate(course: GrayboxCourse) -> void:
	_set_pose(course, _start_x(), 0, _crate_z(), START_YAW)


func _set_pose_on_finish(course: GrayboxCourse) -> void:
	_set_pose(course, _start_x(), 0, _finish_z(), START_YAW)


func _accept_ordered_checkpoints(course: GrayboxCourse) -> void:
	_set_pose(course, _start_x(), 0, 0, START_YAW)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_A))
	_set_pose(course, _start_x(), _up_dest_y(), 0, 0)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_B))
	_set_pose(course, _start_x(), 0, _side_dest_z(), START_YAW)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_C))
	assert_true(course.track.is_finished())


func _set_pose(course: GrayboxCourse, x: int, y: int, z: int, yaw: int) -> void:
	assert_true(course.world.set_pose(course.entity_id, x, y, z, yaw))


func _assert_pose(course: GrayboxCourse, x: int, y: int, z: int, yaw: int) -> void:
	var pose: Dictionary = course.world.get_pose(course.entity_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	var pose_yaw: int = pose.get("yaw", -1)
	assert_eq(pose_x, x)
	assert_eq(pose_y, y)
	assert_eq(pose_z, z)
	assert_eq(pose_yaw, yaw)


func _assert_course_matches(course: GrayboxCourse, oracle: GrayboxCourse) -> void:
	var expected: Dictionary = oracle.world.get_pose(oracle.entity_id)
	var x: int = expected.get("x", -1)
	var y: int = expected.get("y", -1)
	var z: int = expected.get("z", -1)
	var yaw: int = expected.get("yaw", -1)
	_assert_pose(course, x, y, z, yaw)


func _assert_system_command(command: SharedCommand, op_name: String) -> void:
	assert_not_null(command)
	assert_eq(command.kind, SharedCommand.Kind.SYSTEM)
	assert_eq(command.actor_id, 0)
	var op: String = command.payload.get("op", "")
	assert_eq(op, op_name)


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _reset_flag(result: Dictionary) -> bool:
	var flag: bool = result.get("reset", false)
	return flag


func _wide_min() -> int:
	return -_whole(100)


func _wide_max() -> int:
	return _whole(100)


func _reset_wide(course: GrayboxCourse) -> Dictionary:
	return course.try_reset_if_out_of_range(
		_wide_min(),
		_wide_max(),
		_wide_min(),
		_wide_max(),
		_wide_min(),
		_wide_max()
	)


func _step_intent(
	course: GrayboxCourse,
	payload: Dictionary,
	jump_dy: int,
	support_dy: int = 0
) -> Dictionary:
	return course.try_step_intent(payload, jump_dy, support_dy)


func _destroyed(result: Dictionary) -> bool:
	var flag: bool = result.get("destroyed", false)
	return flag


func _landed(result: Dictionary) -> bool:
	var flag: bool = result.get("landed", false)
	return flag


func _health(result: Dictionary) -> int:
	var remaining: int = result.get("health", -1)
	return remaining


func _finish_tick(result: Dictionary) -> int:
	var tick: int = result.get("finish_tick", -2)
	return tick


func _dup_dict(raw: Variant) -> Dictionary:
	var source: Dictionary = raw
	return source.duplicate()


func _whole(units: int) -> int:
	var converted: FixedResultClass = FixedClass.try_from_whole(units)
	assert_true(converted.ok)
	return converted.value
