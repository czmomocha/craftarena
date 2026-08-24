class_name TraprushCheckpointTrack
extends RefCounted

## TRAPRUSH 有序强制检查点进度（纯数据）。
## 依据 CD-21 §4.2：玩家必须经过有序检查点，传送不能跳过未完成的强制检查点。
## 检查点 id 列表由调用方传入，本类型不发明默认个数。复活硬直 tick 不在本刀。

var _ordered_ids: PackedInt32Array = PackedInt32Array()
var _completed_count: int = 0


func _init(ordered_ids: PackedInt32Array = PackedInt32Array()) -> void:
	_ordered_ids = ordered_ids.duplicate()
	_completed_count = 0


static func from_int_array(ordered_ids: Array[int]) -> TraprushCheckpointTrack:
	var packed: PackedInt32Array = PackedInt32Array()
	packed.resize(ordered_ids.size())
	for index: int in range(ordered_ids.size()):
		packed[index] = ordered_ids[index]
	return TraprushCheckpointTrack.new(packed)


func completed_count() -> int:
	return _completed_count


func last_accepted_id() -> int:
	if _completed_count <= 0:
		return -1
	return _ordered_ids[_completed_count - 1]


func ordered_ids() -> PackedInt32Array:
	return _ordered_ids.duplicate()


func accepted_ids() -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize(_completed_count)
	for index: int in range(_completed_count):
		ids[index] = _ordered_ids[index]
	return ids


func try_accept(checkpoint_id: int) -> bool:
	if _completed_count > 0 and _ordered_ids[_completed_count - 1] == checkpoint_id:
		return true
	if _completed_count >= _ordered_ids.size():
		return false
	if _ordered_ids[_completed_count] != checkpoint_id:
		return false
	_completed_count += 1
	return true


func can_use_portal(dest_checkpoint_id: int) -> bool:
	var dest_index: int = _ordered_ids.find(dest_checkpoint_id)
	if dest_index < 0:
		return false
	return dest_index <= _completed_count


func reset_pose_index() -> int:
	if _completed_count <= 0:
		return -1
	return _completed_count - 1


func is_finished() -> bool:
	return _completed_count >= _ordered_ids.size()
