class_name ControlPlaneHttp
extends RefCounted

## Blocking JSON GET/POST against the control plane. Tests inject a
## transport callback and never open a socket. Live path uses HTTPClient.

const JoinCodecGd := preload("res://src/client/match_join_codec.gd")

const KEY_OK: String = "ok"
const KEY_STATUS: String = "status"
const KEY_BODY: String = "body"
const KEY_REASON: String = "reason"
const REASON_URL: String = "url_invalid"
const REASON_TRANSPORT: String = "transport_failed"
const REASON_RESPONSE: String = "response_invalid"
const TIMEOUT_MS: int = 10000


static func get_json(
	base: String,
	path: String,
	headers: PackedStringArray,
	transport: Callable = Callable()
) -> Dictionary:
	return exchange(base, "GET", path, headers, "", transport)


static func post_json(
	base: String,
	path: String,
	headers: PackedStringArray,
	payload: Dictionary,
	transport: Callable = Callable()
) -> Dictionary:
	var body: String = "" if payload.is_empty() else JSON.stringify(payload)
	var next_headers: PackedStringArray = headers.duplicate()
	if body != "" and not _has_header(next_headers, "Content-Type"):
		next_headers.append("Content-Type: application/json")
	return exchange(base, "POST", path, next_headers, body, transport)


static func exchange(
	base: String,
	method: String,
	path: String,
	headers: PackedStringArray,
	body: String,
	transport: Callable = Callable()
) -> Dictionary:
	if transport.is_valid():
		var raw: Variant = transport.call(method, path, headers, body)
		return _normalize(raw)
	return _live(base, method, path, headers, body)


static func _normalize(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail(REASON_TRANSPORT, 0, {})
	var data: Dictionary = raw
	var status: int = _as_int(data.get(KEY_STATUS, 0), 0)
	var body_raw: Variant = data.get(KEY_BODY, {})
	var body: Dictionary = {}
	if typeof(body_raw) == TYPE_DICTIONARY:
		body = body_raw
	elif typeof(body_raw) == TYPE_STRING:
		body = _parse_object(str(body_raw))
	if body.is_empty() and data.has("error"):
		body = {"error": str(data.get("error", REASON_RESPONSE))}
	if status <= 0:
		return _fail(REASON_TRANSPORT, status, body)
	return {KEY_OK: true, KEY_STATUS: status, KEY_BODY: body, KEY_REASON: ""}


static func _live(
	base: String,
	method: String,
	path: String,
	headers: PackedStringArray,
	body: String
) -> Dictionary:
	var url: String = JoinCodecGd.http_url(base, path)
	var parts: Dictionary = _split_url(url)
	if parts.is_empty():
		return _fail(REASON_URL, 0, {})
	var http := HTTPClient.new()
	var tls: TLSOptions = null
	if parts.get("tls", false):
		tls = TLSOptions.client()
	var err: int = http.connect_to_host(str(parts.get("host", "")), _as_int(parts.get("port", 80), 80), tls)
	if err != OK:
		return _fail(REASON_TRANSPORT, 0, {})
	if not _wait(http, [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]):
		return _fail(REASON_TRANSPORT, 0, {})
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return _fail(REASON_TRANSPORT, 0, {})
	var verb: int = HTTPClient.METHOD_GET if method == "GET" else HTTPClient.METHOD_POST
	err = http.request(verb, str(parts.get("path", "/")), headers, body)
	if err != OK:
		return _fail(REASON_TRANSPORT, 0, {})
	if not _wait(http, [HTTPClient.STATUS_REQUESTING]):
		return _fail(REASON_TRANSPORT, 0, {})
	if not http.has_response():
		return _fail(REASON_RESPONSE, 0, {})
	var status: int = http.get_response_code()
	var packed: PackedByteArray = PackedByteArray()
	var started: int = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_BODY:
		if Time.get_ticks_msec() - started > TIMEOUT_MS:
			return _fail(REASON_TRANSPORT, status, {})
		http.poll()
		var chunk: PackedByteArray = http.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(1)
			continue
		packed.append_array(chunk)
	var parsed: Dictionary = _parse_object(packed.get_string_from_utf8())
	if parsed.is_empty() and not packed.is_empty():
		return _fail(REASON_RESPONSE, status, {})
	return {KEY_OK: true, KEY_STATUS: status, KEY_BODY: parsed, KEY_REASON: ""}


static func _wait(http: HTTPClient, busy: Array[int]) -> bool:
	var started: int = Time.get_ticks_msec()
	while _status_is(http.get_status(), busy):
		if Time.get_ticks_msec() - started > TIMEOUT_MS:
			return false
		http.poll()
		OS.delay_msec(1)
	var status: int = http.get_status()
	return status != HTTPClient.STATUS_CANT_RESOLVE and status != HTTPClient.STATUS_CANT_CONNECT and status != HTTPClient.STATUS_CONNECTION_ERROR and status != HTTPClient.STATUS_TLS_HANDSHAKE_ERROR


static func _status_is(status: int, busy: Array[int]) -> bool:
	for code: int in busy:
		if status == code:
			return true
	return false


static func _split_url(url: String) -> Dictionary:
	var tls: bool = url.begins_with("https://")
	if not tls and not url.begins_with("http://"):
		return {}
	var rest: String = url.substr(8 if tls else 7)
	var slash: int = rest.find("/")
	var authority: String = rest if slash < 0 else rest.substr(0, slash)
	var path: String = "/" if slash < 0 else rest.substr(slash)
	if authority == "" or authority.contains(" "):
		return {}
	var host: String = authority
	var port: int = 443 if tls else 80
	var colon: int = authority.rfind(":")
	if colon > 0:
		host = authority.substr(0, colon)
		var port_text: String = authority.substr(colon + 1)
		if not port_text.is_valid_int():
			return {}
		port = int(port_text)
	if host == "":
		return {}
	return {"host": host, "port": port, "tls": tls, "path": path}


static func _parse_object(text: String) -> Dictionary:
	if text.strip_edges() == "":
		return {}
	var parsed: Dictionary = JoinCodecGd.parse_json_object(text)
	if not _flag(parsed):
		return {}
	var body_raw: Variant = parsed.get(KEY_BODY, {})
	if typeof(body_raw) != TYPE_DICTIONARY:
		return {}
	return body_raw


static func _has_header(headers: PackedStringArray, name: String) -> bool:
	var prefix: String = "%s:" % name.to_lower()
	for line: String in headers:
		if line.strip_edges().to_lower().begins_with(prefix):
			return true
	return false


static func _fail(reason: String, status: int, body: Dictionary) -> Dictionary:
	return {KEY_OK: false, KEY_STATUS: status, KEY_BODY: body, KEY_REASON: reason}


static func _as_int(raw: Variant, fallback: int) -> int:
	if typeof(raw) == TYPE_INT:
		var value: int = raw
		return value
	if typeof(raw) == TYPE_FLOAT:
		var number: float = raw
		if number != floor(number):
			return fallback
		return int(number)
	return fallback


static func _flag(raw: Dictionary) -> bool:
	var flag: Variant = raw.get(KEY_OK, false)
	return typeof(flag) == TYPE_BOOL and flag
