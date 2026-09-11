extends GutTest

## Web 游玩分发：查询串与 `/play/` 页主机接到已有 `--server=` 旗。

const ServerEndpointGd := preload("res://src/client/server_endpoint.gd")
const WebLaunchArgsGd := preload("res://src/client/web_launch_args.gd")


func test_flag_names_match_server_endpoint() -> void:
	assert_eq(WebLaunchArgsGd.SERVER_FLAG, ServerEndpointGd.SERVER_FLAG)
	assert_eq(WebLaunchArgsGd.CONTROL_PLANE_FLAG, ServerEndpointGd.CONTROL_PLANE_FLAG)
	assert_eq(WebLaunchArgsGd.GATEWAY_FLAG, ServerEndpointGd.GATEWAY_FLAG)


func test_query_fills_absent_flags_and_keeps_command_line() -> void:
	var merged: PackedStringArray = WebLaunchArgsGd.merge(
		PackedStringArray(["--server=203.0.113.9"]),
		"?server=198.51.100.1&gateway=ws://198.51.100.1:9000"
	)
	assert_eq(merged, PackedStringArray([
		"--server=203.0.113.9",
		"--gateway=ws://198.51.100.1:9000",
	]))


func test_query_decodes_and_ignores_unknown_keys() -> void:
	var parsed: Dictionary = WebLaunchArgsGd.parse_search(
		"?server=203.0.113.9%3A9000&foo=1&control-plane=http%3A%2F%2F203.0.113.9%3A9000&room=ABCD23&content=ugc_x"
	)
	assert_eq(str(parsed.get("server", "")), "203.0.113.9:9000")
	assert_eq(str(parsed.get("control-plane", "")), "http://203.0.113.9:9000")
	assert_eq(str(parsed.get("room", "")), "ABCD23")
	assert_false(parsed.has("foo"))
	assert_false(parsed.has("content"))


func test_page_host_only_when_served_from_play() -> void:
	assert_eq(
		WebLaunchArgsGd.page_host_flag("/play/", "203.0.113.9"),
		"--server=203.0.113.9"
	)
	assert_eq(
		WebLaunchArgsGd.page_host_flag("/play/index.html", "203.0.113.9"),
		"--server=203.0.113.9"
	)
	assert_eq(WebLaunchArgsGd.page_host_flag("/", "203.0.113.9"), "")
	assert_eq(WebLaunchArgsGd.page_host_flag("/play/", ""), "")


func test_room_query_normalizes_code_and_never_reads_content() -> void:
	assert_eq(WebLaunchArgsGd.room_code("?room=abcd23"), "ABCD23")
	assert_eq(WebLaunchArgsGd.room_code("?room=ABCD23&content=ugc_secret"), "ABCD23")
	assert_eq(WebLaunchArgsGd.room_code(""), "")
	assert_eq(WebLaunchArgsGd.room_code("?edit=1&room=ABCD23"), "ABCD23")


func test_from_os_uses_play_page_host_when_nothing_else_named_a_server() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.from_os(
		PackedStringArray([]),
		{"pathname": "/play/", "hostname": "203.0.113.9"}
	)
	assert_eq(endpoint.control_plane, "http://203.0.113.9:8080")
	assert_eq(endpoint.gateway, "ws://203.0.113.9:8090")
	assert_false(endpoint.has_errors(), str(endpoint.errors))


func test_from_os_query_beats_play_page_host() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.from_os(
		PackedStringArray([]),
		{
			"search": "?server=198.51.100.1:9000",
			"pathname": "/play/",
			"hostname": "203.0.113.9",
		}
	)
	assert_eq(endpoint.control_plane, "http://198.51.100.1:9000")
	assert_eq(endpoint.gateway, "ws://198.51.100.1:8090")
	assert_false(endpoint.has_errors(), str(endpoint.errors))
