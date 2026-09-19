extends Node

## 对局服务端进程入口。CD-44 §3：一场对局一个 Godot Headless 进程，由 MatchHost
## 分配内网端口、处理租约并回收。本进程把 --course 指定的 AuthoringDocument 编成
## SimulationBundle 并启动 TraprushMatchSession（M3 首章），随后随引擎 physics
## tick 推进权威仿真。人类 2026-09-02 把现桩升为锁定：对局 / Solo 60 physics
## tick/s（CD-43 §4 / E3）。数字未改。
## 实时回路：本场内网端口监听 WebSocket；命令经 MatchRealtime 排队，commit_tick
## 边界按到达顺序应用。命令帧 tick 只解码不信任。每槽每 tick 至多一条。
## 快照 / 心跳间隔已锁定（CD-43 §4）。心跳含 valid_input_tick，全员冲线后另含
## settlement。心跳本身不续租（CD-44 §3）。
## --max-ticks 到达后最终心跳并 exit 0；配置非法 exit 1。动作数值来自 PlayStubs。

const MatchRealtime := preload("res://src/server/match_realtime.gd")
const MatchRealtimeBastionGd := preload("res://src/server/match_realtime_bastion.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushMatchSettlement := preload("res://src/games/traprush/match_settlement.gd")
const BastionMatchSessionGd := preload("res://src/games/bastion/match_session.gd")
const BastionMatchSettlementGd := preload("res://src/games/bastion/match_settlement.gd")
const MatchServerBootGd := preload("res://src/server/match_server_boot.gd")
const MatchGameplayGd := preload("res://src/shared/match_gameplay.gd")
const PlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")

const BOOT_EVENT: String = "match_server_boot"
const LISTEN_EVENT: String = "match_listen"
const TICK_EVENT: String = "match_tick"
const ERROR_EVENT: String = "match_server_error"

## 占位心跳节奏（每 60 个引擎 tick 一行），不是产品快照频率。
const HEARTBEAT_EVERY_TICKS: int = 60
## 占位快照广播节奏（每 2 个 tick 一帧），不是产品快照频率（CD-43 §4）。
const SNAPSHOT_EVERY_TICKS: int = 2

var _session: RefCounted = null
var _traprush_rt: MatchRealtime = null
var _bastion_rt: MatchRealtimeBastionGd = null
var _match_id: String = ""
var _max_ticks: int = 0
var _replay_out: String = ""
var _course_path: String = ""
var _tcp: TCPServer = null
var _peers: Dictionary = {}


func _ready() -> void:
	var options: Dictionary = _parse_user_args(OS.get_cmdline_user_args())
	var config: Dictionary = _boot_config(options)
	if not config.get("ok", false):
		var error_name: String = config.get("error", "bad_config")
		print(JSON.stringify({"event": ERROR_EVENT, "error": error_name}))
		get_tree().quit(1)
		return
	var session: RefCounted = boot_session(config)
	if session == null:
		print(JSON.stringify({"event": ERROR_EVENT, "error": "session_boot_failed"}))
		get_tree().quit(1)
		return
	_session = session
	_course_path = str(config.get("course", ""))
	_replay_out = str(config.get("replay_out", ""))
	if session is TraprushMatchSession:
		PlayStubsGd.apply_opening_countdown(session as TraprushMatchSession)
	if not _attach_realtime(session):
		print(JSON.stringify({"event": ERROR_EVENT, "error": "session_boot_failed"}))
		get_tree().quit(1)
		return
	_match_id = config.get("match_id", "")
	_max_ticks = config.get("max_ticks", 0)
	var port: int = config.get("port", 0)
	var bind: String = config.get("bind", "")
	_tcp = TCPServer.new()
	var listen_err: int = _tcp.listen(port, bind)
	if listen_err != OK:
		print(JSON.stringify({"event": ERROR_EVENT, "error": "listen_failed", "code": listen_err}))
		get_tree().quit(1)
		return
	print(JSON.stringify({
		"event": BOOT_EVENT,
		"match_id": _match_id,
		"port": port,
		"pid": OS.get_process_id(),
		"headless": DisplayServer.get_name() == "headless",
		"course": config.get("course", ""),
		"players": config.get("players", 0),
		"gameplay": config.get("gameplay", MatchGameplayGd.TRAPRUSH),
	}))
	print(JSON.stringify({
		"event": LISTEN_EVENT,
		"match_id": _match_id,
		"port": port,
		"bind": bind,
	}))


func _process(_delta: float) -> void:
	if _tcp == null or not _rt_alive():
		return
	while _tcp.is_connection_available():
		var stream: StreamPeerTCP = _tcp.take_connection()
		if stream == null:
			break
		var peer: WebSocketPeer = WebSocketPeer.new()
		var accept_err: int = peer.accept_stream(stream)
		if accept_err != OK:
			continue
		_peers[peer] = -1
	var closed: Array = []
	for peer: WebSocketPeer in _peers.keys():
		peer.poll()
		var state: int = peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			var slot: int = _peers[peer]
			if slot < 0:
				slot = _bind_peer(peer)
				if slot < 0:
					peer.close(1008, "match full")
					closed.append(peer)
					continue
				_peers[peer] = slot
			while peer.get_available_packet_count() > 0:
				var inbound: PackedByteArray = peer.get_packet()
				var pong: PackedByteArray = _rt_handle_inbound(slot, inbound)
				if pong.is_empty():
					continue
				if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
					peer.send(pong, WebSocketPeer.WRITE_MODE_BINARY)
		elif state == WebSocketPeer.STATE_CLOSED:
			closed.append(peer)
	for peer: WebSocketPeer in closed:
		var slot: int = _peers[peer]
		if slot >= 0:
			_rt_remove_player(slot)
		_peers.erase(peer)


func _bind_peer(peer: WebSocketPeer) -> int:
	if not _rt_alive():
		return -1
	var parsed: Dictionary = MatchRealtime.parse_requested_slot(peer.get_requested_url())
	var present: bool = parsed.get("present", false)
	if present:
		var parsed_ok: bool = parsed.get("ok", false)
		if not parsed_ok:
			return -1
		var requested: int = parsed.get("slot", -1)
		if _rt_occupy_slot(requested):
			return requested
		return -1
	return _rt_add_player()


func _physics_process(_delta: float) -> void:
	if _session == null or not _rt_alive():
		return
	_rt_commit_tick()
	if _traprush_rt != null:
		_traprush_rt.try_flush_replay(_replay_out)
	var tick: int = _session_tick()
	if tick % SNAPSHOT_EVERY_TICKS == 0:
		_broadcast_snapshot()
	var at_max: bool = _max_ticks > 0 and tick >= _max_ticks
	if tick % HEARTBEAT_EVERY_TICKS == 0 or at_max:
		print(_heartbeat_line(_match_id, _session, _rt_last_valid_input_tick()))
	if at_max:
		get_tree().quit(0)


func _broadcast_snapshot() -> void:
	if not _rt_alive():
		return
	for peer: WebSocketPeer in _peers.keys():
		var slot: int = _peers[peer]
		if slot < 0:
			continue
		if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue
		var frame: PackedByteArray = _rt_snapshot_frame_for(slot)
		if frame.is_empty():
			continue
		peer.send(frame, WebSocketPeer.WRITE_MODE_BINARY)


## 只接受 `--key=value` 形式。裸开关与位置参数一律忽略，避免 MatchHost 传参出错时
## 被静默地解释成别的东西。
static func _parse_user_args(user_args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {}

	for argument: String in user_args:
		if not argument.begins_with("--"):
			continue

		var separator_index: int = argument.find("=")
		if separator_index <= 2:
			continue

		var key: String = argument.substr(2, separator_index - 2)
		var value: String = argument.substr(separator_index + 1)
		options[key] = value

	return options


## 把解析后的参数校验成启动配置。max-ticks 缺省为 0（跑到被回收为止）。
static func _boot_config(options: Dictionary) -> Dictionary:
	var failed: Dictionary = {"ok": false, "error": "bad_config"}
	var match_id: String = options.get("match-id", "")
	if match_id.is_empty():
		return failed
	var port_raw: String = options.get("port", "")
	var port: int = _parse_int(port_raw, -1)
	if port < 1 or port > 65535:
		return failed
	var course: String = options.get("course", "")
	var envelope: String = options.get("content-envelope", "")
	var gameplay: String = str(options.get("gameplay", MatchGameplayGd.TRAPRUSH)).strip_edges()
	if gameplay.is_empty():
		gameplay = MatchGameplayGd.TRAPRUSH
	if not MatchGameplayGd.is_id(gameplay):
		return failed
	var has_course: bool = not course.is_empty()
	var has_envelope: bool = not envelope.is_empty()
	if gameplay == MatchGameplayGd.BASTION:
		if has_envelope or not has_course:
			return failed
	elif has_course == has_envelope:
		return failed
	if has_course and not FileAccess.file_exists(course):
		return failed
	if has_envelope and not FileAccess.file_exists(envelope):
		return failed
	var players_raw: String = options.get("players", "")
	var players: int = _parse_int(players_raw, -1)
	if gameplay == MatchGameplayGd.BASTION:
		if players != MatchGameplayGd.BASTION_SEATS:
			return failed
	elif players < 1 or players > TraprushMatchSession.MAX_PLAYERS:
		return failed
	var max_ticks: int = 0
	if options.has("max-ticks"):
		var max_ticks_raw: String = options.get("max-ticks", "")
		max_ticks = _parse_int(max_ticks_raw, -1)
		if max_ticks < 1:
			return failed
	var bind: String = options.get("bind", "0.0.0.0")
	if bind.is_empty():
		return failed
	return {
		"ok": true,
		"match_id": match_id,
		"port": port,
		"course": course,
		"content_envelope": envelope,
		"players": players,
		"max_ticks": max_ticks,
		"bind": bind,
		"gameplay": gameplay,
		"replay_out": str(options.get("replay-out", "")),
	}


static func boot_session(config: Dictionary) -> RefCounted:
	return MatchServerBootGd.boot_session(config)


static func _spawn_offsets(players: int) -> Array[Dictionary]:
	return MatchServerBootGd._spawn_offsets(players)


static func _heartbeat_line(
	match_id: String,
	session: RefCounted,
	valid_input_tick: int = -1
) -> String:
	var bastion: BastionMatchSessionGd = session as BastionMatchSessionGd
	if bastion != null:
		var bastion_body: Dictionary = {
			"event": TICK_EVENT,
			"match_id": match_id,
			"tick": bastion.tick_index(),
			"players": bastion.player_count(),
			"hash": bastion.hash_state(),
			"valid_input_tick": valid_input_tick,
		}
		var bastion_built: Dictionary = BastionMatchSettlementGd.try_build(bastion)
		if bastion_built.get("ok", false):
			bastion_body["settlement"] = BastionMatchSettlementGd.to_heartbeat(bastion_built)
		return JSON.stringify(bastion_body)
	var traprush: TraprushMatchSession = session as TraprushMatchSession
	if traprush == null:
		return "{}"
	var body: Dictionary = {
		"event": TICK_EVENT,
		"match_id": match_id,
		"tick": traprush.tick_index(),
		"players": traprush.player_count(),
		"hash": traprush.hash_state(),
		"valid_input_tick": valid_input_tick,
	}
	var built: Dictionary = TraprushMatchSettlement.try_build(traprush)
	if built.get("ok", false):
		body["settlement"] = TraprushMatchSettlement.to_heartbeat(built)
	return JSON.stringify(body)


func _attach_realtime(session: RefCounted) -> bool:
	var bastion: BastionMatchSessionGd = session as BastionMatchSessionGd
	if bastion != null:
		_bastion_rt = MatchRealtimeBastionGd.create(bastion) as MatchRealtimeBastionGd
		return _bastion_rt != null
	var traprush: TraprushMatchSession = session as TraprushMatchSession
	if traprush == null:
		return false
	_traprush_rt = MatchRealtime.create(traprush)
	if _traprush_rt == null:
		return false
	_traprush_rt.begin_tape(_course_path)
	return true


func _rt_alive() -> bool:
	return _traprush_rt != null or _bastion_rt != null


func _rt_handle_inbound(slot: int, inbound: PackedByteArray) -> PackedByteArray:
	if _bastion_rt != null:
		return _bastion_rt.handle_inbound(slot, inbound)
	if _traprush_rt != null:
		return _traprush_rt.handle_inbound(slot, inbound)
	return PackedByteArray()


func _rt_remove_player(slot: int) -> void:
	if _bastion_rt != null:
		_bastion_rt.remove_player(slot)
		return
	if _traprush_rt != null:
		_traprush_rt.remove_player(slot)


func _rt_occupy_slot(slot: int) -> bool:
	if _bastion_rt != null:
		return _bastion_rt.occupy_slot(slot)
	if _traprush_rt != null:
		return _traprush_rt.occupy_slot(slot)
	return false


func _rt_add_player() -> int:
	if _bastion_rt != null:
		return _bastion_rt.add_player()
	if _traprush_rt != null:
		return _traprush_rt.add_player()
	return -1


func _rt_commit_tick() -> void:
	if _bastion_rt != null:
		_bastion_rt.commit_tick()
		return
	if _traprush_rt != null:
		_traprush_rt.commit_tick()


func _rt_last_valid_input_tick() -> int:
	if _bastion_rt != null:
		return _bastion_rt.last_valid_input_tick()
	if _traprush_rt != null:
		return _traprush_rt.last_valid_input_tick()
	return -1


func _rt_snapshot_frame_for(slot: int) -> PackedByteArray:
	if _bastion_rt != null:
		return _bastion_rt.snapshot_frame_for(slot)
	if _traprush_rt != null:
		return _traprush_rt.snapshot_frame_for(slot)
	return PackedByteArray()


func _session_tick() -> int:
	var bastion: BastionMatchSessionGd = _session as BastionMatchSessionGd
	if bastion != null:
		return bastion.tick_index()
	var traprush: TraprushMatchSession = _session as TraprushMatchSession
	if traprush != null:
		return traprush.tick_index()
	return 0


static func _parse_int(raw: String, fallback: int) -> int:
	if raw.is_empty():
		return fallback
	if not raw.is_valid_int():
		return fallback
	return raw.to_int()
