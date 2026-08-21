extends GutTest

## SplitMix64 对照：同一 seed 序列锁定，n<=0 的 bounded 行为锁定。

const SimRng := preload("res://src/simulation/sim_rng.gd")

const SEED_1_SEQ: Array[int] = [
	-7995527694508729151,
	-4689498862643123097,
	-534904783426661026,
]


func test_same_seed_replays_identical_u64_sequence() -> void:
	var left: SimRng = SimRng.new()
	var right: SimRng = SimRng.new()
	left.seed(1)
	right.seed(1)
	var index: int = 0
	while index < SEED_1_SEQ.size():
		var left_value: int = left.next_u64()
		var right_value: int = right.next_u64()
		assert_eq(left_value, SEED_1_SEQ[index])
		assert_eq(right_value, left_value)
		index += 1


func test_different_seeds_diverge_immediately() -> void:
	var left: SimRng = SimRng.new()
	var right: SimRng = SimRng.new()
	left.seed(1)
	right.seed(42)
	assert_ne(left.next_u64(), right.next_u64())


func test_next_bounded_non_positive_returns_zero_without_consuming() -> void:
	var rng: SimRng = SimRng.new()
	rng.seed(1)
	assert_eq(rng.next_bounded(0), 0)
	assert_eq(rng.next_bounded(-3), 0)
	assert_eq(rng.next_u64(), SEED_1_SEQ[0])


func test_next_bounded_is_deterministic_and_in_range() -> void:
	var rng: SimRng = SimRng.new()
	rng.seed(1)
	var first: int = rng.next_bounded(10)
	var second: int = rng.next_bounded(10)
	assert_true(first >= 0 and first < 10)
	assert_true(second >= 0 and second < 10)
	rng.seed(1)
	assert_eq(rng.next_bounded(10), first)
	assert_eq(rng.next_bounded(10), second)
