class_name TraprushTopologyCompilerFields
extends RefCounted

## Asset refs, occupancy poses, and component bodies for topology compile.
## Public compile() stays on TraprushTopologyCompiler so this file stays under E9.

const PickupKinds := preload("res://src/ugc/traprush_pickup_kinds.gd")


## 实体引用的资产；缺 `gameplay_asset` 组件时默认内置"占满一格"。
## 目录里没登记、或版本不是当前版本，返回空字典（整个编译失败）。
static func asset_ref(record: SharedComponentRecord) -> Dictionary:
	var asset_id: int = SharedGameplayAssetCatalog.LATTICE_CELL_ID
	var gameplay_version: int = SharedGameplayAssetCatalog.LATTICE_CELL_VERSION
	if record.components.has(SharedComponentNames.GAMEPLAY_ASSET):
		var raw: Variant = record.components[SharedComponentNames.GAMEPLAY_ASSET]
		if typeof(raw) != TYPE_DICTIONARY:
			return {}
		var body: Dictionary = raw
		if typeof(body.get("asset_id", null)) != TYPE_INT:
			return {}
		if typeof(body.get("gameplay_version", null)) != TYPE_INT:
			return {}
		asset_id = body["asset_id"]
		gameplay_version = body["gameplay_version"]
	if not SharedGameplayAssetCatalog.has_version(asset_id, gameplay_version):
		return {}
	return {"asset_id": asset_id, "gameplay_version": gameplay_version}


static func with_asset(
	bag: Dictionary, asset_ref_body: Dictionary, used_assets: Dictionary[int, int]
) -> Dictionary:
	var asset_id: int = asset_ref_body["asset_id"]
	var gameplay_version: int = asset_ref_body["gameplay_version"]
	bag["asset_id"] = asset_id
	bag["gameplay_version"] = gameplay_version
	used_assets[asset_id] = gameplay_version
	return bag


## 被引用的资产按 asset_id 升序写进 `assets`，保证 wire 形状规范且可复现。
static func asset_entries(used_assets: Dictionary[int, int], cell: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var ids: Array[int] = []
	for asset_id: int in used_assets:
		ids.append(asset_id)
	ids.sort()
	for asset_id: int in ids:
		var gameplay_version: int = used_assets[asset_id]
		var entry: Dictionary = SharedGameplayAssetCatalog.try_entry(
			asset_id, gameplay_version, cell
		)
		if entry.is_empty():
			return []
		entries.append(entry)
	return entries


static func transform_xyz(record: SharedComponentRecord) -> Dictionary:
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


static func checkpoint_body(record: SharedComponentRecord) -> Dictionary:
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


static func destructible_body(record: SharedComponentRecord) -> Dictionary:
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


static func hazard_body(record: SharedComponentRecord) -> Dictionary:
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


static func inventory_kind(record: SharedComponentRecord) -> String:
	var raw: Variant = record.components[SharedComponentNames.INVENTORY]
	if typeof(raw) != TYPE_DICTIONARY:
		return ""
	var body: Dictionary = raw
	var state_raw: Variant = body.get("item_state", null)
	if typeof(state_raw) != TYPE_STRING:
		return ""
	var kind: String = state_raw
	if not PickupKinds.contains(kind):
		return ""
	return kind


static func has_finish_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.FINISH_ZONE_TAG)


static func has_solid_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.SOLID_ZONE_TAG)


## 传送带标签。`zone.tags` 是自由字符串表（CD-42 §1「触发与查询区域」），
## 认识一个新标签不改 Schema、不废旧内容。见 `TraprushConveyorCycle` 文件头。
static func has_conveyor_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.CONVEYOR_ZONE_TAG)


static func has_lift_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.LIFT_ZONE_TAG)


static func has_launch_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.LAUNCH_ZONE_TAG)


static func has_switch_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.SWITCH_ZONE_TAG)


static func has_gate_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.GATE_ZONE_TAG)


static func has_energy_wall_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.ENERGY_WALL_ZONE_TAG)


static func has_portal_switch_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.PORTAL_SWITCH_ZONE_TAG)


static func has_spike_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.SPIKE_ZONE_TAG)


static func has_flame_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.FLAME_ZONE_TAG)


static func has_crusher_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.CRUSHER_ZONE_TAG)


