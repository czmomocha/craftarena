class_name SimulationBundle
extends RefCounted

## v2 TRAPRUSH topology compile of AuthoringWorld. Field list owner: CD-42 §3.4.
## Pads, two_way / one_way portals, at most one finish occupancy bag,
## destructible occupancy bags, hazard occupancy bags, always-solid occupancy
## bags, and pickup occupancy bags. Dangling portals are omitted. Portal bags
## include source occupancy x/y/z and dest landing pose. Finish bags are
## entity_id plus occupancy x/y/z. Destructible bags add durability. Hazard bags
## add cooldown_ticks (existing component field, used as a half-period; not a
## new period key, not damage/knockback). Solid bags are entity_id plus
## occupancy x/y/z from zone.tags including "solid"; always solid, no period.
## Pickup bags are entity_id plus occupancy x/y/z plus kind (bomb/dash) from
## inventory.item_state.
##
## v2 adds the `assets` bag and gives every entity bag an `asset_id` +
## `gameplay_version` reference into it (ADR-0006, Q1 = B). Before v2 the
## authoritative half-extents were `cell / 2` hardcoded in
## `TraprushTopologyLoader`, and the `zone.shape` a creator authored was
## silently discarded at compile time. Now the published bundle carries the
## deciding geometry itself, so old content and old replays do not depend on
## whatever the program's asset table happens to contain today.
##
## The reference is deliberately redundant (the version is also in the `assets`
## entry): every bag stays self-describing when read alone in a log or replay
## diff, and `from_dictionary` rejects any bag whose pair is missing from
## `assets`. Assets must be strictly ascending by `asset_id` and every entry
## must be referenced, so the wire form is canonical.
##
## v1 still decodes (CD-31 §6 promises current plus two previous versions):
## a v1 body migrates to "every entity references the built-in lattice-cell
## asset", which is byte-identical to the old `cell / 2` behaviour at any cell.
## `to_dictionary` always emits v2, so migration is one-way.
##
## Not in v2: footprint (derived from the collision AABB, Q2 = A), visual mesh
## (never in the bundle; the client resolves `latest` by asset_id, Q4 = A) and
## navigation (no navmesh in this phase). Godot JSON.parse_string may yield
## whole-number floats; decode coerces those that round-trip through int.
## Not a signed binary. Not a Rule VM graph.

const PickupKinds := preload("res://src/ugc/traprush_pickup_kinds.gd")

const SCHEMA_VERSION: int = 2
## 仍可解码、迁移到当前版本的旧 wire 版本（CD-31 §6）。
const MIGRATED_FROM_VERSION: int = 1
const FIELD_SCHEMA_VERSION: String = "schema_version"
const FIELD_CELL: String = "cell"
const FIELD_SOURCE_REVISION: String = "source_revision"
const FIELD_ASSETS: String = "assets"
const FIELD_PADS: String = "pads"
const FIELD_PORTALS: String = "portals"
const FIELD_FINISH: String = "finish"
const FIELD_DESTRUCTIBLES: String = "destructibles"
const FIELD_HAZARDS: String = "hazards"
const FIELD_SOLIDS: String = "solids"
const FIELD_PICKUPS: String = "pickups"

var cell: int = 0
var source_revision: int = 0
var assets: Array[Dictionary] = []
var pads: Array[Dictionary] = []
var portals: Array[Dictionary] = []
var finish: Array[Dictionary] = []
var destructibles: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var solids: Array[Dictionary] = []
var pickups: Array[Dictionary] = []


