class_name AuthoringPreviewSky
extends RefCounted

## Preview / Editor 相机上的天空。与对局壳同一套 `SharedSkyEnvironment`，
## 所以两边不会慢慢变成两片天。扫描 `environment` 实体；没有就用默认 id。

const CAMERA_NAME: String = AuthoringPreviewMap.CAMERA_NAME


static func apply(map: AuthoringPreviewMap, world: AuthoringWorld) -> bool:
	if map == null:
		return false
	var camera: Camera3D = map.get_node_or_null(CAMERA_NAME) as Camera3D
	return SharedSkyEnvironment.apply_to_camera(camera, sky_id_from_world(world))


static func sky_id_from_world(world: AuthoringWorld) -> int:
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


static func environment_entity_id(world: AuthoringWorld) -> int:
	if world == null:
		return SharedIds.NULL_ID
	for entity_id: int in world.entity_ids():
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			continue
		if record.components.has(SharedComponentNames.ENVIRONMENT):
			return entity_id
	return SharedIds.NULL_ID
