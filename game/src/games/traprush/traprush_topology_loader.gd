class_name TraprushTopologyLoader
extends RefCounted

## Loads a v2 TRAPRUSH SimulationBundle into a SimulationWorld + portal graph.
## Checkpoint pads, portal sources, and the optional finish occupancy become
## non-solid static boxes. Destructibles become solid boxes (durability 0
## loads already open). Hazards become solid boxes (tick 0 is the solid half
## of the cooldown_ticks cycle). Always-solid bags become solid boxes that
## never toggle. Pickup bags become non-solid occupancy boxes.
##
## Half-extents come from the bundle's `assets` bag (ADR-0006), **not** from
## `cell / 2` and **not** from the visual placeholder box. This is the point
## where 权威碰撞 stops being "whatever the loader hardcoded": the deciding
## geometry now travels with the published content, so an old bundle keeps its
## own shapes even after the platform ships different ones.
##
## Numerically the two are still equal today, because the only built-in asset is
## "占满一格" (`SharedGameplayAssetCatalog.LATTICE_CELL_ID`) and D4 kept 1 格 =
## 1 表现米. Structurally they are now independent, and
## `test_gameplay_asset_contract.gd` proves a bundle with different collision
## dimensions loads different occupancy without touching any visual code.
##
## Only `box` collision loads: `SimulationWorld` static geometry is AABB-only
## today. `sphere` / `capsule` / `platform_prefab` stay whitelisted at the Schema
## level (CD-42 §1.1) but have no authoritative static implementation, so a
## bundle that references one is **rejected** instead of being silently
## approximated by a box. Visual meshes never enter this path at all (Q4 = A).
##
## Does not spawn a player. Does not tick. Never settlement.

static func try_load(bundle: SimulationBundle, seed: int) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if bundle == null:
		return failed
	if bundle.cell < 1:
		return failed
	var halves: Dictionary[int, Vector3i] = _asset_half_extents(bundle)
	if halves.size() != bundle.assets.size():
		return failed
	if not _halves_cover_bundle(halves, bundle):
		return failed
	var world: SimulationWorld = SimulationWorld.new(seed)
	var graph: TraprushPortalGraph = TraprushPortalGraph.new()
	var pad_ids: Dictionary = {}
	var portal_ids: Dictionary = {}
	var finish_ids: Dictionary = {}
	var destructible_ids: Dictionary = {}
	var hazard_ids: Dictionary = {}
	var solid_ids: Dictionary = {}
	var pickup_ids: Dictionary = {}
	for pad: Dictionary in bundle.pads:
		var entity_id: int = pad["entity_id"]
		var pad_half: Vector3i = halves[pad["asset_id"]]
		var pad_x: int = pad["x"]
		var pad_y: int = pad["y"]
		var pad_z: int = pad["z"]
		var box_id: int = world.spawn_static_box(
			pad_x, pad_y, pad_z, pad_half.x, pad_half.y, pad_half.z
		)
		if box_id < 1:
			return failed
		if not world.set_static_box_solid(box_id, false):
			return failed
		pad_ids[entity_id] = box_id
	for portal: Dictionary in bundle.portals:
		var source_id: int = portal["entity_id"]
		var dest_id: int = portal["target_id"]
		var portal_half: Vector3i = halves[portal["asset_id"]]
		var source_x: int = portal["x"]
		var source_y: int = portal["y"]
		var source_z: int = portal["z"]
		var dest_x: int = portal["dest_x"]
		var dest_y: int = portal["dest_y"]
		var dest_z: int = portal["dest_z"]
		var dest_yaw_bam: int = portal["dest_yaw_bam"]
		var portal_box_id: int = world.spawn_static_box(
			source_x, source_y, source_z, portal_half.x, portal_half.y, portal_half.z
		)
		if portal_box_id < 1:
			return failed
		if not world.set_static_box_solid(portal_box_id, false):
			return failed
		portal_ids[source_id] = portal_box_id
		var link: TraprushPortalLink = TraprushPortalLink.new(
			source_id,
			dest_id,
			dest_x,
			dest_y,
			dest_z,
			dest_yaw_bam
		)
		if not graph.add_link(link):
			return failed
	for item: Dictionary in bundle.finish:
		var finish_id: int = item["entity_id"]
		var finish_half: Vector3i = halves[item["asset_id"]]
		var finish_x: int = item["x"]
		var finish_y: int = item["y"]
		var finish_z: int = item["z"]
		var finish_box_id: int = world.spawn_static_box(
			finish_x, finish_y, finish_z, finish_half.x, finish_half.y, finish_half.z
		)
		if finish_box_id < 1:
			return failed
		if not world.set_static_box_solid(finish_box_id, false):
			return failed
		finish_ids[finish_id] = finish_box_id
	for item: Dictionary in bundle.destructibles:
		var crate_id: int = item["entity_id"]
		var crate_half: Vector3i = halves[item["asset_id"]]
		var crate_x: int = item["x"]
		var crate_y: int = item["y"]
		var crate_z: int = item["z"]
		var durability: int = item["durability"]
		var crate_box_id: int = world.spawn_static_box(
			crate_x, crate_y, crate_z, crate_half.x, crate_half.y, crate_half.z
		)
		if crate_box_id < 1:
			return failed
		if durability < 1:
			if not world.set_static_box_solid(crate_box_id, false):
				return failed
		destructible_ids[crate_id] = crate_box_id
	for item: Dictionary in bundle.hazards:
		var hazard_id: int = item["entity_id"]
		var hazard_half: Vector3i = halves[item["asset_id"]]
		var hazard_x: int = item["x"]
		var hazard_y: int = item["y"]
		var hazard_z: int = item["z"]
		var hazard_box_id: int = world.spawn_static_box(
			hazard_x, hazard_y, hazard_z, hazard_half.x, hazard_half.y, hazard_half.z
		)
		if hazard_box_id < 1:
			return failed
		hazard_ids[hazard_id] = hazard_box_id
	for item: Dictionary in bundle.solids:
		var solid_id: int = item["entity_id"]
		var solid_half: Vector3i = halves[item["asset_id"]]
		var solid_x: int = item["x"]
		var solid_y: int = item["y"]
		var solid_z: int = item["z"]
		var solid_box_id: int = world.spawn_static_box(
			solid_x, solid_y, solid_z, solid_half.x, solid_half.y, solid_half.z
		)
		if solid_box_id < 1:
			return failed
		solid_ids[solid_id] = solid_box_id
	for item: Dictionary in bundle.pickups:
		var pickup_id: int = item["entity_id"]
		var pickup_half: Vector3i = halves[item["asset_id"]]
		var pickup_x: int = item["x"]
		var pickup_y: int = item["y"]
		var pickup_z: int = item["z"]
		var pickup_box_id: int = world.spawn_static_box(
			pickup_x, pickup_y, pickup_z, pickup_half.x, pickup_half.y, pickup_half.z
		)
		if pickup_box_id < 1:
			return failed
		if not world.set_static_box_solid(pickup_box_id, false):
			return failed
		pickup_ids[pickup_id] = pickup_box_id
	return {
		"ok": true,
		"world": world,
		"graph": graph,
		"pad_ids": pad_ids,
		"portal_ids": portal_ids,
		"finish_ids": finish_ids,
		"destructible_ids": destructible_ids,
		"hazard_ids": hazard_ids,
		"solid_ids": solid_ids,
		"pickup_ids": pickup_ids,
	}


