class_name BastionBlueprintCompilerBags
extends RefCounted

## 按 `zone.tags` 把 AuthoringWorld 的实体分类成 BASTION 的七种角色，并做**单
## 实体**层面的形状校验。跨实体的闭合（两侧预算、路线首尾、槽位落点）在
## `BastionBlueprintCompiler` 里。拆文件只为 E9 400 行。
##
## 一个实体最多带一个 BASTION 角色标签。带两个不按优先级猜，直接 `ambiguous_role`：
## 猜出来的那份蓝图能开局，但和作者想的不是同一张图。
##
## 问题码用 `Array[String]` 而不是 `PackedStringArray`：后者是值类型，跨函数
## 追加不保证写回调用方。

const CodesGd := preload("res://src/ugc/bastion_blueprint_codes.gd")
const PrototypesGd := preload("res://src/ugc/bastion_prototype_catalog.gd")
const BundleGd := preload("res://src/ugc/bastion_blueprint_bundle.gd")

const TAG_CORE: String = "bastion_core"
const TAG_SPAWN: String = "bastion_spawn"
const TAG_BUILD_SLOT: String = "bastion_build_slot"
const TAG_OBSTACLE_SLOT: String = "bastion_obstacle_slot"
const TAG_ROUTE: String = "bastion_route"
const TAG_WAVE: String = "bastion_wave"
const TAG_CONFIG: String = "bastion_config"

const ROLE_TAGS: PackedStringArray = [
	TAG_CORE,
	TAG_SPAWN,
	TAG_BUILD_SLOT,
	TAG_OBSTACLE_SLOT,
	TAG_ROUTE,
	TAG_WAVE,
	TAG_CONFIG,
]


## 该实体声明的 BASTION 角色。没有角色标签返回空串；带两个返回 `ambiguous_role`
## 让调用方直接记一条码。
static func role_of(components: Dictionary) -> String:
	if not components.has(SharedComponentNames.ZONE):
		return ""
	var zone: Dictionary = components[SharedComponentNames.ZONE]
	var tags: Array = zone["tags"]
	var found: String = ""
	for item: Variant in tags:
		var tag: String = item
		if not ROLE_TAGS.has(tag):
			continue
		if not found.is_empty():
			return CodesGd.AMBIGUOUS_ROLE
		found = tag
	return found


static func transform_of(components: Dictionary) -> Dictionary:
	if not components.has(SharedComponentNames.TRANSFORM):
		return {}
	var body: Dictionary = components[SharedComponentNames.TRANSFORM]
	return {"x": body["x"], "y": body["y"], "z": body["z"]}


## `team.team_id` 必须是 1 或 2。0（Schema 里的「空」）在 BASTION 不是合法归属。
static func team_of(components: Dictionary) -> int:
	if not components.has(SharedComponentNames.TEAM):
		return 0
	var body: Dictionary = components[SharedComponentNames.TEAM]
	var team_id: int = body["team_id"]
	if not BundleGd.TEAMS.has(team_id):
		return 0
	return team_id


## 核心：`transform` + `health` + `team`。
static func read_core(
	entity_id: int, components: Dictionary, codes: Array[String]
) -> Dictionary:
	var pose: Dictionary = transform_of(components)
	if pose.is_empty():
		push_code(codes, CodesGd.MISSING_TRANSFORM)
		return {}
	var team_id: int = team_of(components)
	if team_id == 0:
		push_code(codes, CodesGd.BAD_TEAM_ID)
		return {}
	if not components.has(SharedComponentNames.HEALTH):
		push_code(codes, CodesGd.MISSING_CORE)
		return {}
	var health: Dictionary = components[SharedComponentNames.HEALTH]
	var maximum: int = health["maximum"]
	return {"entity_id": entity_id, "team_id": team_id, "pose": pose, "max_health": maximum}


static func read_spawn(
	entity_id: int, components: Dictionary, codes: Array[String]
) -> Dictionary:
	var pose: Dictionary = transform_of(components)
	if pose.is_empty():
		push_code(codes, CodesGd.MISSING_TRANSFORM)
		return {}
	var team_id: int = team_of(components)
	if team_id == 0:
		push_code(codes, CodesGd.BAD_TEAM_ID)
		return {}
	return {"entity_id": entity_id, "team_id": team_id, "pose": pose}


## 建造槽与障碍槽共用 `build_slot`，靠标签区分该查哪一类白名单。
## `occupant_id` 必须是 0：蓝图里的槽位是空的，第一版塔系由准备阶段搭（CD-22 §6）。
static func read_slot(
	entity_id: int, components: Dictionary, kind: String, codes: Array[String]
) -> Dictionary:
	var pose: Dictionary = transform_of(components)
	if pose.is_empty():
		push_code(codes, CodesGd.MISSING_TRANSFORM)
		return {}
	var team_id: int = team_of(components)
	if team_id == 0:
		push_code(codes, CodesGd.BAD_TEAM_ID)
		return {}
	if not components.has(SharedComponentNames.BUILD_SLOT):
		push_code(codes, CodesGd.EMPTY_WHITELIST)
		return {}
	var slot: Dictionary = components[SharedComponentNames.BUILD_SLOT]
	var occupant_id: int = slot["occupant_id"]
	if occupant_id != 0:
		push_code(codes, CodesGd.SLOT_OCCUPIED_IN_BLUEPRINT)
		return {}
	var raw: Array = slot["whitelist"]
	if raw.is_empty():
		push_code(codes, CodesGd.EMPTY_WHITELIST)
		return {}
	var whitelist: PackedInt32Array = PackedInt32Array()
	for item: Variant in raw:
		var prototype_id: int = item
		whitelist.append(prototype_id)
	if not PrototypesGd.whitelist_is_valid(whitelist, kind):
		push_code(codes, CodesGd.UNKNOWN_PROTOTYPE)
		return {}
	return {
		"entity_id": entity_id,
		"team_id": team_id,
		"pose": pose,
		"whitelist": _as_array(whitelist),
	}


