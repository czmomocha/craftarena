class_name AuthoringPreview
extends RefCounted

## Independent Preview session (CD-32 §4). AuthoringSession stays open.
## Applies P0–P2 EditCommand patches at a safe point; failure restores the
## pre-patch world. P3 waits for Rule VM. P4 sets needs_restart.
## try_start_play compiles the Preview world into a v1 TRAPRUSH topology
## bundle, loads SimulationWorld, and spawns on the lowest-order pad.
## Play enters tick so patches are refused until try_stop_play.
## try_advance_play applies caller play_fall_dy via try_move_y_until_blocked,
## then advances the sim tick and toggles compiled hazards via
## TraprushHazardCycle (existing cooldown_ticks, not a new period).
## try_apply_play_intent accepts MoveIntent (caller dx/dz),
## ResetToCheckpointIntent (compiled pad respawn table, no client
## coordinates), UseItemIntent (compiled destructible occupancy at
## caller reach), and JumpIntent (grounded caller play_jump_dy hop via
## IntentStepper; airborne keeps the pose and still reports ok).
## Shove/Interact stay refused. Does not tick. Fall is only on advance.
## Out-of-range reset uses caller AABB via TraprushOutOfRangeReset when
## play_range_enabled; default off. No drop-count N, no stun.
## Occupancy uses existing TraprushPadAccept: overlapping a checkpoint pad
## advances ordered progress. Occupancy uses existing TraprushPortalLanding
## try_land_exit: overlapping a portal source box lands one hop. two_way dest
## volume is latched until the capsule leaves. Occupied dest waits and holds
## the MoveIntent without walking through. Occupancy uses existing
## TraprushFinishAccept.try_cross: all mandatory pads then overlapping the
## compiled finish box records finish_tick. Observed by Preview, not a client
## assertion. No FinishIntent. Reset uses existing TraprushCheckpointSpawn
## plus IntentStepper and does not rewind progress. UseItem uses existing
## TraprushDestructibleBreak: caller reach pose must overlap a compiled
## solid crate; damage and reach are caller stubs. Destroyed boxes become
## non-solid. Jump uses existing TraprushJumpIntent plus the IntentStepper
## grounded check; play_jump_dy / play_support_dy / play_fall_dy are caller
## stubs, not a locked jump height or product gravity. Never settlement or
## online writes.
## Capsule radius/height are caller-provided, not a locked product size.
## Window host is AuthoringPreviewShell.

const HazardCycle := preload("res://src/games/traprush/hazard_cycle.gd")
const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")

var world: AuthoringWorld = null
var preview_revision: int = 0
var connected: bool = false
var needs_restart: bool = false
var play_world: SimulationWorld = null
var play_graph: TraprushPortalGraph = null
var play_pad_ids: Dictionary = {}
var play_portal_ids: Dictionary = {}
var play_finish_ids: Dictionary = {}
var play_destructible_ids: Dictionary = {}
var play_destructible_health: Dictionary = {}
var play_hazard_ids: Dictionary = {}
var play_hazard_cycle: Array[Dictionary] = []
var play_solid_ids: Dictionary = {}
var play_track: TraprushCheckpointTrack = null
var play_spawn: TraprushCheckpointSpawn = null
var play_cell: int = 0
var player_id: int = 0
var play_use_item_damage: int = 0
var play_use_item_reach_dx: int = 0
var play_use_item_reach_dy: int = 0
var play_use_item_reach_dz: int = 0
var play_jump_dy: int = 0
var play_support_dy: int = 0
var play_fall_dy: int = 0
var play_range_enabled: bool = false
var play_range_min_x: int = 0
var play_range_max_x: int = 0
var play_range_min_y: int = 0
var play_range_max_y: int = 0
var play_range_min_z: int = 0
var play_range_max_z: int = 0
var _in_tick: bool = false
var _playing: bool = false
var _portal_latch: Dictionary = {}
var _play_finish_tick: int = -1


func connect_from(session: AuthoringSession) -> bool:
	if session == null or session.world == null:
		return false
	var cloned: AuthoringWorld = session.world.duplicate()
	if cloned == null:
		return false
	_clear_play()
	world = cloned
	preview_revision = 0
	connected = true
	needs_restart = false
	_in_tick = false
	return true


func is_safe_point() -> bool:
	return connected and not needs_restart and not _in_tick


func enter_tick() -> bool:
	if not connected or needs_restart:
		return false
	_in_tick = true
	return true


func leave_tick() -> void:
	_in_tick = false


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func is_playing() -> bool:
	return _playing and play_world != null


