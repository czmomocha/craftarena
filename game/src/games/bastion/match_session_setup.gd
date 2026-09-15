class_name BastionMatchSessionSetup
extends RefCounted

## 会话门面的互设障碍胶水。拆出来只为让 `BastionMatchSession` 低于 E9 400 行；
## 公开 API 仍在会话门面。规则本体在 `BastionMatchSetupState`。

const SetupStateGd := preload("res://src/games/bastion/match_setup_state.gd")
const WavesGd := preload("res://src/games/bastion/match_session_waves.gd")


static func try_place(
	session: BastionMatchSession, team_id: int, node_id: int, prototype_id: int
) -> bool:
	if session.phase != BastionMatchSession.PHASE_SETUP:
		return false
	return session._setup.try_place(
		session.bundle, team_id, node_id, prototype_id, session.tick
	)


static func try_lock(session: BastionMatchSession, team_id: int) -> bool:
	if session.phase != BastionMatchSession.PHASE_SETUP:
		return false
	if not session._setup.try_lock(team_id, session.tick):
		return false
	var team: Dictionary = session._team(team_id)
	team["locked"] = true
	return true


static func on_tick(session: BastionMatchSession) -> void:
	session._setup.record_tick(session.tick)
	var due: int = session.bundle.economy_value("setup_ticks")
	if not session._setup.both_locked() and session._phase_tick < due:
		return
	session._setup.reveal(session.bundle)
	_sync_committed(session)
	WavesGd.freeze_lanes(session)
	session._enter(BastionMatchSession.PHASE_PREP)


static func replay(
	bundle: BastionBlueprintBundle, seed: int, commands: Array
) -> BastionMatchSession:
	var session: BastionMatchSession = BastionMatchSession.create(bundle, seed)
	if session == null:
		return null
	if not session.begin_match():
		return null
	for item: Variant in commands:
		var command: Dictionary = item
		var kind: int = command["kind"]
		match kind:
			SetupStateGd.KIND_PLACE:
				var place_team: int = command["team_id"]
				var place_node: int = command["node_id"]
				var place_proto: int = command["prototype_id"]
				session.try_place_obstacle(place_team, place_node, place_proto)
			SetupStateGd.KIND_LOCK:
				var lock_team: int = command["team_id"]
				session.lock_setup(lock_team)
			SetupStateGd.KIND_TICK:
				session.commit_tick()
			_:
				return null
	return session


static func _sync_committed(session: BastionMatchSession) -> void:
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var team: Dictionary = session._team(team_id)
		var committed: Array[Dictionary] = session._setup.authority_placements(team_id)
		var obstacles: Array = []
		for placement: Dictionary in committed:
			obstacles.append(placement.duplicate(true))
		team["obstacles"] = obstacles
		team["locked"] = true
