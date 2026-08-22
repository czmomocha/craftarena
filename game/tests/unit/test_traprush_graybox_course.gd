extends GutTest

## TraprushGrayboxCourse：单人灰盒跑道夹具。几何、位移、jump_dy、max_hops、max_health、period、capacity、interact/use-item damage 与 reach 只由调用方传入。
## CD-21 §4.2 / §5.2 / §8 与 CD-61 M1：有序检查点、占用垫盒、上下/侧向传送、墙阻挡、打掉箱子后开路、周期 hazard stub、爆破道具 stub。
## 成功 PLAYER 意图写入 SimReplayBuffer（CD-43）；磁带不回放进 world。
## assemble 记录 tick 0 关键快照；try_commit_tick 推进 tick 并按调用方周期切换 hazard 阻挡。
## try_step_intent / try_interact / try_use_item 成功入带；打箱 / 传送 / 检查点不 tick、不 record。
## try_interact 要求 overlapping_static_boxes 含 crate；测试用 world.set_pose 挪到箱心，course API 不自动传送。
## try_use_item 用当前姿态加调用方 reach 做 overlapping_static_boxes_at；测试站在起点，reach 指向 _crate_z，不 set_pose 到箱上。
## 不读客户端最终位置、障碍死亡、道具命中或完成标志；不覆盖道具栏、2p。

const GrayboxCourse := preload("res://src/games/traprush/graybox_course.gd")
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
	var wall_dx: int = _wall_dx()
	var crate_dz: int = _crate_dz()
	var wall_move: Dictionary = course.try_step_intent(_move_payload(wall_dx, 0), 0)
	assert_true(_ok(wall_move))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	var crate_blocked: Dictionary = course.try_step_intent(
		_move_payload(0, crate_dz, 999, 888, 777),
		0
	)
	assert_true(_ok(crate_blocked))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	var zero_damage: Dictionary = course.try_break_crate(0)
	assert_false(_ok(zero_damage))
	assert_false(zero_damage.has("destroyed"))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	var still_blocked: Dictionary = course.try_step_intent(_move_payload(0, crate_dz), 0)
	assert_true(_ok(still_blocked))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	var nick: Dictionary = course.try_break_crate(1)
	assert_true(_ok(nick))
	assert_false(_destroyed(nick))
	assert_eq(_health(nick), CRATE_MAX_HEALTH - 1)
	assert_false(course.crate.is_destroyed())
	var nicked_blocked: Dictionary = course.try_step_intent(_move_payload(0, crate_dz), 0)
	assert_true(_ok(nicked_blocked))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	var broken: Dictionary = course.try_break_crate(CRATE_MAX_HEALTH - 1)
	assert_true(_ok(broken))
	assert_true(_destroyed(broken))
	assert_eq(course.crate.current_health(), 0)
	assert_true(course.crate.is_destroyed())
	var passed: Dictionary = course.try_step_intent(
		_move_payload(0, crate_dz, 999, 888, 777),
		0
	)
	assert_true(_ok(passed))
	_assert_pose(course, _start_x(), 0, crate_dz, START_YAW)
	var wall_still: Dictionary = course.try_step_intent(_move_payload(wall_dx, 0), 0)
	assert_true(_ok(wall_still))
	_assert_pose(course, _start_x(), 0, crate_dz, START_YAW)
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
	assert_false(_ok(course.try_step_intent({}, 0)))
	assert_eq(course.tape.size(), 0)
	assert_false(_ok(course.try_step_intent({"intent": PlayerIntentNames.MOVE}, 0)))
	assert_eq(course.tape.size(), 0)
	assert_false(_ok(course.try_step_intent({"intent": PlayerIntentNames.SHOVE}, 0)))
	assert_eq(course.tape.size(), 0)
	assert_true(_ok(course.try_step_intent(_move_payload(0, 0), 0)))
	assert_eq(course.tape.size(), 1)
	var recorded: SharedCommand = course.tape.command_at(0)
	assert_not_null(recorded)
	assert_eq(recorded.command_id, 1)
	assert_eq(recorded.sequence, 1)
	assert_eq(recorded.actor_id, ACTOR_ID)
	assert_eq(recorded.kind, SharedCommand.Kind.PLAYER)
	assert_eq(course.world.tick_index, 0)


