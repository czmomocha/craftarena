extends GutTest

## 静态 AABB：中心加非负半长。接触（闭区间）算重叠；定点溢出视为不重叠。

const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const FixedResultClass := preload("res://src/shared/fixed/fixed_result.gd")
const KinematicCapsule := preload("res://src/simulation/kinematic_capsule.gd")
const StaticAabb := preload("res://src/simulation/static_aabb.gd")


func test_x_face_closed_contact_overlaps_then_one_unit_clears() -> void:
	var radius: int = _whole(1)
	var box: StaticAabb = _box(0, 0, 0, 1, 1, 1)
	var touching: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	touching.x = _whole(1) + radius
	assert_true(box.overlaps_capsule(touching))
	assert_true(box.overlap_math_ok)
	var separated: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	separated.x = touching.x + 1
	assert_false(box.overlaps_capsule(separated))
	assert_true(box.overlap_math_ok)


func test_y_interval_closed_contact_overlaps_then_one_unit_clears() -> void:
	var radius: int = _whole(1)
	var cylinder_height: int = _whole(2)
	var half_height: int = cylinder_height / 2
	var box: StaticAabb = _box(0, 0, 0, 1, 1, 1)
	var contact_y: int = _whole(1) + radius + half_height
	var touching: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	touching.y = contact_y
	assert_true(box.overlaps_capsule(touching))
	assert_true(box.overlap_math_ok)
	var separated: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	separated.y = contact_y + 1
	assert_false(box.overlaps_capsule(separated))
	assert_true(box.overlap_math_ok)


func test_overflow_is_not_overlap_and_is_observable() -> void:
	var box: StaticAabb = _box(0, 0, 0, 0, 0, 0)
	box.x = FixedClass.INT64_MIN
	var capsule: KinematicCapsule = _upright(0, 0, 0, 1, 2)
	capsule.x = FixedClass.INT64_MAX
	assert_false(box.overlaps_capsule(capsule))
	assert_false(box.overlap_math_ok)


func _whole(units: int) -> int:
	var converted: FixedResultClass = FixedClass.try_from_whole(units)
	assert_true(converted.ok)
	return converted.value


func _box(
	x_whole: int,
	y_whole: int,
	z_whole: int,
	half_x_whole: int,
	half_y_whole: int,
	half_z_whole: int
) -> StaticAabb:
	var box: StaticAabb = StaticAabb.new()
	box.x = _whole(x_whole)
	box.y = _whole(y_whole)
	box.z = _whole(z_whole)
	box.half_x = _whole(half_x_whole)
	box.half_y = _whole(half_y_whole)
	box.half_z = _whole(half_z_whole)
	return box


func _upright(
	x_whole: int,
	y_whole: int,
	z_whole: int,
	radius_whole: int,
	height_whole: int
) -> KinematicCapsule:
	var capsule: KinematicCapsule = KinematicCapsule.new()
	capsule.x = _whole(x_whole)
	capsule.y = _whole(y_whole)
	capsule.z = _whole(z_whole)
	capsule.radius = _whole(radius_whole)
	capsule.cylinder_height = _whole(height_whole)
	return capsule
