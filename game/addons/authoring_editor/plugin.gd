@tool
extends EditorPlugin

## Internal-dev Authoring Editor (CD-32 §1.1).
## Project > Tools > Authoring Editor opens AuthoringEditorShell.
## FileAccess for drafts lives here: Godot treats non-@tool plugin
## helpers as empty in the editor, so store.record cannot persist.
## Not BASTION. No _mcp_game_helper. If this machine has the gitignored
## godot_ai addon, _enter_tree enables that editor plugin so a checkout
## of project.godot does not force a manual toggle.

const HostGd := preload("res://src/creator/authoring_editor_plugin_host.gd")
const GodotAiEnableGd := preload("res://addons/authoring_editor/godot_ai_enable.gd")
const LayoutGd := preload("res://src/creator/authoring_window_layout.gd")
const GAME_VIEW_NAMES: PackedStringArray = ["GameView", "EmbeddedProcess"]

var _host: HostGd = null
var _draft_store: AuthoringDraftStore = null
var _last_embed: Vector2i = Vector2i.ZERO


func _enter_tree() -> void:
	_try_enable_local_godot_ai()
	_host = HostGd.new()
	_draft_store = AuthoringDraftStore.new()
	_host.draft_store = _draft_store
	add_tool_menu_item(HostGd.MENU_ITEM, _on_open_authoring)
	set_process(true)


func _exit_tree() -> void:
	set_process(false)
	if Engine.has_meta(LayoutGd.EMBED_SIZE_META):
		Engine.remove_meta(LayoutGd.EMBED_SIZE_META)
	remove_tool_menu_item(HostGd.MENU_ITEM)
	if _host != null:
		_host.detach()
		_host = null


func _process(_delta: float) -> void:
	if not EditorInterface.is_playing_scene():
		if _last_embed != Vector2i.ZERO:
			_last_embed = Vector2i.ZERO
			if Engine.has_meta(LayoutGd.EMBED_SIZE_META):
				Engine.remove_meta(LayoutGd.EMBED_SIZE_META)
		return
	var embed: Vector2i = _game_view_size()
	if embed.x < 64 or embed.y < 64:
		return
	if embed == _last_embed:
		return
	_last_embed = embed
	Engine.set_meta(LayoutGd.EMBED_SIZE_META, embed)


func _game_view_size() -> Vector2i:
	var base: Node = EditorInterface.get_base_control()
	if base == null:
		return Vector2i.ZERO
	for view_name: String in GAME_VIEW_NAMES:
		var found: Node = base.find_child(view_name, true, false)
		if found is Control:
			var panel: Control = found
			var parent: Node = panel.get_parent()
			if parent is Control:
				var wrapper: Control = parent
				if wrapper.size.x > panel.size.x or wrapper.size.y > panel.size.y:
					panel = wrapper
			if panel.size.x >= 64.0 and panel.size.y >= 64.0:
				return Vector2i(panel.size)
	var screen: Control = EditorInterface.get_editor_main_screen()
	if screen != null and screen.size.x >= 64.0 and screen.size.y >= 64.0:
		return Vector2i(screen.size)
	return Vector2i.ZERO


func _try_enable_local_godot_ai() -> void:
	var cfg_exists: bool = FileAccess.file_exists(GodotAiEnableGd.CFG_PATH)
	var already_enabled: bool = EditorInterface.is_plugin_enabled(GodotAiEnableGd.PLUGIN_ID)
	if not GodotAiEnableGd.should_enable(cfg_exists, already_enabled):
		return
	EditorInterface.set_plugin_enabled(GodotAiEnableGd.PLUGIN_ID, true)


func _on_open_authoring() -> void:
	if _host == null:
		return
	_host.draft_store = _draft_store
	if not _host.attach_to(self):
		return
	if _host.shell == null:
		return
	_host.shell.draft_store = _draft_store
	if not _host.shell.world_committed.is_connected(_on_world_committed):
		_host.shell.world_committed.connect(_on_world_committed)
	_restore_from_plugin()


func _on_world_committed() -> void:
	if _host == null or _host.shell == null or _draft_store == null:
		return
	if _host.shell.session == null or _host.shell.session.world == null:
		_host.shell.note_draft_write(false)
		return
	if not _draft_store.capture(_host.shell.session.world):
		_host.shell.note_draft_write(false)
		return
	var ok: bool = _write_draft_text(_draft_store.resolved_path(), _draft_store.body_text())
	_host.shell.note_draft_write(ok)


func _restore_from_plugin() -> void:
	if _host == null or _host.shell == null or _draft_store == null:
		return
	if _host.shell.session == null or _host.shell.session.world == null:
		return
	if _host.shell.session.world.revision != 0:
		return
	if _host.shell.session.world.entity_count() != 0:
		return
	var text: String = _read_draft_text(_draft_store.resolved_path())
	if text.is_empty():
		return
	if not _draft_store.load_text(text):
		return
	if _host.shell.restore_document(_draft_store.latest):
		_host.shell.note_draft_write(true)


func _write_draft_text(abs_path: String, text: String) -> bool:
	if abs_path.is_empty() or abs_path.begins_with("res://"):
		return false
	if text.is_empty():
		return false
	var parent: String = abs_path.get_base_dir()
	if parent.is_empty():
		return false
	if not DirAccess.dir_exists_absolute(parent):
		DirAccess.make_dir_recursive_absolute(parent)
	if not DirAccess.dir_exists_absolute(parent):
		return false
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	if not FileAccess.file_exists(abs_path):
		return false
	return FileAccess.get_file_as_string(abs_path) == text


func _read_draft_text(abs_path: String) -> String:
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return ""
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text