func test_crate_portal_checkpoint_do_not_append_to_tape() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_true(_ok(course.try_step_intent(_move_payload(_wall_dx(), 0), 0)))
	assert_eq(course.tape.size(), 1)
	assert_true(_ok(course.try_break_crate(1)))
	assert_eq(course.tape.size(), 1)
	assert_false(_ok(course.try_land_portal(UP_SOURCE_ID, CHECKPOINT_B, MAX_HOPS)))
	assert_eq(course.tape.size(), 1)
	assert_true(course.try_accept_checkpoint(CHECKPOINT_A))
	assert_eq(course.tape.size(), 1)
	assert_true(_ok(course.try_land_portal(UP_SOURCE_ID, CHECKPOINT_B, MAX_HOPS)))
	assert_eq(course.tape.size(), 1)
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
	assert_true(_ok(course.try_step_intent(_move_payload(0, 0), 0)))
	assert_eq(course.world.tick_index, 0)
	assert_true(_ok(course.try_step_intent({"intent": PlayerIntentNames.JUMP}, _whole(1))))
	assert_eq(course.world.tick_index, 0)
	_assert_pose(course, _start_x(), _whole(1), 0, START_YAW)


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
	assert_true(_ok(course.try_step_intent(_move_payload(_whole(1), 0), 0)))
	_assert_pose(course, _start_x() + _whole(1), 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	assert_ne(course.world.hash_state().hex_encode(), tick0_hex)
	assert_eq(course.snapshots.hash_at_tick(0).hex_encode(), tick0_hex)


func test_period_one_hazard_toggles_plus_x_blocking_on_commit() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var dx: int = _hazard_dx()
	var tape_before: int = course.tape.size()
	var blocked: Dictionary = course.try_step_intent(_move_payload(dx, 0), 0)
	assert_true(_ok(blocked))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.tape.size(), tape_before + 1)
	assert_true(course.try_commit_tick())
	assert_eq(course.world.tick_index, 1)
	assert_eq(course.tape.size(), tape_before + 1)
	assert_eq(course.snapshots.size(), 2)
	var opened: Dictionary = course.try_step_intent(_move_payload(dx, 0), 0)
	assert_true(_ok(opened))
	_assert_pose(course, _start_x() + dx, 0, 0, START_YAW)
	assert_eq(course.world.tick_index, 1)
	assert_true(course.try_commit_tick())
	assert_eq(course.world.tick_index, 2)
	assert_eq(course.tape.size(), tape_before + 2)
	var reblocked: Dictionary = course.try_step_intent(_move_payload(dx, 0), 0)
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
	assert_true(course.try_commit_tick())
	assert_true(course.try_commit_tick())
	assert_eq(course.world.tick_index, 2)
	assert_eq(course.snapshots.size(), 2)
	assert_eq(course.snapshots.hash_at_tick(0).size(), 0)
	assert_ne(course.snapshots.hash_at_tick(1).size(), 0)
	assert_ne(course.snapshots.hash_at_tick(2).size(), 0)
	assert_true(course.try_commit_tick())
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
	assert_true(_ok(course.try_step_intent(_move_payload(0, 0), 0)))
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
	var crate_dz: int = _crate_dz()
	var blocked: Dictionary = course.try_step_intent(_move_payload(0, crate_dz), 0)
	assert_true(_ok(blocked))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
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
	var passed: Dictionary = course.try_step_intent(_move_payload(0, crate_dz), 0)
	assert_true(_ok(passed))
	_assert_pose(course, _start_x(), 0, crate_dz, START_YAW)
	assert_eq(course.world.tick_index, 0)
	assert_eq(course.snapshots.size(), 1)
	assert_eq(course.tape.size(), 3)


func test_try_break_crate_still_ignores_overlap_and_does_not_append() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	var nicked: Dictionary = course.try_break_crate(1)
	assert_true(_ok(nicked))
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH - 1)
	assert_eq(course.tape.size(), 0)
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
	assert_true(_ok(course.try_step_intent(_move_payload(0, 0), 0)))
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
	var crate_dz: int = _crate_dz()
	var blocked: Dictionary = course.try_step_intent(_move_payload(0, crate_dz), 0)
	assert_true(_ok(blocked))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
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
	var passed: Dictionary = course.try_step_intent(_move_payload(0, crate_dz), 0)
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
	assert_false(empty.try_commit_tick())
	var missing_world: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	missing_world.world = null
	assert_false(missing_world.try_commit_tick())
	var missing_ring: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	missing_ring.snapshots = null
	assert_false(missing_ring.try_commit_tick())
	assert_eq(missing_ring.world.tick_index, 0)


func _run_move_and_commit_sequence(course: GrayboxCourse) -> void:
	assert_true(_ok(course.try_step_intent(_move_payload(_whole(1), 0), 0)))
	_assert_pose(course, _start_x() + _whole(1), 0, 0, START_YAW)
	assert_true(course.try_commit_tick())
	assert_true(_ok(course.try_step_intent(_move_payload(_whole(1), 0), 0)))
	_assert_pose(course, _start_x() + _whole(2), 0, 0, START_YAW)
	assert_true(course.try_commit_tick())
	assert_eq(course.world.tick_index, 2)
	assert_eq(course.tape.size(), 2)
	assert_eq(course.snapshots.size(), 3)


func _run_tape_hash_sequence(course: GrayboxCourse) -> void:
	var blocked: Dictionary = course.try_step_intent(_move_payload(_wall_dx(), 0), 0)
	assert_true(_ok(blocked))
	_assert_pose(course, _start_x(), 0, 0, START_YAW)
	var passed: Dictionary = course.try_step_intent(_move_payload(_whole(1), 0), 0)
	assert_true(_ok(passed))
	_assert_pose(course, _start_x() + _whole(1), 0, 0, START_YAW)


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


func _run_shared_sequence(course: GrayboxCourse) -> void:
	assert_true(_ok(course.try_step_intent(_move_payload(_wall_dx(), 0), 0)))
	assert_true(_ok(course.try_step_intent(_move_payload(0, _crate_dz()), 0)))
	assert_true(_ok(course.try_break_crate(CRATE_MAX_HEALTH)))
	assert_true(_ok(course.try_step_intent(_move_payload(0, _crate_dz()), 0)))
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


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _destroyed(result: Dictionary) -> bool:
	var flag: bool = result.get("destroyed", false)
	return flag


func _landed(result: Dictionary) -> bool:
	var flag: bool = result.get("landed", false)
	return flag


func _health(result: Dictionary) -> int:
	var remaining: int = result.get("health", -1)
	return remaining


func _dup_dict(raw: Variant) -> Dictionary:
	var source: Dictionary = raw
	return source.duplicate()


func _whole(units: int) -> int:
	var converted: FixedResultClass = FixedClass.try_from_whole(units)
	assert_true(converted.ok)
	return converted.value
