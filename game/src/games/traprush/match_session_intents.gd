class_name TraprushMatchIntents
extends RefCounted

## Authoritative command application for TraprushMatchSession.
## Move / jump / reset go through IntentStepper; shove / use-item / sprint
## stay wireless-id and caller-stub. Occupancy after a pose change is scan.

const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const DestructibleBreak := preload("res://src/games/traprush/destructible_break.gd")
const IntentStepper := preload("res://src/games/traprush/intent_stepper.gd")
const JumpIntent := preload("res://src/games/traprush/jump_intent.gd")
const MoveIntent := preload("res://src/games/traprush/move_intent.gd")
const ShoveApply := preload("res://src/games/traprush/shove_apply.gd")
const ShoveGate := preload("res://src/games/traprush/shove_gate.gd")
const ShoveIntent := preload("res://src/games/traprush/shove_intent.gd")
const SprintApply := preload("res://src/games/traprush/sprint_apply.gd")
const SprintIntent := preload("res://src/games/traprush/sprint_intent.gd")
const TraprushDestructible := preload("res://src/games/traprush/destructible.gd")
const UseItemIntent := preload("res://src/games/traprush/use_item_intent.gd")


func apply(session: TraprushMatchSession, slot: int, payload: Dictionary) -> bool:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return false
	var reset_ok: bool = CheckpointSpawn.is_reset_intent(payload)
	if session._player_stunned(player) and not reset_ok:
		return false
	var use_decoded: Dictionary = UseItemIntent.decode(payload)
	var use_ok: bool = use_decoded.get("ok", false)
	if use_ok:
		return _try_use_item(session, player, payload)
	var sprint_decoded: Dictionary = SprintIntent.decode(payload)
	var sprint_ok: bool = sprint_decoded.get("ok", false)
	if sprint_ok:
		return _try_sprint(session, player, payload)
	var shove_decoded: Dictionary = ShoveIntent.decode(payload)
	var shove_ok: bool = shove_decoded.get("ok", false)
	if shove_ok:
		return _try_shove(session, slot, player, payload)
	var move_decoded: Dictionary = MoveIntent.decode(payload)
	var move_ok: bool = move_decoded.get("ok", false)
	if move_ok:
		var move_dx: int = move_decoded.get("dx", 0)
		var move_dz: int = move_decoded.get("dz", 0)
		if not TraprushMatchSession.move_step_allowed(move_dx, move_dz):
			return false
	var jump_decoded: Dictionary = JumpIntent.decode(payload)
	var jump_ok: bool = jump_decoded.get("ok", false)
	if not move_ok and not reset_ok and not jump_ok:
		return false
	var capsule_id: int = player["capsule_id"]
	if move_ok and session._resolve_player_portals(player):
		session._resolve_player_hazards(player)
		session._reset_player_if_out_of_range(player)
		session._grant_player_pickups(player)
		return true
	var track: CheckpointTrack = player["track"]
	var stepped: Dictionary = IntentStepper.apply(
		session._world,
		capsule_id,
		payload,
		session.jump_dy,
		session._spawn,
		track,
		session.support_dy
	)
	var stepped_ok: bool = stepped.get("ok", false)
	if not stepped_ok:
		return false
	if reset_ok:
		player["latch"] = {}
	session._resolve_player_hazards(player)
	session._reset_player_if_out_of_range(player)
	session._accept_player_pads(player)
	session._resolve_player_portals(player)
	session._accept_player_pads(player)
	session._accept_player_finish(player)
	session._grant_player_pickups(player)
	return true


