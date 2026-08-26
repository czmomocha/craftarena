extends Node

## 对局服务端进程入口。CD-44 §3：一场对局一个 Godot Headless 进程，由 MatchHost
## 分配内网端口、处理租约并回收。本进程把 --course 指定的 AuthoringDocument 编成
## SimulationBundle 并启动 TraprushMatchSession（M3 首章），随后随引擎 physics
## tick 推进权威仿真——引擎节奏不是产品 Tick Hz 锁定（CD-43 §4）。
## 实时回路：在本场内网端口监听 WebSocket（--bind 占位 0.0.0.0，公网暴露由部署层
## 与网关拓扑阻止），二进制命令帧经 MatchRealtime 排队、在 commit_tick 边界按到达
## 顺序应用；每 SNAPSHOT_EVERY_TICKS 个 tick 广播一帧二进制快照。命令帧 tick 只
## 解码不信任，服务端 tick 权威（CD-43 §3）。每槽每 tick 至多一条命令（先到先得），
## 断开丢弃排队；握手后按上游 URL 的 slot 占用席位，缺席位则占用最小空槽。
## 墙钟发送速率仍待（CD-63）。
## 心跳：每 HEARTBEAT_EVERY_TICKS 个 tick 打印一行结构化 JSON（含状态哈希与
## `valid_input_tick`），全员冲线后另含 settlement；供 MatchHost 活场 flush /
## 停止前写库、跨进程核对，以及仅在 `valid_input_tick` 前进时续租。
## 心跳本身不续租（CD-44 §3）。
## --max-ticks 到达后打印最终心跳并 exit 0；配置非法打印错误事件并 exit 1。
## 出生偏移、胶囊尺寸、心跳/快照节奏与动作数值（跳跃/支撑/道具伤害与触达/推击）
## 均为进程内占位桩，不锁产品出生布局或数值。与大厅 Solo 占位桩同值。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const Fixed := preload("res://src/shared/fixed/fixed.gd")
const MatchRealtime := preload("res://src/server/match_realtime.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushMatchSettlement := preload("res://src/games/traprush/match_settlement.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const BOOT_EVENT: String = "match_server_boot"
const LISTEN_EVENT: String = "match_listen"
const TICK_EVENT: String = "match_tick"
const ERROR_EVENT: String = "match_server_error"

## 占位心跳节奏（每 60 个引擎 tick 一行），不是产品快照频率。
const HEARTBEAT_EVERY_TICKS: int = 60
## 占位快照广播节奏（每 2 个 tick 一帧），不是产品快照频率（CD-43 §4）。
const SNAPSHOT_EVERY_TICKS: int = 2
## 占位胶囊半径/身高与出生间隔，不锁产品尺寸或出生布局。
const CAPSULE_RADIUS: int = 8192
const CAPSULE_HEIGHT: int = 8192
const SPAWN_STRIDE: int = 32768
## 占位仿真种子；对局种子由控制面下发是后续章节。
const MATCH_SEED: int = 1
## 占位动作数值，与大厅 Solo 对齐，不是产品跳跃高度、支撑探测或爆破表。
const STUB_USE_ITEM_DAMAGE: int = 1
## 占位推击步长（四分之一格）与冷却 tick，不是产品力度或冷却秒数。
const STUB_SHOVE_COOLDOWN_TICKS: int = 1

var _session: TraprushMatchSession = null
var _realtime: MatchRealtime = null
var _match_id: String = ""
var _max_ticks: int = 0
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
	var session: TraprushMatchSession = boot_session(config)
	if session == null:
		print(JSON.stringify({"event": ERROR_EVENT, "error": "session_boot_failed"}))
		get_tree().quit(1)
		return
	_session = session
	_realtime = MatchRealtime.new()
	_realtime.session = session
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
	}))
	print(JSON.stringify({
		"event": LISTEN_EVENT,
		"match_id": _match_id,
		"port": port,
		"bind": bind,
	}))


