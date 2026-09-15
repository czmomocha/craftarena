class_name BastionBlueprintBundle
extends RefCounted

## BASTION 战场蓝图的编译产物。**独立新类型**，与 `SimulationBundle` 无继承、
## 无共享 wire、无共享解码路径（人类 2026-09-15 拍板，[CD-91 D.4](Confirmed-docs/90-reference/91-decision-log.md)
## 键 `bastion_blueprint_bundle`）。
##
## 为什么不塞进 `SimulationBundle` 的 22 个袋：`ContentHash` 覆盖那份
## `to_dictionary()`，动它就牵动**已发布内容与旧回放**的哈希（宪法第六条）。
## 本文件落地后，`SimulationBundle` 的解码与 `to_dictionary()` 逐字节不变，
## `test_bastion_blueprint_contract.gd` 有金标断言守着这件事。
##
## 蓝图的**输入**仍然是一份普通 `AuthoringDocument`，Component Schema v1
## 一个字节不改（本 wire 只是编译产物）。输入怎么映射见
## `BastionBlueprintCompiler` 文件头。
##
## 两处显式判别位，让「拿错 wire」在第一个字段就失败而不是在第十个：
## `schema_version` 与 `gameplay`。旧 TRAPRUSH bundle 没有 `gameplay` 键、
## 键数也不对，喂进来必被拒；反之亦然。
##
## 本 wire 里**没有任何塔 / 兵的数值**。蓝图只声明「哪些原型可用」和「战场长
## 什么样」；伤害 / 血量 / 速度 / 赏金是占位桩，落 `BastionPlayStubs` 一处
## （CD-63 §1.3 仍延期）。经济标量是创作者可编辑项（CD-22 §7.1），所以它们
## 在 wire 里。
##
## 未签名 wire。平台签名仍是 `ContentSign` sidecar。不是 Rule VM 图。

const DecodeGd := preload("res://src/ugc/bastion_blueprint_decode.gd")

const SCHEMA_VERSION: int = 1
## 显式玩法判别键的取值。解码第一步就比对它。
const GAMEPLAY_ID: String = "bastion"

## 1v1 只有两队。多队 / 2v2 属 M7，本 wire 不留扩展位——留了也没人验。
const TEAM_A: int = 1
const TEAM_B: int = 2
const TEAMS: PackedInt32Array = [TEAM_A, TEAM_B]

## `economy` 必须**恰好**是这八个键。少一个、多一个都整份拒绝。
const ECONOMY_KEYS: PackedStringArray = [
	"initial_gold",
	"base_income",
	"bounty_cap",
	"time_limit_ticks",
	"setup_ticks",
	"prep_ticks",
	"wave_interval_ticks",
	"obstacle_points",
]

const FIELD_SCHEMA_VERSION: String = "schema_version"
const FIELD_GAMEPLAY: String = "gameplay"
const FIELD_CELL: String = "cell"
const FIELD_SOURCE_REVISION: String = "source_revision"
const FIELD_CORES: String = "cores"
const FIELD_SPAWNS: String = "spawns"
const FIELD_BUILD_SLOTS: String = "build_slots"
const FIELD_OBSTACLE_SLOTS: String = "obstacle_slots"
const FIELD_WAYPOINTS: String = "waypoints"
const FIELD_EDGES: String = "edges"
const FIELD_WAVES: String = "waves"
const FIELD_ECONOMY: String = "economy"

var cell: int = 0
var source_revision: int = 0
## 每队一个核心：`entity_id` / `team_id` / `node_id` / `max_health`。
## 位置不在这里复制一份，由 `node_id` 指向 `waypoints`——一个坐标只有一个落点。
var cores: Array[Dictionary] = []
## 出兵点：`entity_id` / `team_id` / `node_id`。
var spawns: Array[Dictionary] = []
## 建造槽：`entity_id` / `team_id` / `x` / `y` / `z` / `whitelist`。
## 槽位不在兵线节点上，所以它带自己的坐标而不是 `node_id`。
var build_slots: Array[Dictionary] = []
## 障碍槽：`entity_id` / `team_id` / `node_id` / `whitelist`。必须压在本队兵线
## 节点上，否则放了也改不了寻路。
var obstacle_slots: Array[Dictionary] = []
## 兵线节点：`node_id` / `team_id` / `x` / `y` / `z`。按 `node_id` 严格升序。
var waypoints: Array[Dictionary] = []
## 有向边：`from_id` / `to_id` / `cost`。按 (`from_id`, `to_id`) 严格升序。
var edges: Array[Dictionary] = []
## 波次基础表：`index` / `prototype_id` / `count` / `interval_ticks`。
## 两队共用同一张表——镜像波次的公平性就靠「只有一张表」（CD-22 §5.2）。
var waves: Array[Dictionary] = []
var economy: Dictionary = {}


