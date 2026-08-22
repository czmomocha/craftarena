extends GutTest

## TraprushGrayboxCourse：单人灰盒跑道夹具。几何、位移、jump_dy、max_hops、max_health 只由调用方传入。
## CD-21 §4.2 / §5.2 与 CD-61 M1：有序检查点、上下/侧向传送、墙阻挡、打掉箱子后开路。
## 不调用 overlaps_static_box 或 world.tick()；不读客户端最终位置；不覆盖 Shove、道具、2p。

const GrayboxCourse := preload("res://src/games/traprush/graybox_course.gd")
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


func test_assemble_exposes_world_ids_track_and_crate() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_not_null(course)
	assert_eq(course.entity_id, 1)
	assert_eq(course.wall_box_id, 1)
	assert_eq(course.crate_box_id, 2)
	assert_eq(course.crate.max_health(), CRATE_MAX_HEALTH)
	assert_eq(course.crate.current_health(), CRATE_MAX_HEALTH)
	assert_false(course.crate.is_destroyed())
	assert_false(course.track.is_finished())
	assert_eq(course.world.tick_index, 0)
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
	assert_false(course.try_accept_checkpoint(CHECKPOINT_B))
	assert_false(course.try_accept_checkpoint(CHECKPOINT_C))
	assert_false(course.track.is_finished())
	assert_true(course.try_accept_checkpoint(CHECKPOINT_A))
	assert_false(course.try_accept_checkpoint(CHECKPOINT_C))
	assert_false(course.track.is_finished())
	assert_true(course.try_accept_checkpoint(CHECKPOINT_B))
	assert_true(course.try_accept_checkpoint(CHECKPOINT_C))
	assert_true(course.track.is_finished())
	assert_false(course.try_accept_checkpoint(CHECKPOINT_A))
	assert_true(course.track.is_finished())


func test_identical_inputs_on_two_worlds_match_hash_finished_and_health() -> void:
	var layout: Dictionary = _valid_layout()
	var left: GrayboxCourse = GrayboxCourse.assemble(layout)
	var right: GrayboxCourse = GrayboxCourse.assemble(layout)
	_run_shared_sequence(left)
	_run_shared_sequence(right)
	assert_eq(left.world.hash_state().hex_encode(), right.world.hash_state().hex_encode())
	assert_true(left.track.is_finished())
	assert_true(right.track.is_finished())
	assert_eq(left.crate.current_health(), 0)
	assert_eq(right.crate.current_health(), 0)
	assert_eq(left.world.tick_index, 0)
	assert_eq(right.world.tick_index, 0)
	assert_eq(left.crate.current_health(), right.crate.current_health())
	assert_eq(left.track.is_finished(), right.track.is_finished())


func test_try_step_intent_does_not_call_tick() -> void:
	var course: GrayboxCourse = GrayboxCourse.assemble(_valid_layout())
	assert_eq(course.world.tick_index, 0)
	assert_true(_ok(course.try_step_intent(_move_payload(0, 0), 0)))
	assert_eq(course.world.tick_index, 0)
	assert_true(_ok(course.try_step_intent({"intent": PlayerIntentNames.JUMP}, _whole(1))))
	assert_eq(course.world.tick_index, 0)
	_assert_pose(course, _start_x(), _whole(1), 0, START_YAW)


func _run_shared_sequence(course: GrayboxCourse) -> void:
	assert_true(_ok(course.try_step_intent(_move_payload(_wall_dx(), 0), 0)))
	assert_true(_ok(course.try_step_intent(_move_payload(0, _crate_dz()), 0)))
	assert_true(_ok(course.try_break_crate(CRATE_MAX_HEALTH)))
	assert_true(_ok(course.try_step_intent(_move_payload(0, _crate_dz()), 0)))
	assert_false(course.try_accept_checkpoint(CHECKPOINT_B))
	assert_false(_ok(course.try_land_portal(UP_SOURCE_ID, CHECKPOINT_B, MAX_HOPS)))
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
			"z": _whole(5),
			"half_x": half,
			"half_y": half,
			"half_z": half,
		},
		"crate_max_health": CRATE_MAX_HEALTH,
		"checkpoint_ids": [CHECKPOINT_A, CHECKPOINT_B, CHECKPOINT_C],
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


func _up_dest_y() -> int:
	return _whole(8)


func _side_dest_z() -> int:
	return _whole(20)


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
