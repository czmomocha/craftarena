extends Node

## Client boot scene. Prints a structured boot line for Headless smoke,
## then opens the TRAPRUSH match lobby (code-created Window). Live HTTP/WS
## stays off in headless so CI --quit does not call localhost.

const BOOT_EVENT: String = "client_boot"
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")

var lobby: MatchLobbyShellGd = null


func _ready() -> void:
	print(_format_log_line(BOOT_EVENT, {
		"project": ProjectSettings.get_setting("application/config/name", ""),
		"engine": Engine.get_version_info().get("string", ""),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"headless": DisplayServer.get_name() == "headless",
		"debug_build": OS.is_debug_build(),
	}))
	lobby = MatchLobbyShellGd.create()
	if lobby == null:
		return
	lobby.live_io = DisplayServer.get_name() != "headless"
	add_child(lobby)
	lobby.open()


static func _format_log_line(event: String, fields: Dictionary) -> String:
	var payload: Dictionary = fields.duplicate()
	payload["event"] = event
	return JSON.stringify(payload)
