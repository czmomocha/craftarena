class_name BastionPathGuard
extends RefCounted

## 「任意时刻至少保留一条从出兵点到核心的合法路径」（CD-22 §4.3）的实现。
##
## 三处用法，同一份判据：
##
## - **发布前**：`problems(bundle)` 在空布障的初始拓扑上跑一遍，蓝图本身就封死
##   的路不许发布，问题码形状照 `AuthoringReachabilityCodes`；
## - **运行时提交**：`slot_allows_placement()` 验槽位 / 白名单 / 占用。互设障碍
##   阶段的提案还没上图（pending 不是活图），所以提交时不在这里判封路；
## - **运行时揭示**：`lanes_are_open()` 在 `MatchSetupState.reveal()` 里对整份
##   提案重跑，非法放置 LIFO 撤销并退点（CD-22 §4.1 第 6、7 步）。
## - **`allows_obstacle()`** 仍是「把它算进去之后还走得通」的增量判据，D2 测试
##   与任何需要当场问一句的调用方继续用它。
##
## 障碍语义全部来自 `BastionPlayStubs.OBSTACLES`（占位桩，CD-63 §1.2 / §1.3 仍
## 延期），边图与节点来自 `BastionBlueprintBundle`，搜索本体是与玩法无关的
## `FixedGraphSearch`。三层各自只知道自己那一份，所以改数值不会动搜索，
## 改搜索不会动蓝图 wire。
##
## 炮塔为什么不需要单独一条守卫：建造槽在编译期就被判定**不得压在兵线格上**
## （`BastionBlueprintCodes.BUILD_SLOT_ON_LANE`），所以建塔在拓扑上碰不到任何
## 边。`allows_tower()` 仍然存在，是为了让「万一有份 bundle 绕过了那条编译期
## 断言」在运行时也被拒，而不是默默让塔把路堵上。

const CodesGd := preload("res://src/ugc/bastion_blueprint_codes.gd")
const StubsGd := preload("res://src/games/bastion/play_stubs.gd")


## 发布前可达性。空数组 = 每一队的每个出兵点都能到本队核心。
static func problems(bundle: BastionBlueprintBundle) -> PackedStringArray:
	var codes: PackedStringArray = PackedStringArray()
	if bundle == null:
		codes.append(CodesGd.LANE_UNREACHABLE)
		return codes
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var status: int = team_status(bundle, team_id, [])
		var code: String = _code_for(status)
		if code.is_empty():
			continue
		if not codes.has(code):
			codes.append(code)
	return codes


## 在给定布障下，该队最差的一条出兵点 → 核心的搜索状态。
## `FixedGraphSearch.RESULT_OK` 表示全部可达。
static func team_status(
	bundle: BastionBlueprintBundle, team_id: int, placements: Array
) -> int:
	if bundle == null:
		return FixedGraphSearch.RESULT_INVALID
	var core_id: int = bundle.core_node_id(team_id)
	if core_id == 0:
		return FixedGraphSearch.RESULT_INVALID
	var spawn_ids: PackedInt32Array = bundle.spawn_node_ids(team_id)
	if spawn_ids.is_empty():
		return FixedGraphSearch.RESULT_INVALID
	var lane: Dictionary = lane_graph(bundle, team_id, placements)
	var nodes: PackedInt32Array = lane["nodes"]
	var edges: Array[Dictionary] = lane["edges"]
	var blocked: PackedInt32Array = lane["blocked"]
	for spawn_id: int in spawn_ids:
		var result: Dictionary = FixedGraphSearch.search(
			nodes,
			edges,
			blocked,
			spawn_id,
			core_id,
			StubsGd.SEARCH_MAX_NODES,
			StubsGd.SEARCH_MAX_EDGES,
			StubsGd.SEARCH_MAX_EXPANSIONS
		)
		var status: int = result["status"]
		if status != FixedGraphSearch.RESULT_OK:
			return status
	return FixedGraphSearch.RESULT_OK


static func lanes_are_open(
	bundle: BastionBlueprintBundle, team_id: int, placements: Array
) -> bool:
	return team_status(bundle, team_id, placements) == FixedGraphSearch.RESULT_OK


## 接受这次放置吗。`existing` 是该队防区已生效的放置，`candidate` 是新的一条。
## 判据是「把它算进去之后还走得通」，不是「它自己看起来无害」——两个各自合法的
## 障碍合起来封死唯一路径，正是这条守卫存在的理由。
static func allows_obstacle(
	bundle: BastionBlueprintBundle,
	team_id: int,
	existing: Array,
	candidate: Dictionary
) -> bool:
	if bundle == null or candidate.is_empty():
		return false
	if not _placement_is_legal(bundle, team_id, existing, candidate):
		return false
	var next: Array = existing.duplicate()
	next.append(candidate)
	return lanes_are_open(bundle, team_id, next)


