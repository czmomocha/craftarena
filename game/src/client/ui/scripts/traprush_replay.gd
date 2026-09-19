extends Control
## TRAPRUSH match-record list. View only; persist and playback stay on the entry.

signal back_requested()
signal play_requested(index: int)

const UiCopyPlayGd := preload("res://src/shared/ui_copy_play.gd")

const _LIST := "Layout/Main/List"
const _EMPTY := "Layout/Main/Empty"
const _ERROR := "Layout/Main/Error"

var _chrome_ready: bool = false
var _rows: Array[Dictionary] = []


func _ready() -> void:
	_ensure_chrome()


func set_rows(rows: Array) -> void:
	_ensure_chrome()
	_rows.clear()
	for item: Variant in rows:
		if typeof(item) == TYPE_DICTIONARY:
			_rows.append(item)
	_fill_list()


func set_error(code: String) -> void:
	_ensure_chrome()
	var error: Label = get_node_or_null(_ERROR) as Label
	if error == null:
		return
	if code == "":
		error.text = ""
		error.visible = false
		return
	error.visible = true
	error.text = code


func _ensure_chrome() -> void:
	if _chrome_ready:
		return
	_chrome_ready = true
	_apply_copy()
	_wire_chrome()


func _apply_copy() -> void:
	_set_text("Layout/TopBar/Row/TitleBox/Title", UiCopyPlayGd.REPLAY_TITLE)
	_set_text("Layout/TopBar/Row/TitleBox/Subtitle", UiCopyPlayGd.REPLAY_SUBTITLE)
	_set_text(_EMPTY, UiCopyPlayGd.REPLAY_EMPTY)
	var back: Button = get_node_or_null("Layout/TopBar/Row/Back") as Button
	if back != null:
		back.text = UiCopy.text(UiCopy.CANCEL)


func _wire_chrome() -> void:
	var back: Button = get_node_or_null("Layout/TopBar/Row/Back") as Button
	if back != null:
		back.pressed.connect(func() -> void: back_requested.emit())
	var list: ItemList = get_node_or_null(_LIST) as ItemList
	if list != null:
		list.item_activated.connect(_on_item_activated)


func _fill_list() -> void:
	var list: ItemList = get_node_or_null(_LIST) as ItemList
	var empty: Label = get_node_or_null(_EMPTY) as Label
	if list == null:
		return
	list.clear()
	for row: Dictionary in _rows:
		list.add_item(_row_caption(row))
	if empty != null:
		empty.visible = _rows.is_empty()
	list.visible = not _rows.is_empty()


func _row_caption(row: Dictionary) -> String:
	var source: String = str(row.get("source", "local"))
	var source_key: String = UiCopyPlayGd.REPLAY_LOCAL
	if source == "online":
		source_key = UiCopyPlayGd.REPLAY_ONLINE
	var course_id: String = str(row.get("course_id", ""))
	if course_id == "":
		var tape_raw: Variant = row.get("tape", {})
		if typeof(tape_raw) == TYPE_DICTIONARY:
			var tape: Dictionary = tape_raw
			course_id = str(tape.get("course_id", ""))
	var created: String = str(row.get("created_at", ""))
	return "%s  %s  %s" % [UiCopy.text(source_key), course_id, created]


func _on_item_activated(index: int) -> void:
	play_requested.emit(index)


func _set_text(path: String, key: String) -> void:
	var node: Node = get_node_or_null(path)
	if node is Label:
		(node as Label).text = UiCopy.text(key)
	elif node is Button:
		(node as Button).text = UiCopy.text(key)
