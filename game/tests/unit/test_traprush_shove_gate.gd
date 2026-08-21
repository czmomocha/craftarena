extends GutTest

## TraprushShoveGate：基础推击冷却门闩。冷却 tick 由调用方传入，本文件不锁定秒数或力度。
## CD-21 §2 / §3.2 / §5.3：所有玩家有低强度、长冷却的基础推击；数值见 CD-63。
## 比较的是 tick 差，不把 tick 换成秒。不实现击退向量。

const ShoveGate := preload("res://src/games/traprush/shove_gate.gd")


func test_never_shoved_is_allowed_when_cooldown_is_at_least_one_tick() -> void:
	assert_true(ShoveGate.can_shove(0, -1, 1))
	assert_true(ShoveGate.can_shove(100, -1, 30))
	assert_true(ShoveGate.can_shove(0, -8, 1))


func test_cooldown_below_one_tick_is_always_rejected() -> void:
	assert_false(ShoveGate.can_shove(0, -1, 0))
	assert_false(ShoveGate.can_shove(50, -1, -3))
	assert_false(ShoveGate.can_shove(20, 0, 0))
	assert_false(ShoveGate.can_shove(20, 10, -1))


func test_elapsed_ticks_strictly_less_than_cooldown_are_rejected() -> void:
	assert_false(ShoveGate.can_shove(14, 10, 5))
	assert_false(ShoveGate.can_shove(10, 10, 1))
	assert_false(ShoveGate.can_shove(9, 10, 5))


func test_ready_exactly_when_elapsed_equals_caller_cooldown() -> void:
	assert_true(ShoveGate.can_shove(15, 10, 5))
	assert_true(ShoveGate.can_shove(11, 10, 1))
	assert_true(ShoveGate.can_shove(40, 10, 5))


func test_gate_does_not_encode_a_product_cooldown_in_seconds() -> void:
	var caller_cooldown_ticks: int = 30
	assert_true(ShoveGate.can_shove(30, 0, caller_cooldown_ticks))
	assert_false(ShoveGate.can_shove(29, 0, caller_cooldown_ticks))
