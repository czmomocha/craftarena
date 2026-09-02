class_name AuthoringPreviewBootstrap
extends RefCounted

## Assembles AuthoringPreview play from a compiled Preview world.
## The facade keeps connect_from / try_start_play / try_stop_play;
## this type owns topology load, spawn, and destructible ledgers so
## the session file stays under E9.

const HazardCycle := preload("res://src/games/traprush/hazard_cycle.gd")


static func connect_from(preview: AuthoringPreview, session: AuthoringSession) -> bool:
	if session == null or session.world == null:
		return false
	var cloned: AuthoringWorld = session.world.duplicate()
	if cloned == null:
		return false
	clear_play(preview)
	preview.world = cloned
	preview.preview_revision = 0
	preview.connected = true
	preview.needs_restart = false
	preview._in_tick = false
	return true


static func try_start_play(
	preview: AuthoringPreview,
	seed: int,
	radius: int = 0,
	cylinder_height: int = 0
) -> bool:
	if not preview.is_safe_point():
		return false
	if radius < 0 or cylinder_height < 0:
		return false
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(preview.world)
	if bundle == null:
		return false
	if bundle.pads.is_empty():
		return false
	var start: Dictionary = start_pose(bundle)
	if start.is_empty():
		return false
	var spawn: TraprushCheckpointSpawn = play_spawn_from_bundle(bundle, start)
	if spawn == null:
		return false
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, seed)
	var loaded_ok: bool = loaded.get("ok", false)
	if not loaded_ok:
		return false
	var world_raw: Variant = loaded.get("world", null)
	var graph_raw: Variant = loaded.get("graph", null)
	var pads_raw: Variant = loaded.get("pad_ids", {})
	var portals_raw: Variant = loaded.get("portal_ids", {})
	var finish_raw: Variant = loaded.get("finish_ids", {})
	var crates_raw: Variant = loaded.get("destructible_ids", {})
	var hazards_raw: Variant = loaded.get("hazard_ids", {})
	var solids_raw: Variant = loaded.get("solid_ids", {})
	var pickups_raw: Variant = loaded.get("pickup_ids", {})
	if not (world_raw is SimulationWorld):
		return false
	if not (graph_raw is TraprushPortalGraph):
		return false
	if typeof(pads_raw) != TYPE_DICTIONARY:
		return false
	if typeof(portals_raw) != TYPE_DICTIONARY:
		return false
	if typeof(finish_raw) != TYPE_DICTIONARY:
		return false
	if typeof(crates_raw) != TYPE_DICTIONARY:
		return false
	if typeof(hazards_raw) != TYPE_DICTIONARY:
		return false
	if typeof(solids_raw) != TYPE_DICTIONARY:
		return false
	if typeof(pickups_raw) != TYPE_DICTIONARY:
		return false
	var sim: SimulationWorld = world_raw
	var graph: TraprushPortalGraph = graph_raw
	var pad_ids: Dictionary = pads_raw
	var portal_ids: Dictionary = portals_raw
	var finish_ids: Dictionary = finish_raw
	var crate_ids: Dictionary = crates_raw
	var hazard_ids: Dictionary = hazards_raw
	var solid_ids: Dictionary = solids_raw
	var pickup_ids: Dictionary = pickups_raw
	var crate_health: Dictionary = destructible_ledgers(bundle, crate_ids)
	if crate_health.size() != durable_crate_count(bundle):
		return false
	var cycle: Array[Dictionary] = HazardCycle.entries_from(bundle.hazards, hazard_ids)
	if cycle.size() != bundle.hazards.size():
		return false
	var start_x: int = start["x"]
	var start_y: int = start["y"]
	var start_z: int = start["z"]
	var spawned_id: int = sim.spawn_capsule(start_x, start_y, start_z, 0, radius, cylinder_height)
	if spawned_id < 1:
		return false
	if not preview.enter_tick():
		return false
	preview.play_world = sim
	preview.play_graph = graph
	preview.play_pad_ids = pad_ids
	preview.play_portal_ids = portal_ids
	preview.play_finish_ids = finish_ids
	preview.play_destructible_ids = crate_ids
	preview.play_destructible_health = crate_health
	preview.play_hazard_ids = hazard_ids
	preview.play_hazard_cycle = cycle
	preview.play_solid_ids = solid_ids
	preview.play_pickup_ids = pickup_ids
	preview.play_pickup_kinds = pickup_kinds_from_bundle(bundle)
	preview.play_bomb = 0
	preview.play_dash = 0
	preview.play_taken = {}
	preview.play_last_use_item_tick = -1
	preview.play_last_sprint_tick = -1
	preview.play_track = TraprushCheckpointTrack.new(ordered_checkpoint_ids(bundle))
	preview.play_spawn = spawn
	preview.play_cell = bundle.cell
	preview.player_id = spawned_id
	preview._playing = true
	preview._portal_latch = {}
	preview._play_finish_tick = -1
	preview._play_stun_remaining = 0
	preview._accept_overlapping_play_pads()
	preview._resolve_play_portals()
	preview._accept_overlapping_play_finish()
	preview._grant_play_pickups()
	preview._resolve_play_hazards()
	return true


