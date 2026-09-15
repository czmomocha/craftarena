extends RefCounted

## Settlement JSON key sets and ranking checks for MatchJoinAccept.
## TRAPRUSH rows require unique consecutive places. BASTION may send teams[]
## with a draw (both place=1). Codec stays under the E9 line cap.

const MatchGameplayGd := preload("res://src/shared/match_gameplay.gd")
const MatchJoinCodecGd := preload("res://src/client/match_join_codec.gd")

const SETTLEMENT_KEYS: PackedStringArray = [
	"matchId",
	"tick",
	"stateHash",
	"padTotal",
	"mvpSlot",
	"rows",
	"createdAt",
]
const SETTLEMENT_KEYS_TEAMS: PackedStringArray = [
	"matchId",
	"tick",
	"stateHash",
	"padTotal",
	"mvpSlot",
	"rows",
	"createdAt",
	"teams",
]
const SETTLEMENT_ROW_KEYS: PackedStringArray = [
	"slot",
	"place",
	"finishTick",
	"acceptedCount",
]
const SETTLEMENT_TEAM_KEYS: PackedStringArray = [
	"teamId",
	"place",
	"coreHealth",
	"leaked",
	"finishTick",
]


static func is_body(body: Dictionary) -> bool:
	return (
		MatchJoinCodecGd.keys_only(body, SETTLEMENT_KEYS)
		or MatchJoinCodecGd.keys_only(body, SETTLEMENT_KEYS_TEAMS)
	)


static func parse_rows(rows: Array, mvp_slot: int, teams: Variant = null) -> Dictionary:
	if rows.is_empty() or rows.size() > 8:
		return {"ok": false}
	var slots: Dictionary = {}
	var places: Dictionary = {}
	var winner_slot: int = -1
	var collected: Array[Dictionary] = []
	var allow_tied_place: bool = typeof(teams) == TYPE_ARRAY
	for item: Variant in rows:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false}
		var row: Dictionary = item
		if not MatchJoinCodecGd.keys_only(row, SETTLEMENT_ROW_KEYS):
			return {"ok": false}
		var slot_read: Dictionary = MatchJoinCodecGd.read_int(row, "slot")
		var place_read: Dictionary = MatchJoinCodecGd.read_int(row, "place")
		var finish_read: Dictionary = MatchJoinCodecGd.read_int(row, "finishTick")
		var accepted_read: Dictionary = MatchJoinCodecGd.read_int(row, "acceptedCount")
		if not slot_read.get("ok", false) or not place_read.get("ok", false):
			return {"ok": false}
		if not finish_read.get("ok", false) or not accepted_read.get("ok", false):
			return {"ok": false}
		var slot_value: int = slot_read.get("value", -1)
		var place_value: int = place_read.get("value", 0)
		var finish_value: int = finish_read.get("value", -1)
		var accepted_value: int = accepted_read.get("value", -1)
		if slot_value < 0 or slot_value > 7:
			return {"ok": false}
		if place_value < 1 or place_value > 8:
			return {"ok": false}
		if finish_value < 0 or accepted_value < 0:
			return {"ok": false}
		if slots.has(slot_value):
			return {"ok": false}
		if not allow_tied_place and places.has(place_value):
			return {"ok": false}
		slots[slot_value] = true
		places[place_value] = true
		collected.append({
			"slot": slot_value,
			"place": place_value,
			"finish_tick": finish_value,
			"accepted_count": accepted_value,
		})
		if place_value == 1:
			winner_slot = slot_value
	if allow_tied_place:
		if not _teams_match_rows(teams, collected, mvp_slot):
			return {"ok": false}
	else:
		if winner_slot < 0 or winner_slot != mvp_slot:
			return {"ok": false}
		for place_index: int in range(1, rows.size() + 1):
			if not places.has(place_index):
				return {"ok": false}
	var parts: PackedStringArray = PackedStringArray()
	for item: Dictionary in collected:
		parts.append("#%ds%d" % [item["place"], item["slot"]])
	return {
		"ok": true,
		"line": "%s mvp=%d" % [",".join(parts), mvp_slot],
		"rows": collected,
	}


static func _teams_match_rows(teams_raw: Variant, rows: Array[Dictionary], mvp_slot: int) -> bool:
	if typeof(teams_raw) != TYPE_ARRAY:
		return false
	var teams: Array = teams_raw
	if teams.size() != 2 or rows.size() != 2:
		return false
	var by_team: Dictionary = {}
	for item: Variant in teams:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var team: Dictionary = item
		if not MatchJoinCodecGd.keys_only(team, SETTLEMENT_TEAM_KEYS):
			return false
		var team_read: Dictionary = MatchJoinCodecGd.read_int(team, "teamId")
		var place_read: Dictionary = MatchJoinCodecGd.read_int(team, "place")
		var health_read: Dictionary = MatchJoinCodecGd.read_int(team, "coreHealth")
		var leaked_read: Dictionary = MatchJoinCodecGd.read_int(team, "leaked")
		var finish_read: Dictionary = MatchJoinCodecGd.read_int(team, "finishTick")
		if not team_read.get("ok", false) or not place_read.get("ok", false):
			return false
		if not health_read.get("ok", false) or not leaked_read.get("ok", false):
			return false
		if not finish_read.get("ok", false):
			return false
		var team_id: int = team_read.get("value", 0)
		var place_value: int = place_read.get("value", 0)
		if MatchGameplayGd.seat_for_team_id(team_id) < 0 or by_team.has(team_id):
			return false
		if place_value != 1 and place_value != 2:
			return false
		if health_read.get("value", -1) < 0 or leaked_read.get("value", -1) < 0:
			return false
		if finish_read.get("value", -1) < 0:
			return false
		by_team[team_id] = place_value
	if not by_team.has(MatchGameplayGd.TEAM_A) or not by_team.has(MatchGameplayGd.TEAM_B):
		return false
	for row: Dictionary in rows:
		var slot_value: int = row["slot"]
		var team_id: int = MatchGameplayGd.team_id_for_seat(slot_value)
		if team_id == 0 or not by_team.has(team_id):
			return false
		if row["place"] != by_team[team_id]:
			return false
	var place_one: int = 0
	var winner_seat: int = -1
	for team_id: int in by_team.keys():
		if by_team[team_id] == 1:
			place_one += 1
			winner_seat = MatchGameplayGd.seat_for_team_id(team_id)
	if place_one == 2:
		return mvp_slot == 0 or mvp_slot == 1
	return place_one == 1 and mvp_slot == winner_seat
