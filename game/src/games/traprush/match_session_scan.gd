class_name TraprushMatchScan
extends RefCounted

## Occupancy after a pose change: pads, portals, finish, pickups,
## hazards, out-of-range reset, and stun. Order stays pad→portal→pad→finish.

const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const FinishAccept := preload("res://src/games/traprush/finish_accept.gd")
const HazardHit := preload("res://src/games/traprush/hazard_hit.gd")
const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const PadAccept := preload("res://src/games/traprush/pad_accept.gd")
const PickupAccept := preload("res://src/games/traprush/pickup_accept.gd")
const PortalLanding := preload("res://src/games/traprush/portal_landing.gd")


func accept_player_pads(session: TraprushMatchSession, player: Dictionary) -> void:
	var track: CheckpointTrack = player["track"]
	var capsule_id: int = player["capsule_id"]
	for index: int in range(session._ordered_ids.size()):
		var checkpoint_id: int = session._ordered_ids[index]
		if not session._pad_ids.has(checkpoint_id):
			continue
		var box_raw: Variant = session._pad_ids[checkpoint_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		var ok: bool = PadAccept.try_accept_on_pad(
			session._world,
			capsule_id,
			track,
			checkpoint_id,
			box_id
		)
		if ok:
			accept_player_finish(session, player)


func resolve_player_portals(session: TraprushMatchSession, player: Dictionary) -> bool:
	if session._graph == null:
		return false
	var capsule_id: int = player["capsule_id"]
	var latch: Dictionary = player["latch"]
	var overlapping: Array[int] = []
	for key: Variant in session._portal_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		var box_raw: Variant = session._portal_ids[entity_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		if session._world.overlaps_static_box(capsule_id, box_id):
			overlapping.append(entity_id)
	overlapping.sort()
	var next_latch: Dictionary = {}
	for entity_id: int in overlapping:
		if latch.has(entity_id):
			next_latch[entity_id] = true
	player["latch"] = next_latch
	for entity_id: int in overlapping:
		if next_latch.has(entity_id):
			continue
		var landed: Dictionary = PortalLanding.try_land_exit(
			session._world,
			capsule_id,
			session._graph,
			entity_id
		)
		var land_ok: bool = landed.get("ok", false)
		if not land_ok:
			continue
		var did_land: bool = landed.get("landed", false)
		if not did_land:
			return true
		next_latch[entity_id] = true
		var dest_raw: Variant = landed.get("dest_id", 0)
		if typeof(dest_raw) == TYPE_INT:
			var dest_id: int = dest_raw
			if dest_id >= 1:
				next_latch[dest_id] = true
		accept_player_pads(session, player)
		accept_player_finish(session, player)
		grant_player_pickups(session, player)
		return false
	return false


func accept_player_finish(session: TraprushMatchSession, player: Dictionary) -> void:
	var finish_tick: int = player["finish_tick"]
	if finish_tick != -1:
		return
	var track: CheckpointTrack = player["track"]
	var capsule_id: int = player["capsule_id"]
	for key: Variant in session._finish_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var box_raw: Variant = session._finish_ids[key]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		var crossed: Dictionary = FinishAccept.try_cross(
			session._world,
			capsule_id,
			track,
			box_id
		)
		var crossed_ok: bool = crossed.get("ok", false)
		if crossed_ok:
			player["finish_tick"] = session._world.tick_index
			return


func reset_player_if_out_of_range(session: TraprushMatchSession, player: Dictionary) -> bool:
	if not session.range_enabled:
		return false
	if session._world == null or session._spawn == null:
		return false
	var capsule_id: int = player["capsule_id"]
	var track: CheckpointTrack = player["track"]
	var result: Dictionary = OutOfRangeReset.try_apply(
		session._world,
		capsule_id,
		session._spawn,
		track,
		session.range_min_y,
		session.range_max_y,
		session.range_min_x,
		session.range_max_x,
		session.range_min_z,
		session.range_max_z
	)
	var reset: bool = result.get("reset", false)
	if reset:
		player["latch"] = {}
		player["stun_remaining"] = session.respawn_stun_ticks
	return reset


func resolve_player_hazards(session: TraprushMatchSession, player: Dictionary) -> bool:
	if session._world == null or session._spawn == null:
		return false
	var capsule_id: int = player["capsule_id"]
	var track: CheckpointTrack = player["track"]
	var result: Dictionary = HazardHit.try_apply(
		session._world,
		capsule_id,
		session._hazard_cycle,
		session.hazard_knockback_step,
		session._spawn,
		track
	)
	var result_ok: bool = result.get("ok", false)
	if not result_ok:
		return false
	var reset: bool = result.get("reset", false)
	if reset:
		player["latch"] = {}
		player["stun_remaining"] = session.respawn_stun_ticks
	return reset


func player_stunned(player: Dictionary) -> bool:
	var stun_raw: Variant = player.get("stun_remaining", 0)
	if typeof(stun_raw) != TYPE_INT:
		return false
	var stun: int = stun_raw
	return stun > 0


func tick_stuns(session: TraprushMatchSession) -> void:
	for player: Dictionary in session._players:
		var stun_raw: Variant = player.get("stun_remaining", 0)
		if typeof(stun_raw) != TYPE_INT:
			continue
		var stun: int = stun_raw
		if stun < 1:
			continue
		player["stun_remaining"] = stun - 1


func grant_player_pickups(session: TraprushMatchSession, player: Dictionary) -> void:
	var capsule_id: int = player["capsule_id"]
	var taken_raw: Variant = player.get("taken", {})
	var taken: Dictionary = {}
	if typeof(taken_raw) == TYPE_DICTIONARY:
		taken = taken_raw
	var bomb: int = player.get("bomb", 0)
	var dash: int = player.get("dash", 0)
	var granted: Dictionary = PickupAccept.try_grant(
		session._world,
		capsule_id,
		session._pickup_ids,
		session._pickup_kinds,
		taken,
		bomb,
		dash
	)
	var granted_ok: bool = granted.get("ok", false)
	if not granted_ok:
		return
	var next_bomb_raw: Variant = granted.get("bomb", bomb)
	if typeof(next_bomb_raw) == TYPE_INT:
		player["bomb"] = next_bomb_raw
	var next_dash_raw: Variant = granted.get("dash", dash)
	if typeof(next_dash_raw) == TYPE_INT:
		player["dash"] = next_dash_raw
	var next_taken_raw: Variant = granted.get("taken", taken)
	if typeof(next_taken_raw) == TYPE_DICTIONARY:
		player["taken"] = next_taken_raw
