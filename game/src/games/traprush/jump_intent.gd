class_name TraprushJumpIntent
extends RefCounted

## PLAYER JumpIntent 纯数据解码。短跳是按钮意图，只认名字，不发明跳跃高度或重力。
## 依据 CD-21 §8：客户端只发意图，不得发送最终位置。跳跃数值见 CD-63，本刀不锁定。
## 接地判定与 jump_dy 由 IntentStepper 的调用方传入；本解码不读支撑、高度或最终姿态。
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
	if intent_name != PlayerIntentNames.JUMP:
		return failed
	return {"ok": true}
