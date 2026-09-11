class_name ContentPlazaEntry
extends Node

## Lobby window for the public content plaza (CD-12 / CD-31).
## Lists signed UGC by word-bank name and occupancy tags. Solo uses a
## SimulationBundle already bound by the caller — no AuthoringDocument
## path, no matchmaking HTTP. Tests call `apply_list` without HTTP.

const PlazaGd := preload("res://src/ugc/content_plaza.gd")
const PlazaHttpGd := preload("res://src/client/content_plaza_http.gd")

const WINDOW_NAME: String = "PlazaWindow"
const TAB_ROW_NAME: String = "PlazaTabs"
const LIST_NAME: String = "PlazaList"
const SOLO_NAME: String = "PlazaSolo"
const EMPTY_NAME: String = "PlazaEmpty"
const CLOSE_NAME: String = "PlazaClose"
const NEWEST_NAME: String = "PlazaNewest"
const RATING_NAME: String = "PlazaRating"
const PLAYS_NAME: String = "PlazaPlays"
const VERIFIED_NAME: String = "PlazaVerified"

var window: Window = null
var list: ItemList = null
var empty: Label = null
var lobby_window: Window = null
var tab: String = PlazaGd.TAB_NEWEST
var items: Array = []
var selected_id: String = ""
var bundles: Dictionary = {}
var on_solo: Callable = Callable()
var on_tab: Callable = Callable()
var live_io: bool = false
var control_plane_base: String = ""
var last_error: String = ""
var http_transport: Callable = Callable()
var on_fetch_list: Callable = Callable()
var on_fetch_latest: Callable = Callable()


static func ensure(shell: MatchLobbyShell, existing: ContentPlazaEntry) -> ContentPlazaEntry:
	if existing != null:
		return existing
	var entry := new()
	entry.lobby_window = shell.window
	shell.add_child(entry)
	return entry


func is_open() -> bool:
	return window != null and window.visible


func try_open() -> bool:
	_ensure_window()
	if window == null:
		return false
	if tab == "":
		tab = PlazaGd.TAB_NEWEST
	_refresh_live_list()
	_rebuild()
	window.visible = true
	_set_lobby_visible(false)
	return true


func try_close() -> bool:
	var lobby_hidden: bool = (
		lobby_window != null and is_instance_valid(lobby_window) and not lobby_window.visible
	)
	if not is_open() and not lobby_hidden:
		return false
	if window != null:
		window.visible = false
	_set_lobby_visible(true)
	return true


func apply_list(next_tab: String, listed: Array) -> void:
	if PlazaGd.is_tab(next_tab):
		tab = next_tab
	items = listed.duplicate(true)
	_rebuild()


func bind_bundle(content_id: String, bundle: SimulationBundle) -> void:
	bundles[content_id] = bundle


func apply_http_list(raw: Dictionary) -> void:
	var parsed: Dictionary = PlazaHttpGd.read_list(raw)
	var ok_raw: Variant = parsed.get(PlazaGd.KEY_OK, false)
	if typeof(ok_raw) != TYPE_BOOL or not ok_raw:
		last_error = str(parsed.get(PlazaGd.KEY_REASON, "plaza_invalid"))
		_rebuild()
		return
	last_error = ""
	var listed_raw: Variant = parsed.get(PlazaHttpGd.KEY_ITEMS, [])
	var listed: Array = []
	if typeof(listed_raw) == TYPE_ARRAY:
		listed = listed_raw
	apply_list(str(parsed.get(PlazaHttpGd.KEY_TAB, tab)), listed)


func apply_latest(content_id: String, raw: Dictionary) -> bool:
	var bundle: SimulationBundle = PlazaHttpGd.read_latest_bundle(raw)
	if bundle == null:
		last_error = PlazaGd.REASON_MISSING
		return false
	bind_bundle(content_id, bundle)
	return true


func ensure_bundle(content_id: String) -> SimulationBundle:
	var existing: SimulationBundle = bundle_of(content_id)
	if existing != null:
		return existing
	var fetched: Variant = {}
	if on_fetch_latest.is_valid():
		fetched = on_fetch_latest.call(content_id)
	elif live_io:
		fetched = PlazaHttpGd.fetch_latest(control_plane_base, content_id, http_transport)
	else:
		return null
	if typeof(fetched) != TYPE_DICTIONARY:
		return null
	var latest: Dictionary = fetched
	if not apply_latest(content_id, latest):
		return null
	return bundle_of(content_id)


func bundle_of(content_id: String) -> SimulationBundle:
	var raw: Variant = bundles.get(content_id, null)
	if raw is SimulationBundle:
		var bundle: SimulationBundle = raw
		return bundle
	return null


func selected_content_id() -> String:
	return selected_id