static func from_dictionary(data: Dictionary) -> BastionBlueprintBundle:
	return DecodeGd.from_dictionary(data)


func to_dictionary() -> Dictionary:
	return {
		FIELD_SCHEMA_VERSION: SCHEMA_VERSION,
		FIELD_GAMEPLAY: GAMEPLAY_ID,
		FIELD_CELL: cell,
		FIELD_SOURCE_REVISION: source_revision,
		FIELD_CORES: _copy_of(cores),
		FIELD_SPAWNS: _copy_of(spawns),
		FIELD_BUILD_SLOTS: _copy_of(build_slots),
		FIELD_OBSTACLE_SLOTS: _copy_of(obstacle_slots),
		FIELD_WAYPOINTS: _copy_of(waypoints),
		FIELD_EDGES: _copy_of(edges),
		FIELD_WAVES: _copy_of(waves),
		FIELD_ECONOMY: economy.duplicate(true),
	}


## 内容哈希用的规范摘要。走 `StateHasher.write_canonical`（键排序 + SHA-256），
## 不用 `Variant.hash()`——那个不保证版本间稳定。
func digest_hex() -> String:
	var hasher: StateHasher = StateHasher.new()
	if not hasher.write_canonical(to_dictionary()):
		return ""
	return hasher.digest_hex()


func core_of(team_id: int) -> Dictionary:
	for core: Dictionary in cores:
		var owner_id: int = core["team_id"]
		if owner_id == team_id:
			return core.duplicate(true)
	return {}


func core_node_id(team_id: int) -> int:
	var core: Dictionary = core_of(team_id)
	if core.is_empty():
		return 0
	var node_id: int = core["node_id"]
	return node_id


## 该节点的定义；未知 `node_id` 返回空字典。
func node_at(node_id: int) -> Dictionary:
	for node: Dictionary in waypoints:
		var current: int = node["node_id"]
		if current == node_id:
			return node.duplicate(true)
	return {}


func node_team(node_id: int) -> int:
	var node: Dictionary = node_at(node_id)
	if node.is_empty():
		return 0
	var team_id: int = node["team_id"]
	return team_id


## 从该节点出发的边，按 `to_id` 升序（`edges` 本身已按 (from, to) 升序）。
## 「编号最小的那条出边」就是这个数组的第 0 项，分流门掐的是它。
func edges_from(node_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for edge: Dictionary in edges:
		var from_id: int = edge["from_id"]
		if from_id == node_id:
			out.append(edge.duplicate(true))
	return out


func node_ids_of(team_id: int) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for node: Dictionary in waypoints:
		var owner_id: int = node["team_id"]
		if owner_id == team_id:
			var node_id: int = node["node_id"]
			ids.append(node_id)
	return ids


func spawn_node_ids(team_id: int) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for spawn: Dictionary in spawns:
		var owner_id: int = spawn["team_id"]
		if owner_id == team_id:
			var node_id: int = spawn["node_id"]
			ids.append(node_id)
	return ids


func obstacle_slot_node_ids(team_id: int) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for slot: Dictionary in obstacle_slots:
		var owner_id: int = slot["team_id"]
		if owner_id == team_id:
			var node_id: int = slot["node_id"]
			ids.append(node_id)
	return ids


func build_slot_ids(team_id: int) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for slot: Dictionary in build_slots:
		var owner_id: int = slot["team_id"]
		if owner_id == team_id:
			var entity_id: int = slot["entity_id"]
			ids.append(entity_id)
	return ids


func build_slot_at(entity_id: int) -> Dictionary:
	for slot: Dictionary in build_slots:
		var current: int = slot["entity_id"]
		if current == entity_id:
			return slot.duplicate(true)
	return {}


func obstacle_slot_at(entity_id: int) -> Dictionary:
	for slot: Dictionary in obstacle_slots:
		var current: int = slot["entity_id"]
		if current == entity_id:
			return slot.duplicate(true)
	return {}


## 经济标量。未知键返回 0；调用方不得把 0 当默认值——`economy` 的键集合是
## 恰好八个，解码已经保证过了。
func economy_value(key: String) -> int:
	if not economy.has(key):
		return 0
	var value: int = economy[key]
	return value


func total_wave_count() -> int:
	return waves.size()


func _copy_of(source: Array[Dictionary]) -> Array:
	var out: Array = []
	for item: Dictionary in source:
		out.append(item.duplicate(true))
	return out
