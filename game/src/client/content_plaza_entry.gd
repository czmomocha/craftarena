class_name ContentPlazaEntry
extends Node

## Lobby window for the public content plaza (CD-12 / CD-31).
## Lists signed UGC by word-bank name and occupancy tags. Solo uses a
## SimulationBundle already bound by the caller — no AuthoringDocument
## path, no matchmaking HTTP. Tests call `apply_list` without HTTP.
##
## UI wiring batch 1 (2026-09-13) replaced the hand-built ItemList with the
## product UI screen `s3_workshop.tscn`. **Only the view changed**: tabs, HTTP,
## bundle resolution, selection and both exits behave exactly as before, and the
## public API is untouched so `match_lobby_director.gd` needed no edit.
##
## Three things the designed screen does not cover, all recorded in
## docs/runbooks/ui-wiring.md rather than invented here:
##   * it has no Solo / Create room affordance, so the existing action row is
##     still built in code and appended below the screen (STOPGAP_ACTIONS);
##   * its Sort / Tag / Search controls have no backing logic in ContentPlaza,
##     so the view disables them;
##   * its cards were drawn with an author and a thumbnail, neither of which
##     exists in a listing row.

const PlazaGd := preload("res://src/ugc/content_plaza.gd")
const PlazaHttpGd := preload("res://src/client/content_plaza_http.gd")
const HttpGd := preload("res://src/client/control_plane_http.gd")
const JoinCodecGd := preload("res://src/client/match_join_codec.gd")
const WorkshopScene := preload("res://src/client/ui/scenes/s3_workshop.tscn")

const WINDOW_NAME: String = "PlazaWindow"
const SCREEN_NAME: String = "PlazaScreen"
const ACTION_ROW_NAME: String = "PlazaActions"
const SOLO_NAME: String = "PlazaSolo"
const CREATE_ROOM_NAME: String = "PlazaCreateRoom"
const CLOSE_NAME: String = "PlazaClose"

## The window is sized for the 1920x1080 UI baseline rather than the old
## 960x540: the screen is a four-column grid and collapses below roughly a
## thousand pixels wide.
const WINDOW_SIZE: Vector2i = Vector2i(1600, 900)
const WINDOW_MIN_SIZE: Vector2i = Vector2i(1024, 640)

var window: Window = null
var screen: Control = null
var lobby_window: Window = null
var tab: String = PlazaGd.TAB_NEWEST
var items: Array = []
var selected_id: String = ""
var bundles: Dictionary = {}
var on_solo: Callable = Callable()
var on_create_room: Callable = Callable()
var on_tab: Callable = Callable()
var live_io: bool = false
var control_plane_base: String = ""
var last_error: String = ""
var http_transport: Callable = Callable()
var on_fetch_list: Callable = Callable()
var on_fetch_latest: Callable = Callable()
## Live list GET must not use ControlPlaneHttp on the UI thread: that helper
## polls with `OS.delay_msec` and freezes the window until TCP times out
## (`TIMEOUT_MS` = 10 s). Windows waits; macOS usually refuses immediately.
var _list_http: HTTPRequest = null
var _list_tab: String = ""


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
	_rebuild()
	window.visible = true
	_set_lobby_visible(false)
	_refresh_live_list()
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


func selected_version() -> int:
	if selected_id == "":
		return 0
	for raw: Variant in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw
		if str(item.get("content_id", "")) != selected_id:
			continue
		var version_raw: Variant = item.get("version", 0)
		if typeof(version_raw) == TYPE_INT:
			return version_raw
		if typeof(version_raw) == TYPE_FLOAT:
			var number: float = version_raw
			if number == floor(number):
				return int(number)
		return 0
	return 0


func try_select_tab(next_tab: String) -> bool:
	if not PlazaGd.is_tab(next_tab):
		return false
	tab = next_tab
	if on_tab.is_valid():
		on_tab.call(next_tab)
	items = []
	_rebuild()
	_refresh_live_list()
	return true


func try_select_id(content_id: String) -> bool:
	if screen == null:
		return false
	var card: Variant = screen.call("card_for", content_id)
	if not (card is Button):
		return false
	selected_id = content_id
	return true


func try_solo_selected() -> bool:
	if selected_id == "" or not on_solo.is_valid():
		return false
	var raw: Variant = on_solo.call(selected_id)
	return raw == true


