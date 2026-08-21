class_name TraprushDestructible
extends RefCounted

## TRAPRUSH 可破坏障碍的权威耐久账本（纯数据）。
## 依据 CD-21 §5.2：health 服务端权威；玩家普通撞击不能直接摧毁，必须走爆破/钻头/冲击/地图机关。
## 耐久是 CD-42 §1.1 尺度 1 的整数（不是 Q48.16）。max_health 由调用方传入，本类型不发明默认血量。
## 伤害入口是 apply_damage；爆破数值见 CD-63，本刀不锁定。不实现重生、无敌、碎片或撞击扣血。

var _max_health: int = 0
var _current_health: int = 0


static func create(max_health: int) -> TraprushDestructible:
	if max_health < 1:
		return null
	var obstacle: TraprushDestructible = TraprushDestructible.new()
	obstacle._max_health = max_health
	obstacle._current_health = max_health
	return obstacle


func apply_damage(amount: int) -> Dictionary:
	if amount < 1:
		return {"ok": false}
	if amount >= _current_health:
		_current_health = 0
	else:
		_current_health -= amount
	return {
		"ok": true,
		"health": _current_health,
		"destroyed": _current_health == 0,
	}


func is_destroyed() -> bool:
	return _current_health == 0


func current_health() -> int:
	return _current_health


func max_health() -> int:
	return _max_health
