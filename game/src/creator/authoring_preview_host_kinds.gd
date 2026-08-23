class_name AuthoringPreviewHostKinds
extends RefCounted

## CD-32 Preview host surfaces. Desktop Godot opens `window`.
## Browser tab is reserved; this slice does not open it.

const WINDOW: String = "window"
const TAB: String = "tab"

const ALL: PackedStringArray = [
	WINDOW,
	TAB,
]


static func contains(kind: String) -> bool:
	return ALL.has(kind)
