class_name WebLaunchArgs
extends RefCounted

## Browser query string → the same `--server=` / `--control-plane=` /
## `--gateway=` flags `ServerEndpoint` already understands. Godot Web can
## also forward the query into `OS.get_cmdline_user_args()`; merging here
## is idempotent. Command-line flags win over the query. Serving the export
## from the control plane at `/play/` can pin the host from the page URL
## when nothing else named a server.

const MatchInviteGd := preload("res://src/client/match_invite.gd")

const SERVER_FLAG: String = "--server="
const CONTROL_PLANE_FLAG: String = "--control-plane="
const GATEWAY_FLAG: String = "--gateway="
const QUERY_SERVER: String = "server"
const QUERY_CONTROL_PLANE: String = "control-plane"
const QUERY_GATEWAY: String = "gateway"
const QUERY_EDIT: String = "edit"
const QUERY_ROOM: String = "room"
const EDIT_FLAG: String = "--edit"
const PLAY_PATH_PREFIX: String = "/play"
## `?edit=0` / `?edit=false` 明确关掉。其余任何值（含 `?edit`）都是开。
## 不做「像布尔的字符串」的宽松解析：这是分发链接里的开关，含糊等于不可复现。
const _EDIT_OFF: PackedStringArray = ["0", "false", "off", "no"]


static func merge(user_args: PackedStringArray, search: String) -> PackedStringArray:
	var merged: PackedStringArray = user_args.duplicate()
	var query: Dictionary = parse_search(search)
	_append_absent(merged, SERVER_FLAG, str(query.get(QUERY_SERVER, "")))
	_append_absent(merged, CONTROL_PLANE_FLAG, str(query.get(QUERY_CONTROL_PLANE, "")))
	_append_absent(merged, GATEWAY_FLAG, str(query.get(QUERY_GATEWAY, "")))
	return merged


static func parse_search(search: String) -> Dictionary:
	var text: String = search.strip_edges()
	if text.begins_with("?"):
		text = text.substr(1)
	var parsed: Dictionary = {}
	if text == "":
		return parsed
	var pairs: PackedStringArray = text.split("&")
	for pair: String in pairs:
		if pair == "":
			continue
		var eq: int = pair.find("=")
		var raw_key: String = pair if eq < 0 else pair.substr(0, eq)
		var raw_value: String = "" if eq < 0 else pair.substr(eq + 1)
		var key: String = raw_key.uri_decode()
		if (
			key != QUERY_SERVER
			and key != QUERY_CONTROL_PLANE
			and key != QUERY_GATEWAY
			and key != QUERY_EDIT
			and key != QUERY_ROOM
		):
			continue
		parsed[key] = raw_value.uri_decode()
	return parsed


## 这次启动是不是要直接进创作。链接里带 `?edit=1` 就能把编辑器发给外人试，
## 不必先教他去点大厅上的按钮；桌面用 `-- --edit`。
static func wants_edit(user_args: PackedStringArray, search: String) -> bool:
	for arg: String in user_args:
		if arg == EDIT_FLAG:
			return true
	var query: Dictionary = parse_search(search)
	if not query.has(QUERY_EDIT):
		return false
	return not _EDIT_OFF.has(str(query[QUERY_EDIT]).strip_edges().to_lower())


static func room_code(search: String) -> String:
	var query: Dictionary = parse_search(search)
	if not query.has(QUERY_ROOM):
		return ""
	return MatchInviteGd.parse_room(str(query[QUERY_ROOM]))


static func has_flag(args: PackedStringArray, flag: String) -> bool:
	for arg: String in args:
		if arg.begins_with(flag) and arg.substr(flag.length()).strip_edges() != "":
			return true
	return false


static func page_host_flag(pathname: String, hostname: String) -> String:
	var host: String = hostname.strip_edges()
	if host == "":
		return ""
	var path: String = pathname.strip_edges()
	if not path.begins_with(PLAY_PATH_PREFIX):
		return ""
	return SERVER_FLAG + host


static func _append_absent(args: PackedStringArray, flag: String, raw_value: String) -> void:
	var value: String = raw_value.strip_edges()
	if value == "" or has_flag(args, flag):
		return
	args.append(flag + value)
