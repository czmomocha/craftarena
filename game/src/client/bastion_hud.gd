class_name BastionHud
extends RefCounted

## BASTION status-line tokens. Names stay untranslated like `pads=`.

const PHASE_NAMES: PackedStringArray = [
	"handshake",
	"setup",
	"prep",
	"waves",
	"settled",
]


static func phase_name(phase: int) -> String:
	if phase < 0 or phase >= PHASE_NAMES.size():
		return "unknown"
	return PHASE_NAMES[phase]


static func view_from_follow(
	follow: BastionSnapshotFollow,
	own_team_id: int,
	wave_total: int,
	remain: int
) -> Dictionary:
	var empty: Dictionary = {
		"active": false,
		"phase": 0,
		"phase_name": "",
		"remain": 0,
		"wave_index": 0,
		"wave_total": wave_total,
		"own_gold": 0,
		"own_leaked": 0,
		"own_locked": 0,
		"core_a": 0,
		"core_b": 0,
		"leaked_a": 0,
		"leaked_b": 0,
		"result": 0,
	}
	if follow == null or not follow.has_snapshot:
		return empty
	var own: Dictionary = follow.team_of(own_team_id)
	var a: Dictionary = follow.team_of(BastionBlueprintBundle.TEAM_A)
	var b: Dictionary = follow.team_of(BastionBlueprintBundle.TEAM_B)
	return {
		"active": true,
		"phase": follow.phase,
		"phase_name": phase_name(follow.phase),
		"remain": remain,
		"wave_index": follow.wave_index,
		"wave_total": wave_total,
		"own_gold": PlayClock.dict_int(own, "gold", 0),
		"own_leaked": PlayClock.dict_int(own, "leaked", 0),
		"own_locked": PlayClock.dict_int(own, "locked", 0),
		"core_a": PlayClock.dict_int(a, "core_health", 0),
		"core_b": PlayClock.dict_int(b, "core_health", 0),
		"leaked_a": PlayClock.dict_int(a, "leaked", 0),
		"leaked_b": PlayClock.dict_int(b, "leaked", 0),
		"result": follow.result,
	}


static func append_play(parts: PackedStringArray, view: Dictionary) -> void:
	if not view.get("active", false):
		return
	parts.append("phase=%s" % str(view.get("phase_name", "")))
	parts.append("remain=%d" % PlayClock.dict_int(view, "remain", 0))
	parts.append(
		"cores=%d/%d"
		% [PlayClock.dict_int(view, "core_a", 0), PlayClock.dict_int(view, "core_b", 0)]
	)
	parts.append("gold=%d" % PlayClock.dict_int(view, "own_gold", 0))
	parts.append(
		"wave=%d/%d"
		% [PlayClock.dict_int(view, "wave_index", 0), PlayClock.dict_int(view, "wave_total", 0)]
	)
	parts.append(
		"leaked=%d/%d"
		% [PlayClock.dict_int(view, "leaked_a", 0), PlayClock.dict_int(view, "leaked_b", 0)]
	)
	if PlayClock.dict_int(view, "own_locked", 0) == 1:
		parts.append("locked=1")
	var result_id: int = PlayClock.dict_int(view, "result", 0)
	if result_id != 0:
		parts.append("result=%d" % result_id)
