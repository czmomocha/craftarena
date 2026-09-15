class_name BastionMatchSessionWaves
extends RefCounted

## 镜像波次的生成与行进。拆出来只为让 `BastionMatchSession` 低于 E9 400 行；
## 公开 API 仍在会话门面。
##
## **公平性不是靠比较两份表得来的，是靠只有一张表。** 波次表在
## `BastionBlueprintBundle.waves` 里只存一份，两队的生成 tick 与属性都由同一段
## 代码、同一个种子推出来（CD-22 §5.2）。所以「两侧逐字节等价」在这里是构造性
## 事实，测试只是把它钉住，不是在核对两份可能不同的数据。
##
## 边权既是寻路代价，也是行进距离：一条 `cost = 2` 的边长 `2 * cell`。减速地块
## 加边权 ⇒ 既可能改路，也一定走得更久。这是**占位模型**，不是产品速度曲线
## （CD-63 §1.3 仍延期）。
##
## 单位不进 `SimulationWorld`：BASTION 的兵沿离散边图走，没有胶囊、没有扫掠、
## 不需要碰撞。权威状态住在会话里并进会话自己的 `hash_state`，与 TRAPRUSH 的
## 进度和门闩住在 `TraprushMatchSession` 是同一种安排。

const GuardGd := preload("res://src/games/bastion/path_guard.gd")
const StubsGd := preload("res://src/games/bastion/play_stubs.gd")

## 单位已经走过最后一条边、把伤害交给核心的标记。
const LEG_AT_CORE: int = -1


## 本波第 `slot` 只的生成 tick。两队共用这一个函数，所以两队同 tick。
static func spawn_tick_of(wave_start_tick: int, interval_ticks: int, slot: int) -> int:
	return wave_start_tick + interval_ticks * slot


## 每只兵一个稳定随机数，由 (种子, 波序, 序号) 推出，**两队相同**。
## M6 的波次表本身是确定的，这个随机数今天不改变任何属性；它存在是为了让
## 「同一种子 → 同一批兵」这件事可被观察，而不是一句没有证据的声明。
static func spawn_roll(seed: int, wave_index: int, slot: int) -> int:
	var rng: SimRng = SimRng.new()
	rng.seed(seed ^ (wave_index * 1000003) ^ (slot * 31))
	return rng.next_u64()


static func make_unit(
	unit_id: int, prototype_id: int, spawn_tick: int, roll: int
) -> Dictionary:
	return {
		"unit_id": unit_id,
		"prototype_id": prototype_id,
		"health": StubsGd.unit_max_health(prototype_id),
		"max_health": StubsGd.unit_max_health(prototype_id),
		"speed": StubsGd.unit_speed(prototype_id),
		"bounty": StubsGd.unit_bounty(prototype_id),
		"core_damage": StubsGd.unit_core_damage(prototype_id),
		"leg": 0,
		"progress": 0,
		"slow_ticks": 0,
		"spawn_tick": spawn_tick,
		"spawn_roll": roll,
	}


## 单位沿路径推进一 tick。返回 `true` 表示它这一拍到达核心。
## `path` 是 node_id 序列，`leg_lengths` 是每条边的定点长度。
static func advance(
	unit: Dictionary, leg_lengths: PackedInt64Array, slow_numerator: int, slow_denominator: int
) -> bool:
	var leg: int = unit["leg"]
	if leg == LEG_AT_CORE:
		return false
	var step: int = unit["speed"]
	var slow_ticks: int = unit["slow_ticks"]
	if slow_ticks > 0:
		step = step * slow_numerator / slow_denominator
		unit["slow_ticks"] = slow_ticks - 1
	if step < 1:
		step = 1
	var progress: int = unit["progress"]
	progress += step
	while leg < leg_lengths.size():
		var length: int = leg_lengths[leg]
		if progress < length:
			break
		progress -= length
		leg += 1
	if leg >= leg_lengths.size():
		unit["leg"] = LEG_AT_CORE
		unit["progress"] = 0
		return true
	unit["leg"] = leg
	unit["progress"] = progress
	return false


## 单位当前的定点世界坐标。到核心的单位返回核心格。
static func position_of(
	unit: Dictionary, path: PackedInt32Array, positions: Dictionary[int, Dictionary],
	leg_lengths: PackedInt64Array
) -> Dictionary:
	var leg: int = unit["leg"]
	if leg == LEG_AT_CORE or path.size() < 2:
		return positions[path[path.size() - 1]]
	var from_point: Dictionary = positions[path[leg]]
	var to_point: Dictionary = positions[path[leg + 1]]
	var length: int = leg_lengths[leg]
	if length < 1:
		return from_point
	var progress: int = unit["progress"]
	return {
		"x": _lerp_axis(from_point, to_point, "x", progress, length),
		"y": _lerp_axis(from_point, to_point, "y", progress, length),
		"z": _lerp_axis(from_point, to_point, "z", progress, length),
	}


