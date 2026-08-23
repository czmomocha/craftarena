extends GutTest

## Authoring EditorPlugin: Project > Tools opens the existing shell.
## Not a new EDIT op. Not BASTION. Never settlement. No godot_ai autoload.

const AuthoringEditorPluginHost := preload("res://src/creator/authoring_editor_plugin_host.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")

const PLUGIN_CFG: String = "res://addons/authoring_editor/plugin.cfg"
const PLUGIN_SCRIPT: String = "res://addons/authoring_editor/plugin.gd"
const GUT_CFG: String = "res://addons/gut/plugin.cfg"
const GODOT_AI_CFG: String = "res://addons/godot_ai/plugin.cfg"

var _host: AuthoringEditorPluginHost = null


func after_each() -> void:
	if _host != null:
		_host.detach()
	_host = null


func test_plugin_cfg_points_at_editor_plugin_script() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(PLUGIN_CFG), OK)
	var plugin_name: String = cfg.get_value("plugin", "name", "")
	var script_name: String = cfg.get_value("plugin", "script", "")
	assert_eq(plugin_name, "Authoring Editor")
	assert_eq(script_name, "plugin.gd")
	assert_eq(FileAccess.file_exists(PLUGIN_SCRIPT), true)
	var source: String = FileAccess.get_file_as_string(PLUGIN_SCRIPT)
	assert_eq(source.begins_with("@tool\nextends EditorPlugin"), true)
	assert_eq(source.contains("AuthoringDraftStore.new()"), true)
	assert_eq(source.contains("DraftGd.new()"), false)
	assert_eq(source.contains("_write_draft_text"), true)
	assert_eq(source.contains("FileAccess.open"), true)
	assert_eq(source.contains("world_committed"), true)


func test_project_enables_gut_and_authoring_not_godot_ai() -> void:
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	assert_eq(enabled.has(GUT_CFG), true)
	assert_eq(enabled.has(PLUGIN_CFG), true)
	assert_eq(enabled.has(GODOT_AI_CFG), false)
	assert_eq(ProjectSettings.has_setting("autoload/_mcp_game_helper"), false)


func test_host_opens_internal_dev_shell_and_never_settles() -> void:
	_host = AuthoringEditorPluginHost.new()
	assert_eq(_host.MENU_ITEM, "Authoring Editor")
	assert_eq(_host.PLUGIN_CFG_PATH, PLUGIN_CFG)
	assert_false(_host.attach_to(null))
	assert_true(_host.attach_to(self))
	assert_true(_host.is_open())
	assert_not_null(_host.shell)
	assert_eq(_host.shell.surface, AuthoringSurfaceNames.INTERNAL_DEV)
	assert_true(_host.shell.is_window_visible())
	assert_false(_host.shell.allows_settlement())
	assert_false(_host.shell.allows_online_writes())
	assert_true(_host.shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_host.shell.session.world.has_entity(1))


func test_close_hides_and_keeps_session_detach_frees() -> void:
	_host = AuthoringEditorPluginHost.new()
	assert_true(_host.attach_to(self))
	assert_true(_host.shell.try_place_checkpoint(1, 0, 0, 0, 0))
	_host.shell.hide_window()
	assert_false(_host.is_open())
	assert_true(_host.shell.session.world.has_entity(1))
	assert_true(_host.attach_to(self))
	assert_true(_host.is_open())
	assert_true(_host.shell.session.world.has_entity(1))
	var first_shell: AuthoringEditorShell = _host.shell
	_host.detach()
	assert_false(is_instance_valid(first_shell))
	assert_null(_host.shell)
	assert_false(_host.is_open())
