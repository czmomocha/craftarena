extends GutTest

## 可玩性深化 轨 1：传送 / 复位那一帧的跟随相机跳变滑行。
## 强断言写在状态机上（它是逻辑，不是占位色板）；节点与颜色只烟测。

const TransitionGd := preload("res://src/shared/camera_follow_transition.gd")


func _far() -> Vector3:
	return Vector3(0.0, 0.0, PlaceholderSpec.CAMERA_TELEPORT_SNAP_M + 5.0)


func test_first_target_snaps_without_gliding() -> void:
	var transition: CameraFollowTransition = TransitionGd.new()
	assert_false(transition.has_anchor(), "未认过目标时不该有锚点")
	assert_false(transition.track(Vector3(3.0, 0.0, 4.0)), "首个目标不开滑行")
	assert_true(transition.has_anchor())
	assert_false(transition.active)
	assert_eq(transition.anchor, Vector3(3.0, 0.0, 4.0))


func test_small_steps_track_exactly() -> void:
	var transition: CameraFollowTransition = TransitionGd.new()
	transition.snap_to(Vector3.ZERO)
	# 一帧最大的合法位移是冲刺 1 格 = 1 米，远小于跳变阈值。
	assert_false(transition.track(Vector3(1.0, 0.0, 0.0)))
	assert_false(transition.active, "常态跟随不得引入滑行延迟")
	assert_eq(transition.anchor, Vector3(1.0, 0.0, 0.0))
	assert_false(transition.track(Vector3(2.0, 0.0, 0.0)))
	assert_eq(transition.anchor, Vector3(2.0, 0.0, 0.0))


func test_teleport_opens_a_glide_and_lands_on_target() -> void:
	var transition: CameraFollowTransition = TransitionGd.new()
	transition.snap_to(Vector3.ZERO)
	assert_true(transition.track(_far()), "跳变必须开滑行并让壳清掉平移量")
	assert_true(transition.active)
	assert_eq(transition.anchor, Vector3.ZERO, "滑行起点是旧锚点，不是新目标")
	assert_eq(transition.progress(), 0.0)
	var half: float = PlaceholderSpec.CAMERA_TELEPORT_GLIDE_S / 2.0
	assert_true(transition.advance(half), "半程仍在滑行")
	assert_gt(transition.anchor.z, 0.0)
	assert_lt(transition.anchor.z, _far().z)
	assert_false(transition.advance(PlaceholderSpec.CAMERA_TELEPORT_GLIDE_S), "超时必须收尾")
	assert_false(transition.active)
	assert_eq(transition.anchor, _far())


func test_glide_retargets_without_restarting_on_small_moves() -> void:
	var transition: CameraFollowTransition = TransitionGd.new()
	transition.snap_to(Vector3.ZERO)
	transition.track(_far())
	transition.advance(PlaceholderSpec.CAMERA_TELEPORT_GLIDE_S / 2.0)
	var moved: Vector3 = _far() + Vector3(0.5, 0.0, 0.0)
	assert_false(transition.track(moved), "滑行中的小位移只改终点，不重开滑行")
	assert_true(transition.active)
	assert_almost_eq(transition.progress(), 0.5, 0.01)


func test_second_teleport_during_glide_restarts_from_current_anchor() -> void:
	var transition: CameraFollowTransition = TransitionGd.new()
	transition.snap_to(Vector3.ZERO)
	transition.track(_far())
	transition.advance(PlaceholderSpec.CAMERA_TELEPORT_GLIDE_S / 2.0)
	var mid: Vector3 = transition.anchor
	assert_true(transition.track(_far() * 4.0), "滑行中再被传送，重新开一段")
	assert_eq(transition.anchor, mid, "新滑行从当前机位起，不回跳")
	assert_eq(transition.progress(), 0.0)


func test_reset_forgets_anchor_so_next_target_snaps() -> void:
	var transition: CameraFollowTransition = TransitionGd.new()
	transition.snap_to(_far())
	transition.reset()
	assert_false(transition.has_anchor())
	assert_eq(transition.anchor, Vector3.ZERO)
	assert_false(transition.track(_far()), "离局后重新入局直接就位")
	assert_false(transition.active)


func test_ease_out_is_monotonic_and_bounded() -> void:
	assert_eq(TransitionGd.ease_out(0.0), 0.0)
	assert_eq(TransitionGd.ease_out(1.0), 1.0)
	assert_eq(TransitionGd.ease_out(-3.0), 0.0)
	assert_eq(TransitionGd.ease_out(9.0), 1.0)
	assert_gt(TransitionGd.ease_out(0.5), 0.5, "缓出：前半程走得比线性快")


func test_advance_without_active_glide_is_a_no_op() -> void:
	var transition: CameraFollowTransition = TransitionGd.new()
	transition.snap_to(Vector3(1.0, 2.0, 3.0))
	assert_false(transition.advance(1.0))
	assert_eq(transition.anchor, Vector3(1.0, 2.0, 3.0))