## 路径每条边的定点长度。`cost` 是格数，乘 `cell` 变成 Q48.16 距离。
static func leg_lengths_of(
	path: PackedInt32Array, costs: Dictionary[String, int], cell: int
) -> PackedInt64Array:
	var lengths: PackedInt64Array = PackedInt64Array()
	for index: int in range(path.size() - 1):
		var key: String = "%d|%d" % [path[index], path[index + 1]]
		var cost: int = costs.get(key, 0)
		lengths.append(cost * cell)
	return lengths


static func _lerp_axis(
	from_point: Dictionary, to_point: Dictionary, axis: String, progress: int, length: int
) -> int:
	var start: int = from_point[axis]
	var end: int = to_point[axis]
	if start == end:
		return start
	return start + (end - start) * progress / length


## 布障锁定后把边图冻结成一条固定路径。运行阶段不再改拓扑（CD-22 §4.3），
## 所以路径算一次就够，也保证同一局里兵不会因为重算而走出两种轨迹。
static func freeze_lanes(session: BastionMatchSession) -> void:
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var team: Dictionary = session._team(team_id)
		var placements: Array = team["obstacles"]
		var lane: Dictionary = GuardGd.lane_graph(session.bundle, team_id, placements)
		var spawn_ids: PackedInt32Array = session.bundle.spawn_node_ids(team_id)
		var lane_nodes: PackedInt32Array = lane["nodes"]
		var lane_edges: Array[Dictionary] = lane["edges"]
		var lane_blocked: PackedInt32Array = lane["blocked"]
		var search: Dictionary = FixedGraphSearch.search(
			lane_nodes,
			lane_edges,
			lane_blocked,
			spawn_ids[0],
			session.bundle.core_node_id(team_id),
			StubsGd.SEARCH_MAX_NODES,
			StubsGd.SEARCH_MAX_EDGES,
			StubsGd.SEARCH_MAX_EXPANSIONS
		)
		var path: PackedInt32Array = search["path"]
		team["path"] = path
		var costs: Dictionary[String, int] = {}
		for edge: Dictionary in lane_edges:
			costs["%d|%d" % [edge["from_id"], edge["to_id"]]] = edge["cost"]
		team["leg_lengths"] = leg_lengths_of(path, costs, session.bundle.cell)
		team["spawn_log"] = []


static func spawn_due(session: BastionMatchSession) -> void:
	if session._waves_done:
		return
	var wave: Dictionary = session.bundle.waves[session._wave_index - 1]
	var count: int = wave["count"]
	var interval: int = wave["interval_ticks"]
	var prototype_id: int = wave["prototype_id"]
	while session._wave_spawned < count:
		var due: int = spawn_tick_of(session._wave_start_tick, interval, session._wave_spawned)
		if session.tick < due:
			break
		var roll: int = spawn_roll(session.seed, session._wave_index, session._wave_spawned)
		for team_id: int in BastionBlueprintBundle.TEAMS:
			_spawn_for(session, team_id, prototype_id, due, roll)
		session._wave_spawned += 1
	var cadence: int = session.bundle.economy_value("wave_interval_ticks")
	if session._wave_spawned < count:
		return
	if session.tick - session._wave_start_tick < cadence:
		return
	if session._wave_index >= session.bundle.total_wave_count():
		session._waves_done = true
		return
	session._wave_index += 1
	session._wave_start_tick = session.tick
	session._wave_spawned = 0


static func _spawn_for(
	session: BastionMatchSession, team_id: int, prototype_id: int, due: int, roll: int
) -> void:
	var team: Dictionary = session._team(team_id)
	var units: Array = team["units"]
	var unit: Dictionary = make_unit(session._next_unit_serial, prototype_id, due, roll)
	session._next_unit_serial += 1
	units.append(unit)
	var records: Array = team["spawn_log"]
	records.append({
		"tick": due,
		"prototype_id": prototype_id,
		"max_health": unit["max_health"],
		"speed": unit["speed"],
		"bounty": unit["bounty"],
		"roll": roll,
	})


static func advance_all(session: BastionMatchSession) -> void:
	for team_id: int in BastionBlueprintBundle.TEAMS:
		var team: Dictionary = session._team(team_id)
		var units: Array = team["units"]
		var lengths: PackedInt64Array = team["leg_lengths"]
		var survivors: Array = []
		for item: Variant in units:
			var unit: Dictionary = item
			var arrived: bool = advance(
				unit,
				lengths,
				StubsGd.TOWER_FROST_SLOW_NUMERATOR,
				StubsGd.TOWER_FROST_SLOW_DENOMINATOR
			)
			if not arrived:
				survivors.append(unit)
				continue
			var leaks: int = team["leaked"]
			team["leaked"] = leaks + 1
			var damage: int = unit["core_damage"]
			var current: int = team["core_health"]
			team["core_health"] = maxi(current - damage, 0)
		team["units"] = survivors
		var cleared: int = team["clear_tick"]
		if session._waves_done and survivors.is_empty() and cleared == 0:
			team["clear_tick"] = session.tick
