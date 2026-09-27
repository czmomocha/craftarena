class_name MatchProgress
extends RefCounted

## Client-only race progress along the checkpoint polyline.
## Inputs are compiled wayfind bags (Q48.16) and already-accepted snapshot
## fields. Not authority, not a protocol field.

const KIND_OWN: String = "own"
const KIND_REMOTE: String = "remote"
const KIND_GHOST: String = "ghost"

const GhostGd := preload("res://src/client/match_offline_ghost.gd")
const PlayClockGd := preload("res://src/shared/play_clock.gd")


static func polyline(pads: Array, finish: Array) -> Array:
	var ordered: Array = []
	for raw: Variant in pads:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var pad: Dictionary = raw
		var point: Dictionary = _point_of(pad)
		if point.is_empty():
			continue
		var order: int = _int_of(pad, "order", -1)
		if order < 0:
			continue
		point["order"] = order
		ordered.append(point)
	ordered.sort_custom(_order_less)
	var points: Array = []
	for item: Variant in ordered:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var bag: Dictionary = item
		points.append({"x": bag["x"], "y": bag["y"], "z": bag["z"]})
	for raw: Variant in finish:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var finish_bag: Dictionary = raw
		var point: Dictionary = _point_of(finish_bag)
		if point.is_empty():
			continue
		points.append(point)
		break
	return points


static func total_length(points: Array) -> float:
	var total: float = 0.0
	if points.size() < 2:
		return total
	for index: int in range(points.size() - 1):
		var from_raw: Variant = points[index]
		var to_raw: Variant = points[index + 1]
		if typeof(from_raw) != TYPE_DICTIONARY or typeof(to_raw) != TYPE_DICTIONARY:
			continue
		var from_point: Dictionary = from_raw
		var to_point: Dictionary = to_raw
		total += _dist(from_point, to_point)
	return total


static func progress_along(points: Array, accepted: int, x: int, y: int, z: int) -> float:
	if accepted < 0 or points.size() < 2:
		return 0.0
	var last_index: int = points.size() - 2
	var seg: int = clampi(accepted, 0, last_index)
	var completed: float = 0.0
	for index: int in range(seg):
		var from_raw: Variant = points[index]
		var to_raw: Variant = points[index + 1]
		if typeof(from_raw) != TYPE_DICTIONARY or typeof(to_raw) != TYPE_DICTIONARY:
			continue
		var from_point: Dictionary = from_raw
		var to_point: Dictionary = to_raw
		completed += _dist(from_point, to_point)
	var start_raw: Variant = points[seg]
	var end_raw: Variant = points[seg + 1]
	if typeof(start_raw) != TYPE_DICTIONARY or typeof(end_raw) != TYPE_DICTIONARY:
		return completed
	var start_point: Dictionary = start_raw
	var end_point: Dictionary = end_raw
	return completed + _project_clamped(x, y, z, start_point, end_point)


static func percent(
	points: Array,
	accepted: int,
	x: int,
	y: int,
	z: int,
	finish_tick: int = -1
) -> int:
	if finish_tick >= 0:
		return 100
	var total: float = total_length(points)
	if total <= 0.0:
		return 0
	var along: float = progress_along(points, accepted, x, y, z)
	return clampi(roundi(along / total * 100.0), 0, 100)


static func markers(points: Array, players: Array, own_slot: int, ghost: Dictionary) -> Array:
	var out: Array = []
	for slot: int in range(players.size()):
		var raw: Variant = players[slot]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var kind: String = KIND_OWN if slot == own_slot else KIND_REMOTE
		var body: Dictionary = raw
		var marker: Dictionary = marker_from_player(points, body, kind, slot)
		if not marker.is_empty():
			out.append(marker)
	if not ghost.is_empty():
		var ghost_marker: Dictionary = marker_from_player(points, ghost, KIND_GHOST, -1)
		if not ghost_marker.is_empty():
			out.append(ghost_marker)
	return out