static func from_dictionary(data: Dictionary) -> SimulationBundle:
	var coerced: Variant = _coerce_json_ints(data)
	if typeof(coerced) != TYPE_DICTIONARY:
		return null
	var body: Dictionary = coerced
	if not body.has(FIELD_SCHEMA_VERSION) or typeof(body[FIELD_SCHEMA_VERSION]) != TYPE_INT:
		return null
	var version: int = body[FIELD_SCHEMA_VERSION]
	if version != SCHEMA_VERSION and version != MIGRATED_FROM_VERSION:
		return null
	var carries_assets: bool = version == SCHEMA_VERSION
	var expected_size: int = 11 if carries_assets else 10
	if body.size() != expected_size:
		return null
	if not body.has(FIELD_CELL) or typeof(body[FIELD_CELL]) != TYPE_INT:
		return null
	var cell: int = body[FIELD_CELL]
	if cell < 1:
		return null
	if not body.has(FIELD_SOURCE_REVISION) or typeof(body[FIELD_SOURCE_REVISION]) != TYPE_INT:
		return null
	var source_revision: int = body[FIELD_SOURCE_REVISION]
	if source_revision < 0:
		return null
	if not body.has(FIELD_PADS) or typeof(body[FIELD_PADS]) != TYPE_ARRAY:
		return null
	if not body.has(FIELD_PORTALS) or typeof(body[FIELD_PORTALS]) != TYPE_ARRAY:
		return null
	var pads: Array[Dictionary] = []
	var pad_ids: Dictionary[int, bool] = {}
	var raw_pads: Array = body[FIELD_PADS]
	for item: Variant in raw_pads:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var bag: Dictionary = item
		var pad: Dictionary = _parse_pad(bag, carries_assets)
		if pad.is_empty():
			return null
		var pad_id: int = pad["entity_id"]
		if pad_ids.has(pad_id):
			return null
		pad_ids[pad_id] = true
		pads.append(pad)
	var portals: Array[Dictionary] = []
	var portal_ids: Dictionary[int, bool] = {}
	var raw_portals: Array = body[FIELD_PORTALS]
	for item: Variant in raw_portals:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var bag: Dictionary = item
		var portal: Dictionary = _parse_portal(bag, carries_assets)
		if portal.is_empty():
			return null
		var portal_id: int = portal["entity_id"]
		if portal_ids.has(portal_id):
			return null
		portal_ids[portal_id] = true
		portals.append(portal)
	if not body.has(FIELD_FINISH) or typeof(body[FIELD_FINISH]) != TYPE_ARRAY:
		return null
	var finish_list: Array[Dictionary] = []
	var raw_finish: Array = body[FIELD_FINISH]
	if raw_finish.size() > 1:
		return null
	for item: Variant in raw_finish:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var finish_bag: Dictionary = item
		var parsed_finish: Dictionary = _parse_finish(finish_bag, carries_assets)
		if parsed_finish.is_empty():
			return null
		var finish_id: int = parsed_finish["entity_id"]
		if pad_ids.has(finish_id) or portal_ids.has(finish_id):
			return null
		finish_list.append(parsed_finish)
	if not body.has(FIELD_DESTRUCTIBLES) or typeof(body[FIELD_DESTRUCTIBLES]) != TYPE_ARRAY:
		return null
	var destructible_list: Array[Dictionary] = []
	var destructible_ids: Dictionary[int, bool] = {}
	var raw_destructibles: Array = body[FIELD_DESTRUCTIBLES]
	for item: Variant in raw_destructibles:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var crate_bag: Dictionary = item
		var parsed_crate: Dictionary = _parse_destructible(crate_bag, carries_assets)
		if parsed_crate.is_empty():
			return null
		var crate_id: int = parsed_crate["entity_id"]
		if (
			destructible_ids.has(crate_id)
			or pad_ids.has(crate_id)
			or portal_ids.has(crate_id)
		):
			return null
		for finish_item: Dictionary in finish_list:
			var finish_entity: int = finish_item["entity_id"]
			if finish_entity == crate_id:
				return null
		destructible_ids[crate_id] = true
		destructible_list.append(parsed_crate)
	if not body.has(FIELD_HAZARDS) or typeof(body[FIELD_HAZARDS]) != TYPE_ARRAY:
		return null
	var hazard_list: Array[Dictionary] = []
	var hazard_ids: Dictionary[int, bool] = {}
	var raw_hazards: Array = body[FIELD_HAZARDS]
	for item: Variant in raw_hazards:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var hazard_bag: Dictionary = item
		var parsed_hazard: Dictionary = _parse_hazard(hazard_bag, carries_assets)
		if parsed_hazard.is_empty():
			return null
		var hazard_id: int = parsed_hazard["entity_id"]
		if (
			hazard_ids.has(hazard_id)
			or pad_ids.has(hazard_id)
			or portal_ids.has(hazard_id)
			or destructible_ids.has(hazard_id)
		):
			return null
		for finish_item: Dictionary in finish_list:
			var finish_entity: int = finish_item["entity_id"]
			if finish_entity == hazard_id:
				return null
		hazard_ids[hazard_id] = true
		hazard_list.append(parsed_hazard)
	if not body.has(FIELD_SOLIDS) or typeof(body[FIELD_SOLIDS]) != TYPE_ARRAY:
		return null
	var solid_list: Array[Dictionary] = []
	var solid_ids: Dictionary[int, bool] = {}
	var raw_solids: Array = body[FIELD_SOLIDS]
	for item: Variant in raw_solids:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var solid_bag: Dictionary = item
		var parsed_solid: Dictionary = _parse_solid(solid_bag, carries_assets)
		if parsed_solid.is_empty():
			return null
		var solid_id: int = parsed_solid["entity_id"]
		if (
			solid_ids.has(solid_id)
			or pad_ids.has(solid_id)
			or portal_ids.has(solid_id)
			or destructible_ids.has(solid_id)
			or hazard_ids.has(solid_id)
		):
			return null
		for finish_item: Dictionary in finish_list:
			var finish_entity: int = finish_item["entity_id"]
			if finish_entity == solid_id:
				return null
		solid_ids[solid_id] = true
		solid_list.append(parsed_solid)
	if not body.has(FIELD_PICKUPS) or typeof(body[FIELD_PICKUPS]) != TYPE_ARRAY:
		return null
	var pickup_list: Array[Dictionary] = []
	var pickup_ids: Dictionary[int, bool] = {}
	var raw_pickups: Array = body[FIELD_PICKUPS]
	for item: Variant in raw_pickups:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var pickup_bag: Dictionary = item
		var parsed_pickup: Dictionary = _parse_pickup(pickup_bag, carries_assets)
		if parsed_pickup.is_empty():
			return null
		var pickup_id: int = parsed_pickup["entity_id"]
		if (
			pickup_ids.has(pickup_id)
			or pad_ids.has(pickup_id)
			or portal_ids.has(pickup_id)
			or destructible_ids.has(pickup_id)
			or hazard_ids.has(pickup_id)
			or solid_ids.has(pickup_id)
		):
			return null
		for finish_item: Dictionary in finish_list:
			var finish_entity: int = finish_item["entity_id"]
			if finish_entity == pickup_id:
				return null
		pickup_ids[pickup_id] = true
		pickup_list.append(parsed_pickup)
	var occupancy: Array[Dictionary] = []
	occupancy.append_array(pads)
	occupancy.append_array(portals)
	occupancy.append_array(finish_list)
	occupancy.append_array(destructible_list)
	occupancy.append_array(hazard_list)
	occupancy.append_array(solid_list)
	occupancy.append_array(pickup_list)
	var asset_list: Array[Dictionary] = []
	if carries_assets:
		if not body.has(FIELD_ASSETS) or typeof(body[FIELD_ASSETS]) != TYPE_ARRAY:
			return null
		asset_list = _parse_assets(body[FIELD_ASSETS])
		if asset_list.is_empty() and not _is_empty_array(body[FIELD_ASSETS]):
			return null
	else:
		asset_list = _migrated_assets(cell, occupancy.is_empty())
		if asset_list.is_empty() and not occupancy.is_empty():
			return null
	if not _references_are_closed(asset_list, occupancy):
		return null
	var bundle: SimulationBundle = SimulationBundle.new()
	bundle.cell = cell
	bundle.source_revision = source_revision
	bundle.assets = asset_list
	bundle.pads = pads
	bundle.portals = portals
	bundle.finish = finish_list
	bundle.destructibles = destructible_list
	bundle.hazards = hazard_list
	bundle.solids = solid_list
	bundle.pickups = pickup_list
	return bundle


