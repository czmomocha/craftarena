class_name RuleVmHost
extends RefCounted

## In-memory Rule VM host for the chapter-4 Query / Action subset.
## Reads and writes stay on this object until commit(). Over-gas / failed
## runs call rollback() so Spawn / Despawn / ApplyEffect / EmitGameEvent
## do not leak. This is not a SimulationWorld and does not change official
## courses. Preview P3 safety is a later chapter.

const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")

var fields: Dictionary = {}
var zone_counts: Dictionary = {}
var spawned: Array[Dictionary] = []
var despawned: PackedInt64Array = PackedInt64Array()
var effects: Array[Dictionary] = []
var events: Array[Dictionary] = []

var _next_entity: int = 1
var _pending_spawns: Array[Dictionary] = []
var _pending_despawns: PackedInt64Array = PackedInt64Array()
var _pending_effects: Array[Dictionary] = []
var _pending_events: Array[Dictionary] = []
var _pending_next: int = 1


func begin() -> void:
	_pending_spawns.clear()
	_pending_despawns = PackedInt64Array()
	_pending_effects.clear()
	_pending_events.clear()
	_pending_next = _next_entity


func commit() -> void:
	for item: Dictionary in _pending_spawns:
		spawned.append(item)
	for entity_id: int in _pending_despawns:
		despawned.append(entity_id)
	for item: Dictionary in _pending_effects:
		effects.append(item)
	for item: Dictionary in _pending_events:
		events.append(item)
	_next_entity = _pending_next
	begin()


func rollback() -> void:
	begin()


func put_field(entity_id: int, field_id: int, value: int) -> void:
	fields[_field_key(entity_id, field_id)] = value


func put_zone_count(zone_id: int, tag_id: int, count: int) -> void:
	if count < 0:
		count = 0
	zone_counts[_zone_key(zone_id, tag_id)] = count


func get_field(entity_id: int, field_id: int) -> Dictionary:
	if not Opcodes.field_ok(field_id):
		return _refuse()
	var key: int = _field_key(entity_id, field_id)
	if not fields.has(key):
		return _refuse()
	var value: int = fields[key]
	return {Opcodes.KEY_OK: true, Opcodes.KEY_VALUE: value}


func count_in_zone(zone_id: int, tag_id: int) -> Dictionary:
	if not Opcodes.tag_ok(tag_id):
		return _refuse()
	var key: int = _zone_key(zone_id, tag_id)
	var count: int = 0
	if zone_counts.has(key):
		count = zone_counts[key]
	if count < 0:
		return _refuse()
	return {Opcodes.KEY_OK: true, Opcodes.KEY_COUNT: count}


func spawn(archetype: int, marker: int, count: int) -> Dictionary:
	if not Opcodes.archetype_ok(archetype):
		return _refuse()
	if count != 1:
		return _refuse()
	var entity_id: int = _pending_next
	_pending_next += 1
	_pending_spawns.append({
		Opcodes.KEY_ARCHETYPE: archetype,
		"marker": marker,
		Opcodes.KEY_COUNT: count,
		"entity_id": entity_id,
	})
	return {Opcodes.KEY_OK: true, "entity_id": entity_id}


func despawn(entity_id: int) -> Dictionary:
	if entity_id < 1:
		return _refuse()
	_pending_despawns.append(entity_id)
	return {Opcodes.KEY_OK: true}


func apply_effect(target: int, effect: int, magnitude: int) -> Dictionary:
	if target < 1:
		return _refuse()
	if not Opcodes.effect_ok(effect):
		return _refuse()
	_pending_effects.append({
		"target": target,
		Opcodes.KEY_EFFECT: effect,
		Opcodes.KEY_MAGNITUDE: magnitude,
	})
	return {Opcodes.KEY_OK: true}


func emit_event(event_id: int, payload: int) -> Dictionary:
	if not Opcodes.event_name_ok(event_id):
		return _refuse()
	_pending_events.append({
		Opcodes.KEY_EVENT: event_id,
		"payload": payload,
	})
	return {Opcodes.KEY_OK: true}


func _field_key(entity_id: int, field_id: int) -> int:
	return entity_id * 256 + field_id


func _zone_key(zone_id: int, tag_id: int) -> int:
	return zone_id * 256 + tag_id


func _refuse() -> Dictionary:
	return {Opcodes.KEY_OK: false, Opcodes.KEY_REASON: Opcodes.REASON_HOST_REFUSED}
