extends Control
## Character select view. Fills chrome from UiCopy and emits intent.
## Persistence and lobby navigation stay on CharacterSelectEntry.

signal back_requested()
signal character_selected(id: String)

const UiCopyCharGd := preload("res://src/shared/ui_copy_char.gd")
const PreviewGd := preload("res://src/client/ui/scripts/character_select_preview.gd")

const _GRID := "Layout/Main/HBox/CardScroll/Grid"
const _HINT := "Layout/Main/HBox/PreviewColumn/Hint"
const _SELECTED := "Layout/Main/HBox/PreviewColumn/SelectedName"

const CARD_VARIATION: StringName = &"ContentCard"
const CARD_ACTIVE_VARIATION: StringName = &"TabChipActive"
const CARD_MIN_SIZE := Vector2(0, 88)

var _chrome_ready: bool = false
var _selected_id: String = SharedCharacterCatalog.DEFAULT_ID
var _cards: Dictionary = {}
var _preview: PreviewGd = PreviewGd.new()


func _ready() -> void:
	_ensure_chrome()


func _process(delta: float) -> void:
	if visible:
		_preview.advance(delta)


func _ensure_chrome() -> void:
	if _chrome_ready:
		return
	_chrome_ready = true
	_apply_copy()
	_wire_chrome()
	_fill_cards()
	_preview.mount(self)
	set_selected(_selected_id)


func _exit_tree() -> void:
	_preview.clear()


func set_selected(id: String) -> void:
	_ensure_chrome()
	_selected_id = SharedCharacterCatalog.resolve(id)
	_refresh_cards()
	_refresh_selected_copy()
	_preview.show_id(_selected_id)


func selected_id() -> String:
	return _selected_id


func _apply_copy() -> void:
	_set_text("Layout/TopBar/Row/TitleBox/Title", UiCopyCharGd.TITLE)
	_set_text("Layout/TopBar/Row/TitleBox/Subtitle", UiCopyCharGd.SUBTITLE)
	_set_text(_HINT, UiCopyCharGd.HINT)
	var back: Button = get_node_or_null("Layout/TopBar/Row/Back") as Button
	if back != null:
		back.text = UiCopy.text(UiCopyCharGd.BACK)


func _wire_chrome() -> void:
	var back: Button = get_node_or_null("Layout/TopBar/Row/Back") as Button
	if back != null:
		back.pressed.connect(func() -> void: back_requested.emit())


func _fill_cards() -> void:
	var grid: GridContainer = get_node_or_null(_GRID) as GridContainer
	if grid == null:
		return
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.free()
	_cards.clear()
	for id: String in SharedCharacterCatalog.all_ids():
		var button: Button = Button.new()
		button.name = "Card_%s" % id
		button.theme_type_variation = CARD_VARIATION
		button.custom_minimum_size = CARD_MIN_SIZE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = UiCopy.text(SharedCharacterCatalog.name_key(id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_card_pressed.bind(id))
		grid.add_child(button)
		_cards[id] = button


func _on_card_pressed(id: String) -> void:
	set_selected(id)
	character_selected.emit(_selected_id)


func _refresh_cards() -> void:
	for id: String in SharedCharacterCatalog.all_ids():
		if not _cards.has(id):
			continue
		var raw: Variant = _cards[id]
		if not (raw is Button):
			continue
		var button: Button = raw
		if id == _selected_id:
			button.theme_type_variation = CARD_ACTIVE_VARIATION
		else:
			button.theme_type_variation = CARD_VARIATION


func _refresh_selected_copy() -> void:
	var selected: Label = get_node_or_null(_SELECTED) as Label
	if selected == null:
		return
	selected.text = "%s %s" % [
		UiCopy.text(UiCopyCharGd.SELECTED),
		UiCopy.text(SharedCharacterCatalog.name_key(_selected_id)),
	]


func _set_text(path: String, key: String) -> void:
	_set_plain(path, UiCopy.text(key))


func _set_plain(path: String, value: String) -> void:
	var node: Node = get_node_or_null(path)
	if node is Label:
		(node as Label).text = value
	elif node is Button:
		(node as Button).text = value
