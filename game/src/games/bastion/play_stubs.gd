class_name BastionPlayStubs
extends RefCounted

## BASTION 玩法占位数值的单一配置源，形状照 `TraprushPlayStubs`。
##
## 落点由 `.cursor/rules/course-correction-freeze.mdc` §2 指定：占位**色板与几何**
## 进 `PlaceholderSpec`，**玩法占位数值**进本文件。分两处不是有人抄错了，是语义
## 不同——色板是 D4 的美术规格，塔伤害 / 兵速度 / 金币是 [CD-63 §1.2 / §1.3](Confirmed-docs/60-plan/63-open-decisions.md)
## 仍延期的玩法桩。**一个数字只许有一个落点**，新增消费方从这里注入。
##
## 这里**没有一个数是产品数值**。2026-09-15 那次拍板只关闭了「M6 用哪九个」，
## 没有关闭数值（[CD-22 当前生效值](Confirmed-docs/20-gameplay/22-bastion.md)）。
## 谁要把某个数说成已定稿，先去拿人类拍板。
##
## 分四组：
##
## - **TOWER / UNIT / OBSTACLE**：九个原型各自的动作桩。id 的所有者是
##   `BastionPrototypeCatalog`（L2 白名单），本文件只给数字（L3）。
## - **SEARCH**：D2 确定性边图搜索的三项预算。搜索本体在 `simulation/`、
##   与玩法无关，预算由调用方注入，所以数字住在这里而不是那边。
## - **GRAYBOX_ECONOMY**：灰盒夹具蓝图用的那一组经济值。经济是**蓝图作者可编辑
##   的内容**（CD-22 §7.1），运行时以蓝图为准；这一份只是夹具的来源，由
##   `test_bastion_blueprint_contract.gd` 断言夹具与它逐字段相等，避免两处漂移。

const PrototypesGd := preload("res://src/ugc/bastion_prototype_catalog.gd")

# --- 炮塔（占位桩，不是产品塔表）-------------------------------------------

## 射程按格给，编译与裁决时乘 `cell`。写成格是因为它要和蓝图的格点布局对齐；
## 写成 Q48.16 常量会让「箭塔能打到隔壁两格」这件事看不出来。
const TOWER_ARROW_RANGE_CELLS: int = 3
const TOWER_CANNON_RANGE_CELLS: int = 2
const TOWER_FROST_RANGE_CELLS: int = 2

## 火炮塔的溅射半径（格）。冰霜塔不溅射，箭塔不溅射。
const TOWER_CANNON_SPLASH_CELLS: int = 1

## 冰霜塔减速：命中后若干 tick 内速度乘 `SLOW_NUMERATOR / SLOW_DENOMINATOR`。
## 不叠加、不延长——同一单位再次命中只刷新剩余 tick。
const TOWER_FROST_SLOW_NUMERATOR: int = 1
const TOWER_FROST_SLOW_DENOMINATOR: int = 2
const TOWER_FROST_SLOW_TICKS: int = 30

## 出售返还比例（分子 / 分母）。不是产品经济，只为让「建了又拆」有代价。
const SELL_REFUND_NUMERATOR: int = 3
const SELL_REFUND_DENOMINATOR: int = 5

## 每个塔：1 级建造价、每次升级价、1 级伤害、冷却 tick。
## 升级只加伤害，不加射程、不改冷却——M6 不做塔的分支树。
const TOWERS: Dictionary[int, Dictionary] = {
	PrototypesGd.TOWER_ARROW: {
		"build_cost": 50,
		"upgrade_cost": 40,
		"damage": 4,
		"cooldown_ticks": 6,
		"range_cells": TOWER_ARROW_RANGE_CELLS,
		"splash_cells": 0,
	},
	PrototypesGd.TOWER_CANNON: {
		"build_cost": 90,
		"upgrade_cost": 70,
		"damage": 9,
		"cooldown_ticks": 18,
		"range_cells": TOWER_CANNON_RANGE_CELLS,
		"splash_cells": TOWER_CANNON_SPLASH_CELLS,
	},
	PrototypesGd.TOWER_FROST: {
		"build_cost": 70,
		"upgrade_cost": 55,
		"damage": 1,
		"cooldown_ticks": 12,
		"range_cells": TOWER_FROST_RANGE_CELLS,
		"splash_cells": 0,
	},
}