static func marker_from_player(points: Array, body: Dictionary, kind: String, slot: int) -> Dictionary:
	var x: int = _int_of(body, "x", 0)
	var y: int = _int_of(body, "y", 0)
	var z: int = _int_of(body, "z", 0)
	if not body.has("x") or typeof(body["x"]) != TYPE_INT:
		return {}
	if not body.has("z") or typeof(body["z"]) != TYPE_INT:
		return {}
	var accepted: int = _int_of(body, "accepted_count", 0)
	var finish_tick: int = _int_of(body, "finish_tick", -1)
	return {
		"kind": kind,
		"slot": slot,
		"percent": percent(points, accepted, x, y, z, finish_tick),
	}


static func fill_lobby_view(
	view: Dictionary,
	course: MatchCourseMap,
	follow: MatchSnapshotFollow,
	own_slot: int,
	offline: MatchOfflineSession
) -> void:
	view["progress_markers"] = []
	if not PlayClockGd.dict_bool(view, "play_hud_active", false):
		return
	if PlayClockGd.dict_bool(view, "bastion_active", false):
		return
	var pads: Array = []
	var finish: Array = []
	if course != null:
		pads = course.wayfind_pads()
		finish = course.wayfind_finish()
	var players: Array = []
	if follow != null:
		players = follow.players
	view["progress_markers"] = markers(
		polyline(pads, finish), players, own_slot, ghost_player(offline)
	)


static func ghost_player(offline: MatchOfflineSession) -> Dictionary:
	if offline == null or not GhostGd.is_active(offline):
		return {}
	if offline.ghost.follow.players.is_empty():
		return {}
	var raw: Variant = offline.ghost.follow.players[0]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	return body


static func albedo_for(kind: String) -> Color:
	if kind == KIND_OWN:
		return PlaceholderSpec.OWN_ALBEDO
	var remote: Color = PlaceholderSpec.REMOTE_ALBEDO
	if kind == KIND_GHOST:
		remote.a = MatchSnapshotMapGhost.FADE
	return remote


static func _point_of(bag: Dictionary) -> Dictionary:
	if not bag.has("x") or typeof(bag["x"]) != TYPE_INT:
		return {}
	if not bag.has("y") or typeof(bag["y"]) != TYPE_INT:
		return {}
	if not bag.has("z") or typeof(bag["z"]) != TYPE_INT:
		return {}
	return {"x": bag["x"], "y": bag["y"], "z": bag["z"]}


static func _int_of(bag: Dictionary, key: String, fallback: int) -> int:
	var raw: Variant = bag.get(key, fallback)
	if typeof(raw) != TYPE_INT:
		return fallback
	return raw


static func _order_less(left: Dictionary, right: Dictionary) -> bool:
	return _int_of(left, "order", 0) < _int_of(right, "order", 0)


static func _dist(from_point: Dictionary, to_point: Dictionary) -> float:
	return _delta(from_point, to_point).length()


static func _delta(from_point: Dictionary, to_point: Dictionary) -> Vector3:
	return Vector3(
		float(_int_of(to_point, "x", 0) - _int_of(from_point, "x", 0)),
		float(_int_of(to_point, "y", 0) - _int_of(from_point, "y", 0)),
		float(_int_of(to_point, "z", 0) - _int_of(from_point, "z", 0))
	)


static func _project_clamped(
	x: int, y: int, z: int, from_point: Dictionary, to_point: Dictionary
) -> float:
	var ab: Vector3 = _delta(from_point, to_point)
	var length_sq: float = ab.length_squared()
	if length_sq <= 0.0:
		return 0.0
	var ap: Vector3 = Vector3(
		float(x - _int_of(from_point, "x", 0)),
		float(y - _int_of(from_point, "y", 0)),
		float(z - _int_of(from_point, "z", 0))
	)
	var t: float = clampf(ap.dot(ab) / length_sq, 0.0, 1.0)
	return t * ab.length()
