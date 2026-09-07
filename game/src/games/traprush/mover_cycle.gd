class_name TraprushMoverCycle
extends RefCounted

## Authoritative moving solids (F-line FE). Pose is f(tick, path, speed, loop).
## v1 snapshots do not carry platform fields. hash_state still omits AABB;
## only passenger capsules change the hash. Failure mode: the platform always
## moves; a blocked passenger is returned so the session can out-of-range reset.


static func pose_at(tick_index: int, path: Array, speed: int, loop: bool) -> Dictionary:
	if path.size() < 2 or speed == 0:
		return _point_at(path, 0)
	var length: int = _path_length(path)
	if length < 1:
		return _point_at(path, 0)
	var distance: int = 0
	if speed > 0:
		distance = _mul_mod(tick_index, speed, length, loop)
	else:
		distance = _mul_mod(tick_index, -speed, length, loop)
		distance = length - distance
	return _point_along(path, distance, length, loop)


static func entries_from(movers: Array, solid_ids: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item: Variant in movers:
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var bag: Dictionary = item
		if typeof(bag.get("entity_id", null)) != TYPE_INT:
			return []
		if typeof(bag.get("speed", null)) != TYPE_INT:
			return []
		if typeof(bag.get("loop", null)) != TYPE_BOOL:
			return []
		if typeof(bag.get("path", null)) != TYPE_ARRAY:
			return []
		var entity_id: int = bag["entity_id"]
		if not solid_ids.has(entity_id):
			return []
		var box_raw: Variant = solid_ids[entity_id]
		if typeof(box_raw) != TYPE_INT:
			return []
		var box_id: int = box_raw
		if box_id < 1:
			return []
		var path: Array = bag["path"]
		if path.size() < 2:
			return []
		if not _path_is_axial(path):
			return []
		entries.append({
			"entity_id": entity_id,
			"box_id": box_id,
			"speed": bag["speed"],
			"loop": bag["loop"],
			"path": path.duplicate(true),
		})
	return entries


## Returns capsule ids that could not follow the full delta (caller resets).
static func apply(
	world: SimulationWorld,
	entries: Array,
	capsule_ids: PackedInt32Array,
	support_dy: int
) -> PackedInt32Array:
	var blocked: PackedInt32Array = PackedInt32Array()
	if world == null:
		return blocked
	for item: Variant in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var box_id: int = _int_field(entry, "box_id")
		var path_raw: Variant = entry.get("path", [])
		if typeof(path_raw) != TYPE_ARRAY:
			continue
		var path: Array = path_raw
		var speed: int = _int_field(entry, "speed")
		var loop_raw: Variant = entry.get("loop", false)
		if typeof(loop_raw) != TYPE_BOOL:
			continue
		var loop_on: bool = loop_raw
		var next: Dictionary = pose_at(world.tick_index, path, speed, loop_on)
		if next.is_empty():
			continue
		var old: Dictionary = world.static_box_pose(box_id)
		if old.is_empty():
			continue
		var dx: int = _int_field(next, "x") - _int_field(old, "x")
		var dy: int = _int_field(next, "y") - _int_field(old, "y")
		var dz: int = _int_field(next, "z") - _int_field(old, "z")
		if dx == 0 and dy == 0 and dz == 0:
			continue
		var riders: PackedInt32Array = PackedInt32Array()
		for capsule_id: int in capsule_ids:
			var supports: PackedInt32Array = world.supporting_solid_static_boxes(
				capsule_id, support_dy
			)
			for support_id: int in supports:
				if support_id == box_id:
					riders.append(capsule_id)
					break
		if not world.try_set_static_box_pose(
			box_id, _int_field(next, "x"), _int_field(next, "y"), _int_field(next, "z")
		):
			continue
		for capsule_id: int in riders:
			if not _follow(world, capsule_id, dx, dy, dz):
				blocked.append(capsule_id)
	return blocked


static func _follow(world: SimulationWorld, capsule_id: int, dx: int, dy: int, dz: int) -> bool:
	var before: Dictionary = world.get_pose(capsule_id)
	if before.is_empty():
		return false
	if not world.try_move_xz_until_blocked(capsule_id, dx, dz):
		return false
	if not world.try_move_y_until_blocked(capsule_id, dy):
		return false
	var after: Dictionary = world.get_pose(capsule_id)
	if after.is_empty():
		return false
	return after["x"] == before["x"] + dx and after["y"] == before["y"] + dy and after["z"] == before["z"] + dz


static func _path_is_axial(path: Array) -> bool:
	var index: int = 1
	while index < path.size():
		var prev: Dictionary = _as_xyz(path[index - 1])
		var cur: Dictionary = _as_xyz(path[index])
		if prev.is_empty() or cur.is_empty():
			return false
		var diffs: int = 0
		if prev["x"] != cur["x"]:
			diffs += 1
		if prev["y"] != cur["y"]:
			diffs += 1
		if prev["z"] != cur["z"]:
			diffs += 1
		if diffs != 1:
			return false
		index += 1
	return true


static func _path_length(path: Array) -> int:
	var total: int = 0
	var index: int = 1
	while index < path.size():
		var prev: Dictionary = _as_xyz(path[index - 1])
		var cur: Dictionary = _as_xyz(path[index])
		total += _manhattan(prev, cur)
		index += 1
	return total


static func _mul_mod(tick_index: int, speed: int, length: int, loop: bool) -> int:
	var period: int = length
	if loop:
		period = length * 2
	if period < 1:
		return 0
	var raw: int = tick_index * speed
	if raw < 0:
		raw = 0
	return raw % period


static func _point_along(path: Array, distance: int, length: int, loop: bool) -> Dictionary:
	var walked: int = distance
	if loop and walked > length:
		walked = length * 2 - walked
	var remain: int = walked
	var index: int = 1
	while index < path.size():
		var prev: Dictionary = _as_xyz(path[index - 1])
		var cur: Dictionary = _as_xyz(path[index])
		var seg: int = _manhattan(prev, cur)
		if remain <= seg:
			return _lerp_axis(prev, cur, remain, seg)
		remain -= seg
		index += 1
	return _point_at(path, path.size() - 1)


static func _lerp_axis(a: Dictionary, b: Dictionary, remain: int, seg: int) -> Dictionary:
	if seg < 1:
		return a.duplicate()
	var out: Dictionary = a.duplicate()
	if a["x"] != b["x"]:
		out["x"] = _step_toward(_int_field(a, "x"), _int_field(b, "x"), remain)
	elif a["y"] != b["y"]:
		out["y"] = _step_toward(_int_field(a, "y"), _int_field(b, "y"), remain)
	else:
		out["z"] = _step_toward(_int_field(a, "z"), _int_field(b, "z"), remain)
	return out


static func _step_toward(from_v: int, to_v: int, remain: int) -> int:
	if to_v >= from_v:
		return from_v + remain
	return from_v - remain


static func _manhattan(a: Dictionary, b: Dictionary) -> int:
	return abs(_int_field(a, "x") - _int_field(b, "x")) + abs(_int_field(a, "y") - _int_field(b, "y")) + abs(_int_field(a, "z") - _int_field(b, "z"))


static func _point_at(path: Array, index: int) -> Dictionary:
	if path.is_empty():
		return {}
	var safe: int = index
	if safe < 0:
		safe = 0
	if safe >= path.size():
		safe = path.size() - 1
	return _as_xyz(path[safe])


static func _int_field(bag: Dictionary, key: String) -> int:
	var raw: Variant = bag.get(key, null)
	if typeof(raw) != TYPE_INT:
		return 0
	var value: int = raw
	return value


static func _as_xyz(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var bag: Dictionary = value
	if typeof(bag.get("x", null)) != TYPE_INT:
		return {}
	if typeof(bag.get("y", null)) != TYPE_INT:
		return {}
	if typeof(bag.get("z", null)) != TYPE_INT:
		return {}
	return {"x": bag["x"], "y": bag["y"], "z": bag["z"]}
