class_name ServerEndpoint
extends RefCounted

## Where the client points its control-plane HTTP and its gateway WebSocket.
##
## Course correction C1 chapter 2. The two base URLs used to be constants
## pinned to 127.0.0.1 with no second assignment anywhere in the tree, so a
## deployed test server was unreachable no matter how it was configured. This
## resolves them once at boot and lets the lobby retarget them at runtime.
##
## Resolution order, lowest priority first:
##
##   1. built-in defaults (a local `npm run dev`)
##   2. host override: `--server=HOST` or CRAFTARENA_SERVER, which swaps the
##      host of both defaults and keeps their scheme and port
##   3. full override: `--control-plane=URL` / `--gateway=URL`, or
##      CRAFTARENA_CONTROL_PLANE / CRAFTARENA_GATEWAY
##
## Command line beats environment at the same level. A rejected value never
## silently degrades to something that merely looks right: the previous value
## stays and the reason lands in `errors`, which the lobby HUD prints. Pointing
## at the wrong machine must be visible, not inferred from a failed join.
##
## Both plaintext and TLS schemes are accepted. Test-stage remote play runs on
## http / ws by human decision D11; https / wss keep the same entry point valid
## once公开运营前的证书到位（宪法第二十二条）。

const DEFAULT_CONTROL_PLANE: String = "http://127.0.0.1:8080"
const DEFAULT_GATEWAY: String = "ws://127.0.0.1:8090"

const SERVER_FLAG: String = "--server="
const CONTROL_PLANE_FLAG: String = "--control-plane="
const GATEWAY_FLAG: String = "--gateway="

const SERVER_ENV: String = "CRAFTARENA_SERVER"
const CONTROL_PLANE_ENV: String = "CRAFTARENA_CONTROL_PLANE"
const GATEWAY_ENV: String = "CRAFTARENA_GATEWAY"

const HTTP_SCHEMES: Array[String] = ["http", "https"]
const WS_SCHEMES: Array[String] = ["ws", "wss"]

const _MIN_PORT: int = 1
const _MAX_PORT: int = 65535

var control_plane: String = DEFAULT_CONTROL_PLANE
var gateway: String = DEFAULT_GATEWAY
var errors: PackedStringArray = PackedStringArray()


static func from_os(user_args: PackedStringArray) -> ServerEndpoint:
	var env: Dictionary = {}
	for key: String in [SERVER_ENV, CONTROL_PLANE_ENV, GATEWAY_ENV]:
		var value: String = OS.get_environment(key)
		if value != "":
			env[key] = value
	return resolve(user_args, env)


static func resolve(user_args: PackedStringArray, env: Dictionary = {}) -> ServerEndpoint:
	var endpoint: ServerEndpoint = new()
	var host: String = _lookup(user_args, SERVER_FLAG, env, SERVER_ENV)
	if host != "":
		endpoint.try_apply_host(host)
	var control_plane_url: String = _lookup(user_args, CONTROL_PLANE_FLAG, env, CONTROL_PLANE_ENV)
	if control_plane_url != "":
		endpoint.try_apply_control_plane(control_plane_url)
	var gateway_url: String = _lookup(user_args, GATEWAY_FLAG, env, GATEWAY_ENV)
	if gateway_url != "":
		endpoint.try_apply_gateway(gateway_url)
	return endpoint


## Retargets both bases at one machine, keeping whatever scheme and port they
## already carry. This is what `--server=` and the lobby's server field do; a
## different port still needs the explicit per-base override, because guessing
## a gateway port from a control-plane port would be an invented rule.
func try_apply_host(raw_host: String) -> bool:
	var host: String = raw_host.strip_edges()
	var reason: String = _host_rejection(host)
	if reason != "":
		errors.append("server host %s: %s" % [_quote(raw_host), reason])
		return false
	var next_control_plane: String = _with_host(control_plane, host)
	var next_gateway: String = _with_host(gateway, host)
	if next_control_plane == "" or next_gateway == "":
		errors.append("server host %s: current base URL cannot be retargeted" % _quote(raw_host))
		return false
	control_plane = next_control_plane
	gateway = next_gateway
	return true


func try_apply_control_plane(raw_url: String) -> bool:
	var url: String = raw_url.strip_edges()
	var reason: String = _url_rejection(url, HTTP_SCHEMES)
	if reason != "":
		errors.append("control plane %s: %s" % [_quote(raw_url), reason])
		return false
	control_plane = _strip_trailing_slash(url)
	return true


func try_apply_gateway(raw_url: String) -> bool:
	var url: String = raw_url.strip_edges()
	var reason: String = _url_rejection(url, WS_SCHEMES)
	if reason != "":
		errors.append("gateway %s: %s" % [_quote(raw_url), reason])
		return false
	gateway = _strip_trailing_slash(url)
	return true


