class_name FixedGraphSearch
extends RefCounted

## 整数边权的确定性最短路。**与玩法无关**：它只认节点 id、有向边和三项预算，
## 不知道什么是兵线、障碍或核心。BASTION 的语义在 `BastionPathGuard` 里，把边
## 改好了再喂进来。
##
## 为什么住在 `simulation/`：它是权威裁决路径的一部分（拒绝一次封路的操作要靠
## 它的结论），所以受宪法第五条约束——纯整数、不碰 SceneTree、同输入同输出。
##
## **确定性来自三处，缺一不可**：
##
## 1. 取下一个节点时按 (距离, 节点 id) 升序，平局永远选小 id；
## 2. 松弛时按边在输入数组里的顺序，而输入要求按 (from_id, to_id) 升序——
##    `BastionBlueprintBundle` 的 wire 就是这么规范化的；
## 3. 等距路径只保留**先到**的那条前驱，不做任何"更好看"的替换。
##
## **超预算拒绝整次搜索**，不给一条"差不多"的路。这与 `SimulationWorldMove` 的
## `MAX_SWEEP_STEPS` 超限拒绝整段位移是同一风格：预算是安全上限（宪法第十七条），
## 越界时给出的答案没有意义，而"有个答案"会被上层当真。
##
## 溢出同理：边权累加越界时返回 `RESULT_OVERFLOW`，既不饱和也不回绕
## （CD-42 §1.1 的定点数值合同）。

const RESULT_OK: int = 0
const RESULT_UNREACHABLE: int = 1
const RESULT_BUDGET: int = 2
const RESULT_OVERFLOW: int = 3
const RESULT_INVALID: int = 4

## 未访问标记。合法距离恒为非负，所以 -1 不会与任何真实距离撞上。
const _UNVISITED: int = -1


## nodes：节点 id 集合（顺序不敏感，内部按升序处理）。
## edges：`{from_id, to_id, cost}`，`cost >= 1`。
## blocked：不可通行的节点 id；起点或终点被封即判不可达。
## 返回 `{"status", "cost", "path", "expansions"}`；失败时 `cost = -1`、`path` 为空。
static func search(
	nodes: PackedInt32Array,
	edges: Array[Dictionary],
	blocked: PackedInt32Array,
	start_id: int,
	goal_id: int,
	max_nodes: int,
	max_edges: int,
	max_expansions: int
) -> Dictionary:
	if max_nodes < 1 or max_edges < 1 or max_expansions < 1:
		return _failed(RESULT_INVALID)
	if nodes.size() > max_nodes or edges.size() > max_edges:
		return _failed(RESULT_BUDGET)
	var known: Dictionary[int, bool] = {}
	for node_id: int in nodes:
		if node_id < 1 or known.has(node_id):
			return _failed(RESULT_INVALID)
		known[node_id] = true
	if not known.has(start_id) or not known.has(goal_id):
		return _failed(RESULT_INVALID)
	var closed: Dictionary[int, bool] = {}
	for node_id: int in blocked:
		if not known.has(node_id):
			return _failed(RESULT_INVALID)
		closed[node_id] = true
	var adjacency: Dictionary[int, Array] = {}
	for edge: Dictionary in edges:
		if not _edge_is_shaped(edge):
			return _failed(RESULT_INVALID)
		var from_id: int = edge["from_id"]
		var to_id: int = edge["to_id"]
		if not known.has(from_id) or not known.has(to_id):
			return _failed(RESULT_INVALID)
		var bucket: Array = adjacency.get(from_id, [])
		bucket.append(edge)
		adjacency[from_id] = bucket
	if closed.has(start_id) or closed.has(goal_id):
		return _failed(RESULT_UNREACHABLE)
	var order: PackedInt32Array = nodes.duplicate()
	order.sort()
	var distance: Dictionary[int, int] = {}
	var previous: Dictionary[int, int] = {}
	for node_id: int in order:
		distance[node_id] = _UNVISITED
	distance[start_id] = 0
	var settled: Dictionary[int, bool] = {}
	var expansions: int = 0
	while true:
		var current: int = _next_node(order, distance, settled, closed)
		if current == 0:
			return _failed(RESULT_UNREACHABLE)
		if current == goal_id:
			return {
				"status": RESULT_OK,
				"cost": distance[goal_id],
				"path": _path_to(previous, start_id, goal_id),
				"expansions": expansions,
			}
		expansions += 1
		if expansions > max_expansions:
			return _failed(RESULT_BUDGET)
		settled[current] = true
		var relaxed: Dictionary = _relax(
			current, adjacency, distance, previous, settled, closed
		)
		if not relaxed.get("ok", false):
			return _failed(RESULT_OVERFLOW)
	return _failed(RESULT_UNREACHABLE)


