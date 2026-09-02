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