# --- 进攻单位（占位桩，不是产品单位表）-------------------------------------

## `speed` 是每 tick 沿边推进的定点距离。`core_damage` 是漏一只扣多少核心血。
## `bounty` 是击杀赏金，受每波上限约束（CD-22 §6：避免领先方指数滚雪球）。
const UNITS: Dictionary[int, Dictionary] = {
	PrototypesGd.UNIT_SWIFT: {
		"max_health": 12,
		"speed": Fixed.SCALE / 8,
		"bounty": 6,
		"core_damage": 1,
	},
	PrototypesGd.UNIT_HEAVY: {
		"max_health": 40,
		"speed": Fixed.SCALE / 24,
		"bounty": 14,
		"core_damage": 3,
	},
	PrototypesGd.UNIT_SWARM: {
		"max_health": 6,
		"speed": Fixed.SCALE / 12,
		"bounty": 3,
		"core_damage": 1,
	},
}

# --- 障碍（占位桩，不是产品障碍表）-----------------------------------------

## `point_cost` 是互设障碍阶段花的点数（D5）。`edge_cost_delta` 是启用后加在
## 该节点每条出边上的整数边权；`blocks_node` 为真表示该节点直接不可通行。
## 分流门不加权也不封点：它掐掉该节点**编号最小**的那条出边，把兵挤到另一支
## （所以它要求节点至少有两条出边，否则蓝图编译不过）。
const OBSTACLES: Dictionary[int, Dictionary] = {
	PrototypesGd.OBSTACLE_BARRICADE: {
		"point_cost": 3,
		"edge_cost_delta": 0,
		"blocks_node": true,
		"cuts_first_edge": false,
	},
	PrototypesGd.OBSTACLE_SLOW_TILE: {
		"point_cost": 2,
		"edge_cost_delta": 2,
		"blocks_node": false,
		"cuts_first_edge": false,
	},
	PrototypesGd.OBSTACLE_DIVERTER: {
		"point_cost": 2,
		"edge_cost_delta": 0,
		"blocks_node": false,
		"cuts_first_edge": true,
	},
}

# --- 搜索预算（D2 注入 `simulation/` 的边图搜索）---------------------------

## 三项上限。超限**拒绝整次搜索**，不给一条错路——与 `MAX_SWEEP_STEPS` 超限
## 拒绝整段位移同一风格（宪法第十七条：预算是安全上限，不是尽力而为）。
const SEARCH_MAX_NODES: int = 512
const SEARCH_MAX_EDGES: int = 2048
const SEARCH_MAX_EXPANSIONS: int = 4096

# --- 灰盒夹具蓝图的经济值 ---------------------------------------------------

## 运行时以蓝图为准（经济是创作者可编辑项，CD-22 §7.1）。这一份是夹具的唯一
## 来源，被测试逐字段钉住，防止改了一处忘了另一处。
const GRAYBOX_ECONOMY: Dictionary[String, int] = {
	"initial_gold": 200,
	"base_income": 60,
	"bounty_cap": 120,
	"time_limit_ticks": 18000,
	"setup_ticks": 1800,
	"prep_ticks": 1200,
	"wave_interval_ticks": 900,
	"obstacle_points": 6,
}


## 该塔在该等级的伤害。升级只线性加伤害，是占位曲线不是产品成长表。
## 未登记原型或非法等级返回 0（0 不是合法伤害）。
static func tower_damage(prototype_id: int, level: int) -> int:
	if not PrototypesGd.level_is_valid(level):
		return 0
	if not TOWERS.has(prototype_id):
		return 0
	var body: Dictionary = TOWERS[prototype_id]
	var base: int = body["damage"]
	return base * level


