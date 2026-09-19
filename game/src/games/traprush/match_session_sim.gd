class_name TraprushMatchSim
extends RefCounted

## Tick stepping for TraprushMatchSession. Opening countdown (go_tick) freezes
## gravity and cycles until racing; tests keep go_tick = 0.

const Gravity := preload("res://src/games/traprush/gravity.gd")
const ConveyorCycle := preload("res://src/games/traprush/conveyor_cycle.gd")
const LaunchCycle := preload("res://src/games/traprush/launch_cycle.gd")
const GateCycle := preload("res://src/games/traprush/gate_cycle.gd")
const HazardCycle := preload("res://src/games/traprush/hazard_cycle.gd")
const MoverCycle := preload("res://src/games/traprush/mover_cycle.gd")


static func is_racing(session: TraprushMatchSession) -> bool:
	return session.tick_index() >= session.go_tick


static func racing_tick(session: TraprushMatchSession) -> int:
	return maxi(0, session.tick_index() - session.go_tick)


static func apply_falls(session: TraprushMatchSession) -> void:
	if session._world == null or not is_racing(session):
		return
	for player: Dictionary in session._players:
		var capsule_id: int = player["capsule_id"]
		Gravity.integrate(session._world, capsule_id, session.fall_dy)
		session._resolve_player_hazards(player)
		session._reset_player_if_out_of_range(player)


static func advance(session: TraprushMatchSession) -> void:
	if session._world == null:
		return
	if not is_racing(session):
		session._world.tick()
		return
	session._tick_stuns()
	session._world.tick()
	_apply_movers(session)
	_apply_slides(session)
	_apply_launches(session)
	_apply_gates(session)
	HazardCycle.apply(session._world, session._hazard_cycle, racing_tick(session))
	session.scan.keep_flames_nonsolid(session)
	for player: Dictionary in session._players:
		session._resolve_player_hazards(player)
		session._reset_player_if_out_of_range(player)
		session._accept_player_pads(player)
		session._resolve_player_portals(player)
		session._accept_player_pads(player)
		session._accept_player_finish(player)
		session._grant_player_pickups(player)
	session.rule_vm.notify_every_ticks()


static func commit(session: TraprushMatchSession) -> void:
	session.live_patch.call("try_apply_pending", session)
	apply_falls(session)
	advance(session)


static func _capsule_ids(session: TraprushMatchSession) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for player: Dictionary in session._players:
		var capsule_id: int = player["capsule_id"]
		ids.append(capsule_id)
	return ids


static func _reset_capsules(session: TraprushMatchSession, ids: PackedInt32Array) -> void:
	for capsule_id: int in ids:
		for player: Dictionary in session._players:
			var player_id: int = player["capsule_id"]
			if player_id == capsule_id:
				session.scan.reset_player_to_pad(session, player)
				break


static func _apply_movers(session: TraprushMatchSession) -> void:
	var blocked: PackedInt32Array = MoverCycle.apply(
		session._world,
		session._mover_cycle,
		_capsule_ids(session),
		session.support_dy,
		racing_tick(session)
	)
	_reset_capsules(session, blocked)
	session.scan.apply_crushers(session)
	session.scan.apply_pendulums(session)


static func _apply_slides(session: TraprushMatchSession) -> void:
	var ids: PackedInt32Array = _capsule_ids(session)
	if session.conveyor_step > 0:
		ConveyorCycle.apply(
			session._world, session._conveyor_cycle, ids, session.support_dy, session.conveyor_step
		)
	if session.ice_step > 0:
		ConveyorCycle.apply(
			session._world, session._ice_cycle, ids, session.support_dy, session.ice_step
		)


static func _apply_launches(session: TraprushMatchSession) -> void:
	if session._launch_cycle.is_empty():
		return
	if session.launch_dy <= 0 and session.launch_xz <= 0:
		return
	session._launch_supported = LaunchCycle.apply(
		session._world, session._launch_cycle, _capsule_ids(session), session.support_dy,
		session.launch_dy, session.launch_xz, session._launch_supported
	)


static func _apply_gates(session: TraprushMatchSession) -> void:
	if session._gate_cycle.is_empty():
		return
	_reset_capsules(session, GateCycle.apply(
		session._world, session._switch_cycle, session._gate_cycle, _capsule_ids(session), session.support_dy
	))
