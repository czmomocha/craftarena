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
const COUNTDOWN_NAME: String = "Countdown"
const REPLAY_NAME: String = "ReplayBanner"
const ROOT_NAME: String = "PlayHud"
const ClockGd := preload("res://src/shared/play_clock.gd")
const PanelGd := preload("res://src/shared/match_settlement_panel.gd")
const PlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const UiCopyPlayGd := preload("res://src/shared/ui_copy_play.gd")

var clock: Label = null
var split: Label = null
var guide: Label = null
var setback: Label = null
var items: Label = null
var countdown: Label = null
var replay_banner: Label = null
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
	countdown = Label.new()
	countdown.name = COUNTDOWN_NAME
	countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown.add_theme_font_size_override("font_size", PlaceholderSpec.HUD_COUNTDOWN_FONT_SIZE)
	countdown.add_theme_color_override("font_color", PlaceholderSpec.HUD_TEXT_COLOR)
	window.add_child(countdown)
	replay_banner = Label.new()
	replay_banner.name = REPLAY_NAME
	replay_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_banner.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	replay_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	replay_banner.offset_top = 16.0
	replay_banner.add_theme_font_size_override("font_size", PlaceholderSpec.HUD_CLOCK_FONT_SIZE)
	replay_banner.add_theme_color_override("font_color", PlaceholderSpec.HUD_TEXT_COLOR)
	window.add_child(replay_banner)


func apply_text_color(color: Color) -> void:
	for label: Label in [clock, split, guide, setback, items, countdown, replay_banner]:
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
	if countdown != null and is_instance_valid(countdown):
		var line: String = str(view.get("countdown_text", ""))
		countdown.visible = playing and line != ""
		countdown.text = line if countdown.visible else ""
	if replay_banner != null and is_instance_valid(replay_banner):
		var replay_on: bool = ClockGd.dict_bool(view, "replay_active", false)
		replay_banner.visible = playing and replay_on
		replay_banner.text = UiCopy.text(UiCopyPlayGd.REPLAY_BANNER) if replay_banner.visible else ""


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


static func countdown_line(world_tick: int, go_tick: int, player_count: int, playing: bool) -> String:
	if not playing or go_tick <= 0:
		return ""
	var tick: int = maxi(world_tick, 0)
	if player_count > 1 and tick <= 0:
		return UiCopy.text(UiCopyPlayGd.COUNTDOWN_WAIT)
	if tick >= go_tick:
		if tick - go_tick < PlayStubsGd.COUNTDOWN_GO_TICKS:
			return UiCopy.text(UiCopyPlayGd.COUNTDOWN_GO)
		return ""
	return str(PlayStubsGd.overlay_seconds(tick, go_tick))


func countdown_text() -> String:
	if countdown == null or not is_instance_valid(countdown):
		return ""
	return countdown.text
