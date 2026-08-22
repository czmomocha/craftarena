class_name TraprushUseItemIntent
extends RefCounted

## PLAYER UseItemIntent 纯数据解码。使用道具是按钮意图，只认名字，不发明道具表或爆破数值。
## 依据 CD-21 §8：客户端只发意图，不得发送道具命中或障碍死亡断言。爆破数值见 CD-63，本刀不锁定。
## 本刀只解码，不调用 SimulationWorld。

const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")


static func decode(payload: Dictionary) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if not payload.has("intent"):
		return failed
	var intent_value: Variant = payload["intent"]
	if typeof(intent_value) != TYPE_STRING:
		return failed
	var intent_name: String = intent_value
	if intent_name != PlayerIntentNames.USE_ITEM:
		return failed
	return {"ok": true}
