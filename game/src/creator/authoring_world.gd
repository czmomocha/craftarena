class_name AuthoringWorld
extends RefCounted

## Mutable bag of Component Schema v1 records. Not a SimulationWorld: no tick,
## occupancy, or Node. Revision counts successful put/remove only.
## This slice is insert-only; replacing a record is a later EditCommand apply.

var revision: int = 0
var _records: Dictionary[int, SharedComponentRecord] = {}


func put(record: SharedComponentRecord) -> bool:
	if record == null:
		return false
	if not SharedIds.is_valid(record.entity_id):
		return false
	if _records.has(record.entity_id):
		return false
	var stored: SharedComponentRecord = SharedComponentRecord.create(record.entity_id, record.components)
	if stored == null:
		return false
	_records[record.entity_id] = stored
	revision += 1
	return true


func remove(entity_id: int) -> bool:
	if not _records.has(entity_id):
		return false
	_records.erase(entity_id)
	revision += 1
	return true


func get_record(entity_id: int) -> SharedComponentRecord:
	if not _records.has(entity_id):
		return null
	var stored: SharedComponentRecord = _records[entity_id]
	return SharedComponentRecord.create(stored.entity_id, stored.components)


func has_entity(entity_id: int) -> bool:
	return _records.has(entity_id)


func entity_count() -> int:
	return _records.size()


func hash_state() -> PackedByteArray:
	var hasher: StateHasher = StateHasher.new()
	hasher.write_s64(revision)
	var ids: Array[int] = []
	for entity_id: int in _records:
		ids.append(entity_id)
	ids.sort()
	for entity_id: int in ids:
		var stored: SharedComponentRecord = _records[entity_id]
		stored.feed_hasher(hasher)
	var digest_hex: String = hasher.digest_hex()
	return digest_hex.hex_decode()
