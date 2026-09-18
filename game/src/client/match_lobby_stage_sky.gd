class_name MatchLobbyStageSky
extends RefCounted

## Stage collaborator so `match_lobby_stage.gd` stays under E9.
## Resolves `sky_id` from a course JSON or a compiled bundle, then hangs it
## on the TRAPRUSH SnapshotCamera only.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")


static func apply_from_path(map: MatchSnapshotMap, path: String) -> bool:
	if map == null:
		return false
	map.ensure_rig()
	if path.is_empty():
		return SharedSkyEnvironment.apply_to_camera(
			map.camera_node(), SharedSkyCatalog.DEFAULT_SKY_ID
		)
	return apply_from_world(map, AuthoringDocumentGd.load_from_path(path))


static func apply_from_bundle(map: MatchSnapshotMap, bundle: SimulationBundle) -> bool:
	if map == null:
		return false
	map.ensure_rig()
	var sky_id: int = SharedSkyCatalog.DEFAULT_SKY_ID
	if bundle != null:
		sky_id = SharedSkyCatalog.sky_id_from_bag(bundle.environment)
	return SharedSkyEnvironment.apply_to_camera(map.camera_node(), sky_id)


static func apply_from_world(map: MatchSnapshotMap, world: AuthoringWorld) -> bool:
	if map == null:
		return false
	map.ensure_rig()
	return SharedSkyEnvironment.apply_to_camera(map.camera_node(), _sky_id_from_world(world))


static func _sky_id_from_world(world: AuthoringWorld) -> int:
	if world == null:
		return SharedSkyCatalog.DEFAULT_SKY_ID
	var found: int = -1
	for entity_id: int in world.entity_ids():
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			continue
		var sky_id: int = SharedSkyCatalog.sky_id_from_components(record.components)
		if sky_id < 0:
			continue
		if found >= 0:
			return SharedSkyCatalog.DEFAULT_SKY_ID
		found = sky_id
	if found < 0:
		return SharedSkyCatalog.DEFAULT_SKY_ID
	return found
