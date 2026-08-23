class_name EditPayload
extends RefCounted

## EDIT payload 形状。字段名单的所有者是 CD-42 §3.3。
## place / set_component 带完整 v1 实体袋；remove 只带 entity_id。未知键拒绝。

var ok: bool = false
var op: String = ""
var entity_id: int = SharedIds.NULL_ID
var record: SharedComponentRecord = null


static func decode(payload: Dictionary) -> EditPayload:
	var failed: EditPayload = EditPayload.new()
	if not payload.has("op") or typeof(payload["op"]) != TYPE_STRING:
		return failed
	var op_name: String = payload["op"]
	if not EditOpNames.contains(op_name):
		return failed
	match op_name:
		EditOpNames.PLACE:
			return _decode_record_op(payload, op_name, failed)
		EditOpNames.SET_COMPONENT:
			return _decode_record_op(payload, op_name, failed)
		EditOpNames.REMOVE:
			return _decode_remove(payload, failed)
		_:
			return failed


static func inverse(payload: Dictionary, world: AuthoringWorld) -> Dictionary:
	if world == null:
		return {}
	var decoded: EditPayload = decode(payload)
	if not decoded.ok:
		return {}
	match decoded.op:
		EditOpNames.PLACE:
			return {
				"op": EditOpNames.REMOVE,
				"entity_id": decoded.record.entity_id,
			}
		EditOpNames.REMOVE:
			var existing: SharedComponentRecord = world.get_record(decoded.entity_id)
			if existing == null:
				return {}
			return {
				"op": EditOpNames.PLACE,
				"record": existing.to_dictionary(),
			}
		EditOpNames.SET_COMPONENT:
			var previous: SharedComponentRecord = world.get_record(decoded.record.entity_id)
			if previous == null:
				return {}
			return {
				"op": EditOpNames.SET_COMPONENT,
				"record": previous.to_dictionary(),
			}
		_:
			return {}


static func _decode_record_op(payload: Dictionary, op_name: String, failed: EditPayload) -> EditPayload:
	if not _exactly(payload, PackedStringArray(["op", "record"])):
		return failed
	var raw: Variant = payload["record"]
	if typeof(raw) != TYPE_DICTIONARY:
		return failed
	var bag: Dictionary = raw
	var record: SharedComponentRecord = SharedComponentRecord.from_dictionary(bag)
	if record == null:
		return failed
	var decoded: EditPayload = EditPayload.new()
	decoded.ok = true
	decoded.op = op_name
	decoded.entity_id = record.entity_id
	decoded.record = record
	return decoded


static func _decode_remove(payload: Dictionary, failed: EditPayload) -> EditPayload:
	if not _exactly(payload, PackedStringArray(["op", "entity_id"])):
		return failed
	if typeof(payload["entity_id"]) != TYPE_INT:
		return failed
	var parsed_id: int = payload["entity_id"]
	if not SharedIds.is_valid(parsed_id):
		return failed
	var decoded: EditPayload = EditPayload.new()
	decoded.ok = true
	decoded.op = EditOpNames.REMOVE
	decoded.entity_id = parsed_id
	return decoded


static func _exactly(source: Dictionary, keys: PackedStringArray) -> bool:
	if source.size() != keys.size():
		return false
	for key: String in keys:
		if not source.has(key):
			return false
	return true
