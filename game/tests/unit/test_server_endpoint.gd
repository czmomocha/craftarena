extends GutTest

## 客户端服务器地址（纠偏 C1 第 2 章）。
##
## 这批断言守的是「第二台真机能不能连到远端测试机」这条链路。此前两个基址是
## 写死 127.0.0.1 的 const，全仓没有第二处赋值，所以远端部署起来了也连不上。
##
## 重点不是「能解析 URL」，而是**填错时必须看得见**：被拒的值不会退回成一个
## 看起来正常的地址，而是保留原值并留下 errors，由大厅 HUD 打出来。静默连回
## 127.0.0.1 会被读成「服务器挂了」，那是最贵的一类排查。

const ServerEndpointGd := preload("res://src/client/server_endpoint.gd")

const REMOTE_HOST: String = "203.0.113.9"


func test_defaults_point_at_a_local_npm_run_dev() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(PackedStringArray([]))
	assert_eq(endpoint.control_plane, ServerEndpointGd.DEFAULT_CONTROL_PLANE)
	assert_eq(endpoint.gateway, ServerEndpointGd.DEFAULT_GATEWAY)
	assert_false(endpoint.has_errors(), str(endpoint.errors))


func test_server_flag_retargets_both_bases_and_keeps_their_ports() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--server=%s" % REMOTE_HOST])
	)
	assert_eq(endpoint.control_plane, "http://%s:8080" % REMOTE_HOST)
	assert_eq(endpoint.gateway, "ws://%s:8090" % REMOTE_HOST)
	assert_false(endpoint.has_errors(), str(endpoint.errors))


func test_environment_provides_the_same_host_override() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray([]),
		{ServerEndpointGd.SERVER_ENV: REMOTE_HOST}
	)
	assert_eq(endpoint.control_plane_host(), REMOTE_HOST)
	assert_eq(endpoint.gateway_host(), REMOTE_HOST)


func test_command_line_beats_environment() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--server=%s" % REMOTE_HOST]),
		{ServerEndpointGd.SERVER_ENV: "198.51.100.1"}
	)
	assert_eq(endpoint.control_plane_host(), REMOTE_HOST)


func test_last_repeated_flag_wins() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--server=198.51.100.1", "--server=%s" % REMOTE_HOST])
	)
	assert_eq(endpoint.control_plane_host(), REMOTE_HOST)


func test_full_overrides_beat_the_host_override() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(PackedStringArray([
		"--server=%s" % REMOTE_HOST,
		"--gateway=ws://198.51.100.1:9000",
	]))
	assert_eq(endpoint.control_plane, "http://%s:8080" % REMOTE_HOST)
	assert_eq(endpoint.gateway, "ws://198.51.100.1:9000")
	assert_false(endpoint.has_errors(), str(endpoint.errors))


func test_control_plane_override_accepts_http_and_https_only() -> void:
	var plain: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--control-plane=http://%s:8080" % REMOTE_HOST])
	)
	assert_eq(plain.control_plane, "http://%s:8080" % REMOTE_HOST)
	var secure: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--control-plane=https://example.test"])
	)
	assert_eq(secure.control_plane, "https://example.test")
	var wrong: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--control-plane=ws://%s:8080" % REMOTE_HOST])
	)
	assert_eq(
		wrong.control_plane,
		ServerEndpointGd.DEFAULT_CONTROL_PLANE,
		"被拒的地址不得改动生效值"
	)
	assert_true(wrong.has_errors())


func test_gateway_override_accepts_ws_and_wss_only() -> void:
	var plain: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--gateway=ws://%s:8090" % REMOTE_HOST])
	)
	assert_eq(plain.gateway, "ws://%s:8090" % REMOTE_HOST)
	var secure: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--gateway=wss://example.test"])
	)
	assert_eq(secure.gateway, "wss://example.test")
	var wrong: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--gateway=http://%s:8090" % REMOTE_HOST])
	)
	assert_eq(wrong.gateway, ServerEndpointGd.DEFAULT_GATEWAY, "被拒的地址不得改动生效值")
	assert_true(wrong.has_errors())


func test_host_with_a_port_is_rejected_and_says_what_to_use_instead() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--server=%s:9000" % REMOTE_HOST])
	)
	assert_eq(endpoint.control_plane, ServerEndpointGd.DEFAULT_CONTROL_PLANE)
	assert_eq(endpoint.gateway, ServerEndpointGd.DEFAULT_GATEWAY)
	assert_true(endpoint.error_line().contains("--control-plane"), endpoint.error_line())
	assert_true(
		endpoint.error_line().contains("9000"),
		"报错必须回显原值，否则看不出拒了什么"
	)


func test_host_that_is_actually_a_url_is_rejected() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--server=http://%s" % REMOTE_HOST])
	)
	assert_eq(endpoint.control_plane, ServerEndpointGd.DEFAULT_CONTROL_PLANE)
	assert_true(endpoint.has_errors())


func test_blank_values_fall_through_instead_of_blanking_the_base() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--server=   "]),
		{ServerEndpointGd.SERVER_ENV: REMOTE_HOST}
	)
	assert_eq(endpoint.control_plane_host(), REMOTE_HOST)
	assert_false(endpoint.has_errors(), str(endpoint.errors))


func test_ipv6_literal_keeps_its_brackets() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--server=[2001:db8::1]"])
	)
	assert_eq(endpoint.control_plane, "http://[2001:db8::1]:8080")
	assert_eq(endpoint.gateway, "ws://[2001:db8::1]:8090")
	assert_false(endpoint.has_errors(), str(endpoint.errors))


func test_trailing_slash_is_stripped_so_paths_do_not_double_up() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--control-plane=http://%s:8080/" % REMOTE_HOST])
	)
	assert_eq(endpoint.control_plane, "http://%s:8080" % REMOTE_HOST)


func test_out_of_range_port_is_rejected() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--control-plane=http://%s:99999" % REMOTE_HOST])
	)
	assert_eq(endpoint.control_plane, ServerEndpointGd.DEFAULT_CONTROL_PLANE)
	assert_true(endpoint.has_errors())


func test_missing_scheme_is_rejected() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--gateway=%s:8090" % REMOTE_HOST])
	)
	assert_eq(endpoint.gateway, ServerEndpointGd.DEFAULT_GATEWAY)
	assert_true(endpoint.has_errors())


func test_runtime_retarget_keeps_an_explicit_port() -> void:
	# 大厅那个输入框走的就是这条：先用 --gateway 指定了非默认端口，之后换机器
	# 只该换主机，不该把端口悄悄改回 8090。
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--gateway=ws://198.51.100.1:9000"])
	)
	assert_true(endpoint.try_apply_host(REMOTE_HOST))
	assert_eq(endpoint.gateway, "ws://%s:9000" % REMOTE_HOST)
	assert_eq(endpoint.control_plane, "http://%s:8080" % REMOTE_HOST)


func test_runtime_retarget_reports_failure_without_touching_the_bases() -> void:
	var endpoint: ServerEndpointGd = ServerEndpointGd.resolve(
		PackedStringArray(["--server=%s" % REMOTE_HOST])
	)
	assert_false(endpoint.try_apply_host("bad host"))
	assert_eq(endpoint.control_plane_host(), REMOTE_HOST)
	assert_true(endpoint.has_errors())
	endpoint.clear_errors()
	assert_false(endpoint.has_errors())
