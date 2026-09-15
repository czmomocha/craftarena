class_name BastionBlueprintDecode
extends RefCounted

## `BastionBlueprintBundle.from_dictionary` 的 wire 解码。字段名与
## `SCHEMA_VERSION` 留在门面上（content-validator 只读那一份），本文件只做
## 跨袋不变量。公开 API 仍在门面。
##
## 拒绝的判据全部是**形状与闭合**，不是玩法品味：id 闭合、严格升序、两侧预算
## 相等、槽位落在该落的地方。宪法第三条要求不可信输入在进入裁决前被证伪，
## 所以这里一条不满足就整份拒绝，不做局部修补——修补过的内容会得到一个
## 与作者意图不同、却仍能开局的战场。

const BagsGd := preload("res://src/ugc/bastion_blueprint_decode_bags.gd")
const PrototypesGd := preload("res://src/ugc/bastion_prototype_catalog.gd")

const FIELD_COUNT: int = 12


static func from_dictionary(data: Dictionary) -> BastionBlueprintBundle:
	var coerced: Variant = BagsGd.coerce_json_ints(data)
	if typeof(coerced) != TYPE_DICTIONARY:
		return null
	var body: Dictionary = coerced
	if body.size() != FIELD_COUNT:
		return null
	if not _header_is_valid(body):
		return null
	var cell: int = body[BastionBlueprintBundle.FIELD_CELL]
	var teams: PackedInt32Array = BastionBlueprintBundle.TEAMS
	var waypoints: Array[Dictionary] = _parse_waypoints(body, cell, teams)
	if waypoints.is_empty():
		return null
	var node_teams: Dictionary[int, int] = {}
	var node_positions: Dictionary[String, int] = {}
	for node: Dictionary in waypoints:
		var node_id: int = node["node_id"]
		node_teams[node_id] = BagsGd.read_int(node, "team_id")
		node_positions[_position_key(node)] = node_id
	var edges: Array[Dictionary] = _parse_edges(body, node_teams)
	if edges.is_empty():
		return null
	var cores: Array[Dictionary] = _parse_cores(body, node_teams, teams)
	if cores.is_empty():
		return null
	var core_nodes: Dictionary[int, bool] = {}
	for core: Dictionary in cores:
		core_nodes[BagsGd.read_int(core, "node_id")] = true
	var spawns: Array[Dictionary] = _parse_spawns(body, node_teams, core_nodes, teams)
	if spawns.is_empty():
		return null
	var build_slots: Array[Dictionary] = _parse_build_slots(body, cell, node_positions, teams)
	if build_slots.is_empty():
		return null
	var spawn_nodes: Dictionary[int, bool] = {}
	for spawn: Dictionary in spawns:
		spawn_nodes[BagsGd.read_int(spawn, "node_id")] = true
	var obstacle_slots: Array[Dictionary] = _parse_obstacle_slots(
		body, node_teams, core_nodes, spawn_nodes, edges, teams
	)
	if obstacle_slots.is_empty():
		return null
	if not _entity_ids_are_unique([cores, spawns, build_slots, obstacle_slots]):
		return null
	var waves: Array[Dictionary] = _parse_waves(body)
	if waves.is_empty():
		return null
	var economy: Dictionary = BagsGd.parse_economy(
		body[BastionBlueprintBundle.FIELD_ECONOMY], BastionBlueprintBundle.ECONOMY_KEYS
	)
	if economy.is_empty():
		return null
	var bundle: BastionBlueprintBundle = BastionBlueprintBundle.new()
	bundle.cell = cell
	bundle.source_revision = body[BastionBlueprintBundle.FIELD_SOURCE_REVISION]
	bundle.cores = cores
	bundle.spawns = spawns
	bundle.build_slots = build_slots
	bundle.obstacle_slots = obstacle_slots
	bundle.waypoints = waypoints
	bundle.edges = edges
	bundle.waves = waves
	bundle.economy = economy
	return bundle


static func _header_is_valid(body: Dictionary) -> bool:
	for field: String in [
		BastionBlueprintBundle.FIELD_SCHEMA_VERSION,
		BastionBlueprintBundle.FIELD_GAMEPLAY,
		BastionBlueprintBundle.FIELD_CELL,
		BastionBlueprintBundle.FIELD_SOURCE_REVISION,
		BastionBlueprintBundle.FIELD_CORES,
		BastionBlueprintBundle.FIELD_SPAWNS,
		BastionBlueprintBundle.FIELD_BUILD_SLOTS,
		BastionBlueprintBundle.FIELD_OBSTACLE_SLOTS,
		BastionBlueprintBundle.FIELD_WAYPOINTS,
		BastionBlueprintBundle.FIELD_EDGES,
		BastionBlueprintBundle.FIELD_WAVES,
		BastionBlueprintBundle.FIELD_ECONOMY,
	]:
		if not body.has(field):
			return false
	if typeof(body[BastionBlueprintBundle.FIELD_SCHEMA_VERSION]) != TYPE_INT:
		return false
	var version: int = body[BastionBlueprintBundle.FIELD_SCHEMA_VERSION]
	if version != BastionBlueprintBundle.SCHEMA_VERSION:
		return false
	if typeof(body[BastionBlueprintBundle.FIELD_GAMEPLAY]) != TYPE_STRING:
		return false
	var gameplay: String = body[BastionBlueprintBundle.FIELD_GAMEPLAY]
	if gameplay != BastionBlueprintBundle.GAMEPLAY_ID:
		return false
	if not BagsGd.int_at_least(body, BastionBlueprintBundle.FIELD_CELL, 1):
		return false
	return BagsGd.int_at_least(body, BastionBlueprintBundle.FIELD_SOURCE_REVISION, 0)