## 路线：`path_agent.waypoints` 是折线；`speed` / `bounty` 必须是 0。
## 单位数值是占位桩（`BastionPlayStubs`），不由蓝图作者填——否则同一个「快速兵」
## 在不同蓝图里是不同的东西，而 CD-63 §1.3 还没拍板它该是什么。
static func read_route(components: Dictionary, codes: Array[String]) -> Dictionary:
	var team_id: int = team_of(components)
	if team_id == 0:
		push_code(codes, CodesGd.BAD_TEAM_ID)
		return {}
	if not components.has(SharedComponentNames.PATH_AGENT):
		push_code(codes, CodesGd.MISSING_ROUTE)
		return {}
	var agent: Dictionary = components[SharedComponentNames.PATH_AGENT]
	var speed: int = agent["speed"]
	var bounty: int = agent["bounty"]
	if speed != 0 or bounty != 0:
		push_code(codes, CodesGd.AUTHORED_UNIT_NUMBERS)
		return {}
	var raw: Array = agent["waypoints"]
	if raw.size() < 2:
		push_code(codes, CodesGd.ROUTE_TOO_SHORT)
		return {}
	var points: Array = []
	for item: Variant in raw:
		var point: Dictionary = item
		points.append({"x": point["x"], "y": point["y"], "z": point["z"]})
	return {"team_id": team_id, "points": points}


## 波次：`spawner.prototype_id` 是单位原型，`max_alive` 是本波生成总数
## （M6 一波跑完才进下一波，所以「总数」与「同时存活上限」是同一个数），
## `interval_ticks` 是波内两只之间的间隔。波次顺序由 `entity_id` 升序决定。
static func read_wave(components: Dictionary, codes: Array[String]) -> Dictionary:
	if not components.has(SharedComponentNames.SPAWNER):
		push_code(codes, CodesGd.MISSING_WAVE)
		return {}
	var spawner: Dictionary = components[SharedComponentNames.SPAWNER]
	var prototype_id: int = spawner["prototype_id"]
	if not PrototypesGd.is_unit(prototype_id):
		push_code(codes, CodesGd.UNKNOWN_WAVE_PROTOTYPE)
		return {}
	var count: int = spawner["max_alive"]
	if count < 1:
		push_code(codes, CodesGd.BAD_WAVE_COUNT)
		return {}
	var interval_ticks: int = spawner["interval_ticks"]
	return {
		"prototype_id": prototype_id,
		"count": count,
		"interval_ticks": interval_ticks,
	}


## 经济：`score.tallies` 恰好那八个键。
##
## Component Schema v1 **没有**「对局配置」组件，而加一个是 Schema 破坏性变更
## （宪法第十八条，本号不做）。v1 里唯一契约是「字符串键 → 整数、不锁具体统计
## 项」的槽只有 `score.tallies`（CD-42 §1.2），所以经济标量落在它上面，并且实体
## 必须带 `bastion_config` 标签——带标签之后它永远不会被误读成结算统计。
## 将来真加了配置组件，改这一处即可。
static func read_config(components: Dictionary, codes: Array[String]) -> Dictionary:
	if not components.has(SharedComponentNames.SCORE):
		push_code(codes, CodesGd.BAD_CONFIG_KEYS)
		return {}
	var score: Dictionary = components[SharedComponentNames.SCORE]
	var tallies: Dictionary = score["tallies"]
	if tallies.size() != BundleGd.ECONOMY_KEYS.size():
		push_code(codes, CodesGd.BAD_CONFIG_KEYS)
		return {}
	var economy: Dictionary = {}
	for key: String in BundleGd.ECONOMY_KEYS:
		if not tallies.has(key):
			push_code(codes, CodesGd.BAD_CONFIG_KEYS)
			return {}
		var value: int = tallies[key]
		if value < 0:
			push_code(codes, CodesGd.BAD_CONFIG_VALUE)
			return {}
		economy[key] = value
	return economy


## 蓝图里出现 `tower` 一律拒。先判等级上限再判「不是蓝图内容」，这样
## `level = 4` 得到的是「超上限」而不是笼统的「不该在这里」——两条都得有反例：
## 上限那条是 CD-22 §5.1 的产品口径，后一条是 CD-22 §7.3 的层级口径。
static func check_tower(components: Dictionary, codes: Array[String]) -> void:
	if not components.has(SharedComponentNames.TOWER):
		return
	var tower: Dictionary = components[SharedComponentNames.TOWER]
	var level: int = tower["level"]
	if not PrototypesGd.level_is_valid(level):
		push_code(codes, CodesGd.TOWER_LEVEL_ABOVE_CAP)
		return
	push_code(codes, CodesGd.TOWER_NOT_BLUEPRINT_CONTENT)


static func push_code(codes: Array[String], code: String) -> void:
	if not codes.has(code):
		codes.append(code)


static func _as_array(values: PackedInt32Array) -> Array:
	var out: Array = []
	for value: int in values:
		out.append(value)
	return out
