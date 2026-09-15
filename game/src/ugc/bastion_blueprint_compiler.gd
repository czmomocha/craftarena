class_name BastionBlueprintCompiler
extends RefCounted

## AuthoringWorld → `BastionBlueprintBundle`。整张战场的全量编译，不是增量子图。
##
## **输入是一份普通 `AuthoringDocument`，Component Schema v1 一个字节不改**
## （2026-09-15 拍板，[CD-91 D.4](Confirmed-docs/90-reference/91-decision-log.md)）。
## 角色靠 `zone.tags` 声明，字段借 v1 已有的组件：
##
## | 标签 | 需要的组件 | 说明 |
## |---|---|---|
## | `bastion_core` | `transform` + `health` + `team` | 每队一个，两侧 `maximum` 必须相等 |
## | `bastion_spawn` | `transform` + `team` | 出兵点 |
## | `bastion_build_slot` | `transform` + `team` + `build_slot` | 白名单是塔原型；不得压在兵线格上 |
## | `bastion_obstacle_slot` | `transform` + `team` + `build_slot` | 白名单是障碍原型；必须压在本队兵线格上 |
## | `bastion_route` | `team` + `path_agent` | 折线分支；`speed` / `bounty` 必须为 0 |
## | `bastion_wave` | `spawner` | 顺序 = `entity_id` 升序 |
## | `bastion_config` | `score` | 八个经济标量（理由见 `BastionBlueprintCompilerBags.read_config`） |
##
## 没带任何 BASTION 标签的实体被**忽略**，不报错：蓝图里允许有纯装饰或纯几何的
## 实体。唯一例外是 `tower` 组件——它在哪个实体上都要拒（CD-22 §7.3：建塔是玩法
## 命令，不是内容）。
##
## 失败时 `compile()` 返回 `null`，`problems()` 给出升序去重的问题码。给码不是
## 为了好看：一张蓝图有十几条互相独立的拒绝理由，只给 `null` 的话正反例测试只能
## 证明「拒了」，证明不了「按哪条拒的」（宪法第二十条）。
##
## 本编译器**不查可达性**。「不得完全封路」是 D2 的守卫，它吃的是本文件产出的
## 边图。这里只保证图本身闭合。

const BagsGd := preload("res://src/ugc/bastion_blueprint_compiler_bags.gd")
const CodesGd := preload("res://src/ugc/bastion_blueprint_codes.gd")
const GraphGd := preload("res://src/ugc/bastion_blueprint_compiler_graph.gd")
const PrototypesGd := preload("res://src/ugc/bastion_prototype_catalog.gd")


static func compile(world: AuthoringWorld) -> BastionBlueprintBundle:
	var assembled: Dictionary = _assemble(world)
	var codes: Array[String] = assembled["codes"]
	if not codes.is_empty():
		return null
	var body: Dictionary = assembled["body"]
	if body.is_empty():
		return null
	return BastionBlueprintBundle.from_dictionary(body)


## 升序去重的问题码。空数组 = 可编译。
static func problems(world: AuthoringWorld) -> PackedStringArray:
	var assembled: Dictionary = _assemble(world)
	var codes: Array[String] = assembled["codes"]
	codes.sort()
	var out: PackedStringArray = PackedStringArray()
	for code: String in codes:
		out.append(code)
	return out


