class_name AuthoringWindowLayout
extends RefCounted

## Embedded Editor + Preview panes inside the main viewport.
## Positions use the **host viewport** (project 1920×1080), not the 1600
## window override — otherwise Preview sits on top of Editor.
## `gui_embed_subwindows` stays true (Web, and the 4K `content_scale_*` trap).
## Chrome layout, not gameplay geometry: do not copy these into placeholder_spec.

const MARGIN: int = 8
const GAP: int = 8
const FALLBACK_HOST: Vector2i = Vector2i(1920, 1080)
const FALLBACK_PANE_SIZE: Vector2i = Vector2i(948, 1064)
const PANE_MIN_SIZE: Vector2i = Vector2i(480, 360)


static func host_size_of(host: Node) -> Vector2i:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return FALLBACK_HOST
	var parent: Node = host.get_parent()
	var probe: Node = host
	if host is Window and parent != null:
		probe = parent
	var viewport: Viewport = probe.get_viewport()
	if viewport == null:
		return FALLBACK_HOST
	var raw: Vector2 = viewport.get_visible_rect().size
	if raw.x < 64.0 or raw.y < 64.0:
		return FALLBACK_HOST
	return Vector2i(int(raw.x), int(raw.y))


static func pane_size(host: Vector2i) -> Vector2i:
	var width: int = (host.x - MARGIN * 2 - GAP) / 2
	var height: int = host.y - MARGIN * 2
	if width < PANE_MIN_SIZE.x:
		width = PANE_MIN_SIZE.x
	if height < PANE_MIN_SIZE.y:
		height = PANE_MIN_SIZE.y
	return Vector2i(width, height)


static func editor_rect(host: Vector2i) -> Rect2i:
	return Rect2i(Vector2i(MARGIN, MARGIN), pane_size(host))


static func preview_rect(host: Vector2i) -> Rect2i:
	var pane: Vector2i = pane_size(host)
	return Rect2i(Vector2i(MARGIN + pane.x + GAP, MARGIN), pane)


static func panes_overlap(host: Vector2i) -> bool:
	var left: Rect2i = editor_rect(host)
	var right: Rect2i = preview_rect(host)
	return left.position.x + left.size.x > right.position.x


static func apply_editor(window: Window, host: Node = null) -> void:
	_lock(window, editor_rect(host_size_of(host)))


static func apply_preview(window: Window, host: Node = null) -> void:
	_lock(window, preview_rect(host_size_of(host)))


static func apply_pair(editor: Window, preview: Window, host: Node = null) -> void:
	var size: Vector2i = host_size_of(host)
	_lock(editor, editor_rect(size))
	_lock(preview, preview_rect(size))


static func _lock(window: Window, rect: Rect2i) -> void:
	if window == null or not is_instance_valid(window):
		return
	window.wrap_controls = false
	window.unresizable = true
	window.mode = Window.MODE_WINDOWED
	window.min_size = rect.size
	window.max_size = rect.size
	window.size = rect.size
	window.position = rect.position
