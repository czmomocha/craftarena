class_name TraprushTopologyCompilerBags
extends RefCounted

## Occupancy and portal bags for topology compile.
## Public compile() stays on TraprushTopologyCompiler so this file stays under E9.

const FieldsGd := preload("res://src/ugc/traprush_topology_compiler_fields.gd")


static func collect_occupancy(
	world: AuthoringWorld, used_assets: Dictionary[int, int]
) -> Dictionary:
	var pads: Array[Dictionary] = []
	var finish_list: Array[Dictionary] = []
	var destructible_list: Array[Dictionary] = []
	var hazard_list: Array[Dictionary] = []
	var solid_list: Array[Dictionary] = []
	var pickup_list: Array[Dictionary] = []
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			return {"ok": false}
		var next_asset: Dictionary = FieldsGd.asset_ref(record)
		if next_asset.is_empty():
			return {"ok": false}
		if record.components.has(SharedComponentNames.INVENTORY):
			if not _append_pickup(entity_id, record, next_asset, used_assets, pickup_list):
				return {"ok": false}
			continue
		if FieldsGd.has_finish_tag(record):
			if not _append_finish(entity_id, record, next_asset, used_assets, finish_list):
				return {"ok": false}
			continue
		if FieldsGd.has_solid_tag(record):
			if not _append_solid(entity_id, record, next_asset, used_assets, solid_list):
				return {"ok": false}
			continue
		if record.components.has(SharedComponentNames.DESTRUCTIBLE):
			if not _append_destructible(entity_id, record, next_asset, used_assets, destructible_list):
				return {"ok": false}
			continue
		if record.components.has(SharedComponentNames.HAZARD):
			if not _append_hazard(entity_id, record, next_asset, used_assets, hazard_list):
				return {"ok": false}
			continue
		if not record.components.has(SharedComponentNames.CHECKPOINT):
			continue
		if not _append_pad(entity_id, record, next_asset, used_assets, pads):
			return {"ok": false}
	return {
		"ok": true,
		"pads": pads,
		"finish": finish_list,
		"destructibles": destructible_list,
		"hazards": hazard_list,
		"solids": solid_list,
		"pickups": pickup_list,
	}


static func collect_portals(
	world: AuthoringWorld, used_assets: Dictionary[int, int]
) -> Dictionary:
	var portals: Array[Dictionary] = []
	var links: Array[Dictionary] = world.portal_links()
	for link: Dictionary in links:
		var kind: String = link.get("kind", "")
		if kind == AuthoringPortalKinds.DANGLING:
			continue
		if kind != AuthoringPortalKinds.TWO_WAY and kind != AuthoringPortalKinds.ONE_WAY:
			return {"ok": false}
		var dest_id: int = link.get("dest_id", 0)
		var dest: SharedComponentRecord = world.get_record(dest_id)
		if dest == null:
			return {"ok": false}
		var dest_pose: Dictionary = FieldsGd.transform_xyz(dest)
		if dest_pose.is_empty():
			return {"ok": false}
		var source_id: int = link.get("source_id", 0)
		if source_id < 1:
			return {"ok": false}
		var source: SharedComponentRecord = world.get_record(source_id)
		if source == null:
			return {"ok": false}
		var source_pose: Dictionary = FieldsGd.transform_xyz(source)
		if source_pose.is_empty():
			return {"ok": false}
		var source_asset: Dictionary = FieldsGd.asset_ref(source)
		if source_asset.is_empty():
			return {"ok": false}
		var dest_yaw_bam: int = link.get("dest_yaw_bam", 0)
		portals.append(FieldsGd.with_asset({
			"entity_id": source_id,
			"target_id": dest_id,
			"kind": kind,
			"x": source_pose["x"],
			"y": source_pose["y"],
			"z": source_pose["z"],
			"dest_x": dest_pose["x"],
			"dest_y": dest_pose["y"],
			"dest_z": dest_pose["z"],
			"dest_yaw_bam": dest_yaw_bam,
		}, source_asset, used_assets))
	return {"ok": true, "portals": portals}


static func _append_pickup(
	entity_id: int,
	record: SharedComponentRecord,
	next_asset: Dictionary,
	used_assets: Dictionary[int, int],
	pickup_list: Array[Dictionary]
) -> bool:
	if FieldsGd.has_finish_tag(record):
		return false
	if FieldsGd.has_solid_tag(record):
		return false
	if record.components.has(SharedComponentNames.CHECKPOINT):
		return false
	if record.components.has(SharedComponentNames.PORTAL):
		return false
	if record.components.has(SharedComponentNames.DESTRUCTIBLE):
		return false
	if record.components.has(SharedComponentNames.HAZARD):
		return false
	var pickup_pose: Dictionary = FieldsGd.transform_xyz(record)
	if pickup_pose.is_empty():
		return false
	var pickup_kind: String = FieldsGd.inventory_kind(record)
	if pickup_kind.is_empty():
		return false
	pickup_list.append(FieldsGd.with_asset({
		"entity_id": entity_id,
		"x": pickup_pose["x"],
		"y": pickup_pose["y"],
		"z": pickup_pose["z"],
		"kind": pickup_kind,
	}, next_asset, used_assets))
	return true


