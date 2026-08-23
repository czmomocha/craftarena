@tool
extends EditorPlugin

## Internal-dev Authoring Editor (CD-32 §1.1).
## Project > Tools > Authoring Editor opens AuthoringEditorShell.
## Enables local draft restore. Not BASTION. Not godot_ai. No _mcp_game_helper.

const HostGd := preload("res://src/creator/authoring_editor_plugin_host.gd")
const DraftGd := preload("res://src/creator/authoring_draft_store.gd")

var _host: HostGd = null


func _enter_tree() -> void:
	_host = HostGd.new()
	_host.draft_store = DraftGd.new()
	add_tool_menu_item(HostGd.MENU_ITEM, _on_open_authoring)


func _exit_tree() -> void:
	remove_tool_menu_item(HostGd.MENU_ITEM)
	if _host != null:
		_host.detach()
		_host = null


func _on_open_authoring() -> void:
	if _host == null:
		return
	_host.attach_to(self)
