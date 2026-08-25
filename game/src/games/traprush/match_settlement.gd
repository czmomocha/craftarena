class_name TraprushMatchSettlement
extends RefCounted

## Single-match TRAPRUSH settlement from the authoritative session
## (CD-13 §4, CD-21 §6.1). Built only when every configured player has
## finish_tick >= 0. Ranking reuses TraprushStanding (finish_tick, then
## slot). This is the write payload, not a live HUD and not MMR.
## Path-distance / pad-arrival-time ranking stay deferred.

const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushStanding := preload("res://src/games/traprush/standing.gd")


static func all_finished(session: TraprushMatchSession) -> bool:
	if session == null:
		return false
	var count: int = session.player_count()
	if count < 1:
		return false
	for slot: int in range(count):
		if session.player_finish_tick(slot) < 0:
			return false
	return true


static func try_build(session: TraprushMatchSession) -> Dictionary:
	if not all_finished(session):
		return {"ok": false}
	var players: Array[Dictionary] = []
	for slot: int in range(session.player_count()):
		players.append({
			"accepted_count": session.player_accepted_count(slot),
			"finish_tick": session.player_finish_tick(slot),
		})
	var standing: Dictionary = TraprushStanding.from_players(players, session.checkpoint_count())
	if not standing.get("ok", false):
		return {"ok": false}
	var mvp_raw: Variant = standing.get("mvp_slot", -1)
	if typeof(mvp_raw) != TYPE_INT:
		return {"ok": false}
	var mvp_slot: int = mvp_raw
	if mvp_slot < 0:
		return {"ok": false}
	var rows_raw: Variant = standing.get("rows", [])
	if typeof(rows_raw) != TYPE_ARRAY:
		return {"ok": false}
	var rows: Array[Dictionary] = []
	for item: Variant in rows_raw:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false}
		var row: Dictionary = item
		var slot_raw: Variant = row.get("slot", -1)
		var place_raw: Variant = row.get("place", 0)
		var finish_raw: Variant = row.get("finish_tick", -1)
		var accepted_raw: Variant = row.get("accepted_count", -1)
		if typeof(slot_raw) != TYPE_INT or typeof(place_raw) != TYPE_INT:
			return {"ok": false}
		if typeof(finish_raw) != TYPE_INT or typeof(accepted_raw) != TYPE_INT:
			return {"ok": false}
		var finish_tick: int = finish_raw
		if finish_tick < 0:
			return {"ok": false}
		rows.append({
			"slot": slot_raw,
			"place": place_raw,
			"finish_tick": finish_tick,
			"accepted_count": accepted_raw,
		})
	if rows.is_empty():
		return {"ok": false}
	return {
		"ok": true,
		"tick": session.tick_index(),
		"state_hash": session.hash_state(),
		"pad_total": session.checkpoint_count(),
		"mvp_slot": mvp_slot,
		"rows": rows,
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
	}
