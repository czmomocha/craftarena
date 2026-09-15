class_name BastionMatchSessionTowers
extends RefCounted

## 炮塔与经济：建造 / 升级 / 出售 / 目标优先级 / 自动开火 / 基础收入 / 击杀赏金。
## 拆出来只为让 `BastionMatchSession` 低于 E9 400 行；公开 API 仍在会话门面。
##
## **这一章就是 CD-61 §2 M6 那句验收词的实现**：「非法封路、伪造金币和伪造建造
## 均被拒绝」。所以四类伪造各有一条独立判据，全部在服务端：
##
## 1. 非白名单原型——`build_slot.whitelist` 是准入，不是建议；
## 2. 非本方槽位——槽位带 `team_id`，别人的槽一律拒；
## 3. 余额不足——先验后扣，扣不动就整笔不发生；
## 4. 超 3 级升级——`BastionPrototypeCatalog.MAX_TOWER_LEVEL`（CD-22 §5.1）。
##
## 客户端提交的只有意图。伤害、金币、击杀与赏金全部在这里生效（宪法第二条），
## 表现层只播动画。
##
## 数值一个都不在本文件：伤害 / 射程 / 冷却 / 造价 / 返还比例全部读
## `BastionPlayStubs`（占位桩，CD-63 §1.3 仍延期）。
##
## 确定性来自两条固定顺序，不靠字典遍历：塔按 `slot_id` 升序开火，同一优先级下
## 的平局按 `unit_id` 升序。

const CatalogGd := preload("res://src/ugc/bastion_prototype_catalog.gd")
const GuardGd := preload("res://src/games/bastion/path_guard.gd")
const StubsGd := preload("res://src/games/bastion/play_stubs.gd")
const WavesGd := preload("res://src/games/bastion/match_session_waves.gd")

## 建成即 1 级；默认打最前面那只（CD-22 §5.1 的四种策略之一）。
const INITIAL_LEVEL: int = 1
const DEFAULT_PRIORITY: String = SharedTowerTargetPriorities.FRONT


static func try_build(
	session: BastionMatchSession, team_id: int, slot_id: int, prototype_id: int
) -> bool:
	if not _buildable_phase(session):
		return false
	var team: Dictionary = session._team(team_id)
	if team.is_empty():
		return false
	var slot: Dictionary = session.bundle.build_slot_at(slot_id)
	if slot.is_empty():
		return false
	var owner_id: int = slot["team_id"]
	if owner_id != team_id:
		return false
	var whitelist: Array = slot["whitelist"]
	if not whitelist.has(prototype_id):
		return false
	if not CatalogGd.is_tower(prototype_id):
		return false
	if not GuardGd.allows_tower(session.bundle, team_id, slot_id):
		return false
	if _tower_at(team, slot_id) >= 0:
		return false
	var cost: int = StubsGd.tower_build_cost(prototype_id)
	if cost < 1 or not _spend(team, cost):
		return false
	var towers: Array = team["towers"]
	towers.append({
		"slot_id": slot_id,
		"prototype_id": prototype_id,
		"level": INITIAL_LEVEL,
		"cooldown_left": 0,
		"target_priority": DEFAULT_PRIORITY,
		"x": slot["x"],
		"y": slot["y"],
		"z": slot["z"],
	})
	towers.sort_custom(_by_slot_id)
	return true


static func try_upgrade(session: BastionMatchSession, team_id: int, slot_id: int) -> bool:
	if not _buildable_phase(session):
		return false
	var team: Dictionary = session._team(team_id)
	var index: int = _tower_at(team, slot_id)
	if index < 0:
		return false
	var towers: Array = team["towers"]
	var tower: Dictionary = towers[index]
	var level: int = tower["level"]
	if level >= CatalogGd.MAX_TOWER_LEVEL:
		return false
	var prototype_id: int = tower["prototype_id"]
	var cost: int = StubsGd.tower_upgrade_cost(prototype_id, level)
	if cost < 1 or not _spend(team, cost):
		return false
	tower["level"] = level + 1
	return true


