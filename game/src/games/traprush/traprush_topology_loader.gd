class_name TraprushTopologyLoader
extends RefCounted

## Loads a v1 TRAPRUSH SimulationBundle into a SimulationWorld + portal graph.
## Checkpoint pads, portal sources, and the optional finish occupancy become
## non-solid static boxes. Destructibles become solid boxes (durability 0
## loads already open). Half-extents are cell / 2 (derived from the
## authoring lattice, not a new product budget). Does not spawn a player.
## Does not tick. Never settlement.

static func try_load(bundle: SimulationBundle, seed: int) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if bundle == null:
		return failed
	if bundle.cell < 1:
		return failed
	var world: SimulationWorld = SimulationWorld.new(seed)
	var graph: TraprushPortalGraph = TraprushPortalGraph.new()
	var pad_ids: Dictionary = {}
	var portal_ids: Dictionary = {}
	var finish_ids: Dictionary = {}
	var destructible_ids: Dictionary = {}
	var half: int = bundle.cell / 2
	for pad: Dictionary in bundle.pads:
		var entity_id: int = pad["entity_id"]
		var pad_x: int = pad["x"]
		var pad_y: int = pad["y"]
		var pad_z: int = pad["z"]
		var box_id: int = world.spawn_static_box(pad_x, pad_y, pad_z, half, half, half)
		if box_id < 1:
			return failed
		if not world.set_static_box_solid(box_id, false):
			return failed
		pad_ids[entity_id] = box_id
	for portal: Dictionary in bundle.portals:
		var source_id: int = portal["entity_id"]
		var dest_id: int = portal["target_id"]
		var source_x: int = portal["x"]
		var source_y: int = portal["y"]
		var source_z: int = portal["z"]
		var dest_x: int = portal["dest_x"]
		var dest_y: int = portal["dest_y"]
		var dest_z: int = portal["dest_z"]
		var dest_yaw_bam: int = portal["dest_yaw_bam"]
		var portal_box_id: int = world.spawn_static_box(
			source_x, source_y, source_z, half, half, half
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
		var finish_x: int = item["x"]
		var finish_y: int = item["y"]
		var finish_z: int = item["z"]
		var finish_box_id: int = world.spawn_static_box(
			finish_x, finish_y, finish_z, half, half, half
		)
		if finish_box_id < 1:
			return failed
		if not world.set_static_box_solid(finish_box_id, false):
			return failed
		finish_ids[finish_id] = finish_box_id
	for item: Dictionary in bundle.destructibles:
		var crate_id: int = item["entity_id"]
		var crate_x: int = item["x"]
		var crate_y: int = item["y"]
		var crate_z: int = item["z"]
		var durability: int = item["durability"]
		var crate_box_id: int = world.spawn_static_box(
			crate_x, crate_y, crate_z, half, half, half
		)
		if crate_box_id < 1:
			return failed
		if durability < 1:
			if not world.set_static_box_solid(crate_box_id, false):
				return failed
		destructible_ids[crate_id] = crate_box_id
	return {
		"ok": true,
		"world": world,
		"graph": graph,
		"pad_ids": pad_ids,
		"portal_ids": portal_ids,
		"finish_ids": finish_ids,
		"destructible_ids": destructible_ids,
	}