## 只问「到不到得了」。`search` 的薄壳，让守卫的调用点读起来是一句话。
static func is_reachable(
	nodes: PackedInt32Array,
	edges: Array[Dictionary],
	blocked: PackedInt32Array,
	start_id: int,
	goal_id: int,
	max_nodes: int,
	max_edges: int,
	max_expansions: int
) -> bool:
	var result: Dictionary = search(
		nodes, edges, blocked, start_id, goal_id, max_nodes, max_edges, max_expansions
	)
	var status: int = result["status"]
	return status == RESULT_OK


static func _relax(
	current: int,
	adjacency: Dictionary[int, Array],
	distance: Dictionary[int, int],
	previous: Dictionary[int, int],
	settled: Dictionary[int, bool],
	closed: Dictionary[int, bool]
) -> Dictionary:
	var here: int = distance[current]
	var bucket: Array = adjacency.get(current, [])
	for item: Variant in bucket:
		var edge: Dictionary = item
		var to_id: int = edge["to_id"]
		if closed.has(to_id) or settled.has(to_id):
			continue
		var cost: int = edge["cost"]
		var sum: FixedResult = Fixed.try_add(here, cost)
		if not sum.ok:
			return {"ok": false}
		var candidate: int = sum.value
		var best: int = distance[to_id]
		if best != _UNVISITED and best <= candidate:
			continue
		distance[to_id] = candidate
		previous[to_id] = current
	return {"ok": true}


## 距离最小、平局取最小 id 的未结算节点。没有可展开的节点时返回 0（0 不是合法 id）。
static func _next_node(
	order: PackedInt32Array,
	distance: Dictionary[int, int],
	settled: Dictionary[int, bool],
	closed: Dictionary[int, bool]
) -> int:
	var chosen: int = 0
	var best: int = _UNVISITED
	for node_id: int in order:
		if settled.has(node_id) or closed.has(node_id):
			continue
		var value: int = distance[node_id]
		if value == _UNVISITED:
			continue
		if chosen == 0 or value < best:
			chosen = node_id
			best = value
	return chosen


static func _path_to(
	previous: Dictionary[int, int], start_id: int, goal_id: int
) -> PackedInt32Array:
	var reversed_path: PackedInt32Array = PackedInt32Array()
	var cursor: int = goal_id
	reversed_path.append(cursor)
	while cursor != start_id:
		if not previous.has(cursor):
			return PackedInt32Array()
		cursor = previous[cursor]
		reversed_path.append(cursor)
	var path: PackedInt32Array = PackedInt32Array()
	for index: int in range(reversed_path.size() - 1, -1, -1):
		path.append(reversed_path[index])
	return path


static func _edge_is_shaped(edge: Dictionary) -> bool:
	for key: String in ["from_id", "to_id", "cost"]:
		if not edge.has(key) or typeof(edge[key]) != TYPE_INT:
			return false
	var cost: int = edge["cost"]
	if cost < 1:
		return false
	var from_id: int = edge["from_id"]
	var to_id: int = edge["to_id"]
	return from_id != to_id


static func _failed(status: int) -> Dictionary:
	return {
		"status": status,
		"cost": -1,
		"path": PackedInt32Array(),
		"expansions": 0,
	}