## Host of an already-resolved base URL. The lobby needs this for a base it
## holds itself, so it stays static rather than forcing a round trip through an
## endpoint instance.
static func host_of(url: String) -> String:
	return str(_split_url(url).get("host", ""))


func control_plane_host() -> String:
	return host_of(control_plane)


func gateway_host() -> String:
	return host_of(gateway)


func has_errors() -> bool:
	return not errors.is_empty()


## First rejection only. The HUD has one line, and a person who typed one bad
## address does not need the whole list to fix it.
func error_line() -> String:
	if errors.is_empty():
		return ""
	return errors[0]


func clear_errors() -> void:
	errors = PackedStringArray()


static func _lookup(
	user_args: PackedStringArray,
	flag: String,
	env: Dictionary,
	env_key: String,
) -> String:
	# Last occurrence wins on the command line, matching how a shell user
	# expects a repeated flag to behave.
	var found: String = ""
	for arg: String in user_args:
		if arg.begins_with(flag):
			found = arg.substr(flag.length())
	if found.strip_edges() != "":
		return found
	return str(env.get(env_key, ""))


static func _host_rejection(host: String) -> String:
	if host == "":
		return "empty"
	if host.contains("://"):
		return "looks like a URL, use --control-plane / --gateway instead"
	for forbidden: String in [" ", "\t", "/", "?", "#", "@"]:
		if host.contains(forbidden):
			return "must be a bare host name or IP"
	if host.begins_with("["):
		if not host.ends_with("]"):
			return "unbalanced IPv6 brackets"
		if host.length() <= 2:
			return "empty IPv6 literal"
		return ""
	if host.contains(":"):
		return "must not carry a port, set it with --control-plane / --gateway"
	return ""


static func _url_rejection(url: String, allowed_schemes: Array[String]) -> String:
	var parts: Dictionary = _split_url(url)
	var parsed: bool = parts["ok"]
	if not parsed:
		return str(parts.get("reason", "unparsable"))
	var scheme: String = str(parts.get("scheme", ""))
	if not allowed_schemes.has(scheme):
		return "scheme must be one of %s" % ", ".join(allowed_schemes)
	return ""


## Minimal splitter. Godot 4 has no URL parser exposed to GDScript, and the
## inputs here are a scheme, an authority and an optional path — not the whole
## RFC. Anything it cannot account for is rejected rather than guessed.
static func _split_url(url: String) -> Dictionary:
	var separator: int = url.find("://")
	if separator <= 0:
		return _unparsable("missing scheme://")
	var scheme: String = url.substr(0, separator).to_lower()
	var remainder: String = url.substr(separator + 3)
	var path_start: int = remainder.find("/")
	var authority: String = remainder if path_start < 0 else remainder.substr(0, path_start)
	var rest: String = "" if path_start < 0 else remainder.substr(path_start)
	if authority.contains("@"):
		return _unparsable("credentials in URL are not supported")
	var host: String = authority
	var port: String = ""
	if authority.begins_with("["):
		var close_bracket: int = authority.find("]")
		if close_bracket < 0:
			return _unparsable("unbalanced IPv6 brackets")
		host = authority.substr(0, close_bracket + 1)
		var tail: String = authority.substr(close_bracket + 1)
		if tail != "":
			if not tail.begins_with(":"):
				return _unparsable("unexpected text after IPv6 literal")
			port = tail.substr(1)
	else:
		var colon: int = authority.rfind(":")
		if colon >= 0:
			host = authority.substr(0, colon)
			port = authority.substr(colon + 1)
	if host == "" or host == "[]":
		return _unparsable("empty host")
	if host.contains(" "):
		return _unparsable("host contains whitespace")
	if port != "":
		if not port.is_valid_int():
			return _unparsable("port is not an integer")
		var port_number: int = port.to_int()
		if port_number < _MIN_PORT or port_number > _MAX_PORT:
			return _unparsable("port must be within [%d, %d]" % [_MIN_PORT, _MAX_PORT])
	return {
		"ok": true,
		"scheme": scheme,
		"host": host,
		"port": port,
		"rest": rest,
	}


static func _with_host(url: String, host: String) -> String:
	var parts: Dictionary = _split_url(url)
	var parsed: bool = parts["ok"]
	if not parsed:
		return ""
	var port: String = str(parts.get("port", ""))
	var authority: String = host if port == "" else "%s:%s" % [host, port]
	return "%s://%s%s" % [str(parts.get("scheme", "")), authority, str(parts.get("rest", ""))]


static func _strip_trailing_slash(url: String) -> String:
	var trimmed: String = url
	while trimmed.ends_with("/"):
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	return trimmed


static func _unparsable(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _quote(value: String) -> String:
	return "\"%s\"" % value
