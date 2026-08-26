extends Node

## Client boot scene. Prints a structured boot line for Headless smoke,
## then opens the TRAPRUSH match lobby (code-created Window) and maps the
## default official course occupancy, destructible placeholders,
## compiled portal-link gizmos, checkpoint-order gizmos, and live
## standing labels from the latest snapshot. Solo play starts a local
## embedded match session and keeps "离线试玩，成绩不上传" on the HUD.
## Live HTTP/WS stays off in headless
## so CI --quit does not call localhost.
## `-- --package-check` short-circuits all of that and prints the exported
## package self report instead (course correction C1).

const BOOT_EVENT: String = "client_boot"
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const PackageCheckGd := preload("res://src/client/package_check.gd")

var lobby: MatchLobbyShellGd = null


func _ready() -> void:
	if PackageCheckGd.requested(OS.get_cmdline_user_args()):
		get_tree().quit(PackageCheckGd.run_and_print())
		return
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
