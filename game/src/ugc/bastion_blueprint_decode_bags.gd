class_name BastionBlueprintDecodeBags
extends RefCounted

## `BastionBlueprintDecode` 的袋解析与通用形状断言。拆出来只为让两个文件都
## 低于 E9 400 行；公开入口仍在 `BastionBlueprintBundle.from_dictionary`。
##
## 这里**没有**复用 `SimulationBundleDecode` 的任何一行，连 `coerce_json_ints`
## 都是自己一份。理由写在 M6 章节计划 §3.2：两个玩法一旦共用一条解码路径，
## 改哪边都要回头重读另一边，而 TRAPRUSH 那条路径上挂着已发布内容的 ContentHash。
## 二十行重复换一条不会互相牵动的边界，值。

const PrototypesGd := preload("res://src/ugc/bastion_prototype_catalog.gd")

const CORE_KEYS: PackedStringArray = ["entity_id", "team_id", "node_id", "max_health"]
const SPAWN_KEYS: PackedStringArray = ["entity_id", "team_id", "node_id"]
const BUILD_SLOT_KEYS: PackedStringArray = [
	"entity_id", "team_id", "x", "y", "z", "whitelist"
]
const OBSTACLE_SLOT_KEYS: PackedStringArray = [
	"entity_id", "team_id", "node_id", "whitelist"
]
const WAYPOINT_KEYS: PackedStringArray = ["node_id", "team_id", "x", "y", "z"]
const EDGE_KEYS: PackedStringArray = ["from_id", "to_id", "cost"]
const WAVE_KEYS: PackedStringArray = ["index", "prototype_id", "count", "interval_ticks"]

## 八个经济标量各自的下界。上界不设：那是内容预算（宪法第十七条），归
## `tools/content-validator`，不归 wire 形状。
const ECONOMY_MINIMUMS: Dictionary[String, int] = {
	"initial_gold": 0,
	"base_income": 0,
	"bounty_cap": 0,
	"time_limit_ticks": 1,
	"setup_ticks": 1,
	"prep_ticks": 1,
	"wave_interval_ticks": 1,
	"obstacle_points": 1,
}


## JSON 的整数常常先落成 float。能无损回到 int 的才转；1.5 保持 float，随后被
## 类型断言拒掉。NodePath / Object 一类原样返回，同样会被类型断言拒掉。
static func coerce_json_ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			var number: float = value
			if not is_finite(number):
				return value
			var as_int: int = int(number)
			if float(as_int) != number:
				return value
			return as_int
		TYPE_ARRAY:
			var items: Array = value
			var next_items: Array = []
			for item: Variant in items:
				next_items.append(coerce_json_ints(item))
			return next_items
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var next_body: Dictionary = {}
			for key: Variant in source:
				next_body[key] = coerce_json_ints(source[key])
			return next_body
		_:
			return value


static func exact_keys(body: Dictionary, keys: PackedStringArray) -> bool:
	if body.size() != keys.size():
		return false
	for key: String in keys:
		if not body.has(key):
			return false
	return true


static func int_at_least(body: Dictionary, key: String, minimum: int) -> bool:
	if not body.has(key) or typeof(body[key]) != TYPE_INT:
		return false
	var number: int = body[key]
	return number >= minimum


static func read_int(body: Dictionary, key: String) -> int:
	var value: int = body[key]
	return value


static func on_lattice(body: Dictionary, cell: int) -> bool:
	for axis: String in ["x", "y", "z"]:
		if not body.has(axis) or typeof(body[axis]) != TYPE_INT:
			return false
		var value: int = body[axis]
		if value % cell != 0:
			return false
	return true


## 白名单：整数数组 → `PackedInt32Array`，再交给目录判严格升序与类别。
static func parse_whitelist(value: Variant, kind: String) -> PackedInt32Array:
	var empty: PackedInt32Array = PackedInt32Array()
	if typeof(value) != TYPE_ARRAY:
		return empty
	var items: Array = value
	var parsed: PackedInt32Array = PackedInt32Array()
	for item: Variant in items:
		if typeof(item) != TYPE_INT:
			return empty
		var prototype_id: int = item
		parsed.append(prototype_id)
	if not PrototypesGd.whitelist_is_valid(parsed, kind):
		return empty
	return parsed