static func _assemble(world: AuthoringWorld) -> Dictionary:
	var codes: Array[String] = []
	if world == null or world.grid == null:
		BagsGd.push_code(codes, CodesGd.MISSING_CONFIG)
		return {"codes": codes, "body": {}}
	var cell: int = world.grid.cell
	var gathered: Dictionary = _gather(world, codes)
	var cores: Array[Dictionary] = gathered["cores"]
	var spawns: Array[Dictionary] = gathered["spawns"]
	var build_slots: Array[Dictionary] = gathered["build_slots"]
	var obstacle_slots: Array[Dictionary] = gathered["obstacle_slots"]
	var routes: Array[Dictionary] = gathered["routes"]
	var waves: Array[Dictionary] = gathered["waves"]
	var economy: Dictionary = gathered["economy"]
	_check_cores(cores, codes)
	_check_balance(spawns, codes, CodesGd.MISSING_SPAWN)
	_check_balance(build_slots, codes, CodesGd.MISSING_BUILD_SLOT)
	_check_balance(obstacle_slots, codes, CodesGd.MISSING_OBSTACLE_SLOT)
	_check_route_presence(routes, codes)
	if waves.is_empty():
		BagsGd.push_code(codes, CodesGd.MISSING_WAVE)
	var graph: Dictionary = GraphGd.build(routes, cell)
	var graph_codes: Array[String] = graph["codes"]
	for code: String in graph_codes:
		BagsGd.push_code(codes, code)
	var nodes: Array[Dictionary] = graph["nodes"]
	var index: Dictionary[String, int] = graph["index"]
	_check_routes(routes, cores, spawns, codes)
	_check_slots(build_slots, obstacle_slots, nodes, index, codes)
	if not codes.is_empty():
		return {"codes": codes, "body": {}}
	var edges: Array[Dictionary] = GraphGd.edges_from_routes(routes, index, cell)
	if edges.is_empty():
		BagsGd.push_code(codes, CodesGd.DANGLING_EDGE)
		return {"codes": codes, "body": {}}
	var body: Dictionary = {
		BastionBlueprintBundle.FIELD_SCHEMA_VERSION: BastionBlueprintBundle.SCHEMA_VERSION,
		BastionBlueprintBundle.FIELD_GAMEPLAY: BastionBlueprintBundle.GAMEPLAY_ID,
		BastionBlueprintBundle.FIELD_CELL: cell,
		BastionBlueprintBundle.FIELD_SOURCE_REVISION: world.revision,
		BastionBlueprintBundle.FIELD_CORES: _core_bags(cores, index),
		BastionBlueprintBundle.FIELD_SPAWNS: _spawn_bags(spawns, index),
		BastionBlueprintBundle.FIELD_BUILD_SLOTS: _build_slot_bags(build_slots),
		BastionBlueprintBundle.FIELD_OBSTACLE_SLOTS: _obstacle_slot_bags(obstacle_slots, index),
		BastionBlueprintBundle.FIELD_WAYPOINTS: _node_bags(nodes),
		BastionBlueprintBundle.FIELD_EDGES: _edge_bags(edges),
		BastionBlueprintBundle.FIELD_WAVES: _wave_bags(waves),
		BastionBlueprintBundle.FIELD_ECONOMY: economy,
	}
	return {"codes": codes, "body": body}


static func _gather(world: AuthoringWorld, codes: Array[String]) -> Dictionary:
	var cores: Array[Dictionary] = []
	var spawns: Array[Dictionary] = []
	var build_slots: Array[Dictionary] = []
	var obstacle_slots: Array[Dictionary] = []
	var routes: Array[Dictionary] = []
	var waves: Array[Dictionary] = []
	var economy: Dictionary = {}
	var config_count: int = 0
	for entity_id: int in world.entity_ids():
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			continue
		var components: Dictionary = record.components
		BagsGd.check_tower(components, codes)
		var role: String = BagsGd.role_of(components)
		match role:
			BagsGd.TAG_CORE:
				_append_if_filled(cores, BagsGd.read_core(entity_id, components, codes))
			BagsGd.TAG_SPAWN:
				_append_if_filled(spawns, BagsGd.read_spawn(entity_id, components, codes))
			BagsGd.TAG_BUILD_SLOT:
				_append_if_filled(build_slots, BagsGd.read_slot(
					entity_id, components, PrototypesGd.KIND_TOWER, codes
				))
			BagsGd.TAG_OBSTACLE_SLOT:
				_append_if_filled(obstacle_slots, BagsGd.read_slot(
					entity_id, components, PrototypesGd.KIND_OBSTACLE, codes
				))
			BagsGd.TAG_ROUTE:
				_append_if_filled(routes, BagsGd.read_route(components, codes))
			BagsGd.TAG_WAVE:
				_append_if_filled(waves, BagsGd.read_wave(components, codes))
			BagsGd.TAG_CONFIG:
				config_count += 1
				var parsed: Dictionary = BagsGd.read_config(components, codes)
				if economy.is_empty():
					economy = parsed
			CodesGd.AMBIGUOUS_ROLE:
				BagsGd.push_code(codes, CodesGd.AMBIGUOUS_ROLE)
	if config_count > 1:
		BagsGd.push_code(codes, CodesGd.DUPLICATE_CONFIG)
	elif config_count == 0:
		BagsGd.push_code(codes, CodesGd.MISSING_CONFIG)
	return {
		"cores": cores,
		"spawns": spawns,
		"build_slots": build_slots,
		"obstacle_slots": obstacle_slots,
		"routes": routes,
		"waves": waves,
		"economy": economy,
	}


