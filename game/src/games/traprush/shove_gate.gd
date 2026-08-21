class_name TraprushShoveGate
extends RefCounted

## 基础推击冷却门闩。cooldown_ticks 必须由调用方传入，本类型不锁定冷却秒数或击退力度。
## 依据 CD-21 §2 / §5.3：所有玩家拥有独立于道具的基础推击；具体数值见 CD-63。
## 比较的是 tick 差；从未推击用 last_shove_tick < 0 表示。

static func can_shove(now_tick: int, last_shove_tick: int, cooldown_ticks: int) -> bool:
	if cooldown_ticks < 1:
		return false
	if last_shove_tick < 0:
		return true
	return now_tick - last_shove_tick >= cooldown_ticks
