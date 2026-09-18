class_name AuthoringEditorShellPlaceSky
extends RefCounted

## place / set_component payloads for the world-level `environment` sky.
## Public try_set_sky stays on the shell facade so place.gd stays under E9.


static func try_set_sky(shell: AuthoringEditorShell, entity_id: int, sky_id: int) -> bool:
	if shell == null or shell.session == null or shell.session.world == null:
		return false
	if not SharedSkyCatalog.is_known(sky_id):
		return false
	var world: AuthoringWorld = shell.session.world
	var existing_id: int = AuthoringPreviewSky.environment_entity_id(world)
	if existing_id == SharedIds.NULL_ID:
		if sky_id == AuthoringPreviewSky.sky_id_from_world(world):
			return true
		if not SharedIds.is_valid(entity_id):
			return false
		return shell.try_edit(place_payload(entity_id, sky_id))
	if _stored_sky_id(world.get_record(existing_id)) == sky_id:
		return true
	return _try_replace(shell, existing_id, sky_id)


static func place_payload(entity_id: int, sky_id: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				SharedComponentNames.ENVIRONMENT: {"sky_id": sky_id},
			},
		},
	}


static func _try_replace(shell: AuthoringEditorShell, entity_id: int, sky_id: int) -> bool:
	var record: SharedComponentRecord = shell.session.world.get_record(entity_id)
	if record == null:
		return false
	var next: Dictionary = record.to_dictionary()
	var components_raw: Variant = next.get("components", {})
	if typeof(components_raw) != TYPE_DICTIONARY:
		return false
	var components: Dictionary = components_raw
	var env: Dictionary = {}
	var env_raw: Variant = components.get(SharedComponentNames.ENVIRONMENT, {})
	if typeof(env_raw) == TYPE_DICTIONARY:
		var typed: Dictionary = env_raw
		env = typed.duplicate(true)
	env["sky_id"] = sky_id
	components[SharedComponentNames.ENVIRONMENT] = env
	next["components"] = components
	return shell.try_edit({"op": "set_component", "record": next})


static func _stored_sky_id(record: SharedComponentRecord) -> int:
	if record == null:
		return -1
	var raw: Variant = record.components.get(SharedComponentNames.ENVIRONMENT, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	var bag: Dictionary = raw
	if typeof(bag.get("sky_id", null)) != TYPE_INT:
		return -1
	return bag["sky_id"]
