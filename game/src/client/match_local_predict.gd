class_name MatchLocalPredict
extends RefCounted

## Presentation overlay for the local match seat (CD-21 §8 / CD-43).
## Move and Jump add Q48.16 offsets onto the latest authoritative own-slot
## pose. A newer snapshot tick clears the overlay (hard snap, not smooth
## reconciliation). Own slot is not interpolated. Portals, reset, items,
## finish, and remote capsules are not predicted. Overflow snaps to latest.

const MAX_SLOT: int = 7

var own_slot: int = -1
var origin_tick: int = -1
var dx: int = 0
var dy: int = 0
var dz: int = 0


func bind_slot(slot: int) -> bool:
	if slot < 0 or slot > MAX_SLOT:
		return false
	own_slot = slot
	clear_overlay()
	return true


func unbind() -> void:
	own_slot = -1
	clear_overlay()


func clear_overlay() -> void:
	origin_tick = -1
	dx = 0
	dy = 0
	dz = 0


func on_authoritative_tick(tick: int) -> void:
	if origin_tick < 0:
		origin_tick = tick
		return
	if tick == origin_tick:
		return
	origin_tick = tick
	dx = 0
	dy = 0
	dz = 0


func try_add_move(move_dx: int, move_dz: int) -> bool:
	if own_slot < 0:
		return false
	var next_x: FixedResult = Fixed.try_add(dx, move_dx)
	if not next_x.ok:
		return false
	var next_z: FixedResult = Fixed.try_add(dz, move_dz)
	if not next_z.ok:
		return false
	dx = next_x.value
	dz = next_z.value
	return true


func try_add_jump(jump_dy: int) -> bool:
	if own_slot < 0:
		return false
	var next_y: FixedResult = Fixed.try_add(dy, jump_dy)
	if not next_y.ok:
		return false
	dy = next_y.value
	return true


func try_apply(sampled_players: Array, latest_players: Array) -> Dictionary:
	if not _players_are_mappable(sampled_players):
		return _fail()
	if not _players_are_mappable(latest_players):
		return _fail()
	var copied: Array = _duplicate_players(sampled_players)
	if own_slot < 0:
		return _ok(copied)
	if own_slot >= copied.size() or own_slot >= latest_players.size():
		return _ok(copied)
	var latest_raw: Variant = latest_players[own_slot]
	if typeof(latest_raw) != TYPE_DICTIONARY:
		return _fail()
	var latest_body: Dictionary = latest_raw
	var latest_pose: Dictionary = _pose_from_player(latest_body)
	if latest_pose.is_empty():
		return _fail()
	var mixed: Dictionary = latest_body.duplicate(true)
	if not _offset_pose(mixed):
		mixed["x"] = latest_pose["x"]
		mixed["y"] = latest_pose["y"]
		mixed["z"] = latest_pose["z"]
	copied[own_slot] = mixed
	return _ok(copied)


func _offset_pose(body: Dictionary) -> bool:
	var pose: Dictionary = _pose_from_player(body)
	if pose.is_empty():
		return false
	var base_x: int = pose["x"]
	var base_y: int = pose["y"]
	var base_z: int = pose["z"]
	var x: Variant = _add_axis(base_x, dx)
	var y: Variant = _add_axis(base_y, dy)
	var z: Variant = _add_axis(base_z, dz)
	if x == null or y == null or z == null:
		return false
	body["x"] = x
	body["y"] = y
	body["z"] = z
	return true


func _add_axis(base_value: int, delta: int) -> Variant:
	if delta == 0:
		return base_value
	var mixed: FixedResult = Fixed.try_add(base_value, delta)
	if not mixed.ok:
		return null
	return mixed.value


func _players_are_mappable(players: Array) -> bool:
	for raw: Variant in players:
		if typeof(raw) != TYPE_DICTIONARY:
			return false
		var body: Dictionary = raw
		if _pose_from_player(body).is_empty():
			return false
	return true


func _pose_from_player(body: Dictionary) -> Dictionary:
	if not body.has("x") or typeof(body["x"]) != TYPE_INT:
		return {}
	if not body.has("y") or typeof(body["y"]) != TYPE_INT:
		return {}
	if not body.has("z") or typeof(body["z"]) != TYPE_INT:
		return {}
	if not body.has("yaw_bam") or typeof(body["yaw_bam"]) != TYPE_INT:
		return {}
	var x: int = body["x"]
	var y: int = body["y"]
	var z: int = body["z"]
	var yaw_bam: int = body["yaw_bam"]
	return {
		"x": x,
		"y": y,
		"z": z,
		"yaw_bam": yaw_bam,
	}


func _duplicate_players(players: Array) -> Array:
	var copied: Array = []
	for raw: Variant in players:
		var body: Dictionary = raw
		copied.append(body.duplicate(true))
	return copied


func _ok(players: Array) -> Dictionary:
	return {
		"ok": true,
		"players": players,
	}


func _fail() -> Dictionary:
	return {
		"ok": false,
		"players": [],
	}
