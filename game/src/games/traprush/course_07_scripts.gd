class_name TraprushCourse07Scripts
extends RefCounted

## Scripted WR for official `course_07`. Foldbacks per terrace then portal hops.
## Indices match TraprushCourseCompletionProbe._ACTION_NAMES.

const LayoutGd := preload("res://src/games/traprush/course_07_layout.gd")

const _MOVE_X: int = 0
const _MOVE_NEG_X: int = 1
const _MOVE_Z: int = 2
const _MOVE_NEG_Z: int = 3
const _WAIT: int = 10
const SETTLE_WAITS: int = 8


static func fast_hint() -> PackedByteArray:
	var packed: PackedByteArray = PackedByteArray()
	_append_waits(packed, SETTLE_WAITS)
	var terrace: int = 0
	while terrace < LayoutGd.TERRACE_COUNT:
		var cells: Array[Vector2i] = LayoutGd.wr_cells(terrace)
		var i: int = 1
		while i < cells.size():
			packed.append(_move_dir(cells[i - 1], cells[i]))
			i += 1
		if terrace < LayoutGd.TERRACE_COUNT - 1:
			_append_waits(packed, SETTLE_WAITS)
		terrace += 1
	return packed


static func move_count(hint: PackedByteArray = PackedByteArray()) -> int:
	var packed: PackedByteArray = hint
	if packed.is_empty():
		packed = fast_hint()
	var count: int = 0
	for action: int in packed:
		if action >= 0 and action <= 3:
			count += 1
	return count


static func fast_names() -> Array:
	var names: Array = []
	for action: int in fast_hint():
		names.append(TraprushCourseCompletionProbe._ACTION_NAMES[action])
	return names


static func _move_dir(from_cell: Vector2i, to_cell: Vector2i) -> int:
	var dx: int = to_cell.x - from_cell.x
	var dz: int = to_cell.y - from_cell.y
	if dx == 1 and dz == 0:
		return _MOVE_X
	if dx == -1 and dz == 0:
		return _MOVE_NEG_X
	if dx == 0 and dz == 1:
		return _MOVE_Z
	return _MOVE_NEG_Z


static func _append_waits(packed: PackedByteArray, count: int) -> void:
	var i: int = 0
	while i < count:
		packed.append(_WAIT)
		i += 1