func _try_shove(
	session: TraprushMatchSession,
	slot: int,
	player: Dictionary,
	payload: Dictionary
) -> bool:
	if not TraprushMatchSession.shove_step_allowed(session.shove_step):
		return false
	if session.shove_cooldown_ticks < 1:
		return false
	var target_slot: int = _pick_shove_target_slot(session, slot)
	if target_slot < 0:
		return false
	var target: Dictionary = session._player_at(target_slot)
	if target.is_empty():
		return false
	var actor_id: int = player["capsule_id"]
	var target_id: int = target["capsule_id"]
	var impulse: Dictionary = _shove_impulse(session, actor_id, target_id)
	if impulse.is_empty():
		return false
	var last_tick: int = player.get("last_shove_tick", -1)
	var now_tick: int = 0
	if session._world != null:
		now_tick = session._world.tick_index
	var impulse_dx: int = impulse["dx"]
	var impulse_dz: int = impulse["dz"]
	var result: Dictionary = ShoveApply.apply(
		session._world,
		actor_id,
		target_id,
		payload,
		now_tick,
		last_tick,
		session.shove_cooldown_ticks,
		impulse_dx,
		impulse_dz
	)
	var result_ok: bool = result.get("ok", false)
	if not result_ok:
		return false
	var shoved: bool = result.get("shoved", false)
	if shoved:
		player["last_shove_tick"] = now_tick
		session._resolve_player_hazards(target)
		session._reset_player_if_out_of_range(target)
		session._accept_player_pads(target)
		session._resolve_player_portals(target)
		session._accept_player_pads(target)
		session._accept_player_finish(target)
		session._grant_player_pickups(target)
	return true


func _pick_shove_target_slot(session: TraprushMatchSession, actor_slot: int) -> int:
	var actor_pose: Dictionary = session.player_pose(actor_slot)
	if actor_pose.is_empty():
		return -1
	var best_slot: int = -1
	var best_cheb: int = 0
	var best_man: int = 0
	for slot: int in range(session.player_count()):
		if slot == actor_slot:
			continue
		var pose: Dictionary = session.player_pose(slot)
		if pose.is_empty():
			continue
		var reach: Dictionary = xz_delta(actor_pose, pose)
		if reach.is_empty():
			continue
		var dx: int = reach["dx"]
		var dy: int = reach["dy"]
		var dz: int = reach["dz"]
		if not _within_shove_reach(dx, dy, dz):
			continue
		var cheb: int = _chebyshev_xz(dx, dz)
		var man: int = _manhattan_xz(dx, dz)
		if best_slot < 0:
			best_slot = slot
			best_cheb = cheb
			best_man = man
			continue
		if cheb < best_cheb:
			best_slot = slot
			best_cheb = cheb
			best_man = man
			continue
		if cheb == best_cheb and man < best_man:
			best_slot = slot
			best_man = man
			continue
		if cheb == best_cheb and man == best_man and slot < best_slot:
			best_slot = slot
	return best_slot


func _shove_impulse(session: TraprushMatchSession, actor_id: int, target_id: int) -> Dictionary:
	if session._world == null:
		return {}
	var actor_pose: Dictionary = session._world.get_pose(actor_id)
	var target_pose: Dictionary = session._world.get_pose(target_id)
	if actor_pose.is_empty() or target_pose.is_empty():
		return {}
	var reach: Dictionary = xz_delta(actor_pose, target_pose)
	if reach.is_empty():
		return {}
	var dx_delta: int = reach["dx"]
	var dz_delta: int = reach["dz"]
	var dx: int = 0
	var dz: int = 0
	if dx_delta > 0:
		dx = session.shove_step
	elif dx_delta < 0:
		dx = -session.shove_step
	if dz_delta > 0:
		dz = session.shove_step
	elif dz_delta < 0:
		dz = -session.shove_step
	if dx == 0 and dz == 0 and session.shove_step != 0:
		return {}
	return {"dx": dx, "dz": dz}


static func xz_delta(from_pose: Dictionary, to_pose: Dictionary) -> Dictionary:
	var from_x: int = from_pose.get("x", 0)
	var from_y: int = from_pose.get("y", 0)
	var from_z: int = from_pose.get("z", 0)
	var to_x: int = to_pose.get("x", 0)
	var to_y: int = to_pose.get("y", 0)
	var to_z: int = to_pose.get("z", 0)
	var sub_x: FixedResult = Fixed.try_sub(to_x, from_x)
	var sub_y: FixedResult = Fixed.try_sub(to_y, from_y)
	var sub_z: FixedResult = Fixed.try_sub(to_z, from_z)
	if not sub_x.ok or not sub_y.ok or not sub_z.ok:
		return {}
	return {"dx": sub_x.value, "dy": sub_y.value, "dz": sub_z.value}