func to_dictionary() -> Dictionary:
	var asset_list: Array = []
	for entry: Dictionary in assets:
		asset_list.append(entry.duplicate(true))
	var pad_list: Array = []
	for pad: Dictionary in pads:
		pad_list.append(pad.duplicate(true))
	var portal_list: Array = []
	for portal: Dictionary in portals:
		portal_list.append(portal.duplicate(true))
	var finish_list: Array = []
	for item: Dictionary in finish:
		finish_list.append(item.duplicate(true))
	var destructible_list: Array = []
	for item: Dictionary in destructibles:
		destructible_list.append(item.duplicate(true))
	var hazard_list: Array = []
	for item: Dictionary in hazards:
		hazard_list.append(item.duplicate(true))
	var solid_list: Array = []
	for item: Dictionary in solids:
		solid_list.append(item.duplicate(true))
	var pickup_list: Array = []
	for item: Dictionary in pickups:
		pickup_list.append(item.duplicate(true))
	return {
		FIELD_SCHEMA_VERSION: SCHEMA_VERSION,
		FIELD_CELL: cell,
		FIELD_SOURCE_REVISION: source_revision,
		FIELD_ASSETS: asset_list,
		FIELD_PADS: pad_list,
		FIELD_PORTALS: portal_list,
		FIELD_FINISH: finish_list,
		FIELD_DESTRUCTIBLES: destructible_list,
		FIELD_HAZARDS: hazard_list,
		FIELD_SOLIDS: solid_list,
		FIELD_PICKUPS: pickup_list,
	}