static func _bag_list(body: Dictionary, field: String) -> Array:
	if typeof(body[field]) != TYPE_ARRAY:
		return []
	var items: Array = body[field]
	return items


static func _parse_waypoints(
	body: Dictionary, cell: int, teams: PackedInt32Array
) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	var seen_positions: Dictionary[String, bool] = {}
	var previous: int = 0
	for item: Variant in _bag_list(body, BastionBlueprintBundle.FIELD_WAYPOINTS):
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var raw: Dictionary = item
		var node: Dictionary = BagsGd.parse_waypoint(raw, cell, teams)
		if node.is_empty():
			return []
		var node_id: int = node["node_id"]
		if node_id <= previous:
			return []
		previous = node_id
		var key: String = _position_key(node)
		if seen_positions.has(key):
			return []
		seen_positions[key] = true
		parsed.append(node)
	return parsed


## 悬空边在这里被判死：`from_id` / `to_id` 必须都是已声明的节点，且属于同一队。
## 跨队的边意味着一侧的兵能走进另一侧的防区，那不是 BASTION（CD-22 §3）。
static func _parse_edges(body: Dictionary, node_teams: Dictionary[int, int]) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	var previous_from: int = 0
	var previous_to: int = 0
	for item: Variant in _bag_list(body, BastionBlueprintBundle.FIELD_EDGES):
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var raw: Dictionary = item
		var edge: Dictionary = BagsGd.parse_edge(raw)
		if edge.is_empty():
			return []
		var from_id: int = edge["from_id"]
		var to_id: int = edge["to_id"]
		if not node_teams.has(from_id) or not node_teams.has(to_id):
			return []
		var from_team: int = node_teams[from_id]
		var to_team: int = node_teams[to_id]
		if from_team != to_team:
			return []
		if from_id < previous_from:
			return []
		if from_id == previous_from and to_id <= previous_to:
			return []
		previous_from = from_id
		previous_to = to_id
		parsed.append(edge)
	return parsed


static func _parse_cores(
	body: Dictionary, node_teams: Dictionary[int, int], teams: PackedInt32Array
) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	var seen_teams: Dictionary[int, bool] = {}
	var health: int = 0
	for item: Variant in _bag_list(body, BastionBlueprintBundle.FIELD_CORES):
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var raw: Dictionary = item
		var core: Dictionary = BagsGd.parse_core(raw, teams)
		if core.is_empty():
			return []
		var team_id: int = core["team_id"]
		if seen_teams.has(team_id):
			return []
		seen_teams[team_id] = true
		if not _node_belongs(node_teams, BagsGd.read_int(core, "node_id"), team_id):
			return []
		var maximum: int = core["max_health"]
		if health == 0:
			health = maximum
		elif health != maximum:
			return []
		parsed.append(core)
	if parsed.size() != teams.size():
		return []
	return parsed


static func _parse_spawns(
	body: Dictionary,
	node_teams: Dictionary[int, int],
	core_nodes: Dictionary[int, bool],
	teams: PackedInt32Array
) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	var counts: Dictionary[int, int] = {}
	var previous: int = 0
	var seen_nodes: Dictionary[int, bool] = {}
	for item: Variant in _bag_list(body, BastionBlueprintBundle.FIELD_SPAWNS):
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var raw: Dictionary = item
		var spawn: Dictionary = BagsGd.parse_spawn(raw, teams)
		if spawn.is_empty():
			return []
		var entity_id: int = spawn["entity_id"]
		if entity_id <= previous:
			return []
		previous = entity_id
		var node_id: int = spawn["node_id"]
		if core_nodes.has(node_id) or seen_nodes.has(node_id):
			return []
		seen_nodes[node_id] = true
		var team_id: int = spawn["team_id"]
		if not _node_belongs(node_teams, node_id, team_id):
			return []
		counts[team_id] = counts.get(team_id, 0) + 1
		parsed.append(spawn)
	if not _counts_are_balanced(counts, teams):
		return []
	return parsed


