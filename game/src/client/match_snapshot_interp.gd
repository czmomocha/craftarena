class_name MatchSnapshotInterp
extends RefCounted

## Presentation pose sampler between two authoritative snapshots (CD-43).
## `t` is Q48.16 in 0..SCALE; it is caller-supplied, not a product
## interpolation window. Progress fields stay on the latest snapshot.
## A slot snaps to latest when any XYZ delta is at least one lattice
## cell (Fixed.SCALE / 1 presentation meter), which is not a
## reconciliation threshold. No prediction or correction.

const SNAP_DELTA: int = Fixed.SCALE


static func try_sample(previous_players: Array, latest_players: Array, t: int) -> Dictionary:
	if not _players_are_mappable(latest_players):
		return _fail()
	if latest_players.is_empty():
		return _ok([])
	if previous_players.is_empty() or not _players_are_mappable(previous_players):
		return _ok(_duplicate_players(latest_players))
	var amount: int = _clamp_t(t)
	var sampled: Array = []
	var index: int = 0
	for raw: Variant in latest_players:
		var latest_body: Dictionary = raw
		if index >= previous_players.size():
			sampled.append(latest_body.duplicate(true))
			index += 1
			continue
		var previous_raw: Variant = previous_players[index]
		if typeof(previous_raw) != TYPE_DICTIONARY:
			sampled.append(latest_body.duplicate(true))
			index += 1
			continue
		var previous_body: Dictionary = previous_raw
		var mixed: Dictionary = _mix_player(previous_body, latest_body, amount)
		if mixed.is_empty():
			return _fail()
		sampled.append(mixed)
		index += 1
	return _ok(sampled)


static func _mix_player(previous_body: Dictionary, latest_body: Dictionary, t: int) -> Dictionary:
	var previous_pose: Dictionary = _pose_from_player(previous_body)
	var latest_pose: Dictionary = _pose_from_player(latest_body)
	if previous_pose.is_empty() or latest_pose.is_empty():
		return {}
	var previous_x: int = previous_pose["x"]
	var previous_y: int = previous_pose["y"]
	var previous_z: int = previous_pose["z"]
	var previous_yaw: int = previous_pose["yaw_bam"]
	var latest_x: int = latest_pose["x"]
	var latest_y: int = latest_pose["y"]
	var latest_z: int = latest_pose["z"]
	var latest_yaw: int = latest_pose["yaw_bam"]
	var out: Dictionary = latest_body.duplicate(true)
	if _should_snap(previous_pose, latest_pose) or t >= Fixed.SCALE:
		return out
	if t <= 0:
		out["x"] = previous_x
		out["y"] = previous_y
		out["z"] = previous_z
		out["yaw_bam"] = previous_yaw
		return out
	var x: Variant = _lerp_axis(previous_x, latest_x, t)
	var y: Variant = _lerp_axis(previous_y, latest_y, t)
	var z: Variant = _lerp_axis(previous_z, latest_z, t)
	var yaw: Variant = _lerp_yaw(previous_yaw, latest_yaw, t)
	if x == null or y == null or z == null or yaw == null:
		return out
	out["x"] = x
	out["y"] = y
	out["z"] = z
	out["yaw_bam"] = yaw
	return out


static func _should_snap(previous_pose: Dictionary, latest_pose: Dictionary) -> bool:
	var px: int = previous_pose["x"]
	var py: int = previous_pose["y"]
	var pz: int = previous_pose["z"]
	var lx: int = latest_pose["x"]
	var ly: int = latest_pose["y"]
	var lz: int = latest_pose["z"]
	if _abs_delta(px, lx) >= SNAP_DELTA:
		return true
	if _abs_delta(py, ly) >= SNAP_DELTA:
		return true
	return _abs_delta(pz, lz) >= SNAP_DELTA


static func _abs_delta(left: int, right: int) -> int:
	var delta: FixedResult = Fixed.try_sub(right, left)
	if not delta.ok:
		return SNAP_DELTA
	var value: int = delta.value
	if value == Fixed.INT64_MIN:
		return SNAP_DELTA
	if value < 0:
		return -value
	return value


static func _lerp_axis(previous_value: int, latest_value: int, t: int) -> Variant:
	var delta: FixedResult = Fixed.try_sub(latest_value, previous_value)
	if not delta.ok:
		return null
	var step: FixedResult = Fixed.try_mul_div(delta.value, t, Fixed.SCALE)
	if not step.ok:
		return null
	var mixed: FixedResult = Fixed.try_add(previous_value, step.value)
	if not mixed.ok:
		return null
	return mixed.value


static func _lerp_yaw(previous_bam: int, latest_bam: int, t: int) -> Variant:
	var from_yaw: int = Fixed.wrap_bam(previous_bam)
	var to_yaw: int = Fixed.wrap_bam(latest_bam)
	var delta: int = to_yaw - from_yaw
	var half_turn: int = Fixed.BAM_TURN / 2
	if delta > half_turn:
		delta -= Fixed.BAM_TURN
	if delta < -half_turn:
		delta += Fixed.BAM_TURN
	var step: FixedResult = Fixed.try_mul_div(delta, t, Fixed.SCALE)
	if not step.ok:
		return null
	var mixed: FixedResult = Fixed.try_add(from_yaw, step.value)
	if not mixed.ok:
		return null
	return Fixed.wrap_bam(mixed.value)


static func _clamp_t(t: int) -> int:
	if t < 0:
		return 0
	if t > Fixed.SCALE:
		return Fixed.SCALE
	return t


static func _players_are_mappable(players: Array) -> bool:
	for raw: Variant in players:
		if typeof(raw) != TYPE_DICTIONARY:
			return false
		var body: Dictionary = raw
		if _pose_from_player(body).is_empty():
			return false
	return true


static func _pose_from_player(body: Dictionary) -> Dictionary:
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


static func _duplicate_players(players: Array) -> Array:
	var copied: Array = []
	for raw: Variant in players:
		var body: Dictionary = raw
		copied.append(body.duplicate(true))
	return copied


static func _ok(players: Array) -> Dictionary:
	return {
		"ok": true,
		"players": players,
	}


static func _fail() -> Dictionary:
	return {
		"ok": false,
		"players": [],
	}