## 该 asset_id 在本 bundle 内的权威碰撞袋；未引用的 id 返回空字典。
## 权威几何来自 bundle 自身，**不查** `SharedGameplayAssetCatalog`：已发布内容
## 必须按它发布时的形状裁决（ADR-0006 §1.4）。
func asset_collision(asset_id: int) -> Dictionary:
	for entry: Dictionary in assets:
		var entry_id: int = entry["asset_id"]
		if entry_id == asset_id:
			var collision: Dictionary = entry["collision"]
			return collision.duplicate(true)
	return {}


static func _parse_assets(value: Variant) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return parsed
	var items: Array = value
	var previous_id: int = 0
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var entry: Dictionary = item
		if not SharedGameplayAssetCatalog.entry_is_valid(entry):
			return []
		var asset_id: int = entry["asset_id"]
		if asset_id <= previous_id:
			return []
		previous_id = asset_id
		parsed.append(entry.duplicate(true))
	return parsed


## v1 → v2：全部实体引用内置"占满一格"资产，占用与旧 `cell / 2` 逐字节一致。
static func _migrated_assets(cell: int, occupancy_is_empty: bool) -> Array[Dictionary]:
	var migrated: Array[Dictionary] = []
	if occupancy_is_empty:
		return migrated
	var entry: Dictionary = SharedGameplayAssetCatalog.try_entry(
		SharedGameplayAssetCatalog.LATTICE_CELL_ID,
		SharedGameplayAssetCatalog.LATTICE_CELL_VERSION,
		cell
	)
	if entry.is_empty():
		return migrated
	migrated.append(entry)
	return migrated


## 每个实体袋的 (asset_id, gameplay_version) 必须在 `assets` 里；每条资产也必须
## 至少被引用一次。前者防止裁决形状缺失，后者让 wire 形状保持规范、不夹带。
static func _references_are_closed(
	asset_list: Array[Dictionary], occupancy: Array[Dictionary]
) -> bool:
	var versions: Dictionary[int, int] = {}
	for entry: Dictionary in asset_list:
		var asset_id: int = entry["asset_id"]
		var entry_version: int = entry["gameplay_version"]
		versions[asset_id] = entry_version
	var referenced: Dictionary[int, bool] = {}
	for bag: Dictionary in occupancy:
		var bag_asset: int = bag["asset_id"]
		var bag_version: int = bag["gameplay_version"]
		if not versions.has(bag_asset):
			return false
		var known_version: int = versions[bag_asset]
		if known_version != bag_version:
			return false
		referenced[bag_asset] = true
	for entry: Dictionary in asset_list:
		var listed_id: int = entry["asset_id"]
		if not referenced.has(listed_id):
			return false
	return true


static func _is_empty_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var items: Array = value
	return items.is_empty()


## 把资产引用并进已解析的袋。v1 没有这两个键，按内置"占满一格"补齐。
static func _merge_asset_ref(body: Dictionary, out: Dictionary, carries_assets: bool) -> bool:
	if not carries_assets:
		out["asset_id"] = SharedGameplayAssetCatalog.LATTICE_CELL_ID
		out["gameplay_version"] = SharedGameplayAssetCatalog.LATTICE_CELL_VERSION
		return true
	if not _int_at_least(body, "asset_id", 1):
		return false
	if not _int_at_least(body, "gameplay_version", 1):
		return false
	out["asset_id"] = body["asset_id"]
	out["gameplay_version"] = body["gameplay_version"]
	return true


static func _bag_size(base: int, carries_assets: bool) -> int:
	if carries_assets:
		return base + 2
	return base