static func _parse_build_slots(
	body: Dictionary,
	cell: int,
	node_positions: Dictionary[String, int],
	teams: PackedInt32Array
) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	var counts: Dictionary[int, int] = {}
	var previous: int = 0
	var seen_positions: Dictionary[String, bool] = {}
	for item: Variant in _bag_list(body, BastionBlueprintBundle.FIELD_BUILD_SLOTS):
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var raw: Dictionary = item
		var slot: Dictionary = BagsGd.parse_build_slot(raw, cell, teams)
		if slot.is_empty():
			return []
		var entity_id: int = slot["entity_id"]
		if entity_id <= previous:
			return []
		previous = entity_id
		var key: String = _position_key(slot)
		# 塔不能站在兵线格上：那会让「路被塔堵死」变成建造的副作用。
		if node_positions.has(key) or seen_positions.has(key):
			return []
		seen_positions[key] = true
		var team_id: int = slot["team_id"]
		counts[team_id] = counts.get(team_id, 0) + 1
		parsed.append(slot)
	if not _counts_are_balanced(counts, teams):
		return []
	return parsed


static func _parse_obstacle_slots(
	body: Dictionary,
	node_teams: Dictionary[int, int],
	core_nodes: Dictionary[int, bool],
	spawn_nodes: Dictionary[int, bool],
	edges: Array[Dictionary],
	teams: PackedInt32Array
) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	var counts: Dictionary[int, int] = {}
	var previous: int = 0
	var seen_nodes: Dictionary[int, bool] = {}
	for item: Variant in _bag_list(body, BastionBlueprintBundle.FIELD_OBSTACLE_SLOTS):
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var raw: Dictionary = item
		var slot: Dictionary = BagsGd.parse_obstacle_slot(raw, teams)
		if slot.is_empty():
			return []
		var entity_id: int = slot["entity_id"]
		if entity_id <= previous:
			return []
		previous = entity_id
		var node_id: int = slot["node_id"]
		if core_nodes.has(node_id) or spawn_nodes.has(node_id) or seen_nodes.has(node_id):
			return []
		seen_nodes[node_id] = true
		var team_id: int = slot["team_id"]
		if not _node_belongs(node_teams, node_id, team_id):
			return []
		if not _diverter_has_branch(slot, node_id, edges):
			return []
		counts[team_id] = counts.get(team_id, 0) + 1
		parsed.append(slot)
	if not _counts_are_balanced(counts, teams):
		return []
	return parsed


## 分流门掐掉本节点编号最小的那条出边。只有一条出边时，掐掉就是封路——
## 那与 CD-22 §4.3「任意时刻至少保留一条合法路径」直接冲突，所以在发布前拒。
static func _diverter_has_branch(
	slot: Dictionary, node_id: int, edges: Array[Dictionary]
) -> bool:
	var whitelist: Array = slot["whitelist"]
	if not whitelist.has(PrototypesGd.OBSTACLE_DIVERTER):
		return true
	var out_degree: int = 0
	for edge: Dictionary in edges:
		var from_id: int = edge["from_id"]
		if from_id == node_id:
			out_degree += 1
	return out_degree >= 2


static func _parse_waves(body: Dictionary) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	var expected: int = 1
	for item: Variant in _bag_list(body, BastionBlueprintBundle.FIELD_WAVES):
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var raw: Dictionary = item
		var wave: Dictionary = BagsGd.parse_wave(raw)
		if wave.is_empty():
			return []
		var index: int = wave["index"]
		if index != expected:
			return []
		expected += 1
		parsed.append(wave)
	return parsed


static func _entity_ids_are_unique(groups: Array) -> bool:
	var seen: Dictionary[int, bool] = {}
	for group: Variant in groups:
		var bags: Array[Dictionary] = group
		for bag: Dictionary in bags:
			var entity_id: int = bag["entity_id"]
			if seen.has(entity_id):
				return false
			seen[entity_id] = true
	return true


static func _node_belongs(node_teams: Dictionary[int, int], node_id: int, team_id: int) -> bool:
	if not node_teams.has(node_id):
		return false
	var owner_id: int = node_teams[node_id]
	return owner_id == team_id


## 两侧数量必须都 >= 1 且完全相等。1v1 的对称阵容预算一致是 CD-22 §2 的公平
## 约束；非对称阵容的补偿预设属 M7，本 wire 不留那条路。
static func _counts_are_balanced(counts: Dictionary[int, int], teams: PackedInt32Array) -> bool:
	var reference: int = 0
	for team_id: int in teams:
		var count: int = counts.get(team_id, 0)
		if count < 1:
			return false
		if reference == 0:
			reference = count
		elif reference != count:
			return false
	return true


static func _position_key(bag: Dictionary) -> String:
	var x: int = bag["x"]
	var y: int = bag["y"]
	var z: int = bag["z"]
	return "%d|%d|%d" % [x, y, z]
