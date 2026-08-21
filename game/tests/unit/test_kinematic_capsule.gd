extends GutTest

## 直立胶囊：轴线平行世界 Y。接触（闭区间）算重叠；定点溢出视为不重叠。

const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const FixedResultClass := preload("res://src/shared/fixed/fixed_result.gd")
const KinematicCapsule := preload("res://src/simulation/kinematic_capsule.gd")


func test_concentric_capsules_overlap() -> void:
	var left: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	var right: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	assert_true(left.overlaps(right))
	assert_true(left.overlap_math_ok)


func test_x_separation_closed_contact_overlaps_then_one_unit_clears() -> void:
	var radius: int = _whole(1)
	var left: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	var touching: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	touching.x = radius + radius
	assert_true(left.overlaps(touching))
	assert_true(left.overlap_math_ok)
	var separated: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	separated.x = touching.x + 1
	assert_false(left.overlaps(separated))
	assert_true(left.overlap_math_ok)


func test_y_separation_closed_contact_overlaps_then_one_unit_clears() -> void:
	var radius: int = _whole(1)
	var cylinder_height: int = _whole(2)
	var half_height: int = cylinder_height / 2
	var contact_y: int = half_height + half_height + radius + radius
	var lower: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	var touching: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	touching.y = contact_y
	assert_true(lower.overlaps(touching))
	assert_true(lower.overlap_math_ok)
	var separated: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	separated.y = contact_y + 1
	assert_false(lower.overlaps(separated))
	assert_true(lower.overlap_math_ok)


func test_overflow_is_not_overlap_and_is_observable() -> void:
	var left: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	var right: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	left.x = FixedClass.INT64_MAX
	right.x = FixedClass.INT64_MIN
	assert_false(left.overlaps(right))
	assert_false(left.overlap_math_ok)


func _whole(units: int) -> int:
	var converted: FixedResultClass = FixedClass.try_from_whole(units)
	assert_true(converted.ok)
	return converted.value


func _upright(x_whole: int, y_whole: int, z_whole: int, radius_whole: int, height_whole: int) -> KinematicCapsule:
	var capsule: KinematicCapsule = KinematicCapsule.new()
	capsule.x = _whole(x_whole)
	capsule.y = _whole(y_whole)
	capsule.z = _whole(z_whole)
	capsule.radius = _whole(radius_whole)
	capsule.cylinder_height = _whole(height_whole)
	return capsule
