class_name TraprushTopologyCompiler
extends RefCounted

## Compiles an AuthoringWorld into a v2 TRAPRUSH SimulationBundle.
## Whole-world topology, not an incremental subgraph. Dangling portals are
## omitted. A checkpoint or a classified two_way / one_way portal without
## source or dest transform fails the whole compile. Portal bags include the
## source occupancy pose (x/y/z) and dest landing pose. Finish occupancy is
## a zone whose tags include "finish"; missing transform or two finish
## zones fail the whole compile. Checkpoint or portal on the same entity
## as a finish zone also fails. Destructible bags need transform and
## durability; sharing an entity with checkpoint, portal, finish, hazard, or
## solid fails. Hazard bags need transform and cooldown_ticks; sharing an
## entity with checkpoint, portal, finish, destructible, or solid fails.
## Solid bags need transform and zone.tags including "solid"; sharing an
## entity with checkpoint, portal, finish, destructible, or hazard fails.
## Pickup bags need transform and inventory.item_state of bomb or dash;
## sharing an entity with checkpoint, portal, finish, destructible, hazard,
## or solid fails. Finish and solid tags together fail. Not a new EDIT op.
## Never settlement.
##
## v2 (ADR-0006): every occupancy bag carries the `gameplay_asset` reference it
## was authored with, and the used assets are stamped into the bundle's `assets`
## bag with their authoritative collision resolved at this world's `cell`.
##
## The reference is validated against `SharedGameplayAssetCatalog` here and
## nowhere else: this is the publish gate (Q5 = A, creators pick an `asset_id`,
## they never author dimensions). `has_version` demands the catalog's *current*
## version, so once the platform changes an asset's collision, content that
## referenced the old version stops compiling and must be republished as a new
## content version — which is exactly CD-31 §5's "GameplayAsset 变化必须生成新
## 内容版本". Already-published bundles keep running because they carry their
## own geometry.
##
## Entities without a `gameplay_asset` component default to the built-in
## lattice-cell asset, so the three official courses and every existing
## AuthoringWorld compile to byte-identical occupancy.
##
## `zone.shape` is **not** read here. Since v2 the authoritative collision comes
## from the asset, and `zone` goes back to CD-42 §1's original meaning (触发与
## 查询区域). Before v2 the shape a creator authored was silently discarded,
## which is the defect ADR-0006 §1.3 exists to close.

const PickupKinds := preload("res://src/ugc/traprush_pickup_kinds.gd")

const FINISH_ZONE_TAG: String = "finish"
const SOLID_ZONE_TAG: String = "solid"