static func _check_cores(cores: Array[Dictionary], codes: Array[String]) -> void:
	var teams: Dictionary[int, bool] = {}
	var health: int = 0
	for core: Dictionary in cores:
		var team_id: int = core["team_id"]
		if teams.has(team_id):
			BagsGd.push_code(codes, CodesGd.DUPLICATE_CORE)
		teams[team_id] = true
		var maximum: int = core["max_health"]
		if health == 0:
			health = maximum
		elif health != maximum:
			BagsGd.push_code(codes, CodesGd.CORE_HEALTH_MISMATCH)
	for team_id: int in BastionBlueprintBundle.TEAMS:
		if not teams.has(team_id):
			BagsGd.push_code(codes, CodesGd.MISSING_CORE)


static func _check_route_presence(routes: Array[Dictionary], codes: Array[String]) -> void:
	var route_teams: Dictionary[int, bool] = {}
	for route: Dictionary in routes:
		var team_id: int = route["team_id"]
		route_teams[team_id] = true
	for team_id: int in BastionBlueprintBundle.TEAMS:
		if not route_teams.has(team_id):
			BagsGd.push_code(codes, CodesGd.MISSING_ROUTE)


## 两侧都要有、且数量相等。非对称阵容的补偿预设属 M7，本号不留那条路。
static func _check_balance(
	bags: Array[Dictionary], codes: Array[String], missing_code: String
) -> void:
	var counts: Dictionary[int, int] = {}
	for bag: Dictionary in bags:
		var team_id: int = bag["team_id"]
		counts[team_id] = counts.get(team_id, 0) + 1
	var reference: int = 0
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var count: int = counts.get(team_id, 0)
		if count < 1:
			BagsGd.push_code(codes, missing_code)
			return
		if reference == 0:
			reference = count
		elif reference != count:
			BagsGd.push_code(codes, CodesGd.SLOT_BUDGET_MISMATCH)


static func _check_routes(
	routes: Array[Dictionary],
	cores: Array[Dictionary],
	spawns: Array[Dictionary],
	codes: Array[String]
) -> void:
	var used_spawns: Dictionary[String, bool] = {}
	for route: Dictionary in routes:
		var team_id: int = route["team_id"]
		var points: Array = route["points"]
		if points.size() < 2:
			continue
		var first: Dictionary = points[0]
		var last: Dictionary = points[points.size() - 1]
		if not _matches(cores, team_id, last):
			BagsGd.push_code(codes, CodesGd.ROUTE_NOT_AT_CORE)
		if _matches(spawns, team_id, first):
			used_spawns[GraphGd.node_key(team_id, first)] = true
		else:
			BagsGd.push_code(codes, CodesGd.ROUTE_NOT_AT_SPAWN)
	for spawn: Dictionary in spawns:
		var team_id: int = spawn["team_id"]
		var pose: Dictionary = spawn["pose"]
		if not used_spawns.has(GraphGd.node_key(team_id, pose)):
			BagsGd.push_code(codes, CodesGd.SPAWN_UNUSED)