func try_start_play(seed: int, radius: int = 0, cylinder_height: int = 0) -> bool:
	if not is_safe_point():
		return false
	if radius < 0 or cylinder_height < 0:
		return false
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	if bundle == null:
		return false
	if bundle.pads.is_empty():
		return false
	var start: Dictionary = _start_pose(bundle)
	if start.is_empty():
		return false
	var spawn: TraprushCheckpointSpawn = _play_spawn_from_bundle(bundle, start)
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
	var sim: SimulationWorld = world_raw
	var graph: TraprushPortalGraph = graph_raw
	var pad_ids: Dictionary = pads_raw
	var portal_ids: Dictionary = portals_raw
	var finish_ids: Dictionary = finish_raw
	var crate_ids: Dictionary = crates_raw
	var hazard_ids: Dictionary = hazards_raw
	var solid_ids: Dictionary = solids_raw
	var crate_health: Dictionary = _destructible_ledgers(bundle, crate_ids)
	if crate_health.size() != _durable_crate_count(bundle):
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
	if not enter_tick():
		return false
	play_world = sim
	play_graph = graph
	play_pad_ids = pad_ids
	play_portal_ids = portal_ids
	play_finish_ids = finish_ids
	play_destructible_ids = crate_ids
	play_destructible_health = crate_health
	play_hazard_ids = hazard_ids
	play_hazard_cycle = cycle
	play_solid_ids = solid_ids
	play_track = TraprushCheckpointTrack.new(_ordered_checkpoint_ids(bundle))
	play_spawn = spawn
	play_cell = bundle.cell
	player_id = spawned_id
	_playing = true
	_portal_latch = {}
	_play_finish_tick = -1
	_accept_overlapping_play_pads()
	_resolve_play_portals()
	_accept_overlapping_play_finish()
	return true


func try_stop_play() -> bool:
	if not _playing:
		return false
	leave_tick()
	_clear_play()
	return true


func try_advance_play() -> bool:
	if not is_playing():
		return false
	play_world.try_move_y_until_blocked(player_id, play_fall_dy)
	_reset_play_if_out_of_range()
	play_world.tick()
	HazardCycle.apply(play_world, play_hazard_cycle)
	_reset_play_if_out_of_range()
	_accept_overlapping_play_pads()
	_resolve_play_portals()
	_accept_overlapping_play_pads()
	_accept_overlapping_play_finish()
	return true


func try_apply_play_intent(payload: Dictionary) -> bool:
	if not is_playing():
		return false
	var use_decoded: Dictionary = TraprushUseItemIntent.decode(payload)
	var use_ok: bool = use_decoded.get("ok", false)
	if use_ok:
		return _try_use_item_play(payload)
	var move_decoded: Dictionary = TraprushMoveIntent.decode(payload)
	var move_ok: bool = move_decoded.get("ok", false)
	var jump_decoded: Dictionary = TraprushJumpIntent.decode(payload)
	var jump_ok: bool = jump_decoded.get("ok", false)
	var reset_ok: bool = TraprushCheckpointSpawn.is_reset_intent(payload)
	if not move_ok and not reset_ok and not jump_ok:
		return false
	if move_ok and _resolve_play_portals():
		_reset_play_if_out_of_range()
		return true
	if play_spawn == null or play_track == null:
		return false
	var stepped: Dictionary = TraprushIntentStepper.apply(
		play_world,
		player_id,
		payload,
		play_jump_dy,
		play_spawn,
		play_track,
		play_support_dy
	)
	var stepped_ok: bool = stepped.get("ok", false)
	if not stepped_ok:
		return false
	if reset_ok:
		_portal_latch = {}
	_reset_play_if_out_of_range()
	_accept_overlapping_play_pads()
	_resolve_play_portals()
	_accept_overlapping_play_pads()
	_accept_overlapping_play_finish()
	return true


func enable_play_range(half: int) -> void:
	if half < 1:
		play_range_enabled = false
		return
	play_range_enabled = true
	play_range_min_x = -half
	play_range_max_x = half
	play_range_min_y = -half
	play_range_max_y = half
	play_range_min_z = -half
	play_range_max_z = half


func try_accept_play_checkpoint(checkpoint_id: int) -> bool:
	if not is_playing() or play_track == null:
		return false
	if not play_pad_ids.has(checkpoint_id):
		return false
	var box_raw: Variant = play_pad_ids[checkpoint_id]
	if typeof(box_raw) != TYPE_INT:
		return false
	var box_id: int = box_raw
	var ok: bool = TraprushPadAccept.try_accept_on_pad(
		play_world,
		player_id,
		play_track,
		checkpoint_id,
		box_id
	)
	if ok:
		_accept_overlapping_play_finish()
	return ok


func play_accepted_count() -> int:
	if play_track == null:
		return 0
	return play_track.completed_count()


