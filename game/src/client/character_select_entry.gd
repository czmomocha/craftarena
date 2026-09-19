class_name CharacterSelectEntry
extends Node

## Full-viewport character select overlay on MatchLobbyShell.
## View only emits intent; this node owns the store and the screen instance.

const MatchLobbyHomeGd := preload("res://src/client/match_lobby_home.gd")
const StoreGd := preload("res://src/client/character_select_store.gd")
const ClientAudioGd := preload("res://src/client/client_audio.gd")
const CatalogGd := preload("res://src/shared/schema/audio_cue_catalog.gd")

const SCREEN_NAME: StringName = &"CharacterSelect"
const SCENE_PATH: String = "res://src/client/ui/scenes/character_select.tscn"

var host: MatchLobbyShell = null
var store: StoreGd = null
var screen: Control = null


static func ensure(shell: MatchLobbyShell, existing: CharacterSelectEntry) -> CharacterSelectEntry:
	if existing != null:
		return existing
	var entry := new()
	entry.host = shell
	entry.store = StoreGd.new()
	entry.store.load_or_default()
	shell.add_child(entry)
	return entry


func is_open() -> bool:
	return screen != null and screen.visible


func try_open() -> bool:
	_ensure_screen()
	if screen == null or store == null:
		return false
	store.load_or_default()
	screen.call("set_selected", store.selected_id)
	screen.visible = true
	if host != null:
		host.home_surface = MatchLobbyHomeGd.SURFACE_CHARACTER
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
	root.connect("character_selected", _on_character_selected)


func _on_character_selected(id: String) -> void:
	if store == null:
		return
	store.select(id)
	ClientAudioGd.post(CatalogGd.UI_SELECT)
	if host != null:
		MatchLobbyHomeGd.refresh_character_caption(host)
