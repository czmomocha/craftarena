class_name TraprushCourse06Scripts
extends RefCounted

## Scripted climb for official `course_06`.
## Three two-way hops: walk +X into entity 10 (−6→−2), +X into 12 (−2→+2),
## −X into 14 (+2→+6), then −X onto the finish. Waits let gravity settle
## after each landing. Indices match TraprushCourseCompletionProbe._ACTION_NAMES.

const _MOVE_X: int = 0
const _MOVE_NEG_X: int = 1
const _WAIT: int = 10
const SETTLE_WAITS: int = 8
const LANDING_WAITS: int = 8


static func climb_hint() -> PackedByteArray:
	var packed: PackedByteArray = PackedByteArray()
	_append_waits(packed, SETTLE_WAITS)
	packed.append(_MOVE_X)
	_append_waits(packed, LANDING_WAITS)
	packed.append(_MOVE_X)
	_append_waits(packed, LANDING_WAITS)
	packed.append(_MOVE_NEG_X)
	_append_waits(packed, LANDING_WAITS)
	packed.append(_MOVE_NEG_X)
	_append_waits(packed, 2)
	return packed


static func climb_names() -> Array:
	var names: Array = []
	for action: int in climb_hint():
		names.append(TraprushCourseCompletionProbe._ACTION_NAMES[action])
	return names


static func _append_waits(packed: PackedByteArray, count: int) -> void:
	var i: int = 0
	while i < count:
		packed.append(_WAIT)
		i += 1
