extends RefCounted

## Single-match BASTION settlement from the authoritative session.
## Built only in PHASE_SETTLED. HTTP still requires TRAPRUSH rows + padTotal;
## teams[] carries the real 1v1 ranking. padTotal is 0. acceptedCount is 0.
## Draw: both teams place=1, mvpSlot is 0 or 1 (this builder uses 0).

const BastionBlueprintBundleGd := preload("res://src/ugc/bastion_blueprint_bundle.gd")
const BastionMatchSessionGd := preload("res://src/games/bastion/match_session.gd")


static func all_finished(session: BastionMatchSessionGd) -> bool:
	if session == null:
		return false
	return session.phase == BastionMatchSessionGd.PHASE_SETTLED


static func try_build(session: BastionMatchSessionGd) -> Dictionary:
	if not all_finished(session):
		return {"ok": false}
	var result_id: int = session.result
	var place_a: int = 2
	var place_b: int = 2
	var mvp_slot: int = 0
	if result_id == BastionMatchSessionGd.RESULT_DRAW:
		place_a = 1
		place_b = 1
		mvp_slot = 0
	elif result_id == BastionBlueprintBundleGd.TEAM_A:
		place_a = 1
		place_b = 2
		mvp_slot = 0
	elif result_id == BastionBlueprintBundleGd.TEAM_B:
		place_a = 2
		place_b = 1
		mvp_slot = 1
	else:
		return {"ok": false}
	var finish_a: int = _finish_tick(session, BastionBlueprintBundleGd.TEAM_A)
	var finish_b: int = _finish_tick(session, BastionBlueprintBundleGd.TEAM_B)
	return {
		"ok": true,
		"tick": session.tick_index(),
		"state_hash": session.hash_state(),
		"pad_total": 0,
		"mvp_slot": mvp_slot,
		"rows": [
			_row(0, place_a, finish_a),
			_row(1, place_b, finish_b),
		],
		"teams": [
			_team(session, BastionBlueprintBundleGd.TEAM_A, place_a, finish_a),
			_team(session, BastionBlueprintBundleGd.TEAM_B, place_b, finish_b),
		],
	}


static func to_heartbeat(built: Dictionary) -> Dictionary:
	if not built.get("ok", false):
		return {}
	return {
		"tick": built.get("tick", 0),
		"state_hash": built.get("state_hash", ""),
		"pad_total": built.get("pad_total", 0),
		"mvp_slot": built.get("mvp_slot", -1),
		"rows": built.get("rows", []),
		"teams": built.get("teams", []),
	}


static func _finish_tick(session: BastionMatchSessionGd, team_id: int) -> int:
	var clear_tick: int = session.clear_tick(team_id)
	if clear_tick > 0:
		return clear_tick
	return session.tick_index()


static func _row(slot: int, place: int, finish_tick: int) -> Dictionary:
	return {
		"slot": slot,
		"place": place,
		"finish_tick": finish_tick,
		"accepted_count": 0,
	}


static func _team(
	session: BastionMatchSessionGd, team_id: int, place: int, finish_tick: int
) -> Dictionary:
	return {
		"team_id": team_id,
		"place": place,
		"core_health": session.core_health(team_id),
		"leaked": session.leaked(team_id),
		"finish_tick": finish_tick,
	}