static func try_stop_play(preview: AuthoringPreview) -> bool:
	if not preview._playing:
		return false
	preview.leave_tick()
	clear_play(preview)
	return true


static func clear_play(preview: AuthoringPreview) -> void:
	preview._playing = false
	preview.play_world = null
	preview.play_graph = null
	preview.play_pad_ids = {}
	preview.play_portal_ids = {}
	preview.play_finish_ids = {}
	preview.play_destructible_ids = {}
	preview.play_destructible_health = {}
	preview.play_hazard_ids = {}
	preview.play_hazard_cycle = []
	preview.play_solid_ids = {}
	preview.play_pickup_ids = {}
	preview.play_pickup_kinds = {}
	preview.play_bomb = 0
	preview.play_dash = 0
	preview.play_taken = {}
	preview.play_last_use_item_tick = -1
	preview.play_last_sprint_tick = -1
	preview.play_track = null
	preview.play_spawn = null
	preview.play_cell = 0
	preview.player_id = 0
	preview._portal_latch = {}
	preview._play_finish_tick = -1
	preview._play_stun_remaining = 0


static func pickup_kinds_from_bundle(bundle: SimulationBundle) -> Dictionary:
	var kinds: Dictionary = {}
	if bundle == null:
		return kinds
	for item: Dictionary in bundle.pickups:
		var entity_id: int = item["entity_id"]
		var kind: String = item["kind"]
		kinds[entity_id] = kind
	return kinds


static func destructible_ledgers(bundle: SimulationBundle, crate_ids: Dictionary) -> Dictionary:
	var ledgers: Dictionary = {}
	if bundle == null:
		return ledgers
	for item: Dictionary in bundle.destructibles:
		var crate_id: int = item["entity_id"]
		var durability: int = item["durability"]
		if durability < 1:
			continue
		if not crate_ids.has(crate_id):
			return {}
		var crate: TraprushDestructible = TraprushDestructible.create(durability)
		if crate == null:
			return {}
		ledgers[crate_id] = crate
	return ledgers


static func durable_crate_count(bundle: SimulationBundle) -> int:
	if bundle == null:
		return 0
	var count: int = 0
	for item: Dictionary in bundle.destructibles:
		var durability: int = item["durability"]
		if durability >= 1:
			count += 1
	return count


static func ordered_checkpoint_ids(bundle: SimulationBundle) -> PackedInt32Array:
	var pads: Array[Dictionary] = []
	for pad: Dictionary in bundle.pads:
		pads.append(pad)
	pads.sort_custom(_pad_order_less)
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize(pads.size())
	for index: int in range(pads.size()):
		var pad: Dictionary = pads[index]
		var entity_id: int = pad["entity_id"]
		ids[index] = entity_id
	return ids


static func _pad_order_less(left: Dictionary, right: Dictionary) -> bool:
	var left_order: int = left["order"]
	var right_order: int = right["order"]
	if left_order != right_order:
		return left_order < right_order
	var left_id: int = left["entity_id"]
	var right_id: int = right["entity_id"]
	return left_id < right_id


