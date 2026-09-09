class_name TraprushTopologyCompilerBags
extends RefCounted

## Occupancy and portal bags for topology compile.
## Public compile() stays on TraprushTopologyCompiler so this file stays under E9.

const FieldsGd := preload("res://src/ugc/traprush_topology_compiler_fields.gd")
const TriggersGd := preload("res://src/ugc/traprush_topology_compiler_triggers.gd")


static func collect_occupancy(
	world: AuthoringWorld, used_assets: Dictionary[int, int]
) -> Dictionary:
	var pads: Array[Dictionary] = []
	var finish_list: Array[Dictionary] = []
	var destructible_list: Array[Dictionary] = []
	var hazard_list: Array[Dictionary] = []
	var solid_list: Array[Dictionary] = []
	var pickup_list: Array[Dictionary] = []
	var mover_list: Array[Dictionary] = []
	var conveyor_list: Array[Dictionary] = []
	var launch_list: Array[Dictionary] = []
	var switch_list: Array[Dictionary] = []
	var gate_list: Array[Dictionary] = []
	var energy_wall_list: Array[Dictionary] = []
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			return {"ok": false}
		var next_asset: Dictionary = FieldsGd.asset_ref(record)
		if next_asset.is_empty():
			return {"ok": false}
		if FieldsGd.has_energy_wall_tag(record) and not record.components.has(
			SharedComponentNames.DESTRUCTIBLE
		):
			return {"ok": false}
		if FieldsGd.has_portal_switch_tag(record):
			if FieldsGd.has_solid_tag(record):
				return {"ok": false}
			if record.components.has(SharedComponentNames.DESTRUCTIBLE):
				return {"ok": false}
			if record.components.has(SharedComponentNames.HAZARD):
				return {"ok": false}
			if FieldsGd.has_finish_tag(record):
				return {"ok": false}
			if not record.components.has(SharedComponentNames.PORTAL):
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
			if not _append_solid(
				entity_id,
				record,
				next_asset,
				used_assets,
				solid_list,
				mover_list,
				conveyor_list,
				launch_list,
				switch_list,
				gate_list
			):
				return {"ok": false}
			continue
		if record.components.has(SharedComponentNames.DESTRUCTIBLE):
			if not _append_destructible(
				entity_id, record, next_asset, used_assets, destructible_list, energy_wall_list
			):
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
		"movers": mover_list,
		"conveyors": conveyor_list,
		"launches": launch_list,
		"switches": switch_list,
		"gates": gate_list,
		"energy_walls": energy_wall_list,
	}


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
	solid_list: Array[Dictionary],
	mover_list: Array[Dictionary],
	conveyor_list: Array[Dictionary],
	launch_list: Array[Dictionary],
	switch_list: Array[Dictionary],
	gate_list: Array[Dictionary]
) -> bool:
	if record.components.has(SharedComponentNames.CHECKPOINT):
		return false
	if record.components.has(SharedComponentNames.PORTAL):
		return false
	if record.components.has(SharedComponentNames.DESTRUCTIBLE):
		return false
	if record.components.has(SharedComponentNames.HAZARD):
		return false
	if FieldsGd.has_energy_wall_tag(record):
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
	var mover_bag: Dictionary = {}
	if record.components.has(SharedComponentNames.MOVER):
		mover_bag = _parse_mover(entity_id, record)
		if mover_bag.is_empty():
			return false
		mover_list.append(mover_bag)
	if FieldsGd.has_lift_tag(record):
		if mover_bag.is_empty():
			return false
		var lift_path: Array = mover_bag["path"]
		if not SimulationBundleBags.path_is_vertical(lift_path):
			return false
	var has_conveyor: bool = FieldsGd.has_conveyor_tag(record)
	var has_launch: bool = FieldsGd.has_launch_tag(record)
	if has_conveyor and has_launch:
		return false
	if has_launch:
		if record.components.has(SharedComponentNames.MOVER):
			return false
		var launch_yaw: int = FieldsGd.transform_yaw_bam(record)
		if launch_yaw < 0:
			return false
		launch_list.append({"entity_id": entity_id, "yaw_bam": launch_yaw})
		return TriggersGd.try_append(
			entity_id, record, mover_bag, has_conveyor, has_launch, switch_list, gate_list
		)
	if not has_conveyor:
		return TriggersGd.try_append(
			entity_id, record, mover_bag, has_conveyor, has_launch, switch_list, gate_list
		)
	# 自己在走 + 又把人往别处推：两段位移的先后顺序没有可解释的答案，拒绝发布。
	if record.components.has(SharedComponentNames.MOVER):
		return false
	var yaw_bam: int = FieldsGd.transform_yaw_bam(record)
	if yaw_bam < 0:
		return false
	conveyor_list.append({"entity_id": entity_id, "yaw_bam": yaw_bam})
	return TriggersGd.try_append(
		entity_id, record, mover_bag, has_conveyor, has_launch, switch_list, gate_list
	)


static func _append_destructible(
	entity_id: int,
	record: SharedComponentRecord,
	next_asset: Dictionary,
	used_assets: Dictionary[int, int],
	destructible_list: Array[Dictionary],
	energy_wall_list: Array[Dictionary]
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
	if not TriggersGd.try_append_energy_wall(entity_id, record, energy_wall_list):
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


static func _parse_mover(entity_id: int, record: SharedComponentRecord) -> Dictionary:
	var raw: Variant = record.components[SharedComponentNames.MOVER]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var bag: Dictionary = raw
	var speed_raw: Variant = bag.get("speed", null)
	var speed: int = 0
	if typeof(speed_raw) == TYPE_INT:
		speed = speed_raw
	elif typeof(speed_raw) == TYPE_FLOAT:
		var speed_float: float = speed_raw
		if speed_float != floor(speed_float):
			return {}
		speed = int(speed_float)
	else:
		return {}
	var loop_raw: Variant = bag.get("loop", null)
	if typeof(loop_raw) != TYPE_BOOL:
		return {}
	var loop_on: bool = loop_raw
	var path_raw: Variant = bag.get("path", null)
	if typeof(path_raw) != TYPE_ARRAY:
		return {}
	var wire: Dictionary = {
		"entity_id": entity_id,
		"speed": speed,
		"loop": loop_on,
		"path": path_raw,
	}
	return SimulationBundleBags.parse_mover(wire)