func try_select_tab(next_tab: String) -> bool:
	if not PlazaGd.is_tab(next_tab):
		return false
	tab = next_tab
	if on_tab.is_valid():
		on_tab.call(next_tab)
	_refresh_live_list()
	_rebuild()
	return true


func try_select_id(content_id: String) -> bool:
	if list == null:
		return false
	for index: int in range(list.item_count):
		if str(list.get_item_metadata(index)) != content_id:
			continue
		list.select(index)
		selected_id = content_id
		return true
	return false


func try_solo_selected() -> bool:
	if selected_id == "" or not on_solo.is_valid():
		return false
	var raw: Variant = on_solo.call(selected_id)
	return raw == true


func _ensure_window() -> void:
	if window != null:
		return
	window = Window.new()
	window.name = WINDOW_NAME
	window.title = UiCopy.text(UiCopy.WINDOW_PLAZA)
	window.size = Vector2i(960, 540)
	window.min_size = Vector2i(640, 360)
	window.exclusive = false
	window.transient = false
	window.close_requested.connect(_on_close)
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "VBoxContainer"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	window.add_child(root)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.name = TAB_ROW_NAME
	root.add_child(tabs)
	_add_tab(tabs, NEWEST_NAME, UiCopy.PLAZA_NEWEST, PlazaGd.TAB_NEWEST)
	_add_tab(tabs, RATING_NAME, UiCopy.PLAZA_RATING, PlazaGd.TAB_RATING)
	_add_tab(tabs, PLAYS_NAME, UiCopy.PLAZA_PLAYS, PlazaGd.TAB_PLAYS)
	_add_tab(tabs, VERIFIED_NAME, UiCopy.PLAZA_VERIFIED, PlazaGd.TAB_VERIFIED)
	empty = Label.new()
	empty.name = EMPTY_NAME
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(empty)
	list = ItemList.new()
	list.name = LIST_NAME
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_on_item_selected)
	root.add_child(list)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.name = "PlazaActions"
	root.add_child(actions)
	_add_button(actions, SOLO_NAME, UiCopy.PLAZA_SOLO, try_solo_selected)
	_add_button(actions, CLOSE_NAME, UiCopy.BACK_TO_LOBBY, try_close)
	add_child(window)


func _add_tab(row: BoxContainer, node_name: String, copy_key: String, tab_id: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = UiCopy.text(copy_key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: try_select_tab(tab_id))
	row.add_child(button)


func _add_button(row: BoxContainer, node_name: String, copy_key: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = UiCopy.text(copy_key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	if handler.is_valid():
		button.pressed.connect(handler)
	row.add_child(button)


func _rebuild() -> void:
	if list == null or empty == null:
		return
	list.clear()
	selected_id = ""
	var shown: Array = _visible_items()
	empty.text = UiCopy.text(UiCopy.PLAZA_EMPTY) if shown.is_empty() else ""
	empty.visible = shown.is_empty()
	list.visible = not shown.is_empty()
	for raw: Variant in shown:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw
		var content_id: String = str(item.get("content_id", ""))
		if content_id == "":
			continue
		var tags_raw: Variant = item.get("tags", PackedStringArray())
		var tags: PackedStringArray = PackedStringArray()
		if tags_raw is PackedStringArray:
			tags = tags_raw
		elif typeof(tags_raw) == TYPE_ARRAY:
			for tag_raw: Variant in tags_raw:
				tags.append(str(tag_raw))
		var verified_raw: Variant = item.get("verified", false)
		var mark: String = "" if verified_raw == true else " %s" % UiCopy.text(UiCopy.PLAZA_UNVERIFIED)
		var line: String = "%s  %s%s" % [str(item.get("display_name", content_id)), ",".join(tags), mark]
		var index: int = list.add_item(line)
		list.set_item_metadata(index, content_id)


func _visible_items() -> Array:
	if tab != PlazaGd.TAB_VERIFIED:
		return items
	var shown: Array = []
	for raw: Variant in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw
		var verified_raw: Variant = item.get("verified", false)
		if verified_raw == true:
			shown.append(item)
	return shown


func _on_item_selected(index: int) -> void:
	if list == null:
		return
	selected_id = str(list.get_item_metadata(index))


func _on_close() -> void:
	try_close()


func _set_lobby_visible(visible: bool) -> void:
	if lobby_window == null or not is_instance_valid(lobby_window):
		return
	lobby_window.visible = visible


func _refresh_live_list() -> void:
	if on_fetch_list.is_valid():
		var raw: Variant = on_fetch_list.call(tab)
		if typeof(raw) == TYPE_DICTIONARY:
			var listed: Dictionary = raw
			apply_http_list(listed)
		return
	if not live_io:
		return
	apply_http_list(PlazaHttpGd.fetch_list(control_plane_base, tab, http_transport))
