class_name TraprushMoveIntent
extends RefCounted

## PLAYER MoveIntent 纯数据解码。位移是调用方给出的 Q48.16 dx/dz，不发明默认速度。
## 依据 CD-21 §8：客户端只发意图，不得发送最终位置。本刀只解码，不调用 SimulationWorld。

const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const _YAW_BAM_OMITTED: int = -1


static func decode(payload: Dictionary) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if not payload.has("intent"):
		return failed
	var intent_value: Variant = payload["intent"]
	if typeof(intent_value) != TYPE_STRING:
		return failed
	var intent_name: String = intent_value
	if intent_name != PlayerIntentNames.MOVE:
		return failed
	var dx_read: Dictionary = _read_int(payload, "dx")
	var dz_read: Dictionary = _read_int(payload, "dz")
	if not _flag(dx_read) or not _flag(dz_read):
		return failed
	var yaw_bam: int = _YAW_BAM_OMITTED
	if payload.has("yaw_bam"):
		var yaw_read: Dictionary = _read_int(payload, "yaw_bam")
		if not _flag(yaw_read):
			return failed
		yaw_bam = _value(yaw_read)
	return {
		"ok": true,
		"dx": _value(dx_read),
		"dz": _value(dz_read),
		"yaw_bam": yaw_bam,
	}


static func _read_int(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": 0}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_INT:
		return {"ok": false, "value": 0}
	var number: int = raw
	return {"ok": true, "value": number}


static func _flag(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


static func _value(result: Dictionary) -> int:
	var number: int = result.get("value", 0)
	return number
