class_name AuthoringDocument
extends RefCounted

## Shared JSON snapshot of AuthoringWorld for desktop_full and web_light.
## Field list owner: CD-32 §1.4. v1 has no Rule VM graph and no surface name.
## Godot JSON.parse_string may yield whole-number floats; decode coerces those
## that round-trip through int. Stored bags remain int.

const SCHEMA_VERSION: int = 1
const FIELD_SCHEMA_VERSION: String = "schema_version"
const FIELD_CELL: String = "cell"
const FIELD_REVISION: String = "revision"
const FIELD_ENTITIES: String = "entities"


static func encode(world: AuthoringWorld) -> Dictionary:
	if world == null or world.grid == null:
		return {}
	var entities: Array = []
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var stored: SharedComponentRecord = world.get_record(entity_id)
		if stored == null:
			return {}
		entities.append(stored.to_dictionary())
	return {
		FIELD_SCHEMA_VERSION: SCHEMA_VERSION,
		FIELD_CELL: world.grid.cell,
		FIELD_REVISION: world.revision,
		FIELD_ENTITIES: entities,
	}


static func decode(data: Dictionary) -> AuthoringWorld:
	var coerced: Variant = _coerce_json_ints(data)
	if typeof(coerced) != TYPE_DICTIONARY:
		return null
	var body: Dictionary = coerced
	if body.size() != 4:
		return null
	if not body.has(FIELD_SCHEMA_VERSION) or typeof(body[FIELD_SCHEMA_VERSION]) != TYPE_INT:
		return null
	var version: int = body[FIELD_SCHEMA_VERSION]
	if version != SCHEMA_VERSION:
		return null
	if not body.has(FIELD_CELL) or typeof(body[FIELD_CELL]) != TYPE_INT:
		return null
	var cell: int = body[FIELD_CELL]
	if not body.has(FIELD_REVISION) or typeof(body[FIELD_REVISION]) != TYPE_INT:
		return null
	var revision: int = body[FIELD_REVISION]
	if not body.has(FIELD_ENTITIES) or typeof(body[FIELD_ENTITIES]) != TYPE_ARRAY:
		return null
	var raw_entities: Array = body[FIELD_ENTITIES]
	var records: Array[SharedComponentRecord] = []
	for item: Variant in raw_entities:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var bag: Dictionary = item
		var record: SharedComponentRecord = SharedComponentRecord.from_dictionary(bag)
		if record == null:
			return null
		records.append(record)
	var world: AuthoringWorld = AuthoringWorld.new()
	if not world.try_restore(records, revision, cell):
		return null
	return world


static func load_json(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = parsed
	return body


static func load_from_path(path: String) -> AuthoringWorld:
	return decode(load_json(path))


static func _coerce_json_ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			var number: float = value
			if not is_finite(number):
				return value
			var as_int: int = int(number)
			if float(as_int) != number:
				return value
			return as_int
		TYPE_ARRAY:
			var items: Array = value
			var next_items: Array = []
			for item: Variant in items:
				next_items.append(_coerce_json_ints(item))
			return next_items
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var next_body: Dictionary = {}
			for key: Variant in source:
				next_body[key] = _coerce_json_ints(source[key])
			return next_body
		_:
			return value
