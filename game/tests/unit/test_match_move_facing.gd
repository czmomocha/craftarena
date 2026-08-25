extends GutTest

## MatchMoveFacing: 8-way discrete yaw_bam from WASD dx/dz signs.
## W is world -Z at 0. Dual-zero is omitted. Not atan2.

const MatchMoveFacing := preload("res://src/client/match_move_facing.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const STEP: int = 16


func test_bam_table_matches_fixed_quarters() -> void:
	assert_eq(MatchMoveFacing.YAW_OMITTED, -1)
	assert_eq(MatchMoveFacing.YAW_FORWARD, 0)
	assert_eq(MatchMoveFacing.YAW_FORWARD_LEFT, Fixed.BAM_TURN / 8)
	assert_eq(MatchMoveFacing.YAW_LEFT, Fixed.BAM_QUARTER)
	assert_eq(MatchMoveFacing.YAW_BACK, Fixed.BAM_TURN / 2)
	assert_eq(MatchMoveFacing.YAW_RIGHT, Fixed.BAM_TURN - Fixed.BAM_QUARTER)
	assert_eq(MatchMoveFacing.YAW_FORWARD_RIGHT, Fixed.BAM_TURN - Fixed.BAM_TURN / 8)


func test_eight_way_table_and_zero_is_forward_not_omitted() -> void:
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(0, 0), MatchMoveFacing.YAW_OMITTED)
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(0, -STEP), MatchMoveFacing.YAW_FORWARD)
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(-STEP, -STEP), MatchMoveFacing.YAW_FORWARD_LEFT)
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(-STEP, 0), MatchMoveFacing.YAW_LEFT)
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(-STEP, STEP), MatchMoveFacing.YAW_BACK_LEFT)
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(0, STEP), MatchMoveFacing.YAW_BACK)
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(STEP, STEP), MatchMoveFacing.YAW_BACK_RIGHT)
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(STEP, 0), MatchMoveFacing.YAW_RIGHT)
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(STEP, -STEP), MatchMoveFacing.YAW_FORWARD_RIGHT)
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(99, 0), MatchMoveFacing.YAW_RIGHT)
	assert_eq(MatchMoveFacing.yaw_bam_from_dx_dz(-1, -99), MatchMoveFacing.YAW_FORWARD_LEFT)


func test_move_axes_write_yaw_and_cancel_is_empty() -> void:
	var forward: Dictionary = MatchMoveFacing.move_axes(true, false, false, false, STEP)
	var right: Dictionary = MatchMoveFacing.move_axes(false, false, false, true, STEP)
	var diag: Dictionary = MatchMoveFacing.move_axes(true, false, false, true, STEP)
	var cancelled: Dictionary = MatchMoveFacing.move_axes(true, true, false, false, STEP)
	var forward_intent: String = forward.get("intent", "")
	var forward_dx: int = forward.get("dx", -1)
	var forward_dz: int = forward.get("dz", 0)
	var forward_yaw: int = forward.get("yaw_bam", -2)
	var right_dx: int = right.get("dx", 0)
	var right_yaw: int = right.get("yaw_bam", -2)
	var diag_dx: int = diag.get("dx", 0)
	var diag_dz: int = diag.get("dz", 0)
	var diag_yaw: int = diag.get("yaw_bam", -2)
	assert_eq(forward_intent, PlayerIntentNames.MOVE)
	assert_eq(forward_dx, 0)
	assert_eq(forward_dz, -STEP)
	assert_eq(forward_yaw, MatchMoveFacing.YAW_FORWARD)
	assert_eq(right_dx, STEP)
	assert_eq(right_yaw, MatchMoveFacing.YAW_RIGHT)
	assert_eq(diag_dx, STEP)
	assert_eq(diag_dz, -STEP)
	assert_eq(diag_yaw, MatchMoveFacing.YAW_FORWARD_RIGHT)
	assert_true(cancelled.is_empty())
	assert_true(MatchMoveFacing.move_axes(true, false, false, false, 0).is_empty())
