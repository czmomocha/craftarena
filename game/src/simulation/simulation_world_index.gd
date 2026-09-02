class_name SimulationWorldIndex
extends RefCounted

## Uniform-cell broadphase for static boxes. Narrowphase stays in Query.
## Candidates are a superset of actual overlaps, then sorted by box id so
## overlapping_* lists stay in spawn order.
## Overflow or a span above MAX_CELLS goes on an always-test list: a miss
## is worse than extra tests. Bucket size is Fixed.SCALE (world cell), not
## a new product size. Capsule-capsule queries stay linear.

const BUCKET: int = Fixed.SCALE
const MAX_CELLS: int = 125


var _cells: Dictionary = {}
var _always: PackedInt32Array = PackedInt32Array()
var _count: int = 0


static func cell_of(value: int) -> int:
	if value >= 0:
		return value / BUCKET
	return (value + 1) / BUCKET - 1


func insert(box_id: int, box: StaticAabb) -> void:
	_count = box_id
	var span: Dictionary = _try_aabb_span(box.x, box.y, box.z, box.half_x, box.half_y, box.half_z)
	var span_ok: bool = span.get("ok", false)
	if not span_ok or not _span_in_budget(span):
		_always.append(box_id)
		return
	var cx0: int = span["cx0"]
	var cx1: int = span["cx1"]
	var cy0: int = span["cy0"]
	var cy1: int = span["cy1"]
	var cz0: int = span["cz0"]
	var cz1: int = span["cz1"]
	var cy: int = cy0
	while cy <= cy1:
		var cz: int = cz0
		while cz <= cz1:
			var cx: int = cx0
			while cx <= cx1:
				_append_cell(Vector3i(cx, cy, cz), box_id)
				cx += 1
			cz += 1
		cy += 1


func candidates_for_capsule(capsule: KinematicCapsule) -> PackedInt32Array:
	var hy_res: FixedResult = Fixed.try_add(capsule.cylinder_height / 2, capsule.radius)
	if not hy_res.ok:
		return _all_ids()
	var span: Dictionary = _try_aabb_span(
		capsule.x, capsule.y, capsule.z, capsule.radius, hy_res.value, capsule.radius
	)
	var span_ok: bool = span.get("ok", false)
	if not span_ok or not _span_in_budget(span):
		return _all_ids()
	var seen: Dictionary = {}
	var acc: Array[int] = []
	_collect(_always, seen, acc)
	var cy: int = span["cy0"]
	var cy1: int = span["cy1"]
	var cz0: int = span["cz0"]
	var cz1: int = span["cz1"]
	var cx0: int = span["cx0"]
	var cx1: int = span["cx1"]
	while cy <= cy1:
		var cz: int = cz0
		while cz <= cz1:
			var cx: int = cx0
			while cx <= cx1:
				var key: Vector3i = Vector3i(cx, cy, cz)
				if _cells.has(key):
					var cell_ids: PackedInt32Array = _cells[key]
					_collect(cell_ids, seen, acc)
				cx += 1
			cz += 1
		cy += 1
	acc.sort()
	var out: PackedInt32Array = PackedInt32Array()
	for box_id: int in acc:
		out.append(box_id)
	return out


func _try_aabb_span(
	x: int, y: int, z: int, half_x: int, half_y: int, half_z: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	var min_x: FixedResult = Fixed.try_sub(x, half_x)
	if not min_x.ok:
		return failed
	var max_x: FixedResult = Fixed.try_add(x, half_x)
	if not max_x.ok:
		return failed
	var min_y: FixedResult = Fixed.try_sub(y, half_y)
	if not min_y.ok:
		return failed
	var max_y: FixedResult = Fixed.try_add(y, half_y)
	if not max_y.ok:
		return failed
	var min_z: FixedResult = Fixed.try_sub(z, half_z)
	if not min_z.ok:
		return failed
	var max_z: FixedResult = Fixed.try_add(z, half_z)
	if not max_z.ok:
		return failed
	var cx0: int = cell_of(min_x.value)
	var cx1: int = cell_of(max_x.value)
	var cy0: int = cell_of(min_y.value)
	var cy1: int = cell_of(max_y.value)
	var cz0: int = cell_of(min_z.value)
	var cz1: int = cell_of(max_z.value)
	if cx0 > cx1 or cy0 > cy1 or cz0 > cz1:
		return failed
	return {
		"ok": true,
		"cx0": cx0,
		"cx1": cx1,
		"cy0": cy0,
		"cy1": cy1,
		"cz0": cz0,
		"cz1": cz1,
	}


func _span_in_budget(span: Dictionary) -> bool:
	var cx0: int = span["cx0"]
	var cx1: int = span["cx1"]
	var cy0: int = span["cy0"]
	var cy1: int = span["cy1"]
	var cz0: int = span["cz0"]
	var cz1: int = span["cz1"]
	var sx: int = cx1 - cx0 + 1
	var sy: int = cy1 - cy0 + 1
	var sz: int = cz1 - cz0 + 1
	if sx < 1 or sy < 1 or sz < 1:
		return false
	if sx > MAX_CELLS or sy > MAX_CELLS or sz > MAX_CELLS:
		return false
	return sx * sy * sz <= MAX_CELLS


func _append_cell(key: Vector3i, box_id: int) -> void:
	var ids: PackedInt32Array = PackedInt32Array()
	if _cells.has(key):
		ids = _cells[key]
	ids.append(box_id)
	_cells[key] = ids


func _collect(source: PackedInt32Array, seen: Dictionary, acc: Array[int]) -> void:
	for box_id: int in source:
		if seen.has(box_id):
			continue
		seen[box_id] = true
		acc.append(box_id)


func _all_ids() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var box_id: int = 1
	while box_id <= _count:
		out.append(box_id)
		box_id += 1
	return out
