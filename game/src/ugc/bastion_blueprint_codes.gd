class_name BastionBlueprintCodes
extends RefCounted

## 蓝图编译问题码。形状照 `AuthoringReachabilityCodes`：只是稳定标识符，
## 不是面向玩家的文案，也不承诺顺序。
##
## 为什么编译器返回码而不是只返回 `null`（`TraprushTopologyCompiler` 那样）：
## 一张 BASTION 蓝图有十几条互相独立的拒绝理由，只给 `null` 的话，正反例测试
## 只能证明「拒了」，证明不了「按哪条拒的」。宪法第二十条要的是可解释，不是
## 布尔值。D2 往本文件追加可达性码，用同一份清单。

# --- 全局配置 ---------------------------------------------------------------

## 缺少 / 出现多于一个 `bastion_config` 实体。
const MISSING_CONFIG: String = "missing_config"
const DUPLICATE_CONFIG: String = "duplicate_config"
## `score.tallies` 的键集合不是恰好那八个，或某个值越界。
const BAD_CONFIG_KEYS: String = "bad_config_keys"
const BAD_CONFIG_VALUE: String = "bad_config_value"

# --- 核心与队伍 -------------------------------------------------------------

## 不是恰好两个核心、或两个核心属于同一队。
const MISSING_CORE: String = "missing_core"
const DUPLICATE_CORE: String = "duplicate_core"
## 两侧核心最大生命不等（CD-22 §2 公平约束）。
const CORE_HEALTH_MISMATCH: String = "core_health_mismatch"
## `team.team_id` 不是 1 或 2。1v1 只有两队；UGC 多队属 M7。
const BAD_TEAM_ID: String = "bad_team_id"
## 实体缺 `transform`，无法落到战场上。
const MISSING_TRANSFORM: String = "missing_transform"
## 同一个实体带了两个以上 BASTION 角色标签。不按优先级猜，整份拒绝。
const AMBIGUOUS_ROLE: String = "ambiguous_role"

# --- 槽位 -------------------------------------------------------------------

const MISSING_BUILD_SLOT: String = "missing_build_slot"
const MISSING_OBSTACLE_SLOT: String = "missing_obstacle_slot"
## 两侧槽位数不等。
const SLOT_BUDGET_MISMATCH: String = "slot_budget_mismatch"
## 建造槽压在兵线节点上（塔不能站在路上）。
const BUILD_SLOT_ON_LANE: String = "build_slot_on_lane"
## 障碍槽没压在本队兵线节点上（放了也影响不了寻路）。
const OBSTACLE_SLOT_OFF_LANE: String = "obstacle_slot_off_lane"
## 白名单为空，或含未登记 / 类别不符的原型 id，或不是严格升序。
const EMPTY_WHITELIST: String = "empty_whitelist"
const UNKNOWN_PROTOTYPE: String = "unknown_prototype"
## 蓝图里的槽位必须是空的：第一版塔系由准备阶段的初始金币搭（CD-22 §6）。
const SLOT_OCCUPIED_IN_BLUEPRINT: String = "slot_occupied_in_blueprint"

# --- 炮塔 -------------------------------------------------------------------

## `tower.level` 超过 `BastionPrototypeCatalog.MAX_TOWER_LEVEL`（CD-22 §5.1 的 3 级）。
const TOWER_LEVEL_ABOVE_CAP: String = "tower_level_above_cap"
## 即便等级合法，塔也不是蓝图内容：建塔是玩法命令，不是内容热更新（CD-22 §7.3）。
const TOWER_NOT_BLUEPRINT_CONTENT: String = "tower_not_blueprint_content"

# --- 兵线 -------------------------------------------------------------------

const MISSING_ROUTE: String = "missing_route"
const MISSING_SPAWN: String = "missing_spawn"
## 出兵点存在但没有任何路线用它。
const SPAWN_UNUSED: String = "spawn_unused"
## 路线少于两个 waypoint。
const ROUTE_TOO_SHORT: String = "route_too_short"
## 相邻 waypoint 不是同一楼层上沿单轴的正距离位移——这条边接不到任何东西。
const DANGLING_EDGE: String = "dangling_edge"
## 路线首点不在本队出兵点、或末点不在本队核心。
const ROUTE_NOT_AT_SPAWN: String = "route_not_at_spawn"
const ROUTE_NOT_AT_CORE: String = "route_not_at_core"
## 路线实体的 `path_agent.speed` / `bounty` 必须为 0：单位数值是占位桩，落
## `BastionPlayStubs` 一处，不由蓝图作者填（CD-63 §1.3 仍延期）。
const AUTHORED_UNIT_NUMBERS: String = "authored_unit_numbers"
## 分流门槽位所在节点只有一条出边，掐掉就是封路。
const DIVERTER_WITHOUT_BRANCH: String = "diverter_without_branch"

# --- 波次 -------------------------------------------------------------------

const MISSING_WAVE: String = "missing_wave"
## `spawner.prototype_id` 不是登记在册的单位原型。
const UNKNOWN_WAVE_PROTOTYPE: String = "unknown_wave_prototype"
## `spawner.max_alive`（本波生成总数）小于 1。
const BAD_WAVE_COUNT: String = "bad_wave_count"

# --- 可达性（D2 填充；本刀只占位不产出）------------------------------------

## 出兵点到核心在初始拓扑下就不可达。
const LANE_UNREACHABLE: String = "lane_unreachable"
## 搜索预算耗尽。拒绝整次搜索，不给一条错路。
const SEARCH_BUDGET_EXHAUSTED: String = "search_budget_exhausted"
## 边权累加溢出（不饱和、不回绕；宪法第五条 / CD-42 §1.1）。
const EDGE_COST_OVERFLOW: String = "edge_cost_overflow"

const ALL: PackedStringArray = [
	MISSING_CONFIG,
	DUPLICATE_CONFIG,
	BAD_CONFIG_KEYS,
	BAD_CONFIG_VALUE,
	MISSING_CORE,
	DUPLICATE_CORE,
	CORE_HEALTH_MISMATCH,
	BAD_TEAM_ID,
	MISSING_TRANSFORM,
	AMBIGUOUS_ROLE,
	MISSING_BUILD_SLOT,
	MISSING_OBSTACLE_SLOT,
	SLOT_BUDGET_MISMATCH,
	BUILD_SLOT_ON_LANE,
	OBSTACLE_SLOT_OFF_LANE,
	EMPTY_WHITELIST,
	UNKNOWN_PROTOTYPE,
	SLOT_OCCUPIED_IN_BLUEPRINT,
	TOWER_LEVEL_ABOVE_CAP,
	TOWER_NOT_BLUEPRINT_CONTENT,
	MISSING_ROUTE,
	MISSING_SPAWN,
	SPAWN_UNUSED,
	ROUTE_TOO_SHORT,
	DANGLING_EDGE,
	ROUTE_NOT_AT_SPAWN,
	ROUTE_NOT_AT_CORE,
	AUTHORED_UNIT_NUMBERS,
	DIVERTER_WITHOUT_BRANCH,
	MISSING_WAVE,
	UNKNOWN_WAVE_PROTOTYPE,
	BAD_WAVE_COUNT,
	LANE_UNREACHABLE,
	SEARCH_BUDGET_EXHAUSTED,
	EDGE_COST_OVERFLOW,
]


static func contains(code: String) -> bool:
	return ALL.has(code)
