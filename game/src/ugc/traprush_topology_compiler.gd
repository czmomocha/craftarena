class_name TraprushTopologyCompiler
extends RefCounted

## Compiles an AuthoringWorld into a v1 TRAPRUSH SimulationBundle.
## Whole-world topology, not an incremental subgraph. Dangling portals are
## omitted. A checkpoint or a classified two_way / one_way portal without
## transform fails the whole compile. Not a new EDIT op. Never settlement.

static func compile(world: AuthoringWorld) -> SimulationBundle:
	if world == null or world.grid == null:
		return null
	var pads: Array[Dictionary] = []
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			return null
		if not record.components.has(SharedComponentNames.CHECKPOINT):
			continue
		var pose: Dictionary = _transform_xyz(record)
		if pose.is_empty():
			return null
		var checkpoint: Dictionary = _checkpoint_body(record)
		if checkpoint.is_empty():
			return null
		pads.append({
			"entity_id": entity_id,
			"x": pose["x"],
			"y": pose["y"],
			"z": pose["z"],
			"order": checkpoint["order"],
			"respawn_dx": checkpoint["respawn_dx"],
			"respawn_dy": checkpoint["respawn_dy"],
			"respawn_dz": checkpoint["respawn_dz"],
		})
	var portals: Array[Dictionary] = []
	var links: Array[Dictionary] = world.portal_links()
	for link: Dictionary in links:
		var kind: String = link.get("kind", "")
		if kind == AuthoringPortalKinds.DANGLING:
			continue
		if kind != AuthoringPortalKinds.TWO_WAY and kind != AuthoringPortalKinds.ONE_WAY:
			return null
		var dest_id: int = link.get("dest_id", 0)
		var dest: SharedComponentRecord = world.get_record(dest_id)
		if dest == null:
			return null
		var dest_pose: Dictionary = _transform_xyz(dest)
		if dest_pose.is_empty():
			return null
		var source_id: int = link.get("source_id", 0)
		if source_id < 1:
			return null
		var dest_yaw_bam: int = link.get("dest_yaw_bam", 0)
		var dest_x: int = dest_pose["x"]
		var dest_y: int = dest_pose["y"]
		var dest_z: int = dest_pose["z"]
		portals.append({
			"entity_id": source_id,
			"target_id": dest_id,
			"kind": kind,
			"dest_x": dest_x,
			"dest_y": dest_y,
			"dest_z": dest_z,
			"dest_yaw_bam": dest_yaw_bam,
		})
	var body: Dictionary = {
		SimulationBundle.FIELD_SCHEMA_VERSION: SimulationBundle.SCHEMA_VERSION,
		SimulationBundle.FIELD_CELL: world.grid.cell,
		SimulationBundle.FIELD_SOURCE_REVISION: world.revision,
		SimulationBundle.FIELD_PADS: pads,
		SimulationBundle.FIELD_PORTALS: portals,
	}
	return SimulationBundle.from_dictionary(body)


static func _transform_xyz(record: SharedComponentRecord) -> Dictionary:
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
	return {"x": body["x"], "y": body["y"], "z": body["z"]}


static func _checkpoint_body(record: SharedComponentRecord) -> Dictionary:
	var raw: Variant = record.components[SharedComponentNames.CHECKPOINT]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	if typeof(body.get("order", null)) != TYPE_INT:
		return {}
	if typeof(body.get("respawn_dx", null)) != TYPE_INT:
		return {}
	if typeof(body.get("respawn_dy", null)) != TYPE_INT:
		return {}
	if typeof(body.get("respawn_dz", null)) != TYPE_INT:
		return {}
	var order: int = body["order"]
	if order < 0:
		return {}
	return {
		"order": order,
		"respawn_dx": body["respawn_dx"],
		"respawn_dy": body["respawn_dy"],
		"respawn_dz": body["respawn_dz"],
	}
