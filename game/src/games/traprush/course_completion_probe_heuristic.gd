class_name TraprushCourseProbeHeuristic
extends RefCounted

## Target, hop distance, and ground-action ranking for the completion probe.
## Public run_path / run_bundle stay on the probe facade so this file stays under E9.

static func _rank_ground_actions(
	session: TraprushMatchSession,
	pads: Array[Dictionary],
	finish: Dictionary,
	after: PackedInt32Array,
	bundle: SimulationBundle,
	action_count: int,
) -> PackedInt32Array:
	var pose: Dictionary = session.player_pose(0)
	var x: int = pose.get("x", 0)
	var y: int = pose.get("y", 0)
	var z: int = pose.get("z", 0)
	var accepted: int = session.player_accepted_count(0)
	var scored: Array[Dictionary] = []
	for action: int in range(action_count):
		var node: Dictionary = {
			"depth": 0,
			"x": x + TraprushCourseCompletionProbe._DIR_X[action] * Fixed.SCALE,
			"y": y,
			"z": z + TraprushCourseCompletionProbe._DIR_Z[action] * Fixed.SCALE,
			"accepted": accepted,
		}
		scored.append({
			"action": action,
			"pri": _priority(node, pads, finish, after, bundle),
		})
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_pri: int = left["pri"]
		var right_pri: int = right["pri"]
		return left_pri < right_pri
	)
	var ranked: PackedInt32Array = PackedInt32Array()
	for item: Dictionary in scored:
		var action_id: int = item["action"]
		ranked.append(action_id)
	return ranked

## 已验收 accepted 个检查点时，下一个要够到的东西在哪。
static func _target_for(
	accepted: int,
	pads: Array[Dictionary],
	finish: Dictionary,
	checkpoints: int,
) -> Dictionary:
	if accepted < checkpoints and accepted >= 0 and accepted < pads.size():
		var pad: Dictionary = pads[accepted]
		return {
			"kind": TraprushCourseCompletionProbe.TARGET_CHECKPOINT,
			"x": pad.get("x", 0),
			"y": pad.get("y", 0),
			"z": pad.get("z", 0),
		}
	return {
		"kind": TraprushCourseCompletionProbe.TARGET_FINISH,
		"x": finish.get("x", 0),
		"y": finish.get("y", 0),
		"z": finish.get("z", 0),
	}


static func _priority(
	node: Dictionary,
	pads: Array[Dictionary],
	finish: Dictionary,
	after: PackedInt32Array,
	bundle: SimulationBundle,
) -> int:
	var g: int = node["depth"]
	return g + TraprushCourseCompletionProbe._HEURISTIC_WEIGHT * _heuristic(node, pads, finish, after, bundle)


## 估计还要走多少步：先到下一个检查点，再顺着剩下的检查点链走到终点。
##
## 「剩下的链」这一项不能省。只估到下一个检查点的话，每验收一个检查点 h 都会
## 突然变大（目标换成了更远的下一个），f 随之跳升，A* 就掉头回去啃旧分支——
## 实测正是这样卡在 course_01 的第二个检查点上的。带上链长以后，进度前进会让
## h 减少一整段，f 单调下降，搜索才会一路往前。
static func _heuristic(
	node: Dictionary,
	pads: Array[Dictionary],
	finish: Dictionary,
	after: PackedInt32Array,
	bundle: SimulationBundle,
) -> int:
	var x: int = node["x"]
	var y: int = node["y"]
	var z: int = node["z"]
	var accepted: int = node["accepted"]
	if accepted >= 0 and accepted < pads.size():
		var pad: Dictionary = pads[accepted]
		var pad_x: int = pad.get("x", 0)
		var pad_y: int = pad.get("y", 0)
		var pad_z: int = pad.get("z", 0)
		return _hop_distance(x, y, z, pad_x, pad_y, pad_z, bundle) + after[accepted]
	var finish_x: int = finish.get("x", 0)
	var finish_y: int = finish.get("y", 0)
	var finish_z: int = finish.get("z", 0)
	return _hop_distance(x, y, z, finish_x, finish_y, finish_z, bundle)


