class_name SimulationBundle
extends RefCounted

## v1 TRAPRUSH topology compile of AuthoringWorld. Field list owner: CD-42 §3.4.
## Pads and two_way / one_way portals only. Dangling portals are omitted.
## Godot JSON.parse_string may yield whole-number floats; decode coerces those
## that round-trip through int. Not a signed binary. Not a Rule VM graph.

const SCHEMA_VERSION: int = 1
const FIELD_SCHEMA_VERSION: String = "schema_version"
const FIELD_CELL: String = "cell"
const FIELD_SOURCE_REVISION: String = "source_revision"
const FIELD_PADS: String = "pads"
const FIELD_PORTALS: String = "portals"

var cell: int = 0
var source_revision: int = 0
var pads: Array[Dictionary] = []
var portals: Array[Dictionary] = []


static func from_dictionary(data: Dictionary) -> SimulationBundle:
	var coerced: Variant = _coerce_json_ints(data)
	if typeof(coerced) != TYPE_DICTIONARY:
		return null
	var body: Dictionary = coerced
	if body.size() != 5:
		return null
	if not body.has(FIELD_SCHEMA_VERSION) or typeof(body[FIELD_SCHEMA_VERSION]) != TYPE_INT:
		return null
	var version: int = body[FIELD_SCHEMA_VERSION]
	if version != SCHEMA_VERSION:
		return null
	if not body.has(FIELD_CELL) or typeof(body[FIELD_CELL]) != TYPE_INT:
		return null
	var cell: int = body[FIELD_CELL]
	if cell < 1:
		return null
	if not body.has(FIELD_SOURCE_REVISION) or typeof(body[FIELD_SOURCE_REVISION]) != TYPE_INT:
		return null
	var source_revision: int = body[FIELD_SOURCE_REVISION]
	if source_revision < 0:
		return null
	if not body.has(FIELD_PADS) or typeof(body[FIELD_PADS]) != TYPE_ARRAY:
		return null
	if not body.has(FIELD_PORTALS) or typeof(body[FIELD_PORTALS]) != TYPE_ARRAY:
		return null
	var pads: Array[Dictionary] = []
	var pad_ids: Dictionary[int, bool] = {}
	var raw_pads: Array = body[FIELD_PADS]
	for item: Variant in raw_pads:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var bag: Dictionary = item
		var pad: Dictionary = _parse_pad(bag)
		if pad.is_empty():
			return null
		var pad_id: int = pad["entity_id"]
		if pad_ids.has(pad_id):
			return null
		pad_ids[pad_id] = true
		pads.append(pad)
	var portals: Array[Dictionary] = []
	var portal_ids: Dictionary[int, bool] = {}
	var raw_portals: Array = body[FIELD_PORTALS]
	for item: Variant in raw_portals:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var bag: Dictionary = item
		var portal: Dictionary = _parse_portal(bag)
		if portal.is_empty():
			return null
		var portal_id: int = portal["entity_id"]
		if portal_ids.has(portal_id):
			return null
		portal_ids[portal_id] = true
		portals.append(portal)
	var bundle: SimulationBundle = SimulationBundle.new()
	bundle.cell = cell
	bundle.source_revision = source_revision
	bundle.pads = pads
	bundle.portals = portals
	return bundle


func to_dictionary() -> Dictionary:
	var pad_list: Array = []
	for pad: Dictionary in pads:
		pad_list.append(pad.duplicate(true))
	var portal_list: Array = []
	for portal: Dictionary in portals:
		portal_list.append(portal.duplicate(true))
	return {
		FIELD_SCHEMA_VERSION: SCHEMA_VERSION,
		FIELD_CELL: cell,
		FIELD_SOURCE_REVISION: source_revision,
		FIELD_PADS: pad_list,
		FIELD_PORTALS: portal_list,
	}


static func _parse_pad(body: Dictionary) -> Dictionary:
	if body.size() != 8:
		return {}
	if not _int_at_least(body, "entity_id", 1):
		return {}
	if not _is_int_field(body, "x"):
		return {}
	if not _is_int_field(body, "y"):
		return {}
	if not _is_int_field(body, "z"):
		return {}
	if not _int_at_least(body, "order", 0):
		return {}
	if not _is_int_field(body, "respawn_dx"):
		return {}
	if not _is_int_field(body, "respawn_dy"):
		return {}
	if not _is_int_field(body, "respawn_dz"):
		return {}
	return {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"order": body["order"],
		"respawn_dx": body["respawn_dx"],
		"respawn_dy": body["respawn_dy"],
		"respawn_dz": body["respawn_dz"],
	}


static func _parse_portal(body: Dictionary) -> Dictionary:
	if body.size() != 7:
		return {}
	if not _int_at_least(body, "entity_id", 1):
		return {}
	if not _int_at_least(body, "target_id", 1):
		return {}
	if not body.has("kind") or typeof(body["kind"]) != TYPE_STRING:
		return {}
	var kind: String = body["kind"]
	if kind != AuthoringPortalKinds.TWO_WAY and kind != AuthoringPortalKinds.ONE_WAY:
		return {}
	if not _is_int_field(body, "dest_x"):
		return {}
	if not _is_int_field(body, "dest_y"):
		return {}
	if not _is_int_field(body, "dest_z"):
		return {}
	if not _is_int_field(body, "dest_yaw_bam"):
		return {}
	return {
		"entity_id": body["entity_id"],
		"target_id": body["target_id"],
		"kind": kind,
		"dest_x": body["dest_x"],
		"dest_y": body["dest_y"],
		"dest_z": body["dest_z"],
		"dest_yaw_bam": body["dest_yaw_bam"],
	}


static func _int_at_least(body: Dictionary, key: String, minimum: int) -> bool:
	if not _is_int_field(body, key):
		return false
	var value: int = body[key]
	return value >= minimum


static func _is_int_field(body: Dictionary, key: String) -> bool:
	return body.has(key) and typeof(body[key]) == TYPE_INT


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