static func _append_finish(
	entity_id: int,
	record: SharedComponentRecord,
	next_asset: Dictionary,
	used_assets: Dictionary[int, int],
	finish_list: Array[Dictionary]
) -> bool:
	if FieldsGd.has_solid_tag(record):
		return false
	if record.components.has(SharedComponentNames.CHECKPOINT):
		return false
	if record.components.has(SharedComponentNames.PORTAL):
		return false
	if record.components.has(SharedComponentNames.DESTRUCTIBLE):
		return false
	if record.components.has(SharedComponentNames.HAZARD):
		return false
	var finish_pose: Dictionary = FieldsGd.transform_xyz(record)
	if finish_pose.is_empty():
		return false
	finish_list.append(FieldsGd.with_asset({
		"entity_id": entity_id,
		"x": finish_pose["x"],
		"y": finish_pose["y"],
		"z": finish_pose["z"],
	}, next_asset, used_assets))
	return true


static func _append_solid(
	entity_id: int,
	record: SharedComponentRecord,
	next_asset: Dictionary,
	used_assets: Dictionary[int, int],
	solid_list: Array[Dictionary]
) -> bool:
	if record.components.has(SharedComponentNames.CHECKPOINT):
		return false
	if record.components.has(SharedComponentNames.PORTAL):
		return false
	if record.components.has(SharedComponentNames.DESTRUCTIBLE):
		return false
	if record.components.has(SharedComponentNames.HAZARD):
		return false
	var solid_pose: Dictionary = FieldsGd.transform_xyz(record)
	if solid_pose.is_empty():
		return false
	solid_list.append(FieldsGd.with_asset({
		"entity_id": entity_id,
		"x": solid_pose["x"],
		"y": solid_pose["y"],
		"z": solid_pose["z"],
	}, next_asset, used_assets))
	return true


static func _append_destructible(
	entity_id: int,
	record: SharedComponentRecord,
	next_asset: Dictionary,
	used_assets: Dictionary[int, int],
	destructible_list: Array[Dictionary]
) -> bool:
	if record.components.has(SharedComponentNames.CHECKPOINT):
		return false
	if record.components.has(SharedComponentNames.PORTAL):
		return false
	if record.components.has(SharedComponentNames.HAZARD):
		return false
	var crate_pose: Dictionary = FieldsGd.transform_xyz(record)
	if crate_pose.is_empty():
		return false
	var crate_body: Dictionary = FieldsGd.destructible_body(record)
	if crate_body.is_empty():
		return false
	destructible_list.append(FieldsGd.with_asset({
		"entity_id": entity_id,
		"x": crate_pose["x"],
		"y": crate_pose["y"],
		"z": crate_pose["z"],
		"durability": crate_body["durability"],
	}, next_asset, used_assets))
	return true


static func _append_hazard(
	entity_id: int,
	record: SharedComponentRecord,
	next_asset: Dictionary,
	used_assets: Dictionary[int, int],
	hazard_list: Array[Dictionary]
) -> bool:
	if record.components.has(SharedComponentNames.CHECKPOINT):
		return false
	if record.components.has(SharedComponentNames.PORTAL):
		return false
	var hazard_pose: Dictionary = FieldsGd.transform_xyz(record)
	if hazard_pose.is_empty():
		return false
	var hazard_body: Dictionary = FieldsGd.hazard_body(record)
	if hazard_body.is_empty():
		return false
	hazard_list.append(FieldsGd.with_asset({
		"entity_id": entity_id,
		"x": hazard_pose["x"],
		"y": hazard_pose["y"],
		"z": hazard_pose["z"],
		"cooldown_ticks": hazard_body["cooldown_ticks"],
	}, next_asset, used_assets))
	return true


static func _append_pad(
	entity_id: int,
	record: SharedComponentRecord,
	next_asset: Dictionary,
	used_assets: Dictionary[int, int],
	pads: Array[Dictionary]
) -> bool:
	var pose: Dictionary = FieldsGd.transform_xyz(record)
	if pose.is_empty():
		return false
	var checkpoint: Dictionary = FieldsGd.checkpoint_body(record)
	if checkpoint.is_empty():
		return false
	pads.append(FieldsGd.with_asset({
		"entity_id": entity_id,
		"x": pose["x"],
		"y": pose["y"],
		"z": pose["z"],
		"order": checkpoint["order"],
		"respawn_dx": checkpoint["respawn_dx"],
		"respawn_dy": checkpoint["respawn_dy"],
		"respawn_dz": checkpoint["respawn_dz"],
	}, next_asset, used_assets))
	return true