## 沿检查点链走到终点还剩多少步。after[i] 是「刚够到 pads[i] 之后」的剩余量，
## after[n] = 0 表示检查点都齐了，只差终点。
static func _remaining_chain(
	pads: Array[Dictionary],
	finish: Dictionary,
	bundle: SimulationBundle,
) -> PackedInt32Array:
	var count: int = pads.size()
	var after: PackedInt32Array = PackedInt32Array()
	after.resize(count + 1)
	after[count] = 0
	var finish_x: int = finish.get("x", 0)
	var finish_y: int = finish.get("y", 0)
	var finish_z: int = finish.get("z", 0)
	var index: int = count - 1
	while index >= 0:
		var pad: Dictionary = pads[index]
		var pad_x: int = pad.get("x", 0)
		var pad_y: int = pad.get("y", 0)
		var pad_z: int = pad.get("z", 0)
		if index == count - 1:
			after[index] = _hop_distance(
				pad_x, pad_y, pad_z, finish_x, finish_y, finish_z, bundle
			)
		else:
			var next_pad: Dictionary = pads[index + 1]
			var next_x: int = next_pad.get("x", 0)
			var next_y: int = next_pad.get("y", 0)
			var next_z: int = next_pad.get("z", 0)
			var leg: int = _hop_distance(pad_x, pad_y, pad_z, next_x, next_y, next_z, bundle)
			after[index] = leg + after[index + 1]
		index -= 1
	return after


## 两点间格距，允许经最多两次传送门中转。跨一整格楼层的直线距离不算能走。
static func _hop_distance(
	x: int, y: int, z: int, tx: int, ty: int, tz: int, bundle: SimulationBundle
) -> int:
	var best: int = _cells_between(x, y, z, tx, ty, tz)
	for portal: Dictionary in bundle.portals:
		var via: int = _via_portal(x, y, z, tx, ty, tz, portal)
		if via < best:
			best = via
		var portal_id: int = portal.get("entity_id", 0)
		var entry_x: int = portal.get("x", 0)
		var entry_y: int = portal.get("y", 0)
		var entry_z: int = portal.get("z", 0)
		var dest_x: int = portal.get("dest_x", 0)
		var dest_y: int = portal.get("dest_y", 0)
		var dest_z: int = portal.get("dest_z", 0)
		for next_portal: Dictionary in bundle.portals:
			if next_portal.get("entity_id", 0) == portal_id:
				continue
			var next_entry_x: int = next_portal.get("x", 0)
			var next_entry_y: int = next_portal.get("y", 0)
			var next_entry_z: int = next_portal.get("z", 0)
			var next_dest_x: int = next_portal.get("dest_x", 0)
			var next_dest_y: int = next_portal.get("dest_y", 0)
			var next_dest_z: int = next_portal.get("dest_z", 0)
			var via_two: int = (
				_cells_between(x, y, z, entry_x, entry_y, entry_z)
				+ _cells_between(dest_x, dest_y, dest_z, next_entry_x, next_entry_y, next_entry_z)
				+ _cells_between(next_dest_x, next_dest_y, next_dest_z, tx, ty, tz)
			)
			if via_two < best:
				best = via_two
	return best


static func _via_portal(
	x: int, y: int, z: int, tx: int, ty: int, tz: int, portal: Dictionary
) -> int:
	var entry_x: int = portal.get("x", 0)
	var entry_y: int = portal.get("y", 0)
	var entry_z: int = portal.get("z", 0)
	var dest_x: int = portal.get("dest_x", 0)
	var dest_y: int = portal.get("dest_y", 0)
	var dest_z: int = portal.get("dest_z", 0)
	return (
		_cells_between(x, y, z, entry_x, entry_y, entry_z)
		+ _cells_between(dest_x, dest_y, dest_z, tx, ty, tz)
	)


## XZ 用 Chebyshev（对角一步同时走 x 与 z）。跨一整格楼层不能走：占位跳跃
## 冲量只有四分之一格，上楼必须经传送。
static func _cells_between(x: int, y: int, z: int, tx: int, ty: int, tz: int) -> int:
	var dx: int = absi(tx - x) / Fixed.SCALE
	var dy: int = absi(ty - y) / Fixed.SCALE
	var dz: int = absi(tz - z) / Fixed.SCALE
	var xz: int = maxi(dx, dz)
	if dy >= 1:
		return TraprushCourseCompletionProbe._FLOOR_HOPS + xz
	return xz

static func _ordered_pads(bundle: SimulationBundle) -> Array[Dictionary]:
	var pads: Array[Dictionary] = bundle.pads.duplicate()
	pads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_order: int = a.get("order", 0)
		var b_order: int = b.get("order", 0)
		if a_order != b_order:
			return a_order < b_order
		var a_id: int = a.get("entity_id", 0)
		var b_id: int = b.get("entity_id", 0)
		return a_id < b_id
	)
	return pads