## 建造价。未登记原型返回 0，调用方必须把 0 当「不可建」而不是「免费」。
static func tower_build_cost(prototype_id: int) -> int:
	if not TOWERS.has(prototype_id):
		return 0
	var body: Dictionary = TOWERS[prototype_id]
	var cost: int = body["build_cost"]
	return cost


## 从 `level` 升到 `level + 1` 的价钱。已封顶或非法等级返回 0。
static func tower_upgrade_cost(prototype_id: int, level: int) -> int:
	if not TOWERS.has(prototype_id):
		return 0
	if not PrototypesGd.level_is_valid(level):
		return 0
	if level >= PrototypesGd.MAX_TOWER_LEVEL:
		return 0
	var body: Dictionary = TOWERS[prototype_id]
	var cost: int = body["upgrade_cost"]
	return cost


## 出售返还：建造价 + 已付升级价，按 `SELL_REFUND_*` 取整（向下）。
static func tower_sell_refund(prototype_id: int, level: int) -> int:
	if not TOWERS.has(prototype_id):
		return 0
	if not PrototypesGd.level_is_valid(level):
		return 0
	var body: Dictionary = TOWERS[prototype_id]
	var build_cost: int = body["build_cost"]
	var upgrade_cost: int = body["upgrade_cost"]
	var paid: int = build_cost + upgrade_cost * (level - 1)
	return paid * SELL_REFUND_NUMERATOR / SELL_REFUND_DENOMINATOR


## 射程的定点距离（Q48.16），按世界 `cell` 换算。
static func tower_range(prototype_id: int, cell: int) -> int:
	if cell < 1:
		return 0
	if not TOWERS.has(prototype_id):
		return 0
	var body: Dictionary = TOWERS[prototype_id]
	var cells: int = body["range_cells"]
	return cells * cell


static func tower_cooldown_ticks(prototype_id: int) -> int:
	if not TOWERS.has(prototype_id):
		return 0
	var body: Dictionary = TOWERS[prototype_id]
	var ticks: int = body["cooldown_ticks"]
	return ticks


static func tower_splash(prototype_id: int, cell: int) -> int:
	if cell < 1:
		return 0
	if not TOWERS.has(prototype_id):
		return 0
	var body: Dictionary = TOWERS[prototype_id]
	var cells: int = body["splash_cells"]
	return cells * cell


## 单位字段读取。未登记原型返回 0；`unit_max_health` 的 0 必须当「不可生成」。
static func unit_field(prototype_id: int, key: String) -> int:
	if not UNITS.has(prototype_id):
		return 0
	var body: Dictionary = UNITS[prototype_id]
	if not body.has(key):
		return 0
	var value: int = body[key]
	return value


static func unit_max_health(prototype_id: int) -> int:
	return unit_field(prototype_id, "max_health")


static func unit_speed(prototype_id: int) -> int:
	return unit_field(prototype_id, "speed")


static func unit_bounty(prototype_id: int) -> int:
	return unit_field(prototype_id, "bounty")


static func unit_core_damage(prototype_id: int) -> int:
	return unit_field(prototype_id, "core_damage")


## 障碍字段读取。未登记原型返回 0 / false。
static func obstacle_point_cost(prototype_id: int) -> int:
	if not OBSTACLES.has(prototype_id):
		return 0
	var body: Dictionary = OBSTACLES[prototype_id]
	var cost: int = body["point_cost"]
	return cost


static func obstacle_edge_cost_delta(prototype_id: int) -> int:
	if not OBSTACLES.has(prototype_id):
		return 0
	var body: Dictionary = OBSTACLES[prototype_id]
	var delta: int = body["edge_cost_delta"]
	return delta


static func obstacle_blocks_node(prototype_id: int) -> bool:
	if not OBSTACLES.has(prototype_id):
		return false
	var body: Dictionary = OBSTACLES[prototype_id]
	var blocks: bool = body["blocks_node"]
	return blocks


static func obstacle_cuts_first_edge(prototype_id: int) -> bool:
	if not OBSTACLES.has(prototype_id):
		return false
	var body: Dictionary = OBSTACLES[prototype_id]
	var cuts: bool = body["cuts_first_edge"]
	return cuts