static func _parse_pad(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(8, carries_assets):
		return {}
	if not _int_at_least(body, "entity_id", 1):
		return {}
	if not _is_int_field(body, "x"):
		return {}
	if not _is_int_field(body, "y"):
		return {}
	if not _is_int_field(body, "z"):
		return {}
	if not _int_at_least(body, "order", 0):
		return {}
	if not _is_int_field(body, "respawn_dx"):
		return {}
	if not _is_int_field(body, "respawn_dy"):
		return {}
	if not _is_int_field(body, "respawn_dz"):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"order": body["order"],
		"respawn_dx": body["respawn_dx"],
		"respawn_dy": body["respawn_dy"],
		"respawn_dz": body["respawn_dz"],
	}
	if not _merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func _parse_portal(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(10, carries_assets):
		return {}
	if not _int_at_least(body, "entity_id", 1):
		return {}
	if not _int_at_least(body, "target_id", 1):
		return {}
	if not body.has("kind") or typeof(body["kind"]) != TYPE_STRING:
		return {}
	var kind: String = body["kind"]
	if kind != AuthoringPortalKinds.TWO_WAY and kind != AuthoringPortalKinds.ONE_WAY:
		return {}
	if not _is_int_field(body, "x"):
		return {}
	if not _is_int_field(body, "y"):
		return {}
	if not _is_int_field(body, "z"):
		return {}
	if not _is_int_field(body, "dest_x"):
		return {}
	if not _is_int_field(body, "dest_y"):
		return {}
	if not _is_int_field(body, "dest_z"):
		return {}
	if not _is_int_field(body, "dest_yaw_bam"):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"target_id": body["target_id"],
		"kind": kind,
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"dest_x": body["dest_x"],
		"dest_y": body["dest_y"],
		"dest_z": body["dest_z"],
		"dest_yaw_bam": body["dest_yaw_bam"],
	}
	if not _merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func _parse_finish(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(4, carries_assets):
		return {}
	if not _int_at_least(body, "entity_id", 1):
		return {}
	if not _is_int_field(body, "x"):
		return {}
	if not _is_int_field(body, "y"):
		return {}
	if not _is_int_field(body, "z"):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
	}
	if not _merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func _parse_destructible(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(5, carries_assets):
		return {}
	if not _int_at_least(body, "entity_id", 1):
		return {}
	if not _is_int_field(body, "x"):
		return {}
	if not _is_int_field(body, "y"):
		return {}
	if not _is_int_field(body, "z"):
		return {}
	if not _int_at_least(body, "durability", 0):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"durability": body["durability"],
	}
	if not _merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func _parse_hazard(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(5, carries_assets):
		return {}
	if not _int_at_least(body, "entity_id", 1):
		return {}
	if not _is_int_field(body, "x"):
		return {}
	if not _is_int_field(body, "y"):
		return {}
	if not _is_int_field(body, "z"):
		return {}
	if not _int_at_least(body, "cooldown_ticks", 0):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"cooldown_ticks": body["cooldown_ticks"],
	}
	if not _merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func _parse_solid(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(4, carries_assets):
		return {}
	if not _int_at_least(body, "entity_id", 1):
		return {}
	if not _is_int_field(body, "x"):
		return {}
	if not _is_int_field(body, "y"):
		return {}
	if not _is_int_field(body, "z"):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
	}
	if not _merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func _parse_pickup(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(5, carries_assets):
		return {}
	if not _int_at_least(body, "entity_id", 1):
		return {}
	if not _is_int_field(body, "x"):
		return {}
	if not _is_int_field(body, "y"):
		return {}
	if not _is_int_field(body, "z"):
		return {}
	if not body.has("kind") or typeof(body["kind"]) != TYPE_STRING:
		return {}
	var kind: String = body["kind"]
	if not PickupKinds.contains(kind):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"kind": kind,
	}
	if not _merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func _int_at_least(body: Dictionary, key: String, minimum: int) -> bool:
	if not _is_int_field(body, key):
		return false
	var value: int = body[key]
	return value >= minimum


static func _is_int_field(body: Dictionary, key: String) -> bool:
	return body.has(key) and typeof(body[key]) == TYPE_INT


static func _coerce_json_ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			var number: float = value
			if not is_finite(number):
				return value
			var as_int: int = int(number)
			if float(as_int) != number:
				return value
			return as_int
		TYPE_ARRAY:
			var items: Array = value
			var next_items: Array = []
			for item: Variant in items:
				next_items.append(_coerce_json_ints(item))
			return next_items
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var next_body: Dictionary = {}
			for key: Variant in source:
				next_body[key] = _coerce_json_ints(source[key])
			return next_body
		_:
			return value
