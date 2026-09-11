class_name MatchAudioSource
extends RefCounted

## Diffs adjacent authoritative snapshots into router events.
## v1 frames have no vy / stun / intent fields. Jump is a y rising
## edge; land is a y falling edge. Misses and false plays are expected.

const RouterGd := preload("res://src/games/traprush/traprush_audio_router.gd")
const PlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const AudioServiceGd := preload("res://src/audio/audio_service.gd")

const KEY_EVENT: String = "event"
const KEY_SLOT: String = "slot"
const KEY_REMOTE: String = "remote"
const KEY_X: String = AudioServiceGd.KEY_X
const KEY_Y: String = AudioServiceGd.KEY_Y
const KEY_Z: String = AudioServiceGd.KEY_Z

var step_stride: int = PlaceholderSpec.MOVE_STEP
var jump_dy: int = PlayStubsGd.JUMP_DY
var _last_tick: int = -1
var _prev_players: Array = []
var _prev_crates: Array = []
var _step_accum: Dictionary = {}


func reset() -> void:
	_last_tick = -1
	_prev_players = []
	_prev_crates = []
	_step_accum.clear()


func collect(follow: MatchSnapshotFollow, own_slot: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if follow == null or not follow.has_snapshot:
		return out
	if follow.tick < _last_tick:
		return out
	if follow.tick == _last_tick:
		return out
	if _last_tick < 0:
		_store(follow)
		return out
	_append_players(out, follow.players, own_slot)
	_append_crates(out, follow.crates)
	_append_settled(out, follow.players)
	_store(follow)
	return out


func _store(follow: MatchSnapshotFollow) -> void:
	_last_tick = follow.tick
	_prev_players = _duplicate_rows(follow.players)
	_prev_crates = _duplicate_rows(follow.crates)


func _append_players(out: Array[Dictionary], players: Array, own_slot: int) -> void:
	var count: int = mini(_prev_players.size(), players.size())
	var rise: int = jump_dy / 2
	if rise < 1:
		rise = 1
	var air: int = jump_dy / 4
	if air < 1:
		air = 1
	for slot: int in range(count):
		var prev: Dictionary = _row(_prev_players, slot)
		var now: Dictionary = _row(players, slot)
		if prev.is_empty() or now.is_empty():
			continue
		var dy: int = _int_at(now, "y", 0) - _int_at(prev, "y", 0)
		if dy >= rise:
			out.append(_event(RouterGd.EVENT_JUMP, slot, own_slot, now))
		elif dy <= -air:
			out.append(_event(RouterGd.EVENT_LAND, slot, own_slot, now))
		elif dy > -air and dy < air:
			_append_step(out, slot, own_slot, prev, now)
		if _int_at(now, "accepted_count", 0) > _int_at(prev, "accepted_count", 0):
			out.append(_event(RouterGd.EVENT_CHECKPOINT, slot, own_slot, now))
		if _int_at(now, "finish_tick", -1) >= 0 and _int_at(prev, "finish_tick", -1) < 0:
			out.append(_event(RouterGd.EVENT_FINISH, slot, own_slot, now))


func _append_step(
	out: Array[Dictionary],
	slot: int,
	own_slot: int,
	prev: Dictionary,
	now: Dictionary
) -> void:
	if step_stride < 1:
		return
	var dx: int = _int_at(now, "x", 0) - _int_at(prev, "x", 0)
	var dz: int = _int_at(now, "z", 0) - _int_at(prev, "z", 0)
	if dx < 0:
		dx = -dx
	if dz < 0:
		dz = -dz
	var accum: int = _variant_int(_step_accum.get(slot, 0), 0) + dx + dz
	if accum < step_stride:
		_step_accum[slot] = accum
		return
	_step_accum[slot] = 0
	out.append(_event(RouterGd.EVENT_STEP, slot, own_slot, now))


func _append_crates(out: Array[Dictionary], crates: Array) -> void:
	var before: Dictionary = _crate_map(_prev_crates)
	var after: Dictionary = _crate_map(crates)
	for key: Variant in before.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		var prev_hp: int = _variant_int(before.get(entity_id, 0), 0)
		var now_hp: int = _variant_int(after.get(entity_id, prev_hp), prev_hp)
		if prev_hp > 0 and now_hp <= 0:
			out.append({
				KEY_EVENT: RouterGd.EVENT_BREAK_CRATE,
				KEY_SLOT: -1,
				KEY_REMOTE: false,
			})


func _append_settled(out: Array[Dictionary], players: Array) -> void:
	if players.is_empty():
		return
	if not _all_finished(players):
		return
	if _all_finished(_prev_players):
		return
	out.append({
		KEY_EVENT: RouterGd.EVENT_SETTLED,
		KEY_SLOT: -1,
		KEY_REMOTE: false,
	})


func _event(event: String, slot: int, own_slot: int, pose: Dictionary) -> Dictionary:
	var remote: bool = own_slot >= 0 and slot != own_slot
	var body: Dictionary = {
		KEY_EVENT: event,
		KEY_SLOT: slot,
		KEY_REMOTE: remote,
	}
	if not remote:
		return body
	var scale: float = float(Fixed.SCALE)
	body[KEY_X] = float(_int_at(pose, "x", 0)) / scale
	body[KEY_Y] = float(_int_at(pose, "y", 0)) / scale
	body[KEY_Z] = float(_int_at(pose, "z", 0)) / scale
	return body


static func _all_finished(players: Array) -> bool:
	if players.is_empty():
		return false
	for raw: Variant in players:
		var row: Dictionary = _as_dict(raw)
		if row.is_empty():
			return false
		if _int_at(row, "finish_tick", -1) < 0:
			return false
	return true


static func _crate_map(crates: Array) -> Dictionary:
	var out: Dictionary = {}
	for raw: Variant in crates:
		var row: Dictionary = _as_dict(raw)
		if row.is_empty():
			continue
		var entity_id: int = _int_at(row, "entity_id", 0)
		if entity_id == 0:
			continue
		out[entity_id] = _int_at(row, "durability", 0)
	return out


static func _duplicate_rows(source: Array) -> Array:
	var copied: Array = []
	for raw: Variant in source:
		var row: Dictionary = _as_dict(raw)
		if row.is_empty():
			continue
		copied.append(row.duplicate(true))
	return copied


static func _row(source: Array, index: int) -> Dictionary:
	if index < 0 or index >= source.size():
		return {}
	return _as_dict(source[index])


static func _as_dict(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	return body


static func _int_at(body: Dictionary, key: String, fallback: int) -> int:
	return _variant_int(body.get(key, fallback), fallback)


static func _variant_int(raw: Variant, fallback: int) -> int:
	if typeof(raw) != TYPE_INT:
		return fallback
	var value: int = raw
	return value