static func try_sell(session: BastionMatchSession, team_id: int, slot_id: int) -> bool:
	if not _buildable_phase(session):
		return false
	var team: Dictionary = session._team(team_id)
	var index: int = _tower_at(team, slot_id)
	if index < 0:
		return false
	var towers: Array = team["towers"]
	var tower: Dictionary = towers[index]
	var prototype_id: int = tower["prototype_id"]
	var level: int = tower["level"]
	var refund: int = StubsGd.tower_sell_refund(prototype_id, level)
	var gold: int = team["gold"]
	team["gold"] = gold + refund
	towers.remove_at(index)
	return true


static func try_set_priority(
	session: BastionMatchSession, team_id: int, slot_id: int, priority: String
) -> bool:
	if not _buildable_phase(session):
		return false
	if not SharedTowerTargetPriorities.contains(priority):
		return false
	var team: Dictionary = session._team(team_id)
	var index: int = _tower_at(team, slot_id)
	if index < 0:
		return false
	var towers: Array = team["towers"]
	var tower: Dictionary = towers[index]
	tower["target_priority"] = priority
	return true


## 每波开始：固定基础收入到账，赏金上限重新计数（CD-22 §6：避免滚雪球）。
static func open_wave(session: BastionMatchSession, team_id: int) -> void:
	var team: Dictionary = session._team(team_id)
	if team.is_empty():
		return
	var gold: int = team["gold"]
	team["gold"] = gold + session.bundle.economy_value("base_income")
	team["wave_bounty"] = 0


## 本队所有塔开火一次。塔只打自己防区的兵，不跨区（CD-22 §5.2）。
static func fire(session: BastionMatchSession, team_id: int) -> void:
	var team: Dictionary = session._team(team_id)
	if team.is_empty():
		return
	var towers: Array = team["towers"]
	if towers.is_empty():
		return
	var poses: Dictionary[int, Dictionary] = _unit_poses(session, team)
	for item: Variant in towers:
		var tower: Dictionary = item
		var cooldown: int = tower["cooldown_left"]
		if cooldown > 0:
			tower["cooldown_left"] = cooldown - 1
			continue
		var target_id: int = _pick_target(session, team, tower, poses)
		if target_id == 0:
			continue
		_strike(session, team, tower, target_id, poses)
		var prototype_id: int = tower["prototype_id"]
		tower["cooldown_left"] = StubsGd.tower_cooldown_ticks(prototype_id)
	_reap(session, team)


static func _strike(
	session: BastionMatchSession,
	team: Dictionary,
	tower: Dictionary,
	target_id: int,
	poses: Dictionary[int, Dictionary]
) -> void:
	var prototype_id: int = tower["prototype_id"]
	var level: int = tower["level"]
	var damage: int = StubsGd.tower_damage(prototype_id, level)
	var splash: int = StubsGd.tower_splash(prototype_id, session.bundle.cell)
	var frost: bool = prototype_id == CatalogGd.TOWER_FROST
	var center: Dictionary = poses[target_id]
	var units: Array = team["units"]
	for item: Variant in units:
		var unit: Dictionary = item
		var unit_id: int = unit["unit_id"]
		var hit: bool = unit_id == target_id
		if not hit and splash > 0:
			hit = _distance_squared(center, poses[unit_id]) <= splash * splash
		if not hit:
			continue
		var health: int = unit["health"]
		unit["health"] = health - damage
		if frost:
			unit["slow_ticks"] = StubsGd.TOWER_FROST_SLOW_TICKS


## 清点这一拍被打死的兵，发赏金（受每波上限约束），记击杀。
static func _reap(session: BastionMatchSession, team: Dictionary) -> void:
	var units: Array = team["units"]
	var survivors: Array = []
	var killed: int = 0
	for item: Variant in units:
		var unit: Dictionary = item
		var health: int = unit["health"]
		if health > 0:
			survivors.append(unit)
			continue
		killed += 1
		var bounty: int = unit["bounty"]
		_grant_bounty(session, team, bounty)
	if killed == 0:
		return
	team["units"] = survivors
	var kills: int = team["kills"]
	team["kills"] = kills + killed


