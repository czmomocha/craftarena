class_name KinematicCapsule
extends RefCounted

## Upright capsule: medial axis parallel to world Y. All fields are Q48.16 int.
## Closed contact counts as overlap. Overflowing Fixed math is not overlap
## and sets overlap_math_ok = false.

var x: int = 0
var y: int = 0
var z: int = 0
var radius: int = 0
var cylinder_height: int = 0
var overlap_math_ok: bool = true


func overlaps(other: KinematicCapsule) -> bool:
	overlap_math_ok = true
	var dx_res: FixedResult = Fixed.try_sub(other.x, x)
	if not dx_res.ok:
		return _math_failed()
	var dz_res: FixedResult = Fixed.try_sub(other.z, z)
	if not dz_res.ok:
		return _math_failed()
	var gap_res: FixedResult = _vertical_segment_gap(other)
	if not gap_res.ok:
		return _math_failed()
	var dx_sq: FixedResult = Fixed.try_mul(dx_res.value, dx_res.value)
	if not dx_sq.ok:
		return _math_failed()
	var dz_sq: FixedResult = Fixed.try_mul(dz_res.value, dz_res.value)
	if not dz_sq.ok:
		return _math_failed()
	var gap_sq: FixedResult = Fixed.try_mul(gap_res.value, gap_res.value)
	if not gap_sq.ok:
		return _math_failed()
	var horiz: FixedResult = Fixed.try_add(dx_sq.value, dz_sq.value)
	if not horiz.ok:
		return _math_failed()
	var dist_sq: FixedResult = Fixed.try_add(horiz.value, gap_sq.value)
	if not dist_sq.ok:
		return _math_failed()
	var rad: FixedResult = Fixed.try_add(radius, other.radius)
	if not rad.ok:
		return _math_failed()
	var rad_sq: FixedResult = Fixed.try_mul(rad.value, rad.value)
	if not rad_sq.ok:
		return _math_failed()
	return dist_sq.value <= rad_sq.value


func _vertical_segment_gap(other: KinematicCapsule) -> FixedResult:
	var half_self: int = cylinder_height / 2
	var half_other: int = other.cylinder_height / 2
	var self_min: FixedResult = Fixed.try_sub(y, half_self)
	if not self_min.ok:
		return FixedResult.fail()
	var self_max: FixedResult = Fixed.try_add(y, half_self)
	if not self_max.ok:
		return FixedResult.fail()
	var other_min: FixedResult = Fixed.try_sub(other.y, half_other)
	if not other_min.ok:
		return FixedResult.fail()
	var other_max: FixedResult = Fixed.try_add(other.y, half_other)
	if not other_max.ok:
		return FixedResult.fail()
	if self_max.value < other_min.value:
		return Fixed.try_sub(other_min.value, self_max.value)
	if other_max.value < self_min.value:
		return Fixed.try_sub(self_min.value, other_max.value)
	return FixedResult.success(0)


func _math_failed() -> bool:
	overlap_math_ok = false
	return false
