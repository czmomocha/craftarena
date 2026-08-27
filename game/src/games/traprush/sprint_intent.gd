class_name TraprushSprintIntent
extends RefCounted

## PLAYER SprintIntent 纯数据解码。冲刺是按钮意图，只认名字，不发明位移或冷却秒数。
## 依据 CD-21 §8：客户端只发意图，不得发送最终位置。步长与冷却见调用方占位桩，本刀不锁定。
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
	if intent_name != PlayerIntentNames.SPRINT:
		return failed
	return {"ok": true}