func play_checkpoint_count() -> int:
	if play_track == null:
		return 0
	return play_track.ordered_ids().size()


func play_last_accepted_id() -> int:
	if play_track == null:
		return -1
	return play_track.last_accepted_id()


func play_accepted_ids() -> PackedInt32Array:
	if play_track == null:
		return PackedInt32Array()
	return play_track.accepted_ids()


func play_floor_index() -> int:
	if not is_playing() or play_cell < 1:
		return 0
	var pose: Dictionary = play_world.get_pose(player_id)
	if pose.is_empty():
		return 0
	var pose_y: int = pose.get("y", 0)
	return pose_y / play_cell


func play_finish_tick() -> int:
	if not is_playing():
		return -1
	return _play_finish_tick


func play_destructible_count() -> int:
	if not is_playing():
		return 0
	return play_destructible_ids.size()


func play_hazard_count() -> int:
	if not is_playing():
		return 0
	return play_hazard_ids.size()


func play_hazard_solid_count() -> int:
	if not is_playing():
		return 0
	var solid: int = 0
	for key: Variant in play_hazard_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		if play_is_hazard_solid(entity_id):
			solid += 1
	return solid


func play_solid_count() -> int:
	if not is_playing():
		return 0
	return play_solid_ids.size()


func play_is_hazard_solid(entity_id: int) -> bool:
	if not is_playing() or play_world == null:
		return false
	if not play_hazard_ids.has(entity_id):
		return false
	var box_raw: Variant = play_hazard_ids[entity_id]
	if typeof(box_raw) != TYPE_INT:
		return false
	var box_id: int = box_raw
	return play_world.is_static_box_solid(box_id)


func play_destructible_alive_count() -> int:
	if not is_playing():
		return 0
	var alive: int = 0
	for key: Variant in play_destructible_health.keys():
		var crate_raw: Variant = play_destructible_health[key]
		if not (crate_raw is TraprushDestructible):
			continue
		var crate: TraprushDestructible = crate_raw
		if not crate.is_destroyed():
			alive += 1
	return alive


func try_cross_play_finish() -> bool:
	if not is_playing() or play_track == null:
		return false
	if _play_finish_tick != -1:
		return true
	if play_finish_ids.is_empty():
		return false
	for key: Variant in play_finish_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var box_raw: Variant = play_finish_ids[key]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		var crossed: Dictionary = TraprushFinishAccept.try_cross(
			play_world,
			player_id,
			play_track,
			box_id
		)
		var crossed_ok: bool = crossed.get("ok", false)
		if not crossed_ok:
			continue
		_play_finish_tick = play_world.tick_index
		return true
	return false


func try_apply_patch(level: String, command: SharedCommand) -> bool:
	if not connected or needs_restart:
		return false
	if _in_tick:
		return false
	if not PreviewPatchLevels.contains(level):
		return false
	if level == PreviewPatchLevels.P4:
		needs_restart = true
		return false
	if level == PreviewPatchLevels.P3:
		return false
	if command == null or command.kind != SharedCommand.Kind.EDIT:
		return false
	if world == null:
		return false
	if command.expected_revision != world.revision:
		return false
	var classified: String = PreviewPatchLevels.classify(command, world)
	if classified.is_empty():
		return false
	if PreviewPatchLevels.rank(classified) > PreviewPatchLevels.rank(level):
		return false
	var snapshot: AuthoringWorld = world.duplicate()
	if snapshot == null:
		return false
	if not _apply_edit(command):
		world = snapshot
		return false
	preview_revision += 1
	return true


func _apply_edit(command: SharedCommand) -> bool:
	var decoded: EditPayload = EditPayload.decode(command.payload)
	if not decoded.ok:
		return false
	if not _preconditions(decoded):
		return false
	return _apply_decoded(decoded)


func _preconditions(decoded: EditPayload) -> bool:
	match decoded.op:
		EditOpNames.PLACE:
			return decoded.record != null and not world.has_entity(decoded.record.entity_id)
		EditOpNames.REMOVE:
			return world.has_entity(decoded.entity_id)
		EditOpNames.SET_COMPONENT:
			return decoded.record != null and world.has_entity(decoded.record.entity_id)
		_:
			return false


func _apply_decoded(decoded: EditPayload) -> bool:
	match decoded.op:
		EditOpNames.PLACE:
			return world.put(decoded.record)
		EditOpNames.REMOVE:
			return world.remove(decoded.entity_id)
		EditOpNames.SET_COMPONENT:
			return world.replace(decoded.record)
		_:
			return false


