class_name BastionPrototypeCatalog
extends RefCounted

## M6 BASTION 原型白名单：三塔 / 三兵 / 三障碍，外加炮塔升级上限 3。
##
## 人类 2026-09-15 拍板的是「**M6 用哪九个**」，不是 CD-22 的完整清单
## （[CD-91 D.4](Confirmed-docs/90-reference/91-decision-log.md) 键
## `bastion_minimum_set_m6`）。[CD-22 §4.2 / §5.1 / §5.2](Confirmed-docs/20-gameplay/22-bastion.md)
## 三张示例表原文就写着「不是锁定清单」，[CD-63 §1.2](Confirmed-docs/60-plan/63-open-decisions.md)
## 的正式清单与 §1.3 的具体数值仍延期。
##
## 所以本文件的存在理由是**把「九个之外一律拒绝」变成编译期硬失败**：没有它，
## 下一个 Agent 会从 CD-22 的示例表里顺手把电弧塔 / 护盾兵 / 视野雾区补全，而
## 那正是宪法第五节禁止的「把示例当已确认答案」。`test_bastion_blueprint_contract.gd`
## 的金标断言把这九个 id 钉住；要加第十个必须先有人类拍板。
##
## **本文件只锁 id 与类别，不锁任何数值。** 伤害 / 射程 / 冷却 / 血量 / 速度 /
## 赏金全部是占位桩，落 `game/src/games/bastion/play_stubs.gd` 一处
## （`.cursor/rules/course-correction-freeze.mdc` §2）。分两处不是有人抄错了：
## 白名单是 UGC 发布门禁（L2，本文件），动作数值是玩法桩（L3，那一份）。
##
## 与 `SharedGameplayAssetCatalog` 的 `asset_id` **不是同一个编号空间**：那份表
## 管权威碰撞几何（ADR-0006），这份表管「哪些玩法原型允许出现在蓝图里」。

## 三种炮塔（CD-22 §5.1 取三个）：单体 / 范围 / 减速。
const TOWER_ARROW: int = 1
const TOWER_CANNON: int = 2
const TOWER_FROST: int = 3

## 三种进攻单位（CD-22 §5.2 取三个）：快速 / 重装 / 集群。
const UNIT_SWIFT: int = 11
const UNIT_HEAVY: int = 12
const UNIT_SWARM: int = 13

## 三种障碍（CD-22 §4.2 取三个）：路障 / 减速地块 / 分流门。
## 「三种障碍」是 2026-09-15 这次拍板新增的口径，CD-61 §4.2 原文只要求
## 「双方各 3 个障碍**槽**」。别把它读成夹具本来的要求。
const OBSTACLE_BARRICADE: int = 21
const OBSTACLE_SLOW_TILE: int = 22
const OBSTACLE_DIVERTER: int = 23

const KIND_TOWER: String = "tower"
const KIND_UNIT: String = "unit"
const KIND_OBSTACLE: String = "obstacle"

## 升级树一期最多 3 级（CD-22 §5.1）。这是产品口径，不是占位桩。
const MAX_TOWER_LEVEL: int = 3

## 原型 id → 类别。新增一行等于扩大 M6 范围，必须先有人类拍板。
const KINDS: Dictionary[int, String] = {
	TOWER_ARROW: KIND_TOWER,
	TOWER_CANNON: KIND_TOWER,
	TOWER_FROST: KIND_TOWER,
	UNIT_SWIFT: KIND_UNIT,
	UNIT_HEAVY: KIND_UNIT,
	UNIT_SWARM: KIND_UNIT,
	OBSTACLE_BARRICADE: KIND_OBSTACLE,
	OBSTACLE_SLOW_TILE: KIND_OBSTACLE,
	OBSTACLE_DIVERTER: KIND_OBSTACLE,
}

## 升序 id，给需要稳定顺序的校验与测试用（字典遍历顺序不是契约）。
const TOWER_IDS: PackedInt32Array = [TOWER_ARROW, TOWER_CANNON, TOWER_FROST]
const UNIT_IDS: PackedInt32Array = [UNIT_SWIFT, UNIT_HEAVY, UNIT_SWARM]
const OBSTACLE_IDS: PackedInt32Array = [
	OBSTACLE_BARRICADE,
	OBSTACLE_SLOW_TILE,
	OBSTACLE_DIVERTER,
]


static func has_prototype(prototype_id: int) -> bool:
	return KINDS.has(prototype_id)


## 未登记原型返回空串；调用方不得把空串当成某一类。
static func kind_of(prototype_id: int) -> String:
	if not KINDS.has(prototype_id):
		return ""
	return KINDS[prototype_id]


static func is_tower(prototype_id: int) -> bool:
	return kind_of(prototype_id) == KIND_TOWER


static func is_unit(prototype_id: int) -> bool:
	return kind_of(prototype_id) == KIND_UNIT


static func is_obstacle(prototype_id: int) -> bool:
	return kind_of(prototype_id) == KIND_OBSTACLE


## 炮塔等级准入。1 级是建成态，3 级封顶（CD-22 §5.1）。
static func level_is_valid(level: int) -> bool:
	return level >= 1 and level <= MAX_TOWER_LEVEL


## 白名单数组准入：非空、严格升序（顺带排掉重复）、每一项都属于 `kind`。
## 严格升序是 wire 规范化要求，与 `SimulationBundle.assets` 同一条理由：
## 同一份内容只有一种字节形状，哈希才稳定。
static func whitelist_is_valid(whitelist: PackedInt32Array, kind: String) -> bool:
	if whitelist.is_empty():
		return false
	var previous: int = 0
	for prototype_id: int in whitelist:
		if prototype_id <= previous:
			return false
		previous = prototype_id
		if kind_of(prototype_id) != kind:
			return false
	return true
