class_name MatchProgressBar
extends RefCounted

## Top-of-window race rail. Own / remote / ghost markers + integer %.
## Presentation only; clock stays bottom-right, replay banner stays above.

const ROOT_NAME: String = "MatchProgress"
const TRACK_NAME: String = "Track"
const MARKERS_NAME: String = "Markers"
const MARKER_PREFIX: String = "Marker_"
const PlayClockGd := preload("res://src/shared/play_clock.gd")
const ProgressGd := preload("res://src/client/match_progress.gd")

const TRACK_HEIGHT: float = 8.0
const BAR_HEIGHT: float = 36.0
const SIDE_INSET: float = 96.0
const TRACK_ALPHA: float = 0.25

var root: Control = null
var track: ColorRect = null
var markers_root: Control = null


func attach(window: Window) -> void:
	if window == null:
		return
	var existing: Node = window.get_node_or_null(ROOT_NAME)
	if existing != null:
		root = existing as Control
		track = existing.get_node_or_null(TRACK_NAME) as ColorRect
		markers_root = existing.get_node_or_null(MARKERS_NAME) as Control
		return
	root = Control.new()
	root.name = ROOT_NAME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.offset_left = SIDE_INSET
	root.offset_right = -SIDE_INSET
	root.offset_top = 16.0 + float(PlaceholderSpec.HUD_CLOCK_FONT_SIZE)
	root.offset_bottom = root.offset_top + BAR_HEIGHT
	root.visible = false
	window.add_child(root)
	track = ColorRect.new()
	track.name = TRACK_NAME
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	track.offset_left = 0.0
	track.offset_right = 0.0
	track.anchor_right = 1.0
	var track_top: float = (BAR_HEIGHT - TRACK_HEIGHT) * 0.5
	track.offset_top = track_top
	track.offset_bottom = track_top + TRACK_HEIGHT
	var rail: Color = PlaceholderSpec.HUD_TEXT_COLOR
	rail.a = TRACK_ALPHA
	track.color = rail
	root.add_child(track)
	markers_root = Control.new()
	markers_root.name = MARKERS_NAME
	markers_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(markers_root)


func apply(view: Dictionary) -> void:
	if root == null or not is_instance_valid(root):
		return
	var playing: bool = PlayClockGd.dict_bool(view, "play_hud_active", false)
	var bastion: bool = PlayClockGd.dict_bool(view, "bastion_active", false)
	if not playing or bastion:
		root.visible = false
		_clear_markers()
		return
	root.visible = true
	var raw: Variant = view.get("progress_markers", [])
	var markers: Array = []
	if typeof(raw) == TYPE_ARRAY:
		markers = raw
	apply_markers(markers)


func apply_markers(markers: Array) -> void:
	if markers_root == null or not is_instance_valid(markers_root):
		return
	_clear_markers()
	for raw: Variant in markers:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = raw
		var kind: String = str(body.get("kind", ProgressGd.KIND_REMOTE))
		var slot: int = PlayClockGd.dict_int(body, "slot", -1)
		var value: int = clampi(PlayClockGd.dict_int(body, "percent", 0), 0, 100)
		markers_root.add_child(_make_marker(kind, slot, value))


func _make_marker(kind: String, slot: int, value: int) -> Control:
	var box: Control = Control.new()
	box.name = _marker_name(kind, slot)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: float = float(value) / 100.0
	box.anchor_left = t
	box.anchor_right = t
	box.anchor_top = 0.0
	box.anchor_bottom = 1.0
	box.offset_left = -14.0
	box.offset_right = 14.0
	box.offset_top = 0.0
	box.offset_bottom = 0.0
	var pip: ColorRect = ColorRect.new()
	pip.name = "Pip"
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.color = ProgressGd.albedo_for(kind)
	pip.offset_left = 9.0
	pip.offset_right = 19.0
	pip.offset_top = 2.0
	pip.offset_bottom = 12.0
	box.add_child(pip)
	var label: Label = Label.new()
	label.name = "Percent"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "%d%%" % value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -16.0
	label.add_theme_font_size_override("font_size", PlaceholderSpec.HUD_STATUS_FONT_SIZE)
	label.add_theme_color_override("font_color", PlaceholderSpec.HUD_TEXT_COLOR)
	box.add_child(label)
	return box


func _marker_name(kind: String, slot: int) -> String:
	if kind == ProgressGd.KIND_OWN:
		return MARKER_PREFIX + ProgressGd.KIND_OWN
	if kind == ProgressGd.KIND_GHOST:
		return MARKER_PREFIX + ProgressGd.KIND_GHOST
	return "%s%s_%d" % [MARKER_PREFIX, ProgressGd.KIND_REMOTE, slot]


func _clear_markers() -> void:
	if markers_root == null or not is_instance_valid(markers_root):
		return
	for child: Node in markers_root.get_children():
		markers_root.remove_child(child)
		child.free()