## 建塔占槽。槽位必须属于本队、存在，且不压在兵线格上。
static func allows_tower(
	bundle: BastionBlueprintBundle, team_id: int, slot_entity_id: int
) -> bool:
	if bundle == null:
		return false
	var slot: Dictionary = bundle.build_slot_at(slot_entity_id)
	if slot.is_empty():
		return false
	var owner_id: int = slot["team_id"]
	if owner_id != team_id:
		return false
	var x: int = slot["x"]
	var y: int = slot["y"]
	var z: int = slot["z"]
	for node: Dictionary in bundle.waypoints:
		var node_x: int = node["x"]
		var node_y: int = node["y"]
		var node_z: int = node["z"]
		if node_x == x and node_y == y and node_z == z:
			return false
	return true


## 把布障摊进边图。返回 `{"nodes", "edges", "blocked"}`。
##
## 三种效果（占位桩）：路障封掉该节点；减速地块给该节点的每条出边加固定边权；
## 分流门掐掉该节点**编号最小**的那条出边，把兵挤到另一支。
static func lane_graph(
	bundle: BastionBlueprintBundle, team_id: int, placements: Array
) -> Dictionary:
	var nodes: PackedInt32Array = bundle.node_ids_of(team_id)
	var lane_nodes: Dictionary[int, bool] = {}
	for node_id: int in nodes:
		lane_nodes[node_id] = true
	var blocked: PackedInt32Array = PackedInt32Array()
	var extra_cost: Dictionary[int, int] = {}
	var cut_edges: Dictionary[String, bool] = {}
	for item: Variant in placements:
		var placement: Dictionary = item
		var node_id: int = placement["node_id"]
		var prototype_id: int = placement["prototype_id"]
		if not lane_nodes.has(node_id):
			continue
		if StubsGd.obstacle_blocks_node(prototype_id) and not blocked.has(node_id):
			blocked.append(node_id)
		var delta: int = StubsGd.obstacle_edge_cost_delta(prototype_id)
		if delta > 0:
			extra_cost[node_id] = extra_cost.get(node_id, 0) + delta
		if StubsGd.obstacle_cuts_first_edge(prototype_id):
			var outgoing: Array[Dictionary] = bundle.edges_from(node_id)
			if not outgoing.is_empty():
				var first: Dictionary = outgoing[0]
				cut_edges[_edge_key(first)] = true
	var edges: Array[Dictionary] = []
	for edge: Dictionary in bundle.edges:
		var from_id: int = edge["from_id"]
		if not lane_nodes.has(from_id):
			continue
		if cut_edges.has(_edge_key(edge)):
			continue
		var cost: int = edge["cost"]
		cost += extra_cost.get(from_id, 0)
		edges.append({
			"from_id": from_id,
			"to_id": edge["to_id"],
			"cost": cost,
		})
	return {"nodes": nodes, "edges": edges, "blocked": blocked}


## 单次放置的槽位合法性：必须落在本队的障碍槽上、原型在该槽白名单里、槽未被占。
## 不含封路——封路是揭示时对整份提案重跑的事。
static func slot_allows_placement(
	bundle: BastionBlueprintBundle,
	team_id: int,
	existing: Array,
	candidate: Dictionary
) -> bool:
	return _placement_is_legal(bundle, team_id, existing, candidate)


static func _placement_is_legal(
	bundle: BastionBlueprintBundle,
	team_id: int,
	existing: Array,
	candidate: Dictionary
) -> bool:
	if not candidate.has("node_id") or not candidate.has("prototype_id"):
		return false
	var node_id: int = candidate["node_id"]
	var prototype_id: int = candidate["prototype_id"]
	var slot: Dictionary = _slot_at_node(bundle, team_id, node_id)
	if slot.is_empty():
		return false
	var whitelist: Array = slot["whitelist"]
	if not whitelist.has(prototype_id):
		return false
	for item: Variant in existing:
		var placement: Dictionary = item
		var used: int = placement["node_id"]
		if used == node_id:
			return false
	return true


static func _slot_at_node(
	bundle: BastionBlueprintBundle, team_id: int, node_id: int
) -> Dictionary:
	for slot: Dictionary in bundle.obstacle_slots:
		var owner_id: int = slot["team_id"]
		var slot_node: int = slot["node_id"]
		if owner_id == team_id and slot_node == node_id:
			return slot
	return {}


static func _code_for(status: int) -> String:
	match status:
		FixedGraphSearch.RESULT_OK:
			return ""
		FixedGraphSearch.RESULT_BUDGET:
			return CodesGd.SEARCH_BUDGET_EXHAUSTED
		FixedGraphSearch.RESULT_OVERFLOW:
			return CodesGd.EDGE_COST_OVERFLOW
		_:
			return CodesGd.LANE_UNREACHABLE


static func _edge_key(edge: Dictionary) -> String:
	return "%d|%d" % [edge["from_id"], edge["to_id"]]