static func compile(world: AuthoringWorld) -> SimulationBundle:
	if world == null or world.grid == null:
		return null
	var pads: Array[Dictionary] = []
	var finish_list: Array[Dictionary] = []
	var destructible_list: Array[Dictionary] = []
	var hazard_list: Array[Dictionary] = []
	var solid_list: Array[Dictionary] = []
	var pickup_list: Array[Dictionary] = []
	var used_assets: Dictionary[int, int] = {}
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			return null
		var asset_ref: Dictionary = _asset_ref(record)
		if asset_ref.is_empty():
			return null
		if record.components.has(SharedComponentNames.INVENTORY):
			if _has_finish_tag(record):
				return null
			if _has_solid_tag(record):
				return null
			if record.components.has(SharedComponentNames.CHECKPOINT):
				return null
			if record.components.has(SharedComponentNames.PORTAL):
				return null
			if record.components.has(SharedComponentNames.DESTRUCTIBLE):
				return null
			if record.components.has(SharedComponentNames.HAZARD):
				return null
			var pickup_pose: Dictionary = _transform_xyz(record)
			if pickup_pose.is_empty():
				return null
			var pickup_kind: String = _inventory_kind(record)
			if pickup_kind.is_empty():
				return null
			pickup_list.append(_with_asset({
				"entity_id": entity_id,
				"x": pickup_pose["x"],
				"y": pickup_pose["y"],
				"z": pickup_pose["z"],
				"kind": pickup_kind,
			}, asset_ref, used_assets))
			continue
		if _has_finish_tag(record):
			if _has_solid_tag(record):
				return null
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
			finish_list.append(_with_asset({
				"entity_id": entity_id,
				"x": finish_pose["x"],
				"y": finish_pose["y"],
				"z": finish_pose["z"],
			}, asset_ref, used_assets))
			continue
		if _has_solid_tag(record):
			if record.components.has(SharedComponentNames.CHECKPOINT):
				return null
			if record.components.has(SharedComponentNames.PORTAL):
				return null
			if record.components.has(SharedComponentNames.DESTRUCTIBLE):
				return null
			if record.components.has(SharedComponentNames.HAZARD):
				return null
			var solid_pose: Dictionary = _transform_xyz(record)
			if solid_pose.is_empty():
				return null
			solid_list.append(_with_asset({
				"entity_id": entity_id,
				"x": solid_pose["x"],
				"y": solid_pose["y"],
				"z": solid_pose["z"],
			}, asset_ref, used_assets))
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
			destructible_list.append(_with_asset({
				"entity_id": entity_id,
				"x": crate_pose["x"],
				"y": crate_pose["y"],
				"z": crate_pose["z"],
				"durability": crate_body["durability"],
			}, asset_ref, used_assets))
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
			hazard_list.append(_with_asset({
				"entity_id": entity_id,
				"x": hazard_pose["x"],
				"y": hazard_pose["y"],
				"z": hazard_pose["z"],
				"cooldown_ticks": hazard_body["cooldown_ticks"],
			}, asset_ref, used_assets))
			continue
		if not record.components.has(SharedComponentNames.CHECKPOINT):
			continue
		var pose: Dictionary = _transform_xyz(record)
		if pose.is_empty():
			return null
		var checkpoint: Dictionary = _checkpoint_body(record)
		if checkpoint.is_empty():
			return null
		pads.append(_with_asset({
			"entity_id": entity_id,
			"x": pose["x"],
			"y": pose["y"],
			"z": pose["z"],
			"order": checkpoint["order"],
			"respawn_dx": checkpoint["respawn_dx"],
			"respawn_dy": checkpoint["respawn_dy"],
			"respawn_dz": checkpoint["respawn_dz"],
		}, asset_ref, used_assets))
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
		var source_asset: Dictionary = _asset_ref(source)
		if source_asset.is_empty():
			return null
		var dest_yaw_bam: int = link.get("dest_yaw_bam", 0)
		var dest_x: int = dest_pose["x"]
		var dest_y: int = dest_pose["y"]
		var dest_z: int = dest_pose["z"]
		var source_x: int = source_pose["x"]
		var source_y: int = source_pose["y"]
		var source_z: int = source_pose["z"]
		portals.append(_with_asset({
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
		}, source_asset, used_assets))
	if finish_list.size() > 1:
		return null
	var assets: Array[Dictionary] = _asset_entries(used_assets, world.grid.cell)
	if assets.is_empty() and not used_assets.is_empty():
		return null
	var body: Dictionary = {
		SimulationBundle.FIELD_SCHEMA_VERSION: SimulationBundle.SCHEMA_VERSION,
		SimulationBundle.FIELD_CELL: world.grid.cell,
		SimulationBundle.FIELD_SOURCE_REVISION: world.revision,
		SimulationBundle.FIELD_ASSETS: assets,
		SimulationBundle.FIELD_PADS: pads,
		SimulationBundle.FIELD_PORTALS: portals,
		SimulationBundle.FIELD_FINISH: finish_list,
		SimulationBundle.FIELD_DESTRUCTIBLES: destructible_list,
		SimulationBundle.FIELD_HAZARDS: hazard_list,
		SimulationBundle.FIELD_SOLIDS: solid_list,
		SimulationBundle.FIELD_PICKUPS: pickup_list,
	}
	return SimulationBundle.from_dictionary(body)


## 实体引用的资产；缺 `gameplay_asset` 组件时默认内置"占满一格"。
## 目录里没登记、或版本不是当前版本，返回空字典（整个编译失败）。
static func _asset_ref(record: SharedComponentRecord) -> Dictionary:
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


static func _with_asset(
	bag: Dictionary, asset_ref: Dictionary, used_assets: Dictionary[int, int]
) -> Dictionary:
	var asset_id: int = asset_ref["asset_id"]
	var gameplay_version: int = asset_ref["gameplay_version"]
	bag["asset_id"] = asset_id
	bag["gameplay_version"] = gameplay_version
	used_assets[asset_id] = gameplay_version
	return bag


## 被引用的资产按 asset_id 升序写进 `assets`，保证 wire 形状规范且可复现。
static func _asset_entries(used_assets: Dictionary[int, int], cell: int) -> Array[Dictionary]:
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


static func _inventory_kind(record: SharedComponentRecord) -> String:
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


static func _has_finish_tag(record: SharedComponentRecord) -> bool:
	return _has_zone_tag(record, FINISH_ZONE_TAG)


static func _has_solid_tag(record: SharedComponentRecord) -> bool:
	return _has_zone_tag(record, SOLID_ZONE_TAG)


static func _has_zone_tag(record: SharedComponentRecord, tag: String) -> bool:
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
