class_name AuthoringPreviewIntents
extends RefCounted

## Play-intent application for AuthoringPreview.
## Move / jump / reset go through IntentStepper; use-item / sprint stay
## wireless-id and caller-stub. Occupancy after a pose change is scan.
## Shove / Interact stay refused. Does not tick.

const ShoveGate := preload("res://src/games/traprush/shove_gate.gd")
const SprintApply := preload("res://src/games/traprush/sprint_apply.gd")


func apply(preview: AuthoringPreview, payload: Dictionary) -> bool:
	if not preview.is_playing():
		return false
	var reset_ok: bool = TraprushCheckpointSpawn.is_reset_intent(payload)
	if preview._play_stunned() and not reset_ok:
		return false
	var use_decoded: Dictionary = TraprushUseItemIntent.decode(payload)
	var use_ok: bool = use_decoded.get("ok", false)
	if use_ok:
		return _try_use_item_play(preview, payload)
	var sprint_decoded: Dictionary = TraprushSprintIntent.decode(payload)
	var sprint_ok: bool = sprint_decoded.get("ok", false)
	if sprint_ok:
		return _try_sprint_play(preview, payload)
	var move_decoded: Dictionary = TraprushMoveIntent.decode(payload)
	var move_ok: bool = move_decoded.get("ok", false)
	var jump_decoded: Dictionary = TraprushJumpIntent.decode(payload)
	var jump_ok: bool = jump_decoded.get("ok", false)
	if not move_ok and not reset_ok and not jump_ok:
		return false
	if move_ok and preview._resolve_play_portals():
		preview._resolve_play_hazards()
		preview._reset_play_if_out_of_range()
		preview._grant_play_pickups()
		return true
	if preview.play_spawn == null or preview.play_track == null:
		return false
	var stepped: Dictionary = TraprushIntentStepper.apply(
		preview.play_world,
		preview.player_id,
		payload,
		preview.play_jump_dy,
		preview.play_spawn,
		preview.play_track,
		preview.play_support_dy
	)
	var stepped_ok: bool = stepped.get("ok", false)
	if not stepped_ok:
		return false
	if reset_ok:
		preview._portal_latch = {}
	preview._resolve_play_hazards()
	preview._reset_play_if_out_of_range()
	preview._accept_overlapping_play_pads()
	preview._resolve_play_portals()
	preview._accept_overlapping_play_pads()
	preview._accept_overlapping_play_finish()
	preview._grant_play_pickups()
	return true


func _try_use_item_play(preview: AuthoringPreview, payload: Dictionary) -> bool:
	if not preview.is_playing():
		return false
	if preview.play_item_cooldown_ticks < 1:
		return false
	var now_tick: int = preview.play_world.tick_index
	if not ShoveGate.can_shove(
		now_tick,
		preview.play_last_use_item_tick,
		preview.play_item_cooldown_ticks
	):
		return true
	if preview.play_bomb < 1:
		return false
	var ids: Array[int] = []
	for key: Variant in preview.play_destructible_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var crate_id: int = key
		ids.append(crate_id)
	ids.sort()
	for crate_id: int in ids:
		if not preview.play_destructible_health.has(crate_id):
			continue
		var box_raw: Variant = preview.play_destructible_ids[crate_id]
		var crate_raw: Variant = preview.play_destructible_health[crate_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		if not (crate_raw is TraprushDestructible):
			continue
		var box_id: int = box_raw
		var crate: TraprushDestructible = crate_raw
		var broken: Dictionary = TraprushDestructibleBreak.try_use_item(
			preview.play_world,
			preview.player_id,
			payload,
			crate,
			box_id,
			preview.play_use_item_damage,
			preview.play_use_item_reach_dx,
			preview.play_use_item_reach_dy,
			preview.play_use_item_reach_dz
		)
		var broken_ok: bool = broken.get("ok", false)
		if broken_ok:
			preview.play_bomb -= 1
			preview.play_last_use_item_tick = now_tick
			return true
	return false


func _try_sprint_play(preview: AuthoringPreview, payload: Dictionary) -> bool:
	if not preview.is_playing():
		return false
	if preview.play_sprint_step < 0 or preview.play_sprint_step > Fixed.SCALE:
		return false
	if preview.play_item_cooldown_ticks < 1:
		return false
	if preview.play_dash < 1:
		return false
	var now_tick: int = preview.play_world.tick_index
	var result: Dictionary = SprintApply.apply(
		preview.play_world,
		preview.player_id,
		payload,
		now_tick,
		preview.play_last_sprint_tick,
		preview.play_item_cooldown_ticks,
		preview.play_sprint_step
	)
	var result_ok: bool = result.get("ok", false)
	if not result_ok:
		return false
	var sprinted: bool = result.get("sprinted", false)
	if sprinted:
		preview.play_dash -= 1
		preview.play_last_sprint_tick = now_tick
		preview._resolve_play_hazards()
		preview._reset_play_if_out_of_range()
		preview._accept_overlapping_play_pads()
		preview._resolve_play_portals()
		preview._accept_overlapping_play_pads()
		preview._accept_overlapping_play_finish()
		preview._grant_play_pickups()
	return true