func _reset_play_if_out_of_range() -> bool:
	if not play_range_enabled:
		return false
	if not is_playing() or play_spawn == null or play_track == null:
		return false
	var result: Dictionary = OutOfRangeReset.try_apply(
		play_world,
		player_id,
		play_spawn,
		play_track,
		play_range_min_y,
		play_range_max_y,
		play_range_min_x,
		play_range_max_x,
		play_range_min_z,
		play_range_max_z
	)
	var reset: bool = result.get("reset", false)
	if reset:
		_portal_latch = {}
	return reset


func _clear_play() -> void:
	_playing = false
	play_world = null
	play_graph = null
	play_pad_ids = {}
	play_portal_ids = {}
	play_finish_ids = {}
	play_destructible_ids = {}
	play_destructible_health = {}
	play_hazard_ids = {}
	play_hazard_cycle = []
	play_solid_ids = {}
	play_track = null
	play_spawn = null
	play_cell = 0
	player_id = 0
	_portal_latch = {}
	_play_finish_tick = -1


func _accept_overlapping_play_pads() -> void:
	if play_track == null:
		return
	var ids: PackedInt32Array = play_track.ordered_ids()
	for index: int in range(ids.size()):
		try_accept_play_checkpoint(ids[index])


func _resolve_play_portals() -> bool:
	if not is_playing() or play_graph == null:
		return false
	var overlapping: Array[int] = []
	for key: Variant in play_portal_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		var box_raw: Variant = play_portal_ids[entity_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		if play_world.overlaps_static_box(player_id, box_id):
			overlapping.append(entity_id)
	overlapping.sort()
	var next_latch: Dictionary = {}
	for entity_id: int in overlapping:
		if _portal_latch.has(entity_id):
			next_latch[entity_id] = true
	_portal_latch = next_latch
	for entity_id: int in overlapping:
		if _portal_latch.has(entity_id):
			continue
		var landed: Dictionary = TraprushPortalLanding.try_land_exit(
			play_world,
			player_id,
			play_graph,
			entity_id
		)
		var land_ok: bool = landed.get("ok", false)
		if not land_ok:
			continue
		var did_land: bool = landed.get("landed", false)
		if not did_land:
			return true
		_portal_latch[entity_id] = true
		var dest_raw: Variant = landed.get("dest_id", 0)
		if typeof(dest_raw) == TYPE_INT:
			var dest_id: int = dest_raw
			if dest_id >= 1:
				_portal_latch[dest_id] = true
		_accept_overlapping_play_pads()
		_accept_overlapping_play_finish()
		return false
	return false


func _accept_overlapping_play_finish() -> void:
	try_cross_play_finish()


func _try_use_item_play(payload: Dictionary) -> bool:
	if not is_playing():
		return false
	var ids: Array[int] = []
	for key: Variant in play_destructible_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var crate_id: int = key
		ids.append(crate_id)
	ids.sort()
	for crate_id: int in ids:
		if not play_destructible_health.has(crate_id):
			continue
		var box_raw: Variant = play_destructible_ids[crate_id]
		var crate_raw: Variant = play_destructible_health[crate_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		if not (crate_raw is TraprushDestructible):
			continue
		var box_id: int = box_raw
		var crate: TraprushDestructible = crate_raw
		var broken: Dictionary = TraprushDestructibleBreak.try_use_item(
			play_world,
			player_id,
			payload,
			crate,
			box_id,
			play_use_item_damage,
			play_use_item_reach_dx,
			play_use_item_reach_dy,
			play_use_item_reach_dz
		)
		var broken_ok: bool = broken.get("ok", false)
		if broken_ok:
			return true
	return false


func _destructible_ledgers(bundle: SimulationBundle, crate_ids: Dictionary) -> Dictionary:
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


func _durable_crate_count(bundle: SimulationBundle) -> int:
	if bundle == null:
		return 0
	var count: int = 0
	for item: Dictionary in bundle.destructibles:
		var durability: int = item["durability"]
		if durability >= 1:
			count += 1
	return count


func _ordered_checkpoint_ids(bundle: SimulationBundle) -> PackedInt32Array:
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


func _start_pose(bundle: SimulationBundle) -> Dictionary:
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


func _play_spawn_from_bundle(
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
	var start_pose: Dictionary = {
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
	var ids: PackedInt32Array = _ordered_checkpoint_ids(bundle)
	for index: int in range(ids.size()):
		var entity_id: int = ids[index]
		if not by_id.has(entity_id):
			return null
		var pad_raw: Variant = by_id[entity_id]
		if typeof(pad_raw) != TYPE_DICTIONARY:
			return null
		var pad: Dictionary = pad_raw
		var pose: Dictionary = _respawn_pose(pad)
		if pose.is_empty():
			return null
		poses.append(pose)
	return TraprushCheckpointSpawn.new(start_pose, poses)


func _respawn_pose(pad: Dictionary) -> Dictionary:
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
