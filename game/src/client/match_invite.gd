class_name MatchInvite
extends RefCounted

## Shareable invite strings. Content id never goes in the URL (CD-12 / C4).

const MatchJoinCodecGd := preload("res://src/client/match_join_codec.gd")

const QUERY_ROOM: String = "room"


static func web_query(room_code: String) -> String:
	var code: String = MatchJoinCodecGd.normalize_room_code(room_code)
	if code == "":
		return ""
	return "?%s=%s" % [QUERY_ROOM, code.uri_encode()]


static func web_url(base: String, room_code: String) -> String:
	var host: String = base.strip_edges()
	var query: String = web_query(room_code)
	if host == "" or query == "":
		return ""
	while host.ends_with("/"):
		host = host.substr(0, host.length() - 1)
	return host + query


static func desktop_text(host_port: String, room_code: String) -> String:
	var host: String = host_port.strip_edges()
	var code: String = MatchJoinCodecGd.normalize_room_code(room_code)
	if host == "" or code == "":
		return ""
	return "%s %s" % [host, code]


static func parse_room(raw: String) -> String:
	var text: String = raw.strip_edges()
	if text == "":
		return ""
	if text.contains(" "):
		var parts: PackedStringArray = text.split(" ")
		return MatchJoinCodecGd.normalize_room_code(parts[parts.size() - 1])
	if text.begins_with("?"):
		text = text.substr(1)
	if text.begins_with("%s=" % QUERY_ROOM):
		return MatchJoinCodecGd.normalize_room_code(text.substr(QUERY_ROOM.length() + 1).uri_decode())
	return MatchJoinCodecGd.normalize_room_code(text)
