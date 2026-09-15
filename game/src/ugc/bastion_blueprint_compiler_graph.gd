class_name BastionBlueprintCompilerGraph
extends RefCounted

## 把蓝图里的**路线折线**（`path_agent.waypoints`）摊成 waypoint 边图。
## 拆出来只为让编译器文件低于 E9 400 行；公开入口仍在 `BastionBlueprintCompiler`。
##
## 为什么用折线而不是「节点实体 + 边实体」：Component Schema v1 一个字节不改是
## 本号的硬约束，而 v1 里唯一能表达「一串有序坐标」的就是 `path_agent.waypoints`
## （CD-42 §1.2 原文：waypoint、速度、赏金）。一条折线 = 一条分支；两条折线共用
## 同一个坐标就自然共用同一个节点，分叉不需要额外字段。
##
## 节点编号是**推导**出来的，不由作者填：把所有出现过的坐标按
## (team_id, x, y, z) 升序排一遍，从 1 开始编号。同一份蓝图编译两次得到同一组
## `node_id`，这是回放与哈希能自证的前提。
##
## 相邻 waypoint 必须是**同一楼层、沿单轴、正距离、整数格**的位移。斜着连或者
## 隔层连都判 `dangling_edge`：那条边在格网上接不到任何实际走得通的东西，
## 编译期放过去，D2 的可达性守卫就会拿到一张与战场不符的图。
##
## 问题码用 `Array[String]` 累加而不是 `PackedStringArray`：后者是值类型，
## 跨函数追加不保证写回调用方。


## routes: [{team_id, points: Array[Dictionary{x,y,z}]}]
## 返回 {"codes": Array[String], "nodes": Array[Dictionary], "index": Dictionary[String,int]}
static func build(routes: Array[Dictionary], cell: int) -> Dictionary:
	var codes: Array[String] = []
	var ordered: Array = []
	var seen: Dictionary[String, bool] = {}
	for route: Dictionary in routes:
		var team_id: int = route["team_id"]
		var points: Array = route["points"]
		if points.size() < 2:
			_push(codes, BastionBlueprintCodes.ROUTE_TOO_SHORT)
			continue
		for item: Variant in points:
			var point: Dictionary = item
			var key: String = node_key(team_id, point)
			if seen.has(key):
				continue
			seen[key] = true
			ordered.append([team_id, _axis(point, "x"), _axis(point, "y"), _axis(point, "z")])
		if not _steps_are_axis_aligned(points, cell):
			_push(codes, BastionBlueprintCodes.DANGLING_EDGE)
	ordered.sort_custom(_before)
	var nodes: Array[Dictionary] = []
	var index: Dictionary[String, int] = {}
	var next_id: int = 1
	for entry: Variant in ordered:
		var tuple: Array = entry
		var team_id: int = tuple[0]
		var x: int = tuple[1]
		var y: int = tuple[2]
		var z: int = tuple[3]
		nodes.append({
			"node_id": next_id,
			"team_id": team_id,
			"x": x,
			"y": y,
			"z": z,
		})
		index["%d|%d|%d|%d" % [team_id, x, y, z]] = next_id
		next_id += 1
	return {"codes": codes, "nodes": nodes, "index": index}


## 折线 → 有向边。同一对 (from, to) 只留一条：两条分支重叠的那一段本来就是
## 同一条路，重复写进 wire 只会让哈希依赖作者的书写顺序。
static func edges_from_routes(
	routes: Array[Dictionary], index: Dictionary[String, int], cell: int
) -> Array[Dictionary]:
	var collected: Array = []
	var seen: Dictionary[String, bool] = {}
	var edges: Array[Dictionary] = []
	for route: Dictionary in routes:
		var team_id: int = route["team_id"]
		var points: Array = route["points"]
		for step: int in range(points.size() - 1):
			var from_point: Dictionary = points[step]
			var to_point: Dictionary = points[step + 1]
			var from_key: String = node_key(team_id, from_point)
			var to_key: String = node_key(team_id, to_point)
			if not index.has(from_key) or not index.has(to_key):
				return edges
			var from_id: int = index[from_key]
			var to_id: int = index[to_key]
			var pair: String = "%d|%d" % [from_id, to_id]
			if seen.has(pair):
				continue
			seen[pair] = true
			var cost: int = step_cost(from_point, to_point, cell)
			if cost < 1:
				return edges
			collected.append([from_id, to_id, cost])
	collected.sort_custom(_edge_before)
	for entry: Variant in collected:
		var tuple: Array = entry
		edges.append({"from_id": tuple[0], "to_id": tuple[1], "cost": tuple[2]})
	return edges


## 一步的整数边权 = 格数。非轴对齐或跨层返回 0，调用方当失败处理。
static func step_cost(from_point: Dictionary, to_point: Dictionary, cell: int) -> int:
	if cell < 1:
		return 0
	var dx: int = _axis(to_point, "x") - _axis(from_point, "x")
	var dy: int = _axis(to_point, "y") - _axis(from_point, "y")
	var dz: int = _axis(to_point, "z") - _axis(from_point, "z")
	if dy != 0:
		return 0
	if dx != 0 and dz != 0:
		return 0
	var delta: int = absi(dx) + absi(dz)
	if delta == 0:
		return 0
	if delta % cell != 0:
		return 0
	return delta / cell


static func node_key(team_id: int, point: Dictionary) -> String:
	return "%d|%d|%d|%d" % [
		team_id, _axis(point, "x"), _axis(point, "y"), _axis(point, "z")
	]


static func same_point(left: Dictionary, right: Dictionary) -> bool:
	if _axis(left, "x") != _axis(right, "x"):
		return false
	if _axis(left, "y") != _axis(right, "y"):
		return false
	return _axis(left, "z") == _axis(right, "z")


static func _steps_are_axis_aligned(points: Array, cell: int) -> bool:
	for step: int in range(points.size() - 1):
		var from_point: Dictionary = points[step]
		var to_point: Dictionary = points[step + 1]
		if step_cost(from_point, to_point, cell) < 1:
			return false
	return true


static func _axis(point: Dictionary, key: String) -> int:
	if not point.has(key) or typeof(point[key]) != TYPE_INT:
		return 0
	var value: int = point[key]
	return value


static func _before(left: Variant, right: Variant) -> bool:
	var a: Array = left
	var b: Array = right
	for slot: int in range(4):
		var lhs: int = a[slot]
		var rhs: int = b[slot]
		if lhs != rhs:
			return lhs < rhs
	return false


static func _edge_before(left: Variant, right: Variant) -> bool:
	var a: Array = left
	var b: Array = right
	var from_left: int = a[0]
	var from_right: int = b[0]
	if from_left != from_right:
		return from_left < from_right
	var to_left: int = a[1]
	var to_right: int = b[1]
	return to_left < to_right


static func _push(codes: Array[String], code: String) -> void:
	if not codes.has(code):
		codes.append(code)
