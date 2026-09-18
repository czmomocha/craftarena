class_name PlayHudOverlay
extends RefCounted

## Shared play HUD widgets: large clock, split popup, settlement table.
## Tokens on the status line stay untranslated; these labels are player-
## facing and go through UiCopy. Headless tests construct them the same
## way as the live windows.

const CLOCK_NAME: String = "Clock"
const SPLIT_NAME: String = "Split"
const GUIDE_NAME: String = "Guide"
const SETBACK_NAME: String = "Setback"
const ITEMS_NAME: String = "Items"
const ROOT_NAME: String = "PlayHud"
const ClockGd := preload("res://src/shared/play_clock.gd")
const PanelGd := preload("res://src/shared/match_settlement_panel.gd")

var clock: Label = null
var split: Label = null
var guide: Label = null
var setback: Label = null
var items: Label = null
var panel: PanelContainer = null
var root: VBoxContainer = null


func attach(window: Window, _toolbar: Control = null) -> void:
	if window == null:
		return
	root = VBoxContainer.new()
	root.name = ROOT_NAME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	root.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.offset_right = -8.0
	root.offset_bottom = -36.0
	root.add_theme_constant_override("separation", 2)
	window.add_child(root)
	clock = _make_label(CLOCK_NAME, PlaceholderSpec.HUD_CLOCK_FONT_SIZE)
	split = _make_label(SPLIT_NAME, PlaceholderSpec.HUD_SPLIT_FONT_SIZE)
	guide = _make_label(GUIDE_NAME, PlaceholderSpec.HUD_SPLIT_FONT_SIZE)
	setback = _make_label(SETBACK_NAME, PlaceholderSpec.HUD_SPLIT_FONT_SIZE)
	items = _make_label(ITEMS_NAME, PlaceholderSpec.HUD_SPLIT_FONT_SIZE)
	apply_text_color(PlaceholderSpec.HUD_TEXT_COLOR)
	panel = PanelGd.attach(window)


func apply_text_color(color: Color) -> void:
	for label: Label in [clock, split, guide, setback, items]:
		if label == null:
			continue
		label.add_theme_color_override("font_color", color)


func _make_label(node_name: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", font_size)
	root.add_child(label)
	return label


func apply(view: Dictionary) -> void:
	var playing: bool = ClockGd.dict_bool(view, "play_hud_active", false)
	var clock_tick: int = ClockGd.dict_int(view, "clock_tick", 0)
	if clock != null and is_instance_valid(clock):
		clock.visible = playing
		if playing:
			clock.text = ClockGd.format_clock(clock_tick)
		else:
			clock.text = ""
	if split != null and is_instance_valid(split):
		var line: String = str(view.get("split_line", ""))
		split.visible = playing and line != ""
		split.text = line
	if guide != null and is_instance_valid(guide):
		var guide_line: String = str(view.get("guide_text", ""))
		guide.visible = playing and guide_line != ""
		guide.text = guide_line
	if setback != null and is_instance_valid(setback):
		var setback_line: String = str(view.get("setback_text", ""))
		setback.visible = playing and setback_line != ""
		setback.text = setback_line
	if items != null and is_instance_valid(items):
		var bomb: int = ClockGd.dict_int(view, "bomb_count", -1)
		var dash: int = ClockGd.dict_int(view, "dash_count", -1)
		if playing and bomb >= 0 and dash >= 0:
			items.visible = true
			var line: String = "%s  %s" % [
				UiCopy.text(UiCopy.HUD_BOMB) % bomb,
				UiCopy.text(UiCopy.HUD_DASH) % dash,
			]
			var fails: int = ClockGd.dict_int(view, "fails_count", -1)
			if fails >= 0:
				line = "%s  %s" % [line, UiCopy.text(UiCopy.HUD_FAILS) % fails]
			items.text = line
		else:
			items.visible = false
			items.text = ""
	var board_raw: Variant = view.get("settlement_board", {})
	var board: Dictionary = {}
	if typeof(board_raw) == TYPE_DICTIONARY:
		board = board_raw
	PanelGd.apply(panel, board)


func clock_text() -> String:
	if clock == null or not is_instance_valid(clock):
		return ""
	return clock.text


func split_text() -> String:
	if split == null or not is_instance_valid(split):
		return ""
	return split.text


func guide_text() -> String:
	if guide == null or not is_instance_valid(guide):
		return ""
	return guide.text


func setback_text() -> String:
	if setback == null or not is_instance_valid(setback):
		return ""
	return setback.text


func items_text() -> String:
	if items == null or not is_instance_valid(items):
		return ""
	return items.text


func settlement_visible() -> bool:
	return panel != null and is_instance_valid(panel) and panel.visible
