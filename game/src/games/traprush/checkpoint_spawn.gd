class_name TraprushCheckpointSpawn
extends RefCounted

## 检查点复活落点查找。起点与各检查点落点由调用方传入，不发明默认图或复活硬直。
## 依据 CD-21 §6：环境失败后返回最近检查点；尚未完成任何检查点则回起点。
## ResetToCheckpointIntent 只认 PlayerIntentNames，不从 payload 读取客户端坐标。

const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

var _start: Dictionary = {}
var _checkpoint_poses: Array[Dictionary] = []


func _init(start: Dictionary = {}, checkpoint_poses: Array = []) -> void:
	_start = _copy_pose_fields(start)
	_checkpoint_poses = []
	for item: Variant in checkpoint_poses:
		if item is Dictionary:
			var pose: Dictionary = item
			_checkpoint_poses.append(_copy_pose_fields(pose))
		else:
			_checkpoint_poses.append({"ok": false})


static func is_reset_intent(payload: Dictionary) -> bool:
	if not payload.has("intent"):
		return false
	var intent_value: Variant = payload["intent"]
	if typeof(intent_value) != TYPE_STRING:
		return false
	var intent_name: String = intent_value
	return intent_name == PlayerIntentNames.RESET_TO_CHECKPOINT


func pose_for(track: TraprushCheckpointTrack) -> Dictionary:
	if track == null:
		return {"ok": false}
	var index: int = track.reset_pose_index()
	if index == -1:
		return _start.duplicate()
	if index < 0 or index >= _checkpoint_poses.size():
		return {"ok": false}
	var stored: Dictionary = _checkpoint_poses[index]
	return stored.duplicate()


static func _copy_pose_fields(source: Dictionary) -> Dictionary:
	var x_read: Dictionary = _read_int(source, "x")
	var y_read: Dictionary = _read_int(source, "y")
	var z_read: Dictionary = _read_int(source, "z")
	var yaw_read: Dictionary = _read_int(source, "yaw_bam")
	if not _flag(x_read) or not _flag(y_read) or not _flag(z_read) or not _flag(yaw_read):
		return {"ok": false}
	return {
		"ok": true,
		"x": _value(x_read),
		"y": _value(y_read),
		"z": _value(z_read),
		"yaw_bam": _value(yaw_read),
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
