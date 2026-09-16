class_name BastionSnapshotFollow
extends RefCounted

## Latest-authoritative BASTION snapshot follower. Type 6 only.
## Older ticks keep the last good frame. No prediction.

const CodecGd := preload("res://src/shared/protocol/bastion_frame_codec.gd")

var has_snapshot: bool = false
var tick: int = -1
var phase: int = 0
var wave_index: int = 0
var result: int = 0
var teams: Array = []
var phase_started_tick: int = 0


func apply_frame(bytes: PackedByteArray) -> bool:
	var decoded: Dictionary = CodecGd.decode_snapshot(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	if not decoded_ok:
		return false
	var next_tick: int = decoded.get("tick", -1)
	if has_snapshot and next_tick < tick:
		return false
	var next_teams: Variant = decoded.get("teams", [])
	if typeof(next_teams) != TYPE_ARRAY:
		return false
	var next_phase: int = decoded.get("phase", 0)
	if (not has_snapshot) or next_phase != phase:
		phase_started_tick = next_tick
	tick = next_tick
	phase = next_phase
	var next_wave: int = decoded.get("wave_index", 0)
	var next_result: int = decoded.get("result", 0)
	wave_index = next_wave
	result = next_result
	teams = next_teams
	has_snapshot = true
	return true


func team_of(team_id: int) -> Dictionary:
	for item: Variant in teams:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var team: Dictionary = item
		var found: int = team.get("team_id", 0)
		if found == team_id:
			return team
	return {}


func remain_ticks(limit: int) -> int:
	if limit < 1:
		return 0
	var elapsed: int = tick - phase_started_tick
	if elapsed < 0:
		return limit
	if elapsed >= limit:
		return 0
	return limit - elapsed


func status_view() -> Dictionary:
	return {
		"has_snapshot": has_snapshot,
		"tick": tick,
		"phase": phase,
		"wave_index": wave_index,
		"result": result,
		"team_count": teams.size(),
	}
