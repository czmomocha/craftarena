@tool
extends RefCounted

## Authoring Editor enables the local Godot AI plugin when the gitignored
## addon files exist. Committed project.godot still omits godot_ai: CI
## import strips a missing addon from the enabled list. Never writes
## _mcp_game_helper.

const CFG_PATH: String = "res://addons/godot_ai/plugin.cfg"
const PLUGIN_ID: String = "godot_ai"


static func should_enable(cfg_exists: bool, already_enabled: bool) -> bool:
	return cfg_exists and not already_enabled
