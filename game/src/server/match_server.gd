extends Node

## 对局服务端进程入口。CD-44 §3：一场对局一个 Godot Headless 进程，由 MatchHost
## 分配内网端口、处理租约并回收。本进程把 --course 指定的 AuthoringDocument 编成
## SimulationBundle 并启动 TraprushMatchSession（M3 首章），随后随引擎 physics
## tick 推进权威仿真——引擎节奏不是产品 Tick Hz 锁定（CD-43 §4）。
## 心跳：每 HEARTBEAT_EVERY_TICKS 个 tick 打印一行结构化 JSON（含状态哈希），
## 供 MatchHost 的 recentOutput 留存与跨进程确定性核对；心跳不续租（CD-44 §3）。
## --max-ticks 到达后打印最终心跳并 exit 0；配置非法打印错误事件并 exit 1。
## 出生偏移、胶囊尺寸与心跳节奏均为进程内占位桩，不锁产品出生布局或数值。
## 无 socket：端口只由 MatchHost 记账占用；WebSocket 监听在后续章节。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const BOOT_EVENT: String = "match_server_boot"
const TICK_EVENT: String = "match_tick"
const ERROR_EVENT: String = "match_server_error"

## 占位心跳节奏（每 60 个引擎 tick 一行），不是产品快照频率。
const HEARTBEAT_EVERY_TICKS: int = 60
## 占位胶囊半径/身高与出生间隔，不锁产品尺寸或出生布局。
const CAPSULE_RADIUS: int = 8192
const CAPSULE_HEIGHT: int = 8192
const SPAWN_STRIDE: int = 32768
## 占位仿真种子；对局种子由控制面下发是后续章节。
const MATCH_SEED: int = 1

var _session: TraprushMatchSession = null
var _match_id: String = ""
var _max_ticks: int = 0


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
	_match_id = config.get("match_id", "")
	_max_ticks = config.get("max_ticks", 0)
	print(JSON.stringify({
		"event": BOOT_EVENT,
		"match_id": _match_id,
		"port": config.get("port", 0),
		"pid": OS.get_process_id(),
		"headless": DisplayServer.get_name() == "headless",
		"course": config.get("course", ""),
		"players": config.get("players", 0),
	}))


func _physics_process(_delta: float) -> void:
	if _session == null:
		return
	_session.commit_tick()
	var tick: int = _session.tick_index()
	var at_max: bool = _max_ticks > 0 and tick >= _max_ticks
	if tick % HEARTBEAT_EVERY_TICKS == 0 or at_max:
		print(_heartbeat_line(_match_id, _session))
	if at_max:
		get_tree().quit(0)


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
	return {
		"ok": true,
		"match_id": match_id,
		"port": port,
		"course": course,
		"players": players,
		"max_ticks": max_ticks,
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
	return TraprushMatchSession.create(
		bundle,
		MATCH_SEED,
		players,
		_spawn_offsets(players),
		CAPSULE_RADIUS,
		CAPSULE_HEIGHT
	)


static func _spawn_offsets(players: int) -> Array[Dictionary]:
	var offsets: Array[Dictionary] = []
	for slot: int in range(players):
		offsets.append({"dx": 0, "dy": 0, "dz": -slot * SPAWN_STRIDE})
	return offsets


static func _heartbeat_line(match_id: String, session: TraprushMatchSession) -> String:
	return JSON.stringify({
		"event": TICK_EVENT,
		"match_id": match_id,
		"tick": session.tick_index(),
		"players": session.player_count(),
		"hash": session.hash_state(),
	})


static func _parse_int(raw: String, fallback: int) -> int:
	if raw.is_empty():
		return fallback
	if not raw.is_valid_int():
		return fallback
	return raw.to_int()
