extends Node

## Client boot scene. Prints a structured boot line for Headless smoke,
## then opens the TRAPRUSH match lobby (code-created Window) and maps the
## default official course occupancy, destructible placeholders,
## compiled portal-link gizmos, checkpoint-order gizmos, and live
## standing labels from the latest snapshot. Solo play starts a local
## embedded match session and keeps `craft_arena.ui.offline_banner` on the HUD.
## Live HTTP/WS stays off in headless
## so CI --quit does not call localhost.
## `-- --package-check` short-circuits all of that and prints the exported
## package self report instead (course correction C1). `-- --bot-run` likewise
## short-circuits into the course-completion probe over the official courses
## (C2; C3 第 7 章可用 `--route=safe` 封掉 course_01 捷径传送门)。
## `-- --server=HOST` or `HOST:CONTROL_PLANE_PORT` (or --control-plane= /
## --gateway=, or the matching CRAFTARENA_* variables, or a Web query
## `?server=` / `?control-plane=` / `?gateway=`) points the lobby at a
## deployed test server instead of a local npm run dev. A page served at
## `/play/` can pin the host from the URL.

const BOOT_EVENT: String = "client_boot"
const BotRunCliGd := preload("res://src/games/traprush/bot_run_cli.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const PackageCheckGd := preload("res://src/client/package_check.gd")
const ServerEndpointGd := preload("res://src/client/server_endpoint.gd")
const WebLaunchArgsGd := preload("res://src/client/web_launch_args.gd")
const WebPageLocationGd := preload("res://src/client/web_page_location.gd")

var lobby: MatchLobbyShellGd = null


func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	UiCopy.ensure_loaded()
	if PackageCheckGd.requested(user_args):
		get_tree().quit(PackageCheckGd.run_and_print())
		return
	if BotRunCliGd.requested(user_args):
		get_tree().quit(BotRunCliGd.run_and_print(user_args))
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
	var page: Dictionary = WebPageLocationGd.read()
	lobby.apply_endpoint(ServerEndpointGd.from_os(user_args, page))
	add_child(lobby)
	lobby.open()
	# `?edit=1`（或桌面 `-- --edit`）直接落在创作上：把链接发给外人时，
	# 「来做一张课」和「来玩一局」应该是两条链接，而不是一条链接加一句口头说明。
	if WebLaunchArgsGd.wants_edit(user_args, str(page.get("search", ""))):
		lobby.try_open_creator()


static func _format_log_line(event: String, fields: Dictionary) -> String:
	var payload: Dictionary = fields.duplicate()
	payload["event"] = event
	return JSON.stringify(payload)
