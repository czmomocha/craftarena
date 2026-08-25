class_name TraprushStanding
extends RefCounted

## Live TRAPRUSH standings from authoritative snapshot fields (CD-21 §6.1).
## Finished players rank by finish_tick, then slot. Unfinished players
## follow, ranked by accepted_count descending, then slot. Path distance
## and pad-arrival time are not in the v1 snapshot and stay deferred.
## This is the live board. Settlement write reuses the same ranking when
## every configured player has finished. Not MMR and not an online write.

const UNFINISHED_TICK: int = -1


static func from_players(players: Array, pad_total: int = 0) -> Dictionary:
	if pad_total < 0:
		return {"ok": false}
	var parsed: Array[Dictionary] = []
	var slot: int = 0
	for raw: Variant in players:
		if typeof(raw) != TYPE_DICTIONARY:
			return {"ok": false}
		var body: Dictionary = raw
		var row: Dictionary = _row_from_player(slot, body, pad_total)
		if row.is_empty():
			return {"ok": false}
		parsed.append(row)
		slot += 1
	parsed.sort_custom(_compare_rows)
	var ranked: Array[Dictionary] = []
	var mvp_slot: int = -1
	var place: int = 1
	for row: Dictionary in parsed:
		var out: Dictionary = row.duplicate()
		out["place"] = place
		ranked.append(out)
		var finished: bool = out["finished"]
		if finished and mvp_slot < 0:
			var winner_slot: int = out["slot"]
			mvp_slot = winner_slot
		place += 1
	return {
		"ok": true,
		"rows": ranked,
		"mvp_slot": mvp_slot,
		"pad_total": pad_total,
	}


static func format_line(standing: Dictionary) -> String:
	if not standing.get("ok", false):
		return ""
	var rows_raw: Variant = standing.get("rows", [])
	if typeof(rows_raw) != TYPE_ARRAY:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var rows: Array = rows_raw
	for raw: Variant in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		var place: int = row.get("place", 0)
		var slot: int = row.get("slot", -1)
		if typeof(place) != TYPE_INT or typeof(slot) != TYPE_INT:
			continue
		parts.append("#%ds%d" % [place, slot])
	var mvp_raw: Variant = standing.get("mvp_slot", -1)
	var mvp_slot: int = -1
	if typeof(mvp_raw) == TYPE_INT:
		mvp_slot = mvp_raw
	var board: String = "-"
	if not parts.is_empty():
		board = ",".join(parts)
	if mvp_slot < 0:
		return "standings=%s mvp=-" % board
	return "standings=%s mvp=%d" % [board, mvp_slot]


static func _row_from_player(slot: int, body: Dictionary, pad_total: int) -> Dictionary:
	if not body.has("accepted_count") or typeof(body["accepted_count"]) != TYPE_INT:
		return {}
	if not body.has("finish_tick") or typeof(body["finish_tick"]) != TYPE_INT:
		return {}
	var accepted_count: int = body["accepted_count"]
	var finish_tick: int = body["finish_tick"]
	if accepted_count < 0:
		return {}
	if finish_tick < UNFINISHED_TICK:
		return {}
	var finished: bool = finish_tick >= 0
	return {
		"slot": slot,
		"accepted_count": accepted_count,
		"finish_tick": finish_tick,
		"finished": finished,
		"pad_total": pad_total,
	}


static func _compare_rows(left: Dictionary, right: Dictionary) -> bool:
	var left_finished: bool = left["finished"]
	var right_finished: bool = right["finished"]
	if left_finished != right_finished:
		return left_finished
	if left_finished:
		var left_tick: int = left["finish_tick"]
		var right_tick: int = right["finish_tick"]
		if left_tick != right_tick:
			return left_tick < right_tick
	else:
		var left_pads: int = left["accepted_count"]
		var right_pads: int = right["accepted_count"]
		if left_pads != right_pads:
			return left_pads > right_pads
	var left_slot: int = left["slot"]
	var right_slot: int = right["slot"]
	return left_slot < right_slot
