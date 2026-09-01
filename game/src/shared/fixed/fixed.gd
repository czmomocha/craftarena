class_name Fixed
extends RefCounted

## 权威定点与 BAM 三角函数。数值合同见 CD-42 §1.1 与 ADR-0005。
## 值以 int64 存储，不包装成对象。溢出与除零返回 FixedResult.ok = false。

const _SinLut := preload("res://src/shared/fixed/fixed_sin_lut.gd")

const SCALE: int = 65536
const BAM_TURN: int = 65536
const BAM_QUARTER: int = 16384
const LUT_SIZE: int = 4096
const LUT_STEP_BAM: int = 16
const INT64_MAX: int = 9223372036854775807
const INT64_MIN: int = -INT64_MAX - 1
const _MASK16: int = 65535
const _LIMB_COUNT: int = 8
const _MAG_LIMBS: int = 4


static func try_add(left: int, right: int) -> FixedResult:
	if right > 0 and left > INT64_MAX - right:
		return FixedResult.fail()
	if right < 0 and left < INT64_MIN - right:
		return FixedResult.fail()
	return FixedResult.success(left + right)


static func try_sub(left: int, right: int) -> FixedResult:
	if right == INT64_MIN:
		if left < 0:
			return FixedResult.success((left + 1) + INT64_MAX)
		return FixedResult.fail()
	return try_add(left, -right)


static func try_neg(value: int) -> FixedResult:
	if value == INT64_MIN:
		return FixedResult.fail()
	return FixedResult.success(-value)


static func try_mul(left: int, right: int) -> FixedResult:
	return try_mul_div(left, right, SCALE)


static func try_div(left: int, right: int) -> FixedResult:
	return try_mul_div(left, SCALE, right)


static func try_mul_int(left: int, right: int) -> FixedResult:
	return try_mul_div(left, right, 1)


static func try_from_whole(whole_units: int) -> FixedResult:
	return try_mul_int(whole_units, SCALE)


static func to_whole_trunc(fixed_value: int) -> int:
	return fixed_value / SCALE


## 128 位中间积是**正确性**需要的：`try_mul` 是 `a * b / SCALE`，两个 Q48.16 相乘
## 会先冲出 int64，再被 SCALE 除回来。但它不该是**常见**路径。
##
## 绝大多数调用的中间积根本不溢出（碰撞检测里是格子尺度的坐标差平方），此时
## 原生 int64 乘除给出的结果与限位长除法**逐位相同**——两者都向零截断，符号都
## 由三个操作数的符号异或决定。所以先试原生，溢出了才回退。
##
## 为什么值得：`_div_mags` 是逐位长除 128 轮，每轮 `_shl1` / `_sub_limbs` /
## `_with_bit` 各新建一个 `PackedInt32Array`。开发机实测单次 `try_mul` **176 µs**，
## 而 `try_add` 只要 1.1 µs。对局里 `is_pose_blocked` 要对 49 个静态盒各做 4 次
## `try_mul`，于是一次碰撞查询 25 ms、整帧 33.7 ms（约 30 FPS）——这就是 2026-09-01
## 之前 Solo 掉帧的全部原因，见 [docs/audits/2026-09-01-offline-frame-cost.md]。
##
## 「两条路径必须给出同一个值」由 `test_fixed_mul_div_paths.gd` 的差分用例钉死：
## 任何时候改了这里，那组用例会先红。不要把快路径的适用条件放宽到未被它覆盖的
## 输入上。
static func try_mul_div(left: int, right: int, divisor: int) -> FixedResult:
	if divisor == 0:
		return FixedResult.fail()
	if divisor != INT64_MIN and _product_fits_int64(left, right):
		return FixedResult.success(left * right / divisor)
	return _mul_div_limbs(left, right, divisor)


## `|left * right| <= INT64_MAX` 吗。用除法判而不是先乘再看，因为先乘就已经溢出了。
static func _product_fits_int64(left: int, right: int) -> bool:
	if left == 0 or right == 0:
		return true
	# INT64_MIN 取不了绝对值，交给限位路径。
	if left == INT64_MIN or right == INT64_MIN:
		return false
	var left_magnitude: int = absi(left)
	var right_magnitude: int = absi(right)
	return left_magnitude <= INT64_MAX / right_magnitude


static func _mul_div_limbs(left: int, right: int, divisor: int) -> FixedResult:
	var negative: bool = false
	if left < 0:
		negative = not negative
	if right < 0:
		negative = not negative
	if divisor < 0:
		negative = not negative
	var product: PackedInt32Array = _mul_mags(_abs_limbs(left), _abs_limbs(right))
	var quotient: PackedInt32Array = _div_mags(product, _abs_limbs(divisor))
	if quotient.is_empty():
		return FixedResult.fail()
	return _signed_from_limbs(quotient, negative)


static func wrap_bam(bam: int) -> int:
	var wrapped: int = bam % BAM_TURN
	if wrapped < 0:
		wrapped += BAM_TURN
	return wrapped


