class_name AuthoringWindowLayout
extends RefCounted

## Embedded Editor + Preview panes inside the main viewport.
## Positions use the **host viewport** (project 1920×1080), not the 1600
## window override — otherwise Preview sits on top of Editor.
## `gui_embed_subwindows` stays true (Web, and the 4K `content_scale_*` trap).
## Default split is half/half. Panes follow host resize and stay user-resizable.
## Chrome layout, not gameplay geometry: do not copy these into placeholder_spec.

const MARGIN: int = 8
const GAP: int = 8
const FALLBACK_HOST: Vector2i = Vector2i(1920, 1080)
const FALLBACK_PANE_SIZE: Vector2i = Vector2i(948, 1064)
const PANE_MIN_SIZE: Vector2i = Vector2i(480, 360)
const SPLIT_MIN: float = 0.28
const SPLIT_MAX: float = 0.72

static var split_ratio: float = 0.5
static var _applying: bool = false
static var _expected_editor: Vector2i = Vector2i.ZERO
static var _expected_preview: Vector2i = Vector2i.ZERO


static func reset_split() -> void:
	split_ratio = 0.5
	_applying = false
	_expected_editor = Vector2i.ZERO
	_expected_preview = Vector2i.ZERO


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
	var widths: Vector2i = _pane_widths(host, 0.5)
	return Vector2i(widths.x, _pane_height(host))


static func editor_rect(host: Vector2i) -> Rect2i:
	var widths: Vector2i = _pane_widths(host, split_ratio)
	return Rect2i(Vector2i(MARGIN, MARGIN), Vector2i(widths.x, _pane_height(host)))


static func preview_rect(host: Vector2i) -> Rect2i:
	var widths: Vector2i = _pane_widths(host, split_ratio)
	return Rect2i(
		Vector2i(MARGIN + widths.x + GAP, MARGIN),
		Vector2i(widths.y, _pane_height(host))
	)


static func panes_overlap(host: Vector2i) -> bool:
	var left: Rect2i = editor_rect(host)
	var right: Rect2i = preview_rect(host)
	return left.position.x + left.size.x > right.position.x


static func apply_editor(window: Window, host: Node = null) -> void:
	_place(window, editor_rect(host_size_of(host)), true)


static func apply_preview(window: Window, host: Node = null) -> void:
	_place(window, preview_rect(host_size_of(host)), false)


static func apply_pair(editor: Window, preview: Window, host: Node = null) -> void:
	var size: Vector2i = host_size_of(host)
	_place(editor, editor_rect(size), true)
	_place(preview, preview_rect(size), false)


static func note_user_resize(editor: Window, preview: Window, host: Node = null) -> void:
	if _applying:
		return
	var editor_ok: bool = editor != null and is_instance_valid(editor)
	if editor_ok and editor.size == _expected_editor:
		var preview_ok: bool = preview != null and is_instance_valid(preview)
		if (not preview_ok) or preview.size == _expected_preview:
			return
	var host_size: Vector2i = host_size_of(host)
	var available: int = host_size.x - MARGIN * 2 - GAP
	if available < PANE_MIN_SIZE.x * 2:
		return
	if editor_ok and editor.size != _expected_editor:
		split_ratio = clampf(float(editor.size.x) / float(available), SPLIT_MIN, SPLIT_MAX)
	elif preview != null and is_instance_valid(preview) and preview.size != _expected_preview:
		split_ratio = clampf(
			1.0 - float(preview.size.x) / float(available),
			SPLIT_MIN,
			SPLIT_MAX
		)
	apply_pair(editor, preview, host)


static func _pane_height(host: Vector2i) -> int:
	var height: int = host.y - MARGIN * 2
	if height < PANE_MIN_SIZE.y:
		return PANE_MIN_SIZE.y
	return height


static func _pane_widths(host: Vector2i, ratio: float) -> Vector2i:
	var available: int = host.x - MARGIN * 2 - GAP
	var left: int = roundi(float(available) * ratio)
	if left < PANE_MIN_SIZE.x:
		left = PANE_MIN_SIZE.x
	if available - left < PANE_MIN_SIZE.x:
		left = available - PANE_MIN_SIZE.x
	if left < PANE_MIN_SIZE.x:
		left = PANE_MIN_SIZE.x
	return Vector2i(left, available - left)


static func _place(window: Window, rect: Rect2i, is_editor: bool) -> void:
	if window == null or not is_instance_valid(window):
		return
	_applying = true
	window.wrap_controls = false
	window.unresizable = false
	window.mode = Window.MODE_WINDOWED
	window.min_size = PANE_MIN_SIZE
	window.max_size = Vector2i.ZERO
	window.size = rect.size
	window.position = rect.position
	if is_editor:
		_expected_editor = rect.size
	else:
		_expected_preview = rect.size
	_applying = false