static func _within_shove_reach(dx: int, dy: int, dz: int) -> bool:
	if dx > TraprushMatchSession.SHOVE_REACH_MAX or dx < -TraprushMatchSession.SHOVE_REACH_MAX:
		return false
	if dy > TraprushMatchSession.SHOVE_REACH_MAX or dy < -TraprushMatchSession.SHOVE_REACH_MAX:
		return false
	if dz > TraprushMatchSession.SHOVE_REACH_MAX or dz < -TraprushMatchSession.SHOVE_REACH_MAX:
		return false
	return true


static func _chebyshev_xz(dx: int, dz: int) -> int:
	var ax: int = dx
	if ax < 0:
		ax = -ax
	var az: int = dz
	if az < 0:
		az = -az
	if ax > az:
		return ax
	return az


static func _manhattan_xz(dx: int, dz: int) -> int:
	var ax: int = dx
	if ax < 0:
		ax = -ax
	var az: int = dz
	if az < 0:
		az = -az
	var sum: FixedResult = Fixed.try_add(ax, az)
	if not sum.ok:
		return TraprushMatchSession.SHOVE_REACH_MAX
	return sum.value


func _try_use_item(session: TraprushMatchSession, player: Dictionary, payload: Dictionary) -> bool:
	if session.item_cooldown_ticks < 1:
		return false
	var now_tick: int = 0
	if session._world != null:
		now_tick = session._world.tick_index
	var last_tick: int = player.get("last_use_item_tick", -1)
	if not ShoveGate.can_shove(now_tick, last_tick, session.item_cooldown_ticks):
		return true
	var bomb: int = player.get("bomb", 0)
	if bomb < 1:
		return false
	var capsule_id: int = player["capsule_id"]
	var ids: Array[int] = []
	for key: Variant in session._crate_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var crate_id: int = key
		ids.append(crate_id)
	ids.sort()
	for crate_id: int in ids:
		if not session._crate_health.has(crate_id):
			continue
		var box_raw: Variant = session._crate_ids[crate_id]
		var crate_raw: Variant = session._crate_health[crate_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		if not (crate_raw is TraprushDestructible):
			continue
		var box_id: int = box_raw
		var crate: TraprushDestructible = crate_raw
		var broken: Dictionary = DestructibleBreak.try_use_item(
			session._world,
			capsule_id,
			payload,
			crate,
			box_id,
			session.use_item_damage,
			session.use_item_reach_dx,
			session.use_item_reach_dy,
			session.use_item_reach_dz
		)
		var broken_ok: bool = broken.get("ok", false)
		if broken_ok:
			player["bomb"] = bomb - 1
			player["last_use_item_tick"] = now_tick
			return true
	return false


func _try_sprint(session: TraprushMatchSession, player: Dictionary, payload: Dictionary) -> bool:
	if not TraprushMatchSession.sprint_step_allowed(session.sprint_step):
		return false
	if session.item_cooldown_ticks < 1:
		return false
	var dash: int = player.get("dash", 0)
	if dash < 1:
		return false
	var capsule_id: int = player["capsule_id"]
	var last_tick: int = player.get("last_sprint_tick", -1)
	var now_tick: int = 0
	if session._world != null:
		now_tick = session._world.tick_index
	var result: Dictionary = SprintApply.apply(
		session._world,
		capsule_id,
		payload,
		now_tick,
		last_tick,
		session.item_cooldown_ticks,
		session.sprint_step
	)
	var result_ok: bool = result.get("ok", false)
	if not result_ok:
		return false
	var sprinted: bool = result.get("sprinted", false)
	if sprinted:
		player["dash"] = dash - 1
		player["last_sprint_tick"] = now_tick
		session._resolve_player_hazards(player)
		session._reset_player_if_out_of_range(player)
		session._accept_player_pads(player)
		session._resolve_player_portals(player)
		session._accept_player_pads(player)
		session._accept_player_finish(player)
		session._grant_player_pickups(player)
	return true