static func parse_waypoint(bag: Dictionary, cell: int, teams: PackedInt32Array) -> Dictionary:
	if not exact_keys(bag, WAYPOINT_KEYS):
		return {}
	if not int_at_least(bag, "node_id", 1):
		return {}
	if not _team_is_known(bag, teams):
		return {}
	if not on_lattice(bag, cell):
		return {}
	return bag.duplicate(true)


static func parse_edge(bag: Dictionary) -> Dictionary:
	if not exact_keys(bag, EDGE_KEYS):
		return {}
	if not int_at_least(bag, "from_id", 1):
		return {}
	if not int_at_least(bag, "to_id", 1):
		return {}
	if not int_at_least(bag, "cost", 1):
		return {}
	if read_int(bag, "from_id") == read_int(bag, "to_id"):
		return {}
	return bag.duplicate(true)


static func parse_core(bag: Dictionary, teams: PackedInt32Array) -> Dictionary:
	if not exact_keys(bag, CORE_KEYS):
		return {}
	if not int_at_least(bag, "entity_id", 1):
		return {}
	if not _team_is_known(bag, teams):
		return {}
	if not int_at_least(bag, "node_id", 1):
		return {}
	if not int_at_least(bag, "max_health", 1):
		return {}
	return bag.duplicate(true)


static func parse_spawn(bag: Dictionary, teams: PackedInt32Array) -> Dictionary:
	if not exact_keys(bag, SPAWN_KEYS):
		return {}
	if not int_at_least(bag, "entity_id", 1):
		return {}
	if not _team_is_known(bag, teams):
		return {}
	if not int_at_least(bag, "node_id", 1):
		return {}
	return bag.duplicate(true)


static func parse_build_slot(bag: Dictionary, cell: int, teams: PackedInt32Array) -> Dictionary:
	if not exact_keys(bag, BUILD_SLOT_KEYS):
		return {}
	if not int_at_least(bag, "entity_id", 1):
		return {}
	if not _team_is_known(bag, teams):
		return {}
	if not on_lattice(bag, cell):
		return {}
	var whitelist: PackedInt32Array = parse_whitelist(
		bag["whitelist"], PrototypesGd.KIND_TOWER
	)
	if whitelist.is_empty():
		return {}
	return bag.duplicate(true)


static func parse_obstacle_slot(bag: Dictionary, teams: PackedInt32Array) -> Dictionary:
	if not exact_keys(bag, OBSTACLE_SLOT_KEYS):
		return {}
	if not int_at_least(bag, "entity_id", 1):
		return {}
	if not _team_is_known(bag, teams):
		return {}
	if not int_at_least(bag, "node_id", 1):
		return {}
	var whitelist: PackedInt32Array = parse_whitelist(
		bag["whitelist"], PrototypesGd.KIND_OBSTACLE
	)
	if whitelist.is_empty():
		return {}
	return bag.duplicate(true)


## 波次：`index` 由调用方按位置核对连续性，这里只查形状与原型类别。
static func parse_wave(bag: Dictionary) -> Dictionary:
	if not exact_keys(bag, WAVE_KEYS):
		return {}
	if not int_at_least(bag, "index", 1):
		return {}
	if not int_at_least(bag, "prototype_id", 1):
		return {}
	if not int_at_least(bag, "count", 1):
		return {}
	if not int_at_least(bag, "interval_ticks", 0):
		return {}
	if not PrototypesGd.is_unit(read_int(bag, "prototype_id")):
		return {}
	return bag.duplicate(true)


static func parse_economy(value: Variant, keys: PackedStringArray) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = value
	if not exact_keys(body, keys):
		return {}
	for key: String in keys:
		if not ECONOMY_MINIMUMS.has(key):
			return {}
		var minimum: int = ECONOMY_MINIMUMS[key]
		if not int_at_least(body, key, minimum):
			return {}
	return body.duplicate(true)


static func _team_is_known(bag: Dictionary, teams: PackedInt32Array) -> bool:
	if not bag.has("team_id") or typeof(bag["team_id"]) != TYPE_INT:
		return false
	var team_id: int = bag["team_id"]
	return teams.has(team_id)
