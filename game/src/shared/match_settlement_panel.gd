class_name MatchSettlementPanel
extends RefCounted

## Presentation table for an already-built settlement board. Online boards
## come from GET; Solo boards come from TraprushMatchSettlement.try_build.
## The client still never POSTs (allows_settlement stays false).

const PANEL_NAME: String = "SettlementPanel"
const TITLE_NAME: String = "SettlementTitle"
const MVP_NAME: String = "SettlementMvp"
const ROWS_NAME: String = "SettlementRows"
const LAYER_NAME: String = "SettlementLayer"

const TraprushMatchSettlementGd := preload("res://src/games/traprush/match_settlement.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const PlayClockGd := preload("res://src/shared/play_clock.gd")


static func board_from_session(session: TraprushMatchSessionGd) -> Dictionary:
	if session == null:
		return {"ok": false}
	return TraprushMatchSettlementGd.try_build(session)


static func board_from_join(
	has_settlement: bool,
	mvp_slot: int,
	pad_total: int,
	rows: Array
) -> Dictionary:
	if not has_settlement or rows.is_empty() or mvp_slot < 0:
		return {"ok": false}
	var copied: Array[Dictionary] = []
	for item: Variant in rows:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false}
		var row: Dictionary = item
		copied.append(row.duplicate())
	return {
		"ok": true,
		"mvp_slot": mvp_slot,
		"pad_total": pad_total,
		"rows": copied,
	}


static func format_rows(board: Dictionary) -> String:
	if not board.get("ok", false):
		return ""
	var rows_raw: Variant = board.get("rows", [])
	if typeof(rows_raw) != TYPE_ARRAY:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for item: Variant in rows_raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var place: int = PlayClockGd.dict_int(row, "place", 0)
		var slot: int = PlayClockGd.dict_int(row, "slot", -1)
		var finish_tick: int = PlayClockGd.dict_int(row, "finish_tick", -1)
		var accepted: int = PlayClockGd.dict_int(row, "accepted_count", -1)
		parts.append(
			"#%d  s%d  %s  pads=%d" % [
				place,
				slot,
				PlayClockGd.format_clock(finish_tick),
				accepted,
			]
		)
	return "\n".join(parts)


static func attach(window: Window) -> PanelContainer:
	if window == null:
		return null
	var existing: Node = window.get_node_or_null(LAYER_NAME)
	if existing != null:
		existing.free()
	var layer: MarginContainer = MarginContainer.new()
	layer.name = LAYER_NAME
	layer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	layer.offset_left = -280.0
	layer.offset_top = 8.0
	layer.offset_right = -12.0
	layer.offset_bottom = 200.0
	layer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = PANEL_NAME
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "SettlementBox"
	panel.add_child(box)
	var title: Label = Label.new()
	title.name = TITLE_NAME
	title.text = UiCopy.text(UiCopy.RESULTS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", PlaceholderSpec.HUD_SPLIT_FONT_SIZE)
	box.add_child(title)
	var mvp: Label = Label.new()
	mvp.name = MVP_NAME
	mvp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvp.add_theme_font_size_override("font_size", PlaceholderSpec.HUD_SPLIT_FONT_SIZE)
	box.add_child(mvp)
	var rows: Label = Label.new()
	rows.name = ROWS_NAME
	rows.autowrap_mode = TextServer.AUTOWRAP_OFF
	rows.add_theme_font_size_override("font_size", PlaceholderSpec.HUD_SPLIT_FONT_SIZE)
	box.add_child(rows)
	return panel


static func apply(panel: PanelContainer, board: Dictionary) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var ok: bool = PlayClockGd.dict_bool(board, "ok", false)
	panel.visible = ok
	if not ok:
		return
	var mvp: Label = panel.get_node_or_null("SettlementBox/%s" % MVP_NAME) as Label
	if mvp != null:
		mvp.text = "%s %d" % [UiCopy.text(UiCopy.MVP), PlayClockGd.dict_int(board, "mvp_slot", -1)]
	var rows: Label = panel.get_node_or_null("SettlementBox/%s" % ROWS_NAME) as Label
	if rows != null:
		rows.text = format_rows(board)
