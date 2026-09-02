class_name AuthoringPreviewScan
extends RefCounted

## Occupancy after a pose change: pads, portals, finish, pickups,
## hazards, out-of-range reset, and stun. Order stays pad→portal→pad→finish.

const HazardHit := preload("res://src/games/traprush/hazard_hit.gd")
const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const PickupAccept := preload("res://src/games/traprush/pickup_accept.gd")


func try_accept_play_checkpoint(preview: AuthoringPreview, checkpoint_id: int) -> bool:
	if not preview.is_playing() or preview.play_track == null:
		return false
	if not preview.play_pad_ids.has(checkpoint_id):
		return false
	var box_raw: Variant = preview.play_pad_ids[checkpoint_id]
	if typeof(box_raw) != TYPE_INT:
		return false
	var box_id: int = box_raw
	var ok: bool = TraprushPadAccept.try_accept_on_pad(
		preview.play_world,
		preview.player_id,
		preview.play_track,
		checkpoint_id,
		box_id
	)
	if ok:
		accept_overlapping_play_finish(preview)
	return ok


func try_cross_play_finish(preview: AuthoringPreview) -> bool:
	if not preview.is_playing() or preview.play_track == null:
		return false
	if preview._play_finish_tick != -1:
		return true
	if preview.play_finish_ids.is_empty():
		return false
	for key: Variant in preview.play_finish_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var box_raw: Variant = preview.play_finish_ids[key]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		var crossed: Dictionary = TraprushFinishAccept.try_cross(
			preview.play_world,
			preview.player_id,
			preview.play_track,
			box_id
		)
		var crossed_ok: bool = crossed.get("ok", false)
		if not crossed_ok:
			continue
		preview._play_finish_tick = preview.play_world.tick_index
		return true
	return false


func reset_play_if_out_of_range(preview: AuthoringPreview) -> bool:
	if not preview.play_range_enabled:
		return false
	if not preview.is_playing() or preview.play_spawn == null or preview.play_track == null:
		return false
	var result: Dictionary = OutOfRangeReset.try_apply(
		preview.play_world,
		preview.player_id,
		preview.play_spawn,
		preview.play_track,
		preview.play_range_min_y,
		preview.play_range_max_y,
		preview.play_range_min_x,
		preview.play_range_max_x,
		preview.play_range_min_z,
		preview.play_range_max_z
	)
	var reset: bool = result.get("reset", false)
	if reset:
		preview._portal_latch = {}
		preview._play_stun_remaining = preview.play_respawn_stun_ticks
	return reset


func resolve_play_hazards(preview: AuthoringPreview) -> bool:
	if not preview.is_playing() or preview.play_spawn == null or preview.play_track == null:
		return false
	var result: Dictionary = HazardHit.try_apply(
		preview.play_world,
		preview.player_id,
		preview.play_hazard_cycle,
		preview.play_hazard_knockback_step,
		preview.play_spawn,
		preview.play_track
	)
	var result_ok: bool = result.get("ok", false)
	if not result_ok:
		return false
	var reset: bool = result.get("reset", false)
	if reset:
		preview._portal_latch = {}
		preview._play_stun_remaining = preview.play_respawn_stun_ticks
	return reset


func play_stunned(preview: AuthoringPreview) -> bool:
	return preview._play_stun_remaining > 0


func tick_play_stun(preview: AuthoringPreview) -> void:
	if preview._play_stun_remaining < 1:
		return
	preview._play_stun_remaining -= 1


func accept_overlapping_play_pads(preview: AuthoringPreview) -> void:
	if preview.play_track == null:
		return
	var ids: PackedInt32Array = preview.play_track.ordered_ids()
	for index: int in range(ids.size()):
		try_accept_play_checkpoint(preview, ids[index])


func resolve_play_portals(preview: AuthoringPreview) -> bool:
	if not preview.is_playing() or preview.play_graph == null:
		return false
	var overlapping: Array[int] = []
	for key: Variant in preview.play_portal_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		var box_raw: Variant = preview.play_portal_ids[entity_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		if preview.play_world.overlaps_static_box(preview.player_id, box_id):
			overlapping.append(entity_id)
	overlapping.sort()
	var next_latch: Dictionary = {}
	for entity_id: int in overlapping:
		if preview._portal_latch.has(entity_id):
			next_latch[entity_id] = true
	preview._portal_latch = next_latch
	for entity_id: int in overlapping:
		if preview._portal_latch.has(entity_id):
			continue
		var landed: Dictionary = TraprushPortalLanding.try_land_exit(
			preview.play_world,
			preview.player_id,
			preview.play_graph,
			entity_id
		)
		var land_ok: bool = landed.get("ok", false)
		if not land_ok:
			continue
		var did_land: bool = landed.get("landed", false)
		if not did_land:
			return true
		preview._portal_latch[entity_id] = true
		var dest_raw: Variant = landed.get("dest_id", 0)
		if typeof(dest_raw) == TYPE_INT:
			var dest_id: int = dest_raw
			if dest_id >= 1:
				preview._portal_latch[dest_id] = true
		accept_overlapping_play_pads(preview)
		accept_overlapping_play_finish(preview)
		grant_play_pickups(preview)
		return false
	return false


func accept_overlapping_play_finish(preview: AuthoringPreview) -> void:
	try_cross_play_finish(preview)


func grant_play_pickups(preview: AuthoringPreview) -> void:
	if not preview.is_playing():
		return
	var granted: Dictionary = PickupAccept.try_grant(
		preview.play_world,
		preview.player_id,
		preview.play_pickup_ids,
		preview.play_pickup_kinds,
		preview.play_taken,
		preview.play_bomb,
		preview.play_dash
	)
	var granted_ok: bool = granted.get("ok", false)
	if not granted_ok:
		return
	var next_bomb_raw: Variant = granted.get("bomb", preview.play_bomb)
	if typeof(next_bomb_raw) == TYPE_INT:
		preview.play_bomb = next_bomb_raw
	var next_dash_raw: Variant = granted.get("dash", preview.play_dash)
	if typeof(next_dash_raw) == TYPE_INT:
		preview.play_dash = next_dash_raw
	var next_taken_raw: Variant = granted.get("taken", preview.play_taken)
	if typeof(next_taken_raw) == TYPE_DICTIONARY:
		preview.play_taken = next_taken_raw
