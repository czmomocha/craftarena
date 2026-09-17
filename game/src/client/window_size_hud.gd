class_name WindowSizeHud
extends Label

## Bottom-right client size of the host Window / viewport.
## Developer overlay: digits only, not product copy, not a locale key.

const HUD_NAME: StringName = &"WindowSizeHud"


static func attach(host: Node) -> Label:
	if host == null:
		return null
	var existing: Node = host.get_node_or_null(NodePath(HUD_NAME))
	if existing != null:
		if existing.has_method("refresh"):
			existing.call("refresh")
		return existing as Label
	var hud: Label = new()
	hud.name = String(HUD_NAME)
	host.add_child(hud)
	return hud


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -180.0
	offset_top = -28.0
	offset_right = -12.0
	offset_bottom = -8.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_theme_font_size_override("font_size", PlaceholderSpec.HUD_STATUS_FONT_SIZE)
	modulate = PlaceholderSpec.WINDOW_SIZE_HUD_MODULATE
	var win: Window = get_window()
	if win != null and not win.size_changed.is_connected(refresh):
		win.size_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var win: Window = get_window()
	if win == null:
		text = ""
		return
	text = "%d × %d" % [win.size.x, win.size.y]
