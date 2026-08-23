@tool
extends EditorPlugin

## Internal-dev Authoring Editor (CD-32 §1.1).
## Project > Tools > Authoring Editor opens AuthoringEditorShell.
## Enables local draft restore. Not BASTION. Not godot_ai. No _mcp_game_helper.
## Instantiates AuthoringDraftStore via class_name so the editor typed
## property matches the global class. Preload copies can fail assignment.

const HostGd := preload("res://src/creator/authoring_editor_plugin_host.gd")

var _host: HostGd = null
var _draft_store: AuthoringDraftStore = null


func _enter_tree() -> void:
	_host = HostGd.new()
	_draft_store = AuthoringDraftStore.new()
	_host.draft_store = _draft_store
	add_tool_menu_item(HostGd.MENU_ITEM, _on_open_authoring)


func _exit_tree() -> void:
	remove_tool_menu_item(HostGd.MENU_ITEM)
	if _host != null:
		_host.detach()
		_host = null


func _on_open_authoring() -> void:
	if _host == null:
		return
	_host.draft_store = _draft_store
	if not _host.attach_to(self):
		return
	if _host.shell != null:
		_host.shell.draft_store = _draft_store