static func try_sin_bam(bam: int) -> FixedResult:
	var wrapped: int = wrap_bam(bam)
	var index: int = wrapped / LUT_STEP_BAM
	var frac: int = wrapped % LUT_STEP_BAM
	var sin0: int = _SinLut.VALUES[index]
	var next_index: int = index + 1
	if next_index == LUT_SIZE:
		next_index = 0
	var sin1: int = _SinLut.VALUES[next_index]
	var delta: int = sin1 - sin0
	return try_add(sin0, (delta * frac) / LUT_STEP_BAM)


static func try_cos_bam(bam: int) -> FixedResult:
	return try_sin_bam(bam + BAM_QUARTER)


static func _zero_limbs() -> PackedInt32Array:
	var limbs: PackedInt32Array = PackedInt32Array()
	limbs.resize(_LIMB_COUNT)
	return limbs


static func _abs_limbs(value: int) -> PackedInt32Array:
	if value == INT64_MIN:
		var min_mag: PackedInt32Array = _zero_limbs()
		min_mag[3] = 32768
		return min_mag
	if value < 0:
		return _u64_to_limbs(-value)
	return _u64_to_limbs(value)


static func _u64_to_limbs(non_negative: int) -> PackedInt32Array:
	var limbs: PackedInt32Array = _zero_limbs()
	var remaining: int = non_negative
	for limb_index: int in range(_MAG_LIMBS):
		limbs[limb_index] = remaining & _MASK16
		remaining = remaining >> 16
	return limbs


static func _mul_mags(left: PackedInt32Array, right: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = _zero_limbs()
	for i: int in range(_MAG_LIMBS):
		for j: int in range(_MAG_LIMBS):
			var product: int = left[i] * right[j]
			var k: int = i + j
			while product != 0:
				var total: int = out[k] + (product & _MASK16)
				out[k] = total & _MASK16
				product = (product >> 16) + (total >> 16)
				k += 1
	return out


static func _div_mags(numerator: PackedInt32Array, denominator: PackedInt32Array) -> PackedInt32Array:
	if _is_zero(denominator):
		return PackedInt32Array()
	var quotient: PackedInt32Array = _zero_limbs()
	var remainder: PackedInt32Array = _zero_limbs()
	for bit_index: int in range(127, -1, -1):
		remainder = _shl1(remainder)
		if _bit_is_set(numerator, bit_index):
			remainder[0] = remainder[0] | 1
		if _cmp_limbs(remainder, denominator) >= 0:
			remainder = _sub_limbs(remainder, denominator)
			quotient = _with_bit(quotient, bit_index)
	return quotient


static func _is_zero(limbs: PackedInt32Array) -> bool:
	for limb_index: int in range(_LIMB_COUNT):
		if limbs[limb_index] != 0:
			return false
	return true


static func _cmp_limbs(left: PackedInt32Array, right: PackedInt32Array) -> int:
	for limb_index: int in range(_LIMB_COUNT - 1, -1, -1):
		if left[limb_index] > right[limb_index]:
			return 1
		if left[limb_index] < right[limb_index]:
			return -1
	return 0


static func _shl1(source: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = _zero_limbs()
	var carry: int = 0
	for limb_index: int in range(_LIMB_COUNT):
		var value: int = (source[limb_index] << 1) | carry
		out[limb_index] = value & _MASK16
		carry = value >> 16
	return out


static func _sub_limbs(left: PackedInt32Array, right: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = _zero_limbs()
	var borrow: int = 0
	for limb_index: int in range(_LIMB_COUNT):
		var value: int = left[limb_index] - right[limb_index] - borrow
		if value < 0:
			value += 65536
			borrow = 1
		else:
			borrow = 0
		out[limb_index] = value
	return out


static func _bit_is_set(limbs: PackedInt32Array, bit_index: int) -> bool:
	var limb_index: int = bit_index / 16
	var offset: int = bit_index % 16
	if limb_index < 0 or limb_index >= _LIMB_COUNT:
		return false
	return ((limbs[limb_index] >> offset) & 1) == 1


static func _with_bit(limbs: PackedInt32Array, bit_index: int) -> PackedInt32Array:
	var out: PackedInt32Array = limbs.duplicate()
	var limb_index: int = bit_index / 16
	var offset: int = bit_index % 16
	if limb_index < 0 or limb_index >= _LIMB_COUNT:
		return out
	out[limb_index] = out[limb_index] | (1 << offset)
	return out


static func _signed_from_limbs(limbs: PackedInt32Array, negative: bool) -> FixedResult:
	for limb_index: int in range(_MAG_LIMBS, _LIMB_COUNT):
		if limbs[limb_index] != 0:
			return FixedResult.fail()
	if limbs[3] > 32768:
		return FixedResult.fail()
	if limbs[3] == 32768:
		if limbs[0] != 0 or limbs[1] != 0 or limbs[2] != 0:
			return FixedResult.fail()
		if negative:
			return FixedResult.success(INT64_MIN)
		return FixedResult.fail()
	var magnitude: int = (
		limbs[0]
		| (limbs[1] << 16)
		| (limbs[2] << 32)
		| (limbs[3] << 48)
	)
	if negative:
		return FixedResult.success(-magnitude)
	return FixedResult.success(magnitude)