func _process(_delta: float) -> void:
	if _tcp == null or _realtime == null:
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
				_realtime.accept_command(slot, peer.get_packet())
		elif state == WebSocketPeer.STATE_CLOSED:
			closed.append(peer)
	for peer: WebSocketPeer in closed:
		var slot: int = _peers[peer]
		if slot >= 0:
			_realtime.remove_player(slot)
		_peers.erase(peer)


func _bind_peer(peer: WebSocketPeer) -> int:
	if _realtime == null:
		return -1
	var parsed: Dictionary = MatchRealtime.parse_requested_slot(peer.get_requested_url())
	var present: bool = parsed.get("present", false)
	if present:
		var parsed_ok: bool = parsed.get("ok", false)
		if not parsed_ok:
			return -1
		var requested: int = parsed.get("slot", -1)
		if _realtime.occupy_slot(requested):
			return requested
		return -1
	return _realtime.add_player()


func _physics_process(_delta: float) -> void:
	if _session == null or _realtime == null:
		return
	_realtime.commit_tick()
	var tick: int = _session.tick_index()
	if tick % SNAPSHOT_EVERY_TICKS == 0:
		_broadcast_snapshot()
	var at_max: bool = _max_ticks > 0 and tick >= _max_ticks
	if tick % HEARTBEAT_EVERY_TICKS == 0 or at_max:
		print(_heartbeat_line(_match_id, _session, _realtime.last_valid_input_tick()))
	if at_max:
		get_tree().quit(0)


func _broadcast_snapshot() -> void:
	if _realtime == null:
		return
	var frame: PackedByteArray = _realtime.snapshot_frame()
	if frame.is_empty():
		return
	for peer: WebSocketPeer in _peers.keys():
		var slot: int = _peers[peer]
		if slot < 0:
			continue
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
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
	if course.is_empty() or not FileAccess.file_exists(course):
		return failed
	var players_raw: String = options.get("players", "")
	var players: int = _parse_int(players_raw, -1)
	if players < 1 or players > TraprushMatchSession.MAX_PLAYERS:
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
		"players": players,
		"max_ticks": max_ticks,
		"bind": bind,
	}


## 从已校验配置启动对局会话。出生偏移为占位环：slot i 向 -Z 退 i * SPAWN_STRIDE。
static func boot_session(config: Dictionary) -> TraprushMatchSession:
	if not config.get("ok", false):
		return null
	var course: String = config.get("course", "")
	var players: int = config.get("players", 0)
	var world: AuthoringWorld = AuthoringDocument.load_from_path(course)
	if world == null:
		return null
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	if bundle == null:
		return null
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle,
		MATCH_SEED,
		players,
		_spawn_offsets(players),
		CAPSULE_RADIUS,
		CAPSULE_HEIGHT
	)
	if session == null:
		return null
	session.jump_dy = Fixed.SCALE
	session.support_dy = Fixed.SCALE
	session.use_item_damage = STUB_USE_ITEM_DAMAGE
	session.use_item_reach_dx = 0
	session.use_item_reach_dy = 0
	session.use_item_reach_dz = Fixed.SCALE
	session.shove_step = Fixed.SCALE / 4
	session.shove_cooldown_ticks = STUB_SHOVE_COOLDOWN_TICKS
	return session


static func _spawn_offsets(players: int) -> Array[Dictionary]:
	var offsets: Array[Dictionary] = []
	for slot: int in range(players):
		offsets.append({"dx": 0, "dy": 0, "dz": -slot * SPAWN_STRIDE})
	return offsets


static func _heartbeat_line(
	match_id: String,
	session: TraprushMatchSession,
	valid_input_tick: int = -1
) -> String:
	var body: Dictionary = {
		"event": TICK_EVENT,
		"match_id": match_id,
		"tick": session.tick_index(),
		"players": session.player_count(),
		"hash": session.hash_state(),
		"valid_input_tick": valid_input_tick,
	}
	var built: Dictionary = TraprushMatchSettlement.try_build(session)
	if built.get("ok", false):
		body["settlement"] = TraprushMatchSettlement.to_heartbeat(built)
	return JSON.stringify(body)


static func _parse_int(raw: String, fallback: int) -> int:
	if raw.is_empty():
		return fallback
	if not raw.is_valid_int():
		return fallback
	return raw.to_int()
