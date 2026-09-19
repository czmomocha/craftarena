class_name TraprushReplayEntry
extends Node

## Full-viewport TRAPRUSH match records overlay. Local ring 50; online GET is
## current-account only.

const MatchLobbyHomeGd := preload("res://src/client/match_lobby_home.gd")
const StoreGd := preload("res://src/client/traprush_replay_store.gd")
const SubmitHttpGd := preload("res://src/ugc/content_submit_http.gd")
const HttpGd := preload("res://src/client/control_plane_http.gd")

const SCREEN_NAME: StringName = &"TraprushReplay"
const SCENE_PATH: String = "res://src/client/ui/scenes/traprush_replay.tscn"

var host: MatchLobbyShell = null
var store: StoreGd = StoreGd.new()
var screen: Control = null
var _rows: Array[Dictionary] = []


static func ensure(shell: MatchLobbyShell, existing: TraprushReplayEntry) -> TraprushReplayEntry:
	if existing != null:
		return existing
	var entry := new()
	entry.host = shell
	shell.add_child(entry)
	return entry


func is_open() -> bool:
	return screen != null and screen.visible


func try_open() -> bool:
	_ensure_screen()
	if screen == null:
		return false
	_refresh_rows()
	screen.visible = true
	if host != null:
		host.home_surface = MatchLobbyHomeGd.SURFACE_REPLAY
		if host.home_screen != null:
			host.home_screen.visible = false
		if host.window != null:
			host.window.visible = false
	return true


func try_close() -> bool:
	if not is_open():
		return false
	if screen != null:
		screen.visible = false
	if host != null:
		MatchLobbyHomeGd.try_show_home(host)
	return true


func _ensure_screen() -> void:
	if screen != null:
		return
	if host == null:
		return
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		return
	var root: Control = packed.instantiate() as Control
	if root == null:
		return
	root.name = String(SCREEN_NAME)
	root.visible = false
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(root)
	screen = root
	root.connect("back_requested", try_close)
	root.connect("play_requested", _on_play_requested)


func _refresh_rows() -> void:
	_rows = store.load_items()
	if host != null and host.live_io:
		_append_online(_rows)
	if screen != null:
		screen.call("set_rows", _rows)


func _append_online(rows: Array[Dictionary]) -> void:
	var guest: Dictionary = SubmitHttpGd.load_guest(SubmitHttpGd.GUEST_FILE)
	if guest.get("ok", false) != true:
		return
	var headers: PackedStringArray = PackedStringArray([
		"%s: %s" % [SubmitHttpGd.HEADER_GUEST_ID, str(guest.get(SubmitHttpGd.KEY_GUEST_ID, ""))],
		"%s: %s" % [SubmitHttpGd.HEADER_GUEST_KEY, str(guest.get(SubmitHttpGd.KEY_RECOVERY_KEY, ""))],
	])
	var exchanged: Dictionary = HttpGd.get_json(host.control_plane_base, "/traprush-replays", headers)
	var body_raw: Variant = exchanged.get(HttpGd.KEY_BODY, {})
	if exchanged.get(HttpGd.KEY_OK, false) != true or typeof(body_raw) != TYPE_DICTIONARY:
		return
	var body: Dictionary = body_raw
	var items_raw: Variant = body.get("items", [])
	if typeof(items_raw) != TYPE_ARRAY:
		return
	for item: Variant in items_raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		row["source"] = "online"
		rows.append(row)


func _on_play_requested(index: int) -> void:
	if index < 0 or index >= _rows.size() or host == null:
		return
	var row: Dictionary = _rows[index]
	var tape_raw: Variant = row.get("tape", {})
	if typeof(tape_raw) != TYPE_DICTIONARY:
		tape_raw = _fetch_online_tape(str(row.get("replay_id", "")))
	if typeof(tape_raw) != TYPE_DICTIONARY:
		if screen != null:
			screen.call("set_error", "hash_mismatch")
		return
	var tape: Dictionary = tape_raw
	if screen != null:
		screen.visible = false
	if not host.director.try_begin_replay(tape):
		if screen != null:
			screen.visible = true
			screen.call("set_error", host.offline.last_error if host.offline != null else "invalid_tape")


func _fetch_online_tape(replay_id: String) -> Variant:
	if replay_id == "" or host == null:
		return {}
	var guest: Dictionary = SubmitHttpGd.load_guest(SubmitHttpGd.GUEST_FILE)
	if guest.get("ok", false) != true:
		return {}
	var headers: PackedStringArray = PackedStringArray([
		"%s: %s" % [SubmitHttpGd.HEADER_GUEST_ID, str(guest.get(SubmitHttpGd.KEY_GUEST_ID, ""))],
		"%s: %s" % [SubmitHttpGd.HEADER_GUEST_KEY, str(guest.get(SubmitHttpGd.KEY_RECOVERY_KEY, ""))],
	])
	var exchanged: Dictionary = HttpGd.get_json(host.control_plane_base, "/traprush-replays/%s" % replay_id, headers)
	var body_raw: Variant = exchanged.get(HttpGd.KEY_BODY, {})
	if exchanged.get(HttpGd.KEY_OK, false) != true or typeof(body_raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = body_raw
	return body.get("tape", {})