## 每波赏金有上限：领先方多杀不会指数滚雪球（CD-22 §6）。超出的部分直接不发，
## 不是延后发——延后发等于上限没生效。
static func _grant_bounty(session: BastionMatchSession, team: Dictionary, bounty: int) -> void:
	var cap: int = session.bundle.economy_value("bounty_cap")
	var used: int = team.get("wave_bounty", 0)
	if used >= cap:
		return
	var payable: int = mini(bounty, cap - used)
	if payable < 1:
		return
	team["wave_bounty"] = used + payable
	var gold: int = team["gold"]
	team["gold"] = gold + payable


static func _pick_target(
	session: BastionMatchSession,
	team: Dictionary,
	tower: Dictionary,
	poses: Dictionary[int, Dictionary]
) -> int:
	var prototype_id: int = tower["prototype_id"]
	var reach: int = StubsGd.tower_range(prototype_id, session.bundle.cell)
	if reach < 1:
		return 0
	var limit: int = reach * reach
	var priority: String = tower["target_priority"]
	var units: Array = team["units"]
	var chosen: int = 0
	var best: int = 0
	for item: Variant in units:
		var unit: Dictionary = item
		var unit_id: int = unit["unit_id"]
		var distance: int = _distance_squared(tower, poses[unit_id])
		if distance > limit:
			continue
		var score: int = _score_of(unit, distance, priority)
		if chosen == 0 or score > best:
			chosen = unit_id
			best = score
	return chosen


## 四种策略折成同一个「越大越先打」的整数分。平局时**不**换目标，而列表本身按
## 生成顺序、`unit_id` 升序，所以平局永远落在小 id 身上。
static func _score_of(unit: Dictionary, distance: int, priority: String) -> int:
	var health: int = unit["health"]
	match priority:
		SharedTowerTargetPriorities.NEAREST:
			return -distance
		SharedTowerTargetPriorities.STRONGEST:
			return health
		SharedTowerTargetPriorities.WEAKEST:
			return -health
		_:
			# front：路上走得最远的那只。leg 优先，同 leg 比 progress。
			var leg: int = unit["leg"]
			if leg == WavesGd.LEG_AT_CORE:
				return 0x7FFFFFFF
			var progress: int = unit["progress"]
			return leg * 0x100000 + mini(progress, 0xFFFFF)


static func _unit_poses(
	session: BastionMatchSession, team: Dictionary
) -> Dictionary[int, Dictionary]:
	var poses: Dictionary[int, Dictionary] = {}
	var team_id: int = team["team_id"]
	for state: Dictionary in session.unit_states(team_id):
		var unit_id: int = state["unit_id"]
		poses[unit_id] = {"x": state["x"], "y": state["y"], "z": state["z"]}
	return poses


static func _distance_squared(left: Dictionary, right: Dictionary) -> int:
	var left_x: int = left["x"]
	var left_y: int = left["y"]
	var left_z: int = left["z"]
	var right_x: int = right["x"]
	var right_y: int = right["y"]
	var right_z: int = right["z"]
	var dx: int = left_x - right_x
	var dy: int = left_y - right_y
	var dz: int = left_z - right_z
	return dx * dx + dy * dy + dz * dz


## 先验后扣：余额不足时整笔不发生，不允许出现「扣了一半」的中间态。
static func _spend(team: Dictionary, cost: int) -> bool:
	var gold: int = team["gold"]
	if gold < cost:
		return false
	team["gold"] = gold - cost
	return true


static func _tower_at(team: Dictionary, slot_id: int) -> int:
	if team.is_empty():
		return -1
	var towers: Array = team["towers"]
	for index: int in range(towers.size()):
		var tower: Dictionary = towers[index]
		var current: int = tower["slot_id"]
		if current == slot_id:
			return index
	return -1


## 建造节奏：M6 用「全程可建」（CD-22 §6 白名单策略之一），所以准备阶段与
## 波次阶段都收。互设障碍阶段不收——那时战场版本还没锁定。
static func _buildable_phase(session: BastionMatchSession) -> bool:
	if session.phase == BastionMatchSession.PHASE_PREP:
		return true
	return session.phase == BastionMatchSession.PHASE_WAVES


static func _by_slot_id(left: Variant, right: Variant) -> bool:
	var a: Dictionary = left
	var b: Dictionary = right
	var left_id: int = a["slot_id"]
	var right_id: int = b["slot_id"]
	return left_id < right_id
