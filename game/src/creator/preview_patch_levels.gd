class_name PreviewPatchLevels
extends RefCounted

## CD-33 P0–P4 names as apply grades for AuthoringPreview.
## Mapping from v1 bags to a grade is CD-32; grade definitions stay on CD-33.
## P3 has no Rule VM yet. mover is whole-bag P2 (path is topology).

const P0: String = "p0"
const P1: String = "p1"
const P2: String = "p2"
const P3: String = "p3"
const P4: String = "p4"

const ALL: PackedStringArray = [
	P0,
	P1,
	P2,
	P3,
	P4,
]

const _P0_COMPONENTS: PackedStringArray = [
	SharedComponentNames.REPLICATION,
	SharedComponentNames.TEAM,
	SharedComponentNames.SCORE,
	SharedComponentNames.INVENTORY,
]

const _P1_COMPONENTS: PackedStringArray = [
	SharedComponentNames.HEALTH,
	SharedComponentNames.HAZARD,
	SharedComponentNames.DESTRUCTIBLE,
	SharedComponentNames.VELOCITY,
	SharedComponentNames.TOWER,
]


static func contains(level: String) -> bool:
	return ALL.has(level)


static func rank(level: String) -> int:
	match level:
		P0:
			return 0
		P1:
			return 1
		P2:
			return 2
		P3:
			return 3
		P4:
			return 4
		_:
			return -1


static func classify(command: SharedCommand, world: AuthoringWorld) -> String:
	if command == null:
		return ""
	if typeof(command.payload) != TYPE_DICTIONARY:
		return ""
	var decoded: EditPayload = EditPayload.decode(command.payload)
	if not decoded.ok:
		return ""
	if decoded.op == EditOpNames.PLACE or decoded.op == EditOpNames.REMOVE:
		return P2
	if decoded.op != EditOpNames.SET_COMPONENT or decoded.record == null:
		return ""
	var names: Dictionary[String, bool] = {}
	_add_component_names(names, decoded.record.components)
	if world != null:
		var previous: SharedComponentRecord = world.get_record(decoded.record.entity_id)
		if previous != null:
			_add_component_names(names, previous.components)
	return _level_for_names(names)


static func _add_component_names(names: Dictionary[String, bool], components: Dictionary) -> void:
	var keys: Array = components.keys()
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING:
			continue
		var component_name: String = key
		names[component_name] = true


static func _level_for_names(names: Dictionary[String, bool]) -> String:
	var required: String = P0
	for component_name: String in names:
		var component_rank: int = _component_rank(component_name)
		if component_rank > rank(required):
			required = ALL[component_rank]
	return required


static func _component_rank(component_name: String) -> int:
	if _P0_COMPONENTS.has(component_name):
		return 0
	if _P1_COMPONENTS.has(component_name):
		return 1
	return 2
