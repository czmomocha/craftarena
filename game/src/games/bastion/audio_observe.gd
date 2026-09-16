class_name BastionAudioObserve
extends RefCounted

## Diffs adjacent BASTION snapshots into router events. Never writes
## authority; Headless stays silent because the audio module is.

const RouterGd := preload("res://src/games/bastion/audio_router.gd")
const SnapshotGd := preload("res://src/shared/protocol/bastion_frame_snapshot.gd")

var _last_tick: int = -1
var _prev_phase: int = -1
var _prev_result: int = 0
var _prev_teams: Dictionary = {}


func reset() -> void:
	_last_tick = -1
	_prev_phase = -1
	_prev_result = 0
	_prev_teams.clear()


func collect(follow: BastionSnapshotFollow) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if follow == null or not follow.has_snapshot:
		return out
	if follow.tick < _last_tick:
		return out
	if follow.tick == _last_tick:
		return out
	if _last_tick < 0:
		_store(follow)
		return out
	_append_phase(out, follow)
	_append_teams(out, follow)
	_store(follow)
	return out


func _append_phase(out: PackedStringArray, follow: BastionSnapshotFollow) -> void:
	if follow.phase != _prev_phase:
		if _prev_phase == SnapshotGd.PHASE_SETUP and follow.phase != SnapshotGd.PHASE_SETUP:
			out.append(RouterGd.EVENT_REVEAL)
		if follow.phase == BastionMatchSession.PHASE_SETTLED:
			out.append(RouterGd.EVENT_SETTLED)
	if follow.result != 0 and _prev_result == 0:
		if out.find(RouterGd.EVENT_SETTLED) < 0:
			out.append(RouterGd.EVENT_SETTLED)


func _append_teams(out: PackedStringArray, follow: BastionSnapshotFollow) -> void:
	for item: Variant in follow.teams:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var team: Dictionary = item
		var team_id: int = _i(team, "team_id")
		var prev_raw: Variant = _prev_teams.get(team_id, {})
		if typeof(prev_raw) != TYPE_DICTIONARY:
			continue
		var prev: Dictionary = prev_raw
		if prev.is_empty():
			continue
		if _i(team, "locked") == 1 and _i(prev, "locked") == 0:
			out.append(RouterGd.EVENT_LOCK)
		if _i(team, "leaked") > _i(prev, "leaked"):
			out.append(RouterGd.EVENT_LEAK)
		if _i(team, "kills") > _i(prev, "kills"):
			out.append(RouterGd.EVENT_KILL)
		if _i(team, "core_health") < _i(prev, "core_health"):
			out.append(RouterGd.EVENT_CORE)
		var towers: Array = _arr(team, "towers")
		var prev_towers: Array = _arr(prev, "towers")
		if towers.size() > prev_towers.size():
			out.append(RouterGd.EVENT_BUILD)
		elif towers.size() < prev_towers.size():
			out.append(RouterGd.EVENT_SELL)
		elif _tower_upgraded(towers, prev_towers):
			out.append(RouterGd.EVENT_UPGRADE)
		var obstacles: Array = _arr(team, "obstacles")
		var prev_obstacles: Array = _arr(prev, "obstacles")
		if obstacles.size() > prev_obstacles.size():
			out.append(RouterGd.EVENT_PLACE)


func _tower_upgraded(towers: Array, previous: Array) -> bool:
	if towers.size() != previous.size():
		return false
	var prev_levels: Dictionary = {}
	for item: Variant in previous:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var tower: Dictionary = item
		prev_levels[_i(tower, "slot_id")] = _i(tower, "level")
	for item: Variant in towers:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var tower: Dictionary = item
		var slot_id: int = _i(tower, "slot_id")
		var level: int = _i(tower, "level")
		var prev_level: int = prev_levels.get(slot_id, 0)
		if level > prev_level:
			return true
	return false


func _store(follow: BastionSnapshotFollow) -> void:
	_last_tick = follow.tick
	_prev_phase = follow.phase
	_prev_result = follow.result
	_prev_teams.clear()
	for item: Variant in follow.teams:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var team: Dictionary = item
		_prev_teams[_i(team, "team_id")] = team.duplicate(true)


static func _i(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	return raw


static func _arr(body: Dictionary, key: String) -> Array:
	var raw: Variant = body.get(key, [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw
