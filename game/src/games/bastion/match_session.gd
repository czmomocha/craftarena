class_name BastionMatchSession
extends RefCounted

## BASTION 对局门面：五阶段、镜像波次、核心伤害、胜负。**离线权威**，不碰协议、
## 不碰表现。
##
## 权威状态为什么住在这里而不是 `SimulationWorld`：那份世界只有位姿、胶囊和静态
## AABB，**没有血量、金币、队伍**。TRAPRUSH 的进度与门闩同样住在
## `TraprushMatchSession`。所以核心血量、波次序号、漏怪数、存活单位位姿都在本
## 会话里，并进本会话自己的 `hash_state`（`SimulationCore` 的定点合同一个字不改）。
##
## 五阶段照 CD-22 §6，推进只由**权威 tick 与锁定**驱动，一处不读墙钟：
##
## | 阶段 | 进入条件 | 离开条件 |
## |---|---|---|
## | 内容握手 | `create()` | `begin_match()` 校验蓝图与可达性通过 |
## | 互设障碍 | 握手通过 | 双方都锁定，或 `setup_ticks` 到 |
## | 准备建造 | 障碍锁定 | `prep_ticks` 到 |
## | 镜像波次 | 准备结束 | 任一核心归零 / 全部波次打完 / `time_limit_ticks` 到 |
## | 结算 | 上一条任一 | 终态 |
##
## 互设障碍这一阶段目前只有**放置与守卫**两件事：点数预算、盲设、揭示、重验退点
## 是 D5，隐藏布障的协议裁剪是 E1。不得据此说「盲设已经做了」。
##
## 一拍之内的顺序是固定的，改了它就改了裁决结果：**生成 → 开火 → 行进 → 判胜负**。
## 开火在行进之前，所以刚生成的兵这一拍就可能挨打；行进在开火之后，所以这一拍
## 被打死的兵不会再往前走一步。

const GuardGd := preload("res://src/games/bastion/path_guard.gd")
const StubsGd := preload("res://src/games/bastion/play_stubs.gd")
const TowersGd := preload("res://src/games/bastion/match_session_towers.gd")
const ViewGd := preload("res://src/games/bastion/match_session_view.gd")
const WavesGd := preload("res://src/games/bastion/match_session_waves.gd")

const PHASE_HANDSHAKE: int = 0
const PHASE_SETUP: int = 1
const PHASE_PREP: int = 2
const PHASE_WAVES: int = 3
const PHASE_SETTLED: int = 4

const RESULT_PENDING: int = 0
const RESULT_DRAW: int = 3

var bundle: BastionBlueprintBundle = null
var seed: int = 0
var phase: int = PHASE_HANDSHAKE
var tick: int = 0
var result: int = RESULT_PENDING

var _phase_tick: int = 0
var _wave_index: int = 0
var _wave_start_tick: int = 0
var _wave_spawned: int = 0
var _waves_done: bool = false
var _income_wave: int = 0
var _teams: Dictionary[int, Dictionary] = {}
var _positions: Dictionary[int, Dictionary] = {}
var _next_unit_serial: int = 1


static func create(p_bundle: BastionBlueprintBundle, p_seed: int) -> BastionMatchSession:
	if p_bundle == null:
		return null
	var session: BastionMatchSession = BastionMatchSession.new()
	session.bundle = p_bundle
	session.seed = p_seed
	for node: Dictionary in p_bundle.waypoints:
		var node_id: int = node["node_id"]
		session._positions[node_id] = {"x": node["x"], "y": node["y"], "z": node["z"]}
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var core: Dictionary = p_bundle.core_of(team_id)
		if core.is_empty():
			return null
		var maximum: int = core["max_health"]
		session._teams[team_id] = {
			"team_id": team_id,
			"core_health": maximum,
			"max_core_health": maximum,
			"gold": p_bundle.economy_value("initial_gold"),
			"leaked": 0,
			"kills": 0,
			"clear_tick": 0,
			"locked": false,
			"wave_bounty": 0,
			"units": [],
			"obstacles": [],
			"towers": [],
			"path": PackedInt32Array(),
		}
	return session


## 内容握手：蓝图必须自带一条走得通的兵线，否则这一局根本不该开。
func begin_match() -> bool:
	if phase != PHASE_HANDSHAKE:
		return false
	if not GuardGd.problems(bundle).is_empty():
		return false
	_enter(PHASE_SETUP)
	return true


## 互设障碍阶段放一个障碍。本章只过 `BastionPathGuard`：点数预算、盲设与揭示
## 退点是 D5，不在这里假装已经有了。
func try_place_obstacle(team_id: int, node_id: int, prototype_id: int) -> bool:
	if phase != PHASE_SETUP:
		return false
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return false
	var locked: bool = team["locked"]
	if locked:
		return false
	var existing: Array = team["obstacles"]
	var candidate: Dictionary = {"node_id": node_id, "prototype_id": prototype_id}
	if not GuardGd.allows_obstacle(bundle, team_id, existing, candidate):
		return false
	existing.append(candidate)
	return true


## 四个建造意图。全部先验后改，任何一条不满足就整笔不发生（宪法第二条：
## 客户端只提交意图，金币与建造由服务端裁决）。
func try_build_tower(team_id: int, slot_id: int, prototype_id: int) -> bool:
	return TowersGd.try_build(self, team_id, slot_id, prototype_id)


func try_upgrade_tower(team_id: int, slot_id: int) -> bool:
	return TowersGd.try_upgrade(self, team_id, slot_id)


func try_sell_tower(team_id: int, slot_id: int) -> bool:
	return TowersGd.try_sell(self, team_id, slot_id)


func try_set_tower_priority(team_id: int, slot_id: int, priority: String) -> bool:
	return TowersGd.try_set_priority(self, team_id, slot_id, priority)


func tower_count(team_id: int) -> int:
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return 0
	var towers: Array = team["towers"]
	return towers.size()


## 该槽上的塔；空槽返回空字典。
func tower_at(team_id: int, slot_id: int) -> Dictionary:
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return {}
	var towers: Array = team["towers"]
	for item: Variant in towers:
		var tower: Dictionary = item
		var current: int = tower["slot_id"]
		if current == slot_id:
			return tower.duplicate(true)
	return {}


func lock_setup(team_id: int) -> bool:
	if phase != PHASE_SETUP:
		return false
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return false
	var locked: bool = team["locked"]
	if locked:
		return false
	team["locked"] = true
	return true


## 推进一个权威 tick。阶段切换、生成、行进、核心伤害、胜负都在这里发生。
func commit_tick() -> void:
	if phase == PHASE_SETTLED:
		return
	tick += 1
	_phase_tick += 1
	match phase:
		PHASE_HANDSHAKE:
			return
		PHASE_SETUP:
			_tick_setup()
		PHASE_PREP:
			_tick_prep()
		PHASE_WAVES:
			_tick_waves()


func tick_index() -> int:
	return tick


func wave_index() -> int:
	return _wave_index


func total_waves() -> int:
	return bundle.total_wave_count()


func core_health(team_id: int) -> int:
	return _team_int(team_id, "core_health")


func gold(team_id: int) -> int:
	return _team_int(team_id, "gold")


func leaked(team_id: int) -> int:
	return _team_int(team_id, "leaked")


func kills(team_id: int) -> int:
	return _team_int(team_id, "kills")


func clear_tick(team_id: int) -> int:
	return _team_int(team_id, "clear_tick")


func alive_units(team_id: int) -> int:
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return 0
	var units: Array = team["units"]
	return units.size()


func lane_path(team_id: int) -> PackedInt32Array:
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return PackedInt32Array()
	var path: PackedInt32Array = team["path"]
	return path


## 该队本局的生成流水：`{tick, prototype_id, max_health, speed, bounty, roll}`。
## 不含 `unit_id`——那是每队各自递增的本地编号，两队理应不同。
func spawn_log(team_id: int) -> Array[Dictionary]:
	return ViewGd.spawn_log(self, team_id)


func unit_states(team_id: int) -> Array[Dictionary]:
	return ViewGd.unit_states(self, team_id)


## 权威状态哈希。覆盖范围见 `BastionMatchSessionView` 文件头。
func hash_state() -> String:
	return ViewGd.hash_state(self)

func _tick_setup() -> void:
	var both_locked: bool = true
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var team: Dictionary = _team(team_id)
		var locked: bool = team["locked"]
		if not locked:
			both_locked = false
	if both_locked or _phase_tick >= bundle.economy_value("setup_ticks"):
		WavesGd.freeze_lanes(self)
		_enter(PHASE_PREP)


func _tick_prep() -> void:
	if _phase_tick >= bundle.economy_value("prep_ticks"):
		_enter(PHASE_WAVES)
		_wave_index = 1
		_wave_start_tick = tick
		_wave_spawned = 0


func _tick_waves() -> void:
	WavesGd.spawn_due(self)
	if _wave_index > _income_wave:
		_income_wave = _wave_index
		for team_id: int in BastionBlueprintBundle.TEAMS:
			TowersGd.open_wave(self, team_id)
	for team_id: int in BastionBlueprintBundle.TEAMS:
		TowersGd.fire(self, team_id)
	WavesGd.advance_all(self)
	if _core_fell():
		_settle()
		return
	if _waves_done and _all_lanes_empty():
		_settle()
		return
	if _phase_tick >= bundle.economy_value("time_limit_ticks"):
		_settle()


func _core_fell() -> bool:
	for team_id: int in BastionBlueprintBundle.TEAMS:
		if core_health(team_id) <= 0:
			return true
	return false


func _all_lanes_empty() -> bool:
	for team_id: int in BastionBlueprintBundle.TEAMS:
		if alive_units(team_id) > 0:
			return false
	return true


## CD-22 §5.2：核心生命 → 漏怪数 → 完成击杀时间，依次比较。
func _settle() -> void:
	result = _compare(BastionBlueprintBundle.TEAM_A, BastionBlueprintBundle.TEAM_B)
	_enter(PHASE_SETTLED)


func _compare(first_id: int, second_id: int) -> int:
	var first_health: int = core_health(first_id)
	var second_health: int = core_health(second_id)
	if first_health != second_health:
		return first_id if first_health > second_health else second_id
	var first_leaked: int = leaked(first_id)
	var second_leaked: int = leaked(second_id)
	if first_leaked != second_leaked:
		return first_id if first_leaked < second_leaked else second_id
	var first_clear: int = clear_tick(first_id)
	var second_clear: int = clear_tick(second_id)
	if first_clear == second_clear:
		return RESULT_DRAW
	if first_clear == 0:
		return second_id
	if second_clear == 0:
		return first_id
	return first_id if first_clear < second_clear else second_id


func _enter(next_phase: int) -> void:
	phase = next_phase
	_phase_tick = 0


func _team(team_id: int) -> Dictionary:
	if not _teams.has(team_id):
		return {}
	return _teams[team_id]


func _team_int(team_id: int, key: String) -> int:
	var team: Dictionary = _team(team_id)
	if team.is_empty():
		return 0
	var value: int = team[key]
	return value
