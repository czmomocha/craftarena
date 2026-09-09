class_name TraprushTopologyCompilerTriggers
extends RefCounted

## Switch / gate occupancy bags for topology compile.
## Public compile() stays on TraprushTopologyCompiler so bags stays under E9.

const FieldsGd := preload("res://src/ugc/traprush_topology_compiler_fields.gd")


## 开关 / 门：固体 + 标签 + 已有 `interactable.link_group`。
## 与 conveyor / launch / mover 互斥。两者都没有标签时是成功的空操作。
static func try_append(
	entity_id: int,
	record: SharedComponentRecord,
	mover_bag: Dictionary,
	has_conveyor: bool,
	has_launch: bool,
	switch_list: Array[Dictionary],
	gate_list: Array[Dictionary]
) -> bool:
	var has_switch: bool = FieldsGd.has_switch_tag(record)
	var has_gate: bool = FieldsGd.has_gate_tag(record)
	if has_switch and has_gate:
		return false
	if not has_switch and not has_gate:
		return true
	if has_conveyor or has_launch:
		return false
	if not mover_bag.is_empty():
		return false
	var link_group: int = FieldsGd.interactable_link_group(record)
	if link_group < 0:
		return false
	var bag: Dictionary = {"entity_id": entity_id, "link_group": link_group}
	if has_switch:
		switch_list.append(bag)
	else:
		gate_list.append(bag)
	return true


## 能量墙：必须已经是可破坏占用。和传送带 / 弹射 / 开关门同体拒绝。
static func try_append_energy_wall(
	entity_id: int, record: SharedComponentRecord, energy_wall_list: Array[Dictionary]
) -> bool:
	if not FieldsGd.has_energy_wall_tag(record):
		return true
	if FieldsGd.has_conveyor_tag(record) or FieldsGd.has_launch_tag(record):
		return false
	if FieldsGd.has_switch_tag(record) or FieldsGd.has_gate_tag(record):
		return false
	if FieldsGd.has_lift_tag(record) or FieldsGd.has_solid_tag(record):
		return false
	energy_wall_list.append({"entity_id": entity_id})
	return true


## 开关传送：必须已经是传送门。和固体 / 开关门 / 能量墙同体拒绝。
## 没有标签时是成功的空操作。
static func try_append_portal_switch(
	entity_id: int, record: SharedComponentRecord, portal_switch_list: Array[Dictionary]
) -> bool:
	if not FieldsGd.has_portal_switch_tag(record):
		return true
	if FieldsGd.has_solid_tag(record):
		return false
	if FieldsGd.has_conveyor_tag(record) or FieldsGd.has_launch_tag(record):
		return false
	if FieldsGd.has_switch_tag(record) or FieldsGd.has_gate_tag(record):
		return false
	if FieldsGd.has_energy_wall_tag(record) or FieldsGd.has_lift_tag(record):
		return false
	if not record.components.has(SharedComponentNames.PORTAL):
		return false
	var link_group: int = FieldsGd.interactable_link_group(record)
	if link_group < 0:
		return false
	portal_switch_list.append({"entity_id": entity_id, "link_group": link_group})
	return true


static func collect_portals(
	world: AuthoringWorld, used_assets: Dictionary[int, int]
) -> Dictionary:
	var portals: Array[Dictionary] = []
	var portal_switch_list: Array[Dictionary] = []
	var gated_sources: Dictionary = {}
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
		if FieldsGd.has_portal_switch_tag(source):
			if not try_append_portal_switch(source_id, source, portal_switch_list):
				return {"ok": false}
			gated_sources[source_id] = true
	for entity_id: int in world.entity_ids():
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			return {"ok": false}
		if not FieldsGd.has_portal_switch_tag(record):
			continue
		if not gated_sources.has(entity_id):
			return {"ok": false}
	return {"ok": true, "portals": portals, "portal_switches": portal_switch_list}
