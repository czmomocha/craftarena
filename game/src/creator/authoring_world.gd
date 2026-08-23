class_name AuthoringWorld
extends RefCounted

## Mutable bag of Component Schema v1 records. Not a SimulationWorld: no tick,
## occupancy, or Node. Revision counts successful put / remove / replace only.
## put is insert-only; replace overwrites an existing id; EditCommand lives on AuthoringSession.
## Transform XYZ must sit on the authoring lattice. portal.target_id may dangle;
## it must not self-loop or point at an existing entity that has no portal.
## Publish-time path / cycle lives on AuthoringReachability, not on put / replace.

var revision: int = 0
var grid: AuthoringGrid = AuthoringGrid.with_default_cell()
var _records: Dictionary[int, SharedComponentRecord] = {}


func _init(p_grid: AuthoringGrid = null) -> void:
	if p_grid != null:
		grid = p_grid


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
	if not _transform_on_grid(stored):
		return false
	var next_records: Dictionary[int, SharedComponentRecord] = _copy_records()
	next_records[stored.entity_id] = stored
	if not _portal_graph_is_legal(next_records):
		return false
	_records = next_records
	revision += 1
	return true


func remove(entity_id: int) -> bool:
	if not _records.has(entity_id):
		return false
	_records.erase(entity_id)
	revision += 1
	return true


func replace(record: SharedComponentRecord) -> bool:
	if record == null:
		return false
	if not SharedIds.is_valid(record.entity_id):
		return false
	if not _records.has(record.entity_id):
		return false
	var stored: SharedComponentRecord = SharedComponentRecord.create(record.entity_id, record.components)
	if stored == null:
		return false
	if not _transform_on_grid(stored):
		return false
	var next_records: Dictionary[int, SharedComponentRecord] = _copy_records()
	next_records[stored.entity_id] = stored
	if not _portal_graph_is_legal(next_records):
		return false
	_records = next_records
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


func entity_ids() -> Array[int]:
	var ids: Array[int] = []
	for entity_id: int in _records:
		ids.append(entity_id)
	ids.sort()
	return ids


func entity_ids_on_floor(floor_index: int) -> Array[int]:
	var ids: Array[int] = []
	for entity_id: int in _records:
		var stored: SharedComponentRecord = _records[entity_id]
		var pose: Dictionary = _transform_xyz(stored)
		if pose.is_empty():
			continue
		var y: int = pose["y"]
		if grid.floor_index(y) == floor_index:
			ids.append(entity_id)
	ids.sort()
	return ids


func portal_links() -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	var source_ids: Array[int] = []
	for entity_id: int in _records:
		var stored: SharedComponentRecord = _records[entity_id]
		if not stored.components.has(SharedComponentNames.PORTAL):
			continue
		source_ids.append(entity_id)
	source_ids.sort()
	for source_id: int in source_ids:
		var stored: SharedComponentRecord = _records[source_id]
		var link: Dictionary = _portal_link_from(stored)
		if not link.is_empty():
			links.append(link)
	return links


func hash_state() -> PackedByteArray:
	var hasher: StateHasher = StateHasher.new()
	hasher.write_s64(revision)
	hasher.write_s64(grid.cell)
	var ids: Array[int] = []
	for entity_id: int in _records:
		ids.append(entity_id)
	ids.sort()
	for entity_id: int in ids:
		var stored: SharedComponentRecord = _records[entity_id]
		stored.feed_hasher(hasher)
	var digest_hex: String = hasher.digest_hex()
	return digest_hex.hex_decode()


func _copy_records() -> Dictionary[int, SharedComponentRecord]:
	var copy: Dictionary[int, SharedComponentRecord] = {}
	for entity_id: int in _records:
		copy[entity_id] = _records[entity_id]
	return copy


func _transform_on_grid(record: SharedComponentRecord) -> bool:
	var pose: Dictionary = _transform_xyz(record)
	if pose.is_empty():
		return true
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	return grid.accepts_xyz(x, y, z)


func _transform_xyz(record: SharedComponentRecord) -> Dictionary:
	if not record.components.has(SharedComponentNames.TRANSFORM):
		return {}
	var raw: Variant = record.components[SharedComponentNames.TRANSFORM]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	if typeof(body.get("x", null)) != TYPE_INT:
		return {}
	if typeof(body.get("y", null)) != TYPE_INT:
		return {}
	if typeof(body.get("z", null)) != TYPE_INT:
		return {}
	var x: int = body["x"]
	var y: int = body["y"]
	var z: int = body["z"]
	return {"x": x, "y": y, "z": z}


func _portal_graph_is_legal(records: Dictionary[int, SharedComponentRecord]) -> bool:
	for entity_id: int in records:
		var stored: SharedComponentRecord = records[entity_id]
		var portal: Dictionary = _portal_body(stored)
		if portal.is_empty():
			continue
		var target_id: int = portal["target_id"]
		if target_id == entity_id:
			return false
		if not records.has(target_id):
			continue
		var dest: SharedComponentRecord = records[target_id]
		if _portal_body(dest).is_empty():
			return false
	return true


func _portal_body(record: SharedComponentRecord) -> Dictionary:
	if not record.components.has(SharedComponentNames.PORTAL):
		return {}
	var raw: Variant = record.components[SharedComponentNames.PORTAL]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	if typeof(body.get("target_id", null)) != TYPE_INT:
		return {}
	if typeof(body.get("yaw_bam", null)) != TYPE_INT:
		return {}
	return body


func _portal_link_from(source: SharedComponentRecord) -> Dictionary:
	var portal: Dictionary = _portal_body(source)
	if portal.is_empty():
		return {}
	var dest_id: int = portal["target_id"]
	var dest_present: bool = _records.has(dest_id)
	var kind: String = AuthoringPortalKinds.DANGLING
	var x: int = 0
	var y: int = 0
	var z: int = 0
	var dest_yaw_bam: int = 0
	if dest_present:
		var dest: SharedComponentRecord = _records[dest_id]
		var dest_portal: Dictionary = _portal_body(dest)
		if dest_portal.is_empty():
			return {}
		var dest_target: int = dest_portal["target_id"]
		if dest_target == source.entity_id:
			kind = AuthoringPortalKinds.TWO_WAY
		else:
			kind = AuthoringPortalKinds.ONE_WAY
		dest_yaw_bam = dest_portal["yaw_bam"]
		var pose: Dictionary = _transform_xyz(dest)
		if not pose.is_empty():
			x = pose["x"]
			y = pose["y"]
			z = pose["z"]
	return {
		"source_id": source.entity_id,
		"dest_id": dest_id,
		"kind": kind,
		"dest_present": dest_present,
		"x": x,
		"y": y,
		"z": z,
		"dest_yaw_bam": dest_yaw_bam,
	}
