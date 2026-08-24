class_name TraprushTopologyLoader
extends RefCounted

## Loads a v1 TRAPRUSH SimulationBundle into a SimulationWorld + portal graph.
## Checkpoint pads become non-solid static boxes. Half-extents are cell / 2
## (derived from the authoring lattice, not a new product budget). Does not
## spawn a player. Does not tick. Never settlement.

static func try_load(bundle: SimulationBundle, seed: int) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if bundle == null:
		return failed
	if bundle.cell < 1:
		return failed
	var world: SimulationWorld = SimulationWorld.new(seed)
	var graph: TraprushPortalGraph = TraprushPortalGraph.new()
	var pad_ids: Dictionary = {}
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
		var dest_x: int = portal["dest_x"]
		var dest_y: int = portal["dest_y"]
		var dest_z: int = portal["dest_z"]
		var dest_yaw_bam: int = portal["dest_yaw_bam"]
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
	return {
		"ok": true,
		"world": world,
		"graph": graph,
		"pad_ids": pad_ids,
	}