static func _check_slots(
	build_slots: Array[Dictionary],
	obstacle_slots: Array[Dictionary],
	nodes: Array[Dictionary],
	index: Dictionary[String, int],
	codes: Array[String]
) -> void:
	var lane_cells: Dictionary[String, bool] = {}
	for node: Dictionary in nodes:
		lane_cells["%d|%d|%d" % [node["x"], node["y"], node["z"]]] = true
	for slot: Dictionary in build_slots:
		var build_pose: Dictionary = slot["pose"]
		var key: String = "%d|%d|%d" % [build_pose["x"], build_pose["y"], build_pose["z"]]
		if lane_cells.has(key):
			BagsGd.push_code(codes, CodesGd.BUILD_SLOT_ON_LANE)
	for slot: Dictionary in obstacle_slots:
		var team_id: int = slot["team_id"]
		var obstacle_pose: Dictionary = slot["pose"]
		if not index.has(GraphGd.node_key(team_id, obstacle_pose)):
			BagsGd.push_code(codes, CodesGd.OBSTACLE_SLOT_OFF_LANE)


static func _matches(bags: Array[Dictionary], team_id: int, point: Dictionary) -> bool:
	for bag: Dictionary in bags:
		var owner_id: int = bag["team_id"]
		if owner_id != team_id:
			continue
		var pose: Dictionary = bag["pose"]
		if GraphGd.same_point(pose, point):
			return true
	return false


static func _core_bags(cores: Array[Dictionary], index: Dictionary[String, int]) -> Array:
	var out: Array = []
	for core: Dictionary in cores:
		var team_id: int = core["team_id"]
		var pose: Dictionary = core["pose"]
		var key: String = GraphGd.node_key(team_id, pose)
		out.append({
			"entity_id": core["entity_id"],
			"team_id": team_id,
			"node_id": index.get(key, 0),
			"max_health": core["max_health"],
		})
	return out


static func _spawn_bags(spawns: Array[Dictionary], index: Dictionary[String, int]) -> Array:
	var out: Array = []
	for spawn: Dictionary in spawns:
		var team_id: int = spawn["team_id"]
		var pose: Dictionary = spawn["pose"]
		var key: String = GraphGd.node_key(team_id, pose)
		out.append({
			"entity_id": spawn["entity_id"],
			"team_id": team_id,
			"node_id": index.get(key, 0),
		})
	return out


static func _build_slot_bags(slots: Array[Dictionary]) -> Array:
	var out: Array = []
	for slot: Dictionary in slots:
		var pose: Dictionary = slot["pose"]
		out.append({
			"entity_id": slot["entity_id"],
			"team_id": slot["team_id"],
			"x": pose["x"],
			"y": pose["y"],
			"z": pose["z"],
			"whitelist": slot["whitelist"],
		})
	return out


static func _obstacle_slot_bags(
	slots: Array[Dictionary], index: Dictionary[String, int]
) -> Array:
	var out: Array = []
	for slot: Dictionary in slots:
		var team_id: int = slot["team_id"]
		var pose: Dictionary = slot["pose"]
		var key: String = GraphGd.node_key(team_id, pose)
		out.append({
			"entity_id": slot["entity_id"],
			"team_id": team_id,
			"node_id": index.get(key, 0),
			"whitelist": slot["whitelist"],
		})
	return out


static func _node_bags(nodes: Array[Dictionary]) -> Array:
	var out: Array = []
	for node: Dictionary in nodes:
		out.append(node.duplicate(true))
	return out


static func _edge_bags(edges: Array[Dictionary]) -> Array:
	var out: Array = []
	for edge: Dictionary in edges:
		out.append(edge.duplicate(true))
	return out


static func _wave_bags(waves: Array[Dictionary]) -> Array:
	var out: Array = []
	var index: int = 1
	for wave: Dictionary in waves:
		out.append({
			"index": index,
			"prototype_id": wave["prototype_id"],
			"count": wave["count"],
			"interval_ticks": wave["interval_ticks"],
		})
		index += 1
	return out


static func _append_if_filled(target: Array[Dictionary], bag: Dictionary) -> void:
	if bag.is_empty():
		return
	target.append(bag)
