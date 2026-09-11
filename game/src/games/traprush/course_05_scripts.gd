class_name TraprushCourse05Scripts
extends RefCounted

## Scripted routes for official `course_05`.
## Danger shortcut: stand on the −Z side of the spine energy wall (UseItem
## reach is +Z only), break it, step back onto z=0, walk +X into the ascent
## portal, then the upstairs pads. Safe road walks +Z / +X / −Z around the
## wall and does not spend the bomb. Indices match
## TraprushCourseCompletionProbe._ACTION_NAMES.
##
## Default A* can air-strafe around the wall in a few ticks because gravity is
## slow and the Q alcove is open. `--bot-run --course=course_05` therefore
## replays this hint instead of searching.

const _MOVE_X: int = 0
const _MOVE_Z: int = 2
const _MOVE_NEG_Z: int = 3
const _USE_ITEM: int = 9


static func fast_hint() -> PackedByteArray:
	var packed: PackedByteArray = PackedByteArray()
	packed.append(_MOVE_X)
	packed.append(_MOVE_NEG_Z)
	packed.append(_MOVE_X)
	packed.append(_USE_ITEM)
	packed.append(_MOVE_Z)
	var walk_i: int = 0
	while walk_i < 5:
		packed.append(_MOVE_X)
		walk_i += 1
	return packed


static func fast_names() -> Array:
	var names: Array = []
	for action: int in fast_hint():
		names.append(TraprushCourseCompletionProbe._ACTION_NAMES[action])
	return names


static func safe_names() -> Array:
	return [
		"move+z", "move+z", "move+z",
		"move+x", "move+x", "move+x", "move+x",
		"move-z", "move-z", "move-z",
		"move+x", "move+x", "move+x",
	]
