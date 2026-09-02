class_name MatchLobbyNet
extends Node

## L4 platform: live HTTP + WebSocket for the lobby. Tests inject HTTP/WS
## events on the shell and leave `live_io` off, so this node stays idle.

const MatchJoinSessionGd := preload("res://src/client/match_join_session.gd")
const MatchPlaySessionGd := preload("res://src/client/match_play_session.gd")

var http: HTTPRequest = null
var peer: WebSocketPeer = null
var http_busy: bool = false
var opened_socket: bool = false
var poll_accum: float = 0.0
var settlement_poll_accum: float = 0.0


func ensure_http(on_completed: Callable) -> void:
	if http != null:
		return
	http = HTTPRequest.new()
	http.timeout = 10.0
	http.request_completed.connect(on_completed)
	add_child(http)


func dispatch(control_plane_base: String, join: MatchJoinSessionGd, on_fail: Callable) -> void:
	if http == null or join == null or not join.has_pending() or http_busy:
		return
	var url: String = MatchJoinSessionGd.http_url(control_plane_base, join.pending_path())
	if url == "":
		join.fail_transport()
		if on_fail.is_valid():
			on_fail.call()
		return
	var method: String = join.pending_method()
	var err: int = ERR_BUG
	if method == "POST":
		var body: String = join.pending_body()
		var headers: PackedStringArray = PackedStringArray()
		if body != "":
			headers.append("Content-Type: application/json")
		err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	elif method == "GET":
		err = http.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	elif method == "DELETE":
		err = http.request(url, PackedStringArray(), HTTPClient.METHOD_DELETE)
	if err != OK:
		join.fail_transport()
		if on_fail.is_valid():
			on_fail.call()
		return
	http_busy = true


func on_http_completed(
	result: int,
	response_code: int,
	body: PackedByteArray,
	join: MatchJoinSessionGd,
	apply_text: Callable,
	on_fail: Callable
) -> void:
	http_busy = false
	if join == null:
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		join.fail_transport()
		if on_fail.is_valid():
			on_fail.call()
		return
	if apply_text.is_valid():
		apply_text.call(response_code, body.get_string_from_utf8())


func connect_gateway(play: MatchPlaySessionGd) -> void:
	if play == null or play.websocket_url == "":
		return
	drop_gateway()
	peer = WebSocketPeer.new()
	var tls: TLSOptions = MatchPlaySessionGd.tls_client_options(play.websocket_url)
	var err: int = peer.connect_to_url(play.websocket_url, tls)
	if err != OK:
		play.on_close()
		peer = null


func drop_gateway() -> void:
	if peer == null:
		return
	peer.close(-1)
	peer = null
	opened_socket = false


func poll_queue_clock(
	delta: float,
	queue_poll_s: float,
	join: MatchJoinSessionGd,
	offline_playing: bool,
	try_poll: Callable
) -> void:
	if join == null or join.state != MatchJoinSessionGd.STATE_WAITING or offline_playing:
		poll_accum = 0.0
		return
	if join.has_pending() or http_busy:
		return
	poll_accum += delta
	if poll_accum < queue_poll_s:
		return
	poll_accum = 0.0
	if try_poll.is_valid():
		try_poll.call()


func poll_settlement_clock(
	delta: float,
	queue_poll_s: float,
	join: MatchJoinSessionGd,
	play: MatchPlaySessionGd,
	finished: bool,
	try_fetch: Callable
) -> void:
	if join == null or join.state != MatchJoinSessionGd.STATE_READY:
		settlement_poll_accum = 0.0
		return
	if play == null or play.state != MatchPlaySessionGd.STATE_IN_MATCH:
		settlement_poll_accum = 0.0
		return
	if join.has_settlement:
		settlement_poll_accum = 0.0
		return
	if join.has_pending() or http_busy:
		return
	if not finished:
		settlement_poll_accum = 0.0
		return
	settlement_poll_accum += delta
	if settlement_poll_accum < queue_poll_s:
		return
	settlement_poll_accum = 0.0
	if try_fetch.is_valid():
		try_fetch.call()


func poll_gateway(
	play: MatchPlaySessionGd,
	last_sent: PackedByteArray,
	on_open: Callable,
	on_binary: Callable,
	on_close: Callable,
	on_probe: Callable
) -> PackedByteArray:
	if peer == null:
		return last_sent
	peer.poll()
	var ready: int = peer.get_ready_state()
	if ready == WebSocketPeer.STATE_OPEN:
		if not opened_socket:
			opened_socket = true
			if on_open.is_valid():
				on_open.call()
		while peer.get_available_packet_count() > 0:
			if on_binary.is_valid():
				on_binary.call(peer.get_packet())
		var sent: PackedByteArray = last_sent
		if not last_sent.is_empty() and play != null and not play.last_command.is_empty():
			if last_sent != play.last_command:
				peer.send(play.last_command, WebSocketPeer.WRITE_MODE_BINARY)
				sent = play.last_command
		if on_probe.is_valid():
			on_probe.call()
		return sent
	if ready == WebSocketPeer.STATE_CLOSED:
		peer = null
		opened_socket = false
		if on_close.is_valid():
			on_close.call()
	return last_sent


func note_command(bytes: PackedByteArray) -> PackedByteArray:
	if bytes.is_empty() or peer == null:
		return PackedByteArray()
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return PackedByteArray()
	peer.send(bytes, WebSocketPeer.WRITE_MODE_BINARY)
	return bytes


func send_probe(bytes: PackedByteArray) -> void:
	if peer == null or bytes.is_empty():
		return
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	peer.send(bytes, WebSocketPeer.WRITE_MODE_BINARY)