func try_create_room_selected() -> bool:
	if selected_id == "" or not on_create_room.is_valid():
		return false
	var raw: Variant = on_create_room.call(selected_id, selected_version())
	return raw == true


func _ensure_window() -> void:
	if window != null:
		return
	window = Window.new()
	window.name = WINDOW_NAME
	window.title = UiCopy.text(UiCopy.WINDOW_PLAZA)
	window.size = WINDOW_SIZE
	window.min_size = WINDOW_MIN_SIZE
	window.exclusive = false
	window.transient = false
	window.close_requested.connect(_on_close)

	var root: VBoxContainer = VBoxContainer.new()
	root.name = "VBoxContainer"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(root)

	screen = WorkshopScene.instantiate() as Control
	screen.name = SCREEN_NAME
	# Before add_child, so the screen's `_ready` does not briefly fill the grid
	# with placeholder cards on the way to showing real ones.
	screen.set("demo_content", false)
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(screen)
	screen.connect("tab_requested", _on_tab_requested)
	screen.connect("content_selected", _on_content_selected)
	screen.connect("back_requested", _on_close)

	# STOPGAP_ACTIONS. The designed screen has a Back button and per-card
	# actions, but no Solo / Create room. Dropping them to match the mockup
	# would delete two shipped product exits, which is a bigger change than the
	# one this commit is making (constitution article 9), so the original row is
	# kept — same node names, same handlers — appended under the screen. Giving
	# these two a home inside the design needs a designer, and is logged in
	# docs/runbooks/ui-wiring.md.
	var actions: HBoxContainer = HBoxContainer.new()
	actions.name = ACTION_ROW_NAME
	root.add_child(actions)
	_add_button(actions, SOLO_NAME, UiCopy.PLAZA_SOLO, try_solo_selected)
	_add_button(actions, CREATE_ROOM_NAME, UiCopy.PLAZA_CREATE_ROOM, try_create_room_selected)
	_add_button(actions, CLOSE_NAME, UiCopy.BACK_TO_LOBBY, try_close)
	add_child(window)


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
	if screen == null:
		return
	selected_id = ""
	var shown: Array = _visible_items()
	screen.call("set_listing", shown)
	screen.call("set_active_tab", tab)
	# The unverified marker is the card's own badge now, not a suffix glued onto
	# a list line, so PLAZA_UNVERIFIED is no longer used here.
	screen.call("set_empty_notice", UiCopy.text(UiCopy.PLAZA_EMPTY) if shown.is_empty() else "")


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


func _on_content_selected(content_id: String) -> void:
	selected_id = content_id


func _on_tab_requested(next_tab: String) -> void:
	try_select_tab(next_tab)


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
	_request_live_list()


func _request_live_list() -> void:
	if _list_http == null:
		_list_http = HTTPRequest.new()
		_list_http.name = "PlazaListHttp"
		_list_http.timeout = float(HttpGd.TIMEOUT_MS) / 1000.0
		_list_http.request_completed.connect(_on_list_http_completed)
		add_child(_list_http)
	_list_http.cancel_request()
	_list_tab = tab
	var url: String = JoinCodecGd.http_url(control_plane_base, PlazaHttpGd.list_path(tab))
	if url == "":
		last_error = HttpGd.REASON_URL
		return
	var err: int = _list_http.request(url)
	if err != OK:
		last_error = HttpGd.REASON_TRANSPORT


func _on_list_http_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		last_error = HttpGd.REASON_TRANSPORT
		return
	var parsed: Dictionary = JoinCodecGd.parse_json_object(body.get_string_from_utf8())
	var ok_raw: Variant = parsed.get("ok", false)
	if typeof(ok_raw) != TYPE_BOOL or not ok_raw:
		apply_http_list({"error": HttpGd.REASON_RESPONSE})
		return
	var body_raw: Variant = parsed.get("body", {})
	if typeof(body_raw) != TYPE_DICTIONARY:
		apply_http_list({"error": HttpGd.REASON_RESPONSE})
		return
	var data: Dictionary = body_raw
	if response_code < 200 or response_code >= 300:
		if not data.has("error"):
			data = {"error": HttpGd.REASON_TRANSPORT}
	var listed_tab: String = str(data.get(PlazaHttpGd.KEY_TAB, ""))
	if listed_tab != "" and listed_tab != tab:
		return
	if _list_tab != tab:
		return
	apply_http_list(data)
