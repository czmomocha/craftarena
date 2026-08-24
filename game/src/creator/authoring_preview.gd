class_name AuthoringPreview
extends RefCounted

## Independent Preview session (CD-32 §4). AuthoringSession stays open.
## Applies P0–P2 EditCommand patches at a safe point; failure restores the
## pre-patch world. P3 waits for Rule VM. P4 sets needs_restart.
## try_start_play compiles the Preview world into a v1 TRAPRUSH topology
## bundle, loads SimulationWorld, and spawns on the lowest-order pad.
## Play enters tick so patches are refused until try_stop_play.
## try_apply_play_intent accepts only MoveIntent and steps XZ through
## TraprushIntentStepper; dx/dz are caller-provided. Does not tick.
## Occupancy uses existing TraprushPadAccept: overlapping a checkpoint pad
## advances ordered progress. Occupancy uses existing TraprushPortalLanding
## try_land_exit: overlapping a portal source box lands one hop. two_way dest
## volume is latched until the capsule leaves. Occupied dest waits and holds
## the MoveIntent without walking through. Occupancy uses existing
## TraprushFinishAccept.try_cross: all mandatory pads then overlapping the
## compiled finish box records finish_tick. Observed by Preview, not a client
## assertion. No FinishIntent. Never settlement or online writes.
## Capsule radius/height are caller-provided, not a locked product size.
## Window host is AuthoringPreviewShell.

var world: AuthoringWorld = null
var preview_revision: int = 0
var connected: bool = false
var needs_restart: bool = false
var play_world: SimulationWorld = null
var play_graph: TraprushPortalGraph = null
var play_pad_ids: Dictionary = {}
var play_portal_ids: Dictionary = {}
var play_finish_ids: Dictionary = {}
var play_track: TraprushCheckpointTrack = null
var play_cell: int = 0
var player_id: int = 0
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
	var loaded: Dictionary = TraprushTopologyLoader.try_load(bundle, seed)
	var loaded_ok: bool = loaded.get("ok", false)
	if not loaded_ok:
		return false
	var world_raw: Variant = loaded.get("world", null)
	var graph_raw: Variant = loaded.get("graph", null)
	var pads_raw: Variant = loaded.get("pad_ids", {})
	var portals_raw: Variant = loaded.get("portal_ids", {})
	var finish_raw: Variant = loaded.get("finish_ids", {})
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
	var sim: SimulationWorld = world_raw
	var graph: TraprushPortalGraph = graph_raw
	var pad_ids: Dictionary = pads_raw
	var portal_ids: Dictionary = portals_raw
	var finish_ids: Dictionary = finish_raw
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
	play_track = TraprushCheckpointTrack.new(_ordered_checkpoint_ids(bundle))
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
	play_world.tick()
	_accept_overlapping_play_pads()
	_resolve_play_portals()
	_accept_overlapping_play_pads()
	_accept_overlapping_play_finish()
	return true


func try_apply_play_intent(payload: Dictionary) -> bool:
	if not is_playing():
		return false
	var decoded: Dictionary = TraprushMoveIntent.decode(payload)
	var decoded_ok: bool = decoded.get("ok", false)
	if not decoded_ok:
		return false
	if _resolve_play_portals():
		return true
	var unused_spawn: TraprushCheckpointSpawn = TraprushCheckpointSpawn.new()
	var unused_track: TraprushCheckpointTrack = TraprushCheckpointTrack.new()
	var stepped: Dictionary = TraprushIntentStepper.apply(
		play_world,
		player_id,
		payload,
		0,
		unused_spawn,
		unused_track,
		0
	)
	var stepped_ok: bool = stepped.get("ok", false)
	if not stepped_ok:
		return false
	_accept_overlapping_play_pads()
	_resolve_play_portals()
	_accept_overlapping_play_pads()
	_accept_overlapping_play_finish()
	return true


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


func _clear_play() -> void:
	_playing = false
	play_world = null
	play_graph = null
	play_pad_ids = {}
	play_portal_ids = {}
	play_finish_ids = {}
	play_track = null
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
