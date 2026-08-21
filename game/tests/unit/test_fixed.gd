extends GutTest

## ADR-0005 整包：尺度 65536、向零截断、溢出拒绝、4096 LUT + BAM 插值。

const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const FixedResultClass := preload("res://src/shared/fixed/fixed_result.gd")
const FixedSinLutClass := preload("res://src/shared/fixed/fixed_sin_lut.gd")


func test_scale_and_whole_roundtrip() -> void:
	assert_eq(FixedClass.SCALE, 65536)
	var one: FixedResultClass = FixedClass.try_from_whole(1)
	assert_true(one.ok)
	assert_eq(one.value, 65536)
	assert_eq(FixedClass.to_whole_trunc(one.value), 1)
	assert_eq(FixedClass.to_whole_trunc(-65535), 0)
	assert_eq(FixedClass.to_whole_trunc(-65536), -1)


func test_add_sub_neg() -> void:
	var added: FixedResultClass = FixedClass.try_add(20, -7)
	assert_true(added.ok)
	assert_eq(added.value, 13)
	var subtracted: FixedResultClass = FixedClass.try_sub(20, 7)
	assert_true(subtracted.ok)
	assert_eq(subtracted.value, 13)
	var negated: FixedResultClass = FixedClass.try_neg(13)
	assert_true(negated.ok)
	assert_eq(negated.value, -13)


func test_add_overflow_is_rejected() -> void:
	assert_false(FixedClass.try_add(FixedClass.INT64_MAX, 1).ok)
	assert_false(FixedClass.try_add(FixedClass.INT64_MIN, -1).ok)
	assert_true(FixedClass.try_add(FixedClass.INT64_MAX, 0).ok)
	assert_true(FixedClass.try_add(FixedClass.INT64_MIN, 0).ok)


func test_neg_and_sub_of_int64_min() -> void:
	assert_false(FixedClass.try_neg(FixedClass.INT64_MIN).ok)
	var min_minus_min: FixedResultClass = FixedClass.try_sub(FixedClass.INT64_MIN, FixedClass.INT64_MIN)
	assert_true(min_minus_min.ok)
	assert_eq(min_minus_min.value, 0)
	var minus_one_minus_min: FixedResultClass = FixedClass.try_sub(-1, FixedClass.INT64_MIN)
	assert_true(minus_one_minus_min.ok)
	assert_eq(minus_one_minus_min.value, FixedClass.INT64_MAX)
	assert_false(FixedClass.try_sub(0, FixedClass.INT64_MIN).ok)


func test_mul_div_basic() -> void:
	var one: FixedResultClass = FixedClass.try_mul(FixedClass.SCALE, FixedClass.SCALE)
	assert_true(one.ok)
	assert_eq(one.value, FixedClass.SCALE)
	var quarter: FixedResultClass = FixedClass.try_mul(32768, 32768)
	assert_true(quarter.ok)
	assert_eq(quarter.value, 16384)
	var three_halves: FixedResultClass = FixedClass.try_div(196608, 131072)
	assert_true(three_halves.ok)
	assert_eq(three_halves.value, 98304)
	var toward_zero: FixedResultClass = FixedClass.try_div(-65536, 131072)
	assert_true(toward_zero.ok)
	assert_eq(toward_zero.value, -32768)


func test_widening_mul_does_not_overflow_intermediate() -> void:
	var wide: FixedResultClass = FixedClass.try_mul(2147483648, 8589934592)
	assert_true(wide.ok)
	assert_eq(wide.value, 281474976710656)
	var big_int: FixedResultClass = FixedClass.try_mul_div(123456789, 987654321, FixedClass.SCALE)
	assert_true(big_int.ok)
	assert_eq(big_int.value, 1860544297983)


func test_mul_overflow_and_div_by_zero() -> void:
	assert_false(FixedClass.try_mul_int(FixedClass.INT64_MAX, 2).ok)
	assert_true(FixedClass.try_mul(FixedClass.INT64_MIN, FixedClass.SCALE).ok)
	assert_eq(FixedClass.try_mul(FixedClass.INT64_MIN, FixedClass.SCALE).value, FixedClass.INT64_MIN)
	assert_false(FixedClass.try_mul(FixedClass.INT64_MIN, FixedClass.SCALE + 1).ok)
	assert_false(FixedClass.try_div(FixedClass.SCALE, 0).ok)
	assert_false(FixedClass.try_from_whole(FixedClass.INT64_MAX).ok)


func test_bam_wrap() -> void:
	assert_eq(FixedClass.wrap_bam(0), 0)
	assert_eq(FixedClass.wrap_bam(65536), 0)
	assert_eq(FixedClass.wrap_bam(-1), 65535)
	assert_eq(FixedClass.wrap_bam(16384), 16384)


func test_sin_cos_quadrants() -> void:
	assert_eq(FixedSinLutClass.SIZE, 4096)
	assert_eq(FixedSinLutClass.VALUES.size(), 4096)
	assert_eq(FixedSinLutClass.VALUES[0], 0)
	assert_eq(FixedSinLutClass.VALUES[1024], 65536)
	assert_eq(FixedSinLutClass.VALUES[2048], 0)
	assert_eq(FixedSinLutClass.VALUES[3072], -65536)
	assert_eq(FixedSinLutClass.VALUES[512], 46340)
	var sin0: FixedResultClass = FixedClass.try_sin_bam(0)
	var sin_q: FixedResultClass = FixedClass.try_sin_bam(16384)
	var cos0: FixedResultClass = FixedClass.try_cos_bam(0)
	var cos_q: FixedResultClass = FixedClass.try_cos_bam(16384)
	assert_true(sin0.ok and sin_q.ok and cos0.ok and cos_q.ok)
	assert_eq(sin0.value, 0)
	assert_eq(sin_q.value, 65536)
	assert_eq(cos0.value, 65536)
	assert_eq(cos_q.value, 0)


func test_sin_interpolation_matches_table_blend() -> void:
	var blended: FixedResultClass = FixedClass.try_sin_bam(8)
	assert_true(blended.ok)
	var expected: int = (FixedSinLutClass.VALUES[1] * 8) / 16
	assert_eq(blended.value, expected)
	assert_eq(expected, 50)