static func has_roller_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.ROLLER_ZONE_TAG)


static func has_rubble_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.RUBBLE_ZONE_TAG)


static func has_obstacle_core_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.OBSTACLE_CORE_ZONE_TAG)


static func has_pendulum_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.PENDULUM_ZONE_TAG)


static func has_ice_tag(record: SharedComponentRecord) -> bool:
	return has_zone_tag(record, TraprushTopologyCompiler.ICE_ZONE_TAG)


static func append_pad(
	entity_id: int,
	record: SharedComponentRecord,
	next_asset: Dictionary,
	used_assets: Dictionary[int, int],
	pads: Array[Dictionary]
) -> bool:
	var pose: Dictionary = transform_xyz(record)
	if pose.is_empty():
		return false
	var checkpoint: Dictionary = checkpoint_body(record)
	if checkpoint.is_empty():
		return false
	pads.append(with_asset({
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


static func append_pickup(
	entity_id: int,
	record: SharedComponentRecord,
	next_asset: Dictionary,
	used_assets: Dictionary[int, int],
	pickup_list: Array[Dictionary]
) -> bool:
	if has_finish_tag(record):
		return false
	if has_solid_tag(record):
		return false
	if record.components.has(SharedComponentNames.CHECKPOINT):
		return false
	if record.components.has(SharedComponentNames.PORTAL):
		return false
	if record.components.has(SharedComponentNames.DESTRUCTIBLE):
		return false
	if record.components.has(SharedComponentNames.HAZARD):
		return false
	var pickup_pose: Dictionary = transform_xyz(record)
	if pickup_pose.is_empty():
		return false
	var pickup_kind: String = inventory_kind(record)
	if pickup_kind.is_empty():
		return false
	pickup_list.append(with_asset({
		"entity_id": entity_id,
		"x": pickup_pose["x"],
		"y": pickup_pose["y"],
		"z": pickup_pose["z"],
		"kind": pickup_kind,
	}, next_asset, used_assets))
	return true


static func append_finish(
	entity_id: int,
	record: SharedComponentRecord,
	next_asset: Dictionary,
	used_assets: Dictionary[int, int],
	finish_list: Array[Dictionary]
) -> bool:
	if has_solid_tag(record):
		return false
	if record.components.has(SharedComponentNames.CHECKPOINT):
		return false
	if record.components.has(SharedComponentNames.PORTAL):
		return false
	if record.components.has(SharedComponentNames.DESTRUCTIBLE):
		return false
	if record.components.has(SharedComponentNames.HAZARD):
		return false
	var finish_pose: Dictionary = transform_xyz(record)
	if finish_pose.is_empty():
		return false
	finish_list.append(with_asset({
		"entity_id": entity_id,
		"x": finish_pose["x"],
		"y": finish_pose["y"],
		"z": finish_pose["z"],
	}, next_asset, used_assets))
	return true


## 已有 `interactable.link_group`。缺组件 / 不是非负整数 → -1（整份编译失败）。
static func interactable_link_group(record: SharedComponentRecord) -> int:
	if not record.components.has(SharedComponentNames.INTERACTABLE):
		return -1
	var raw: Variant = record.components[SharedComponentNames.INTERACTABLE]
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	var body: Dictionary = raw
	if typeof(body.get("link_group", null)) != TYPE_INT:
		return -1
	var link_group: int = body["link_group"]
	if link_group < 0:
		return -1
	return link_group


## 传送带的推送方向。缺 `yaw_bam` 或不是 int 返回 -1（整个编译失败）：
## 一块方向不明的传送带在权威里没有确定行为，宁可拒绝发布。
static func transform_yaw_bam(record: SharedComponentRecord) -> int:
	if not record.components.has(SharedComponentNames.TRANSFORM):
		return -1
	var raw: Variant = record.components[SharedComponentNames.TRANSFORM]
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	var body: Dictionary = raw
	if typeof(body.get("yaw_bam", null)) != TYPE_INT:
		return -1
	var yaw_bam: int = body["yaw_bam"]
	if yaw_bam < 0 or yaw_bam >= Fixed.BAM_TURN:
		return -1
	return yaw_bam


static func has_zone_tag(record: SharedComponentRecord, tag: String) -> bool:
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
		var value: String = item
		if value == tag:
			return true
	return false
