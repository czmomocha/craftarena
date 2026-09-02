class_name AuthoringPreviewView
extends RefCounted

## Read model for AuthoringPreview play: progress, inventory, floor, anim.
## Does not apply intents, patches, or occupancy.


func play_accepted_count(preview: AuthoringPreview) -> int:
	if preview.play_track == null:
		return 0
	return preview.play_track.completed_count()


func play_checkpoint_count(preview: AuthoringPreview) -> int:
	if preview.play_track == null:
		return 0
	return preview.play_track.ordered_ids().size()


func play_last_accepted_id(preview: AuthoringPreview) -> int:
	if preview.play_track == null:
		return -1
	return preview.play_track.last_accepted_id()


func play_accepted_ids(preview: AuthoringPreview) -> PackedInt32Array:
	if preview.play_track == null:
		return PackedInt32Array()
	return preview.play_track.accepted_ids()


func play_floor_index(preview: AuthoringPreview) -> int:
	if not preview.is_playing() or preview.play_cell < 1:
		return 0
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	if pose.is_empty():
		return 0
	var pose_y: int = pose.get("y", 0)
	return pose_y / preview.play_cell


func play_finish_tick(preview: AuthoringPreview) -> int:
	if not preview.is_playing():
		return -1
	return preview._play_finish_tick


func play_destructible_count(preview: AuthoringPreview) -> int:
	if not preview.is_playing():
		return 0
	return preview.play_destructible_ids.size()


func play_hazard_count(preview: AuthoringPreview) -> int:
	if not preview.is_playing():
		return 0
	return preview.play_hazard_ids.size()


func play_hazard_solid_count(preview: AuthoringPreview) -> int:
	if not preview.is_playing():
		return 0
	var solid: int = 0
	for key: Variant in preview.play_hazard_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		if play_is_hazard_solid(preview, entity_id):
			solid += 1
	return solid


func play_solid_count(preview: AuthoringPreview) -> int:
	if not preview.is_playing():
		return 0
	return preview.play_solid_ids.size()


func play_is_hazard_solid(preview: AuthoringPreview, entity_id: int) -> bool:
	if not preview.is_playing() or preview.play_world == null:
		return false
	if not preview.play_hazard_ids.has(entity_id):
		return false
	var box_raw: Variant = preview.play_hazard_ids[entity_id]
	if typeof(box_raw) != TYPE_INT:
		return false
	var box_id: int = box_raw
	return preview.play_world.is_static_box_solid(box_id)


func play_destructible_alive_count(preview: AuthoringPreview) -> int:
	if not preview.is_playing():
		return 0
	var alive: int = 0
	for key: Variant in preview.play_destructible_health.keys():
		var crate_raw: Variant = preview.play_destructible_health[key]
		if not (crate_raw is TraprushDestructible):
			continue
		var crate: TraprushDestructible = crate_raw
		if not crate.is_destroyed():
			alive += 1
	return alive


func play_bomb_count(preview: AuthoringPreview) -> int:
	if not preview.is_playing():
		return 0
	return preview.play_bomb


func play_dash_count(preview: AuthoringPreview) -> int:
	if not preview.is_playing():
		return 0
	return preview.play_dash


func play_stun_remaining(preview: AuthoringPreview) -> int:
	if not preview.is_playing():
		return 0
	return preview._play_stun_remaining


func play_supported_by_solid(preview: AuthoringPreview) -> bool:
	if not preview.is_playing() or preview.play_world == null:
		return false
	return preview.play_world.is_supported_by_solid(preview.player_id, preview.play_support_dy)


func play_portal_latched(preview: AuthoringPreview) -> bool:
	if not preview.is_playing():
		return false
	return not preview._portal_latch.is_empty()


func play_broke_this_tick(preview: AuthoringPreview) -> bool:
	if not preview.is_playing() or preview.play_world == null:
		return false
	return preview.play_last_use_item_tick == preview.play_world.tick_index


func play_vy(preview: AuthoringPreview) -> int:
	if not preview.is_playing() or preview.play_world == null:
		return 0
	return preview.play_world.get_vy(preview.player_id)


func play_airborne(preview: AuthoringPreview) -> bool:
	if not preview.is_playing() or preview.play_world == null:
		return false
	return PlayAnimState.is_airborne(
		play_vy(preview),
		preview.play_world.is_supported_by_solid(preview.player_id, PlayAnimState.CONTACT_DY)
	)
