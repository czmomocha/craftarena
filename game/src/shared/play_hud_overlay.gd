class_name PlayHudOverlay
extends RefCounted

## Shared play HUD widgets: large clock, split popup, settlement table.
## Tokens on the status line stay untranslated; these labels are player-
## facing and go through UiCopy. Headless tests construct them the same
## way as the live windows.

const CLOCK_NAME: String = "Clock"
const SPLIT_NAME: String = "Split"
const ClockGd := preload("res://src/shared/play_clock.gd")
const PanelGd := preload("res://src/shared/match_settlement_panel.gd")

var clock: Label = null
var split: Label = null
var panel: PanelContainer = null


func attach(window: Window, toolbar: Control) -> void:
	if window == null or toolbar == null:
		return
	clock = Label.new()
	clock.name = CLOCK_NAME
	clock.add_theme_font_size_override("font_size", PlaceholderSpec.HUD_CLOCK_FONT_SIZE)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	toolbar.add_child(clock)
	var insert_at: int = 0
	var fps: Node = toolbar.get_node_or_null("Fps")
	if fps != null:
		insert_at = fps.get_index() + 1
	toolbar.move_child(clock, insert_at)
	split = Label.new()
	split.name = SPLIT_NAME
	split.add_theme_font_size_override("font_size", PlaceholderSpec.HUD_SPLIT_FONT_SIZE)
	toolbar.add_child(split)
	toolbar.move_child(split, insert_at + 1)
	panel = PanelGd.attach(window)


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


func settlement_visible() -> bool:
	return panel != null and is_instance_valid(panel) and panel.visible
