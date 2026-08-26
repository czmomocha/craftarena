class_name TraprushTopologyCompiler
extends RefCounted

## Compiles an AuthoringWorld into a v1 TRAPRUSH SimulationBundle.
## Whole-world topology, not an incremental subgraph. Dangling portals are
## omitted. A checkpoint or a classified two_way / one_way portal without
## source or dest transform fails the whole compile. Portal bags include the
## source occupancy pose (x/y/z) and dest landing pose. Finish occupancy is
## a zone whose tags include "finish"; missing transform or two finish
## zones fail the whole compile. Checkpoint or portal on the same entity
## as a finish zone also fails. Destructible bags need transform and
## durability; sharing an entity with checkpoint, portal, finish, or hazard
## fails. Hazard bags need transform and cooldown_ticks; sharing an entity
## with checkpoint, portal, finish, or destructible fails. Not a new EDIT
## op. Never settlement.

const FINISH_ZONE_TAG: String = "finish"


static func compile(world: AuthoringWorld) -> SimulationBundle:
	if world == null or world.grid == null:
		return null
	var pads: Array[Dictionary] = []
	var finish_list: Array[Dictionary] = []
	var destructible_list: Array[Dictionary] = []
	var hazard_list: Array[Dictionary] = []
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			return null
		if _has_finish_tag(record):
			if record.components.has(SharedComponentNames.CHECKPOINT):
				return null
			if record.components.has(SharedComponentNames.PORTAL):
				return null
			if record.components.has(SharedComponentNames.DESTRUCTIBLE):
				return null
			if record.components.has(SharedComponentNames.HAZARD):
				return null
			var finish_pose: Dictionary = _transform_xyz(record)
			if finish_pose.is_empty():
				return null
			finish_list.append({
				"entity_id": entity_id,
				"x": finish_pose["x"],
				"y": finish_pose["y"],
				"z": finish_pose["z"],
			})
			continue
		if record.components.has(SharedComponentNames.DESTRUCTIBLE):
			if record.components.has(SharedComponentNames.CHECKPOINT):
				return null
			if record.components.has(SharedComponentNames.PORTAL):
				return null
			if record.components.has(SharedComponentNames.HAZARD):
				return null
			var crate_pose: Dictionary = _transform_xyz(record)
			if crate_pose.is_empty():
				return null
			var crate_body: Dictionary = _destructible_body(record)
			if crate_body.is_empty():
				return null
			destructible_list.append({
				"entity_id": entity_id,
				"x": crate_pose["x"],
				"y": crate_pose["y"],
				"z": crate_pose["z"],
				"durability": crate_body["durability"],
			})
			continue
		if record.components.has(SharedComponentNames.HAZARD):
			if record.components.has(SharedComponentNames.CHECKPOINT):
				return null
			if record.components.has(SharedComponentNames.PORTAL):
				return null
			var hazard_pose: Dictionary = _transform_xyz(record)
			if hazard_pose.is_empty():
				return null
			var hazard_body: Dictionary = _hazard_body(record)
			if hazard_body.is_empty():
				return null
			hazard_list.append({
				"entity_id": entity_id,
				"x": hazard_pose["x"],
				"y": hazard_pose["y"],
				"z": hazard_pose["z"],
				"cooldown_ticks": hazard_body["cooldown_ticks"],
			})
			continue
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
		var source: SharedComponentRecord = world.get_record(source_id)
		if source == null:
			return null
		var source_pose: Dictionary = _transform_xyz(source)
		if source_pose.is_empty():
			return null
		var dest_yaw_bam: int = link.get("dest_yaw_bam", 0)
		var dest_x: int = dest_pose["x"]
		var dest_y: int = dest_pose["y"]
		var dest_z: int = dest_pose["z"]
		var source_x: int = source_pose["x"]
		var source_y: int = source_pose["y"]
		var source_z: int = source_pose["z"]
		portals.append({
			"entity_id": source_id,
			"target_id": dest_id,
			"kind": kind,
			"x": source_x,
			"y": source_y,
			"z": source_z,
			"dest_x": dest_x,
			"dest_y": dest_y,
			"dest_z": dest_z,
			"dest_yaw_bam": dest_yaw_bam,
		})
	if finish_list.size() > 1:
		return null
	var body: Dictionary = {
		SimulationBundle.FIELD_SCHEMA_VERSION: SimulationBundle.SCHEMA_VERSION,
		SimulationBundle.FIELD_CELL: world.grid.cell,
		SimulationBundle.FIELD_SOURCE_REVISION: world.revision,
		SimulationBundle.FIELD_PADS: pads,
		SimulationBundle.FIELD_PORTALS: portals,
		SimulationBundle.FIELD_FINISH: finish_list,
		SimulationBundle.FIELD_DESTRUCTIBLES: destructible_list,
		SimulationBundle.FIELD_HAZARDS: hazard_list,
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


static func _destructible_body(record: SharedComponentRecord) -> Dictionary:
	var raw: Variant = record.components[SharedComponentNames.DESTRUCTIBLE]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	if typeof(body.get("durability", null)) != TYPE_INT:
		return {}
	var durability: int = body["durability"]
	if durability < 0:
		return {}
	return {"durability": durability}


static func _hazard_body(record: SharedComponentRecord) -> Dictionary:
	var raw: Variant = record.components[SharedComponentNames.HAZARD]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	if typeof(body.get("cooldown_ticks", null)) != TYPE_INT:
		return {}
	var cooldown_ticks: int = body["cooldown_ticks"]
	if cooldown_ticks < 0:
		return {}
	return {"cooldown_ticks": cooldown_ticks}


static func _has_finish_tag(record: SharedComponentRecord) -> bool:
	if not record.components.has(SharedComponentNames.ZONE):
		return false
	var raw: Variant = record.components[SharedComponentNames.ZONE]
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var zone: Dictionary = raw
	var tags_raw: Variant = zone.get("tags", [])
	if typeof(tags_raw) != TYPE_ARRAY:
		return false
	var tags: Array = tags_raw
	for item: Variant in tags:
		if typeof(item) != TYPE_STRING:
			continue
		var tag: String = item
		if tag == FINISH_ZONE_TAG:
			return true
	return false
