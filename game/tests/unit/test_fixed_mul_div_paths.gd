extends GutTest

## `Fixed.try_mul_div` 有两条实现：中间积不溢出 int64 时走原生乘除，溢出时走
## 限位长除法。本文件只证一件事——**它们给出同一个值**。
##
## 这条性质是那次提速的全部安全依据。定点数进状态哈希、进磁带回放、进三张官方
## 赛道的每一次碰撞查询；只要两条路径在某个输入上分叉，仿真就会在「快到能跑」
## 和「慢但正确」之间给出两种结果，而且是静默的。所以这里不断言具体数值（那是
## `test_fixed.gd` 的事），只断言两条路径一致。
##
## 覆盖三类输入：手挑的边界、真实调用点的形状（坐标差平方 / 除以 SCALE）、
## 定种子伪随机的一大把。伪随机用固定种子，失败可复现。

const Fixed := preload("res://src/shared/fixed/fixed.gd")
const FixedResult := preload("res://src/shared/fixed/fixed_result.gd")

const SCALE: int = 65536
const INT64_MAX: int = 9223372036854775807
const INT64_MIN: int = -INT64_MAX - 1
const RANDOM_CASES: int = 4000
const SEED: int = 20260901


func test_boundary_inputs_agree_on_both_paths() -> void:
	var values: Array[int] = [
		0, 1, -1, 2, -2, 3, -3,
		SCALE, -SCALE, SCALE - 1, -(SCALE - 1), SCALE + 1, -(SCALE + 1),
		8192, -8192, 65535, -65535, 4294967295, -4294967295,
		2147483647, -2147483648, 4294967296, -4294967296,
		3037000499, -3037000499,  # 略小于 sqrt(INT64_MAX)，快路径的边界附近
		3037000500, -3037000500,  # 略大于，乘方后溢出
		INT64_MAX, INT64_MIN, INT64_MAX - 1, INT64_MIN + 1,
	]
	for left: int in values:
		for right: int in values:
			for divisor: int in [1, -1, 2, -2, SCALE, -SCALE, INT64_MAX, INT64_MIN]:
				_assert_paths_agree(left, right, divisor)


func test_collision_shaped_inputs_agree_on_both_paths() -> void:
	## `StaticAabb.overlaps_capsule` 的真实形状：格子尺度的间隙自乘再除以 SCALE。
	## 这是快路径每帧要走几百次的那条，必须逐个对得上。
	var gaps: Array[int] = [
		0, 1, 8191, 8192, 8193, 16384, 32768, 65536, 131072,
		262144, 524288, 1048576, 7 * SCALE, 8 * SCALE, 64 * SCALE,
	]
	for gap: int in gaps:
		_assert_paths_agree(gap, gap, SCALE)
		_assert_paths_agree(-gap, gap, SCALE)
		_assert_paths_agree(-gap, -gap, SCALE)


func test_pseudo_random_inputs_agree_on_both_paths() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for _case: int in range(RANDOM_CASES):
		var left: int = _spread(rng)
		var right: int = _spread(rng)
		var divisor: int = _spread(rng)
		if divisor == 0:
			divisor = 1
		_assert_paths_agree(left, right, divisor)


func test_zero_divisor_still_fails_before_either_path() -> void:
	var result: FixedResult = Fixed.try_mul_div(SCALE, SCALE, 0)
	assert_false(result.ok)


func test_fast_path_only_claims_products_that_fit() -> void:
	assert_true(Fixed._product_fits_int64(0, INT64_MIN))
	assert_true(Fixed._product_fits_int64(3037000499, 3037000499))
	assert_false(Fixed._product_fits_int64(3037000500, 3037000500))
	assert_false(Fixed._product_fits_int64(INT64_MIN, 1))
	assert_false(Fixed._product_fits_int64(1, INT64_MIN))
	assert_true(Fixed._product_fits_int64(INT64_MAX, 1))
	assert_true(Fixed._product_fits_int64(-INT64_MAX, 1))
	assert_false(Fixed._product_fits_int64(INT64_MAX, 2))


## 幅度跨若干数量级，让「刚好不溢出」与「刚好溢出」都有机会被抽到。
func _spread(rng: RandomNumberGenerator) -> int:
	var magnitude: int = rng.randi_range(0, 62)
	var value: int = rng.randi_range(0, 65535) << (magnitude / 2)
	value += rng.randi_range(0, 65535)
	if rng.randi_range(0, 1) == 1:
		return -value
	return value


func _assert_paths_agree(left: int, right: int, divisor: int) -> void:
	var fast: FixedResult = Fixed.try_mul_div(left, right, divisor)
	var slow: FixedResult = Fixed._mul_div_limbs(left, right, divisor)
	var label: String = "%d * %d / %d" % [left, right, divisor]
	assert_eq(fast.ok, slow.ok, label)
	if fast.ok and slow.ok:
		assert_eq(fast.value, slow.value, label)
