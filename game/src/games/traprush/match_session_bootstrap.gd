class_name TraprushMatchBootstrap
extends RefCounted

## Assembles a TraprushMatchSession from a compiled bundle.
## The facade keeps create(); this type owns topology load, spawn
## offsets, and destructible ledgers so the session file stays under E9.

const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const HazardCycle := preload("res://src/games/traprush/hazard_cycle.gd")
const TopologyLoader := preload("res://src/games/traprush/traprush_topology_loader.gd")
const TraprushDestructible := preload("res://src/games/traprush/destructible.gd")


static func try_create(
	bundle: SimulationBundle,
	seed: int,
	count: int,
	spawn_offsets: Array,
	radius: int,
	cylinder_height: int
) -> TraprushMatchSession:
	if bundle == null:
		return null
	if count < 1 or count > TraprushMatchSession.MAX_PLAYERS:
		return null
	if spawn_offsets.size() < count:
		return null
	if radius < 1 or cylinder_height < 1:
		return null
	var loaded: Dictionary = TopologyLoader.try_load(bundle, seed)
	if not loaded.get("ok", false):
		return null
	var ordered: PackedInt32Array = ordered_checkpoint_ids(bundle)
	var start: Dictionary = start_pose_from_bundle(bundle)
	if start.is_empty():
		return null
	var spawn: CheckpointSpawn = spawn_from_bundle(bundle, ordered, start)
	if spawn == null:
		return null
	var session: TraprushMatchSession = TraprushMatchSession.new()
	session._world = loaded["world"]
	session._graph = loaded["graph"]
	session._pad_ids = loaded["pad_ids"]
	session._portal_ids = loaded["portal_ids"]
	session._finish_ids = loaded["finish_ids"]
	session._crate_ids = loaded["destructible_ids"]
	session._crate_health = destructible_ledgers(bundle)
	var hazards_raw: Variant = loaded.get("hazard_ids", {})
	if typeof(hazards_raw) != TYPE_DICTIONARY:
		return null
	var hazard_ids: Dictionary = hazards_raw
	var cycle: Array[Dictionary] = HazardCycle.entries_from(bundle.hazards, hazard_ids)
	if cycle.size() != bundle.hazards.size():
		return null
	session._hazard_ids = hazard_ids
	session._hazard_cycle = cycle
	var pickups_raw: Variant = loaded.get("pickup_ids", {})
	if typeof(pickups_raw) != TYPE_DICTIONARY:
		return null
	session._pickup_ids = pickups_raw
	session._pickup_kinds = pickup_kinds_from_bundle(bundle)
	session._spawn = spawn
	session._ordered_ids = ordered
	var start_x: int = start["x"]
	var start_y: int = start["y"]
	var start_z: int = start["z"]
	for slot: int in range(count):
		var offset_raw: Variant = spawn_offsets[slot]
		if typeof(offset_raw) != TYPE_DICTIONARY:
			return null
		var offset: Dictionary = offset_raw
		var pose: Dictionary = offset_pose(start_x, start_y, start_z, offset)
		if pose.is_empty():
			return null
		var pose_x: int = pose["x"]
		var pose_y: int = pose["y"]
		var pose_z: int = pose["z"]
		var capsule_id: int = session._world.spawn_capsule(
			pose_x, pose_y, pose_z, 0, radius, cylinder_height
		)
		if capsule_id < 1:
			return null
		session._players.append({
			"capsule_id": capsule_id,
			"track": CheckpointTrack.new(ordered),
			"finish_tick": -1,
			"latch": {},
			"last_shove_tick": -1,
			"last_use_item_tick": -1,
			"last_sprint_tick": -1,
			"bomb": 0,
			"dash": 0,
			"taken": {},
			"stun_remaining": 0,
		})
	for player: Dictionary in session._players:
		session._accept_player_pads(player)
		session._resolve_player_portals(player)
		session._accept_player_finish(player)
		session._grant_player_pickups(player)
	return session


static func pickup_kinds_from_bundle(bundle: SimulationBundle) -> Dictionary:
	var kinds: Dictionary = {}
	if bundle == null:
		return kinds
	for item: Dictionary in bundle.pickups:
		var entity_id: int = item["entity_id"]
		var kind: String = item["kind"]
		kinds[entity_id] = kind
	return kinds


static func offset_pose(start_x: int, start_y: int, start_z: int, offset: Dictionary) -> Dictionary:
	if (
		not offset.has("dx")
		or not offset.has("dy")
		or not offset.has("dz")
	):
		return {}
	if (
		typeof(offset["dx"]) != TYPE_INT
		or typeof(offset["dy"]) != TYPE_INT
		or typeof(offset["dz"]) != TYPE_INT
	):
		return {}
	var dx: int = offset["dx"]
	var dy: int = offset["dy"]
	var dz: int = offset["dz"]
	var x_add: FixedResult = Fixed.try_add(start_x, dx)
	var y_add: FixedResult = Fixed.try_add(start_y, dy)
	var z_add: FixedResult = Fixed.try_add(start_z, dz)
	if not x_add.ok or not y_add.ok or not z_add.ok:
		return {}
	return {
		"x": x_add.value,
		"y": y_add.value,
		"z": z_add.value,
	}


static func ordered_checkpoint_ids(bundle: SimulationBundle) -> PackedInt32Array:
	var pads: Array[Dictionary] = []
	for pad: Dictionary in bundle.pads:
		pads.append(pad)
	pads.sort_custom(pad_order_less)
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize(pads.size())
	for index: int in range(pads.size()):
		var pad: Dictionary = pads[index]
		var entity_id: int = pad["entity_id"]
		ids[index] = entity_id
	return ids


static func pad_order_less(left: Dictionary, right: Dictionary) -> bool:
	var left_order: int = left["order"]
	var right_order: int = right["order"]
	if left_order != right_order:
		return left_order < right_order
	var left_id: int = left["entity_id"]
	var right_id: int = right["entity_id"]
	return left_id < right_id


static func start_pose_from_bundle(bundle: SimulationBundle) -> Dictionary:
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
		var entity_id: int = pad["entity_id"]
		var order: int = pad["order"]
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


static func spawn_from_bundle(
	bundle: SimulationBundle,
	ordered: PackedInt32Array,
	start: Dictionary
) -> CheckpointSpawn:
	var start_pose: Dictionary = {
		"ok": true,
		"x": start["x"],
		"y": start["y"],
		"z": start["z"],
		"yaw_bam": 0,
	}
	var by_id: Dictionary = {}
	for pad: Dictionary in bundle.pads:
		var pad_id: int = pad["entity_id"]
		by_id[pad_id] = pad
	var poses: Array[Dictionary] = []
	for index: int in range(ordered.size()):
		var entity_id: int = ordered[index]
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
	return CheckpointSpawn.new(start_pose, poses)


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


static func destructible_ledgers(bundle: SimulationBundle) -> Dictionary:
	var ledgers: Dictionary = {}
	for item: Dictionary in bundle.destructibles:
		var crate_id: int = item["entity_id"]
		var durability: int = item["durability"]
		if durability < 1:
			continue
		var crate: TraprushDestructible = TraprushDestructible.create(durability)
		if crate == null:
			return {}
		ledgers[crate_id] = crate
	return ledgers