static func start_pose(bundle: SimulationBundle) -> Dictionary:
	if bundle == null:
		return {}
	if bundle.pads.is_empty():
		return {}
	var found: bool = false
	var best_order: int = 0
	var best_id: int = 0
	var best_x: int = 0
	var best_y: int = 0
	var best_z: int = 0
	var best_dx: int = 0
	var best_dy: int = 0
	var best_dz: int = 0
	for pad: Dictionary in bundle.pads:
		var order: int = pad["order"]
		var entity_id: int = pad["entity_id"]
		var pad_x: int = pad["x"]
		var pad_y: int = pad["y"]
		var pad_z: int = pad["z"]
		var dx: int = pad["respawn_dx"]
		var dy: int = pad["respawn_dy"]
		var dz: int = pad["respawn_dz"]
		if (
			not found
			or order < best_order
			or (order == best_order and entity_id < best_id)
		):
			found = true
			best_order = order
			best_id = entity_id
			best_x = pad_x
			best_y = pad_y
			best_z = pad_z
			best_dx = dx
			best_dy = dy
			best_dz = dz
	if not found:
		return {}
	var x_add: FixedResult = Fixed.try_add(best_x, best_dx)
	var y_add: FixedResult = Fixed.try_add(best_y, best_dy)
	var z_add: FixedResult = Fixed.try_add(best_z, best_dz)
	if not x_add.ok or not y_add.ok or not z_add.ok:
		return {}
	return {
		"x": x_add.value,
		"y": y_add.value,
		"z": z_add.value,
	}


static func play_spawn_from_bundle(
	bundle: SimulationBundle,
	start: Dictionary
) -> TraprushCheckpointSpawn:
	if bundle == null:
		return null
	if not start.has("x") or not start.has("y") or not start.has("z"):
		return null
	if (
		typeof(start["x"]) != TYPE_INT
		or typeof(start["y"]) != TYPE_INT
		or typeof(start["z"]) != TYPE_INT
	):
		return null
	var start_x: int = start["x"]
	var start_y: int = start["y"]
	var start_z: int = start["z"]
	var start_pose_dict: Dictionary = {
		"ok": true,
		"x": start_x,
		"y": start_y,
		"z": start_z,
		"yaw_bam": 0,
	}
	var by_id: Dictionary = {}
	for pad: Dictionary in bundle.pads:
		var pad_id: int = pad["entity_id"]
		by_id[pad_id] = pad
	var poses: Array[Dictionary] = []
	var ids: PackedInt32Array = ordered_checkpoint_ids(bundle)
	for index: int in range(ids.size()):
		var entity_id: int = ids[index]
		if not by_id.has(entity_id):
			return null
		var pad_raw: Variant = by_id[entity_id]
		if typeof(pad_raw) != TYPE_DICTIONARY:
			return null
		var pad: Dictionary = pad_raw
		var pose: Dictionary = respawn_pose(pad)
		if pose.is_empty():
			return null
		poses.append(pose)
	return TraprushCheckpointSpawn.new(start_pose_dict, poses)


static func respawn_pose(pad: Dictionary) -> Dictionary:
	if (
		not pad.has("x")
		or not pad.has("y")
		or not pad.has("z")
		or not pad.has("respawn_dx")
		or not pad.has("respawn_dy")
		or not pad.has("respawn_dz")
	):
		return {}
	if (
		typeof(pad["x"]) != TYPE_INT
		or typeof(pad["y"]) != TYPE_INT
		or typeof(pad["z"]) != TYPE_INT
		or typeof(pad["respawn_dx"]) != TYPE_INT
		or typeof(pad["respawn_dy"]) != TYPE_INT
		or typeof(pad["respawn_dz"]) != TYPE_INT
	):
		return {}
	var pad_x: int = pad["x"]
	var pad_y: int = pad["y"]
	var pad_z: int = pad["z"]
	var dx: int = pad["respawn_dx"]
	var dy: int = pad["respawn_dy"]
	var dz: int = pad["respawn_dz"]
	var x_add: FixedResult = Fixed.try_add(pad_x, dx)
	var y_add: FixedResult = Fixed.try_add(pad_y, dy)
	var z_add: FixedResult = Fixed.try_add(pad_z, dz)
	if not x_add.ok or not y_add.ok or not z_add.ok:
		return {}
	return {
		"ok": true,
		"x": x_add.value,
		"y": y_add.value,
		"z": z_add.value,
		"yaw_bam": 0,
	}
