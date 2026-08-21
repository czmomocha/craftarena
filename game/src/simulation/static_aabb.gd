class_name StaticAabb
extends RefCounted

## Axis-aligned box: center plus non-negative half-extents. All fields are Q48.16 int.
## Closed contact counts as overlap. Overflowing Fixed math is not overlap
## and sets overlap_math_ok = false.

var x: int = 0
var y: int = 0
var z: int = 0
var half_x: int = 0
var half_y: int = 0
var half_z: int = 0
var overlap_math_ok: bool = true


func overlaps_capsule(capsule: KinematicCapsule) -> bool:
	overlap_math_ok = true
	var dx_res: FixedResult = _point_to_range_gap(capsule.x, x, half_x)
	if not dx_res.ok:
		return _math_failed()
	var dz_res: FixedResult = _point_to_range_gap(capsule.z, z, half_z)
	if not dz_res.ok:
		return _math_failed()
	var dy_res: FixedResult = _segment_to_range_gap(capsule)
	if not dy_res.ok:
		return _math_failed()
	var dx_sq: FixedResult = Fixed.try_mul(dx_res.value, dx_res.value)
	if not dx_sq.ok:
		return _math_failed()
	var dz_sq: FixedResult = Fixed.try_mul(dz_res.value, dz_res.value)
	if not dz_sq.ok:
		return _math_failed()
	var dy_sq: FixedResult = Fixed.try_mul(dy_res.value, dy_res.value)
	if not dy_sq.ok:
		return _math_failed()
	var horiz: FixedResult = Fixed.try_add(dx_sq.value, dz_sq.value)
	if not horiz.ok:
		return _math_failed()
	var dist_sq: FixedResult = Fixed.try_add(horiz.value, dy_sq.value)
	if not dist_sq.ok:
		return _math_failed()
	var rad_sq: FixedResult = Fixed.try_mul(capsule.radius, capsule.radius)
	if not rad_sq.ok:
		return _math_failed()
	return dist_sq.value <= rad_sq.value


func _point_to_range_gap(point: int, center: int, half: int) -> FixedResult:
	var range_min: FixedResult = Fixed.try_sub(center, half)
	if not range_min.ok:
		return FixedResult.fail()
	var range_max: FixedResult = Fixed.try_add(center, half)
	if not range_max.ok:
		return FixedResult.fail()
	if point < range_min.value:
		return Fixed.try_sub(range_min.value, point)
	if range_max.value < point:
		return Fixed.try_sub(point, range_max.value)
	return FixedResult.success(0)


func _segment_to_range_gap(capsule: KinematicCapsule) -> FixedResult:
	var half_height: int = capsule.cylinder_height / 2
	var seg_min: FixedResult = Fixed.try_sub(capsule.y, half_height)
	if not seg_min.ok:
		return FixedResult.fail()
	var seg_max: FixedResult = Fixed.try_add(capsule.y, half_height)
	if not seg_max.ok:
		return FixedResult.fail()
	var box_min: FixedResult = Fixed.try_sub(y, half_y)
	if not box_min.ok:
		return FixedResult.fail()
	var box_max: FixedResult = Fixed.try_add(y, half_y)
	if not box_max.ok:
		return FixedResult.fail()
	if seg_max.value < box_min.value:
		return Fixed.try_sub(box_min.value, seg_max.value)
	if box_max.value < seg_min.value:
		return Fixed.try_sub(seg_min.value, box_max.value)
	return FixedResult.success(0)


func _math_failed() -> bool:
	overlap_math_ok = false
	return false
