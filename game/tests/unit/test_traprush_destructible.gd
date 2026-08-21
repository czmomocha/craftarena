extends GutTest

## TraprushDestructible：可破坏障碍的权威耐久账本。max_health 由调用方传入，本文件不发明默认血量。
## CD-21 §5.2：health 服务端权威；玩家普通撞击不能直接摧毁。耐久是 CD-42 §1.1 尺度 1 的整数。
## 伤害数值见 CD-63，本刀不锁定。不调用 SimulationWorld，不读 UseItemIntent。

const Destructible := preload("res://src/games/traprush/destructible.gd")


func test_create_rejects_zero_and_negative_max_health() -> void:
	assert_eq(Destructible.create(0), null)
	assert_eq(Destructible.create(-1), null)
	assert_eq(Destructible.create(-8), null)


func test_create_starts_at_full_caller_supplied_health() -> void:
	var obstacle: Destructible = Destructible.create(7)
	assert_not_null(obstacle)
	assert_eq(obstacle.current_health(), 7)
	assert_eq(obstacle.max_health(), 7)
	assert_false(obstacle.is_destroyed())


func test_one_damage_reduces_health_without_destroying() -> void:
	var obstacle: Destructible = Destructible.create(10)
	var result: Dictionary = obstacle.apply_damage(3)
	assert_true(_ok(result))
	assert_eq(_health(result), 7)
	assert_false(_destroyed(result))
	assert_eq(obstacle.current_health(), 7)
	assert_eq(obstacle.max_health(), 10)
	assert_false(obstacle.is_destroyed())


func test_exact_damage_reaches_zero_and_is_destroyed() -> void:
	var obstacle: Destructible = Destructible.create(5)
	var result: Dictionary = obstacle.apply_damage(5)
	assert_true(_ok(result))
	assert_eq(_health(result), 0)
	assert_true(_destroyed(result))
	assert_eq(obstacle.current_health(), 0)
	assert_true(obstacle.is_destroyed())
	assert_eq(obstacle.max_health(), 5)


func test_overkill_damage_stops_at_zero() -> void:
	var obstacle: Destructible = Destructible.create(3)
	var result: Dictionary = obstacle.apply_damage(100)
	assert_true(_ok(result))
	assert_eq(_health(result), 0)
	assert_true(_destroyed(result))
	assert_eq(obstacle.current_health(), 0)
	assert_true(obstacle.is_destroyed())


func test_zero_damage_fails_and_does_not_destroy() -> void:
	var obstacle: Destructible = Destructible.create(4)
	var result: Dictionary = obstacle.apply_damage(0)
	assert_false(_ok(result))
	assert_eq(result.size(), 1)
	assert_false(result.has("destroyed"))
	assert_eq(obstacle.current_health(), 4)
	assert_false(obstacle.is_destroyed())
	assert_false(_ok(obstacle.apply_damage(-2)))
	assert_eq(obstacle.current_health(), 4)


func test_already_destroyed_stays_destroyed_on_further_damage() -> void:
	var obstacle: Destructible = Destructible.create(2)
	var first: Dictionary = obstacle.apply_damage(2)
	assert_true(_ok(first))
	assert_true(obstacle.is_destroyed())
	var again: Dictionary = obstacle.apply_damage(1)
	assert_true(_ok(again))
	assert_eq(_health(again), 0)
	assert_true(_destroyed(again))
	assert_eq(obstacle.current_health(), 0)
	assert_true(obstacle.is_destroyed())
	assert_eq(obstacle.max_health(), 2)


func test_has_apply_damage_but_no_bump_or_contact_methods() -> void:
	var obstacle: Destructible = Destructible.create(1)
	assert_eq(obstacle.has_method("apply_damage"), true)
	assert_eq(obstacle.has_method("apply_bump"), false)
	assert_eq(obstacle.has_method("apply_contact"), false)
	assert_eq(obstacle.has_method("on_capsule_hit"), false)


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _destroyed(result: Dictionary) -> bool:
	var flag: bool = result.get("destroyed", false)
	return flag


func _health(result: Dictionary) -> int:
	var remaining: int = result.get("health", -1)
	return remaining