## asset_id → 半长。非 box 碰撞或负半长返回空表，调用方据大小不符判为失败。
## 0 半长是退化但合法的占用（`spawn_static_box` 只拒负数），所以不在这里拒。
static func _asset_half_extents(bundle: SimulationBundle) -> Dictionary[int, Vector3i]:
	var halves: Dictionary[int, Vector3i] = {}
	for entry: Dictionary in bundle.assets:
		var collision: Dictionary = entry["collision"]
		var kind: String = collision["kind"]
		if kind != SharedCollisionShapeKinds.BOX:
			return {}
		var half_x: int = collision["hx"]
		var half_y: int = collision["hy"]
		var half_z: int = collision["hz"]
		if half_x < 0 or half_y < 0 or half_z < 0:
			return {}
		var asset_id: int = entry["asset_id"]
		halves[asset_id] = Vector3i(half_x, half_y, half_z)
	return halves


## `SimulationBundle.from_dictionary` 已保证引用闭合，这里是加载前的独立复核：
## 直接下标取半长之前必须确认每个袋的资产都在表里，别让越界变成默认值。
static func _halves_cover_bundle(
	halves: Dictionary[int, Vector3i], bundle: SimulationBundle
) -> bool:
	var lists: Array[Array] = [
		bundle.pads,
		bundle.portals,
		bundle.finish,
		bundle.destructibles,
		bundle.hazards,
		bundle.solids,
		bundle.pickups,
	]
	for list: Array in lists:
		for item: Variant in list:
			if typeof(item) != TYPE_DICTIONARY:
				return false
			var bag: Dictionary = item
			if typeof(bag.get("asset_id", null)) != TYPE_INT:
				return false
			var asset_id: int = bag["asset_id"]
			if not halves.has(asset_id):
				return false
	return true
