class_name AuthoringEditorPluginHost
extends RefCounted

## Testable host for the internal-dev EditorPlugin.
## Opens AuthoringEditorShell on a parent Node. Not a new EDIT op.
## Plugin script is @tool; this host and the shell are not.
## Optional draft_store restores after crash. Never settlement.

const MENU_ITEM: String = "Authoring Editor"
const PLUGIN_CFG_PATH: String = "res://addons/authoring_editor/plugin.cfg"

var shell: AuthoringEditorShell = null
var draft_store: AuthoringDraftStore = null


func attach_to(parent: Node) -> bool:
	if parent == null:
		return false
	if shell != null and is_instance_valid(shell):
		shell.draft_store = draft_store
		return shell.open()
	var next_shell: AuthoringEditorShell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	if next_shell == null:
		return false
	parent.add_child(next_shell)
	next_shell.draft_store = draft_store
	if not next_shell.open():
		next_shell.free()
		return false
	shell = next_shell
	return true


func detach() -> void:
	if shell == null:
		return
	var node: AuthoringEditorShell = shell
	shell = null
	if is_instance_valid(node):
		node.hide_window()
		node.free()


func is_open() -> bool:
	if shell == null or not is_instance_valid(shell):
		return false
	return shell.is_window_visible()
