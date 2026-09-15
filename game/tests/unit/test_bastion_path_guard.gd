extends GutTest

## M6 D2：确定性边图搜索与「不得完全封路」守卫。
##
## 三件事要被证明，其余都是附带：
##
## 1. **同图同序列得同一条路**。节点编号是推导的、平局按 id 破、边按
##    (from, to) 升序——三处缺一条，回放就不能自证（宪法第五条）。
## 2. **封死唯一路径被拒，只是绕远被接受**。CD-22 §4.3 要求的是「任意时刻至少
##    保留一条合法路径」，不是「任意时刻路都一样短」。两条分不清的话，减速地块
##    会被当成封路，路障会被当成合法。
## 3. **超预算与溢出拒绝整次搜索**，不返回一条「差不多」的路。给出一个越界之后
##    算出来的答案，比说不知道更坏——上层会把它当真。
##
## 搜索本体与玩法无关，所以本批一半断言直接喂手写小图，不经过蓝图。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const BastionBlueprintBundle := preload("res://src/ugc/bastion_blueprint_bundle.gd")
const BastionBlueprintCodes := preload("res://src/ugc/bastion_blueprint_codes.gd")
const BastionBlueprintCompiler := preload("res://src/ugc/bastion_blueprint_compiler.gd")
const BastionPathGuard := preload("res://src/games/bastion/path_guard.gd")
const BastionPlayStubs := preload("res://src/games/bastion/play_stubs.gd")
const BastionPrototypeCatalog := preload("res://src/ugc/bastion_prototype_catalog.gd")
const FixedGraphSearch := preload("res://src/simulation/fixed_graph_search.gd")

const GRAYBOX_PATH: String = "res://content/test_fixtures/bastion/blueprints/graybox.json"
const BUDGET: int = 64

## 灰盒里 A 队的七个节点（编号由编译器按 team/x/y/z 升序推导，不由作者填）。
## 两条分支直到核心才汇合，所以「封一条还剩一条」这件事在这张图上成立。
const A_CORE: int = 1
const A_MID: int = 2
const A_FORK: int = 3
const A_SPAWN: int = 4
const A_BRANCH_END: int = 5
const A_BRANCH_MID: int = 6
const A_BRANCH_NEAR: int = 7
## B 队的分叉点，用来证明一侧的障碍碰不到另一侧。
const B_FORK: int = 9


# 1. 搜索本体：确定、平局按 id、预算与溢出拒绝整次搜索。

func test_search_is_deterministic_and_breaks_ties_by_node_id() -> void:
	# 1 → 2 → 4 与 1 → 3 → 4 等长。平局必须永远选小 id 的那条。
	var nodes: PackedInt32Array = PackedInt32Array([1, 2, 3, 4])
	var edges: Array[Dictionary] = [
		{"from_id": 1, "to_id": 2, "cost": 1},
		{"from_id": 1, "to_id": 3, "cost": 1},
		{"from_id": 2, "to_id": 4, "cost": 1},
		{"from_id": 3, "to_id": 4, "cost": 1},
	]
	var first: Dictionary = _search(nodes, edges, PackedInt32Array(), 1, 4)
	var second: Dictionary = _search(nodes, edges, PackedInt32Array(), 1, 4)
	assert_eq(_status(first), FixedGraphSearch.RESULT_OK)
	assert_eq(_cost(first), 2)
	assert_eq(_path(first), PackedInt32Array([1, 2, 4]))
	assert_eq(_path(second), _path(first))


func test_search_prefers_the_cheaper_route_not_the_shorter_hop_count() -> void:
	var nodes: PackedInt32Array = PackedInt32Array([1, 2, 3, 4])
	var edges: Array[Dictionary] = [
		{"from_id": 1, "to_id": 4, "cost": 9},
		{"from_id": 1, "to_id": 2, "cost": 1},
		{"from_id": 2, "to_id": 3, "cost": 1},
		{"from_id": 3, "to_id": 4, "cost": 1},
	]
	var result: Dictionary = _search(nodes, edges, PackedInt32Array(), 1, 4)
	assert_eq(_cost(result), 3)
	assert_eq(_path(result), PackedInt32Array([1, 2, 3, 4]))


func test_blocked_node_makes_the_goal_unreachable() -> void:
	var nodes: PackedInt32Array = PackedInt32Array([1, 2, 3])
	var edges: Array[Dictionary] = [
		{"from_id": 1, "to_id": 2, "cost": 1},
		{"from_id": 2, "to_id": 3, "cost": 1},
	]
	var open: Dictionary = _search(nodes, edges, PackedInt32Array(), 1, 3)
	assert_eq(_status(open), FixedGraphSearch.RESULT_OK)
	var sealed: Dictionary = _search(nodes, edges, PackedInt32Array([2]), 1, 3)
	assert_eq(_status(sealed), FixedGraphSearch.RESULT_UNREACHABLE)
	assert_eq(_cost(sealed), -1)
	# 起点或终点自己被封，同样是不可达而不是崩。
	assert_eq(
		_status(_search(nodes, edges, PackedInt32Array([1]), 1, 3)),
		FixedGraphSearch.RESULT_UNREACHABLE
	)


func test_budget_overrun_rejects_the_whole_search() -> void:
	var nodes: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5])
	var edges: Array[Dictionary] = [
		{"from_id": 1, "to_id": 2, "cost": 1},
		{"from_id": 2, "to_id": 3, "cost": 1},
		{"from_id": 3, "to_id": 4, "cost": 1},
		{"from_id": 4, "to_id": 5, "cost": 1},
	]
	# 节点数超限：先于任何展开就拒。
	var by_nodes: Dictionary = FixedGraphSearch.search(
		nodes, edges, PackedInt32Array(), 1, 5, 4, BUDGET, BUDGET
	)
	assert_eq(_status(by_nodes), FixedGraphSearch.RESULT_BUDGET)
	var by_edges: Dictionary = FixedGraphSearch.search(
		nodes, edges, PackedInt32Array(), 1, 5, BUDGET, 3, BUDGET
	)
	assert_eq(_status(by_edges), FixedGraphSearch.RESULT_BUDGET)
	# 展开次数超限：拒绝整次搜索，不返回半条路。
	var by_expansions: Dictionary = FixedGraphSearch.search(
		nodes, edges, PackedInt32Array(), 1, 5, BUDGET, BUDGET, 2
	)
	assert_eq(_status(by_expansions), FixedGraphSearch.RESULT_BUDGET)
	assert_eq(_path(by_expansions), PackedInt32Array())


func test_edge_cost_overflow_neither_saturates_nor_wraps() -> void:
	var huge: int = 9223372036854775807
	var nodes: PackedInt32Array = PackedInt32Array([1, 2, 3])
	var edges: Array[Dictionary] = [
		{"from_id": 1, "to_id": 2, "cost": huge},
		{"from_id": 2, "to_id": 3, "cost": huge},
	]
	var result: Dictionary = _search(nodes, edges, PackedInt32Array(), 1, 3)
	assert_eq(_status(result), FixedGraphSearch.RESULT_OVERFLOW)
	assert_eq(_cost(result), -1)


func test_malformed_input_is_invalid_rather_than_silently_skipped() -> void:
	var nodes: PackedInt32Array = PackedInt32Array([1, 2])
	assert_eq(
		_status(_search(nodes, [{"from_id": 1, "to_id": 9, "cost": 1}], PackedInt32Array(), 1, 2)),
		FixedGraphSearch.RESULT_INVALID
	)
	assert_eq(
		_status(_search(nodes, [{"from_id": 1, "to_id": 2, "cost": 0}], PackedInt32Array(), 1, 2)),
		FixedGraphSearch.RESULT_INVALID
	)
	assert_eq(
		_status(_search(nodes, [{"from_id": 1, "to_id": 2, "cost": 1}], PackedInt32Array(), 1, 9)),
		FixedGraphSearch.RESULT_INVALID
	)
	assert_eq(
		_status(_search(PackedInt32Array([1, 1]), [], PackedInt32Array(), 1, 1)),
		FixedGraphSearch.RESULT_INVALID
	)


# 2. 守卫：灰盒蓝图上的封路 / 绕远。

func test_graybox_publishes_with_every_lane_open() -> void:
	var bundle: BastionBlueprintBundle = _graybox()
	assert_eq(BastionPathGuard.problems(bundle), PackedStringArray([]))
	for team_id: int in BastionBlueprintBundle.TEAMS:
		assert_true(BastionPathGuard.lanes_are_open(bundle, team_id, []))


func test_node_numbering_matches_the_layout_it_was_derived_from() -> void:
	# 后面的断言都按这组编号读，编号漂了这条先红。
	var bundle: BastionBlueprintBundle = _graybox()
	assert_eq(bundle.core_node_id(BastionBlueprintBundle.TEAM_A), A_CORE)
	assert_eq(
		bundle.spawn_node_ids(BastionBlueprintBundle.TEAM_A), PackedInt32Array([A_SPAWN])
	)
	assert_eq(bundle.edges_from(A_FORK).size(), 2)
	assert_eq(bundle.edges_from(A_MID).size(), 1)


func test_a_detour_is_accepted_and_sealing_the_only_path_is_refused() -> void:
	var bundle: BastionBlueprintBundle = _graybox()
	var team: int = BastionBlueprintBundle.TEAM_A
	# 分叉点是出兵点之后唯一的一格：封了它两条分支一起没，拒。
	# 白名单允许放路障，守卫仍然拒——CD-22 §4.3 是运行时判据，不是白名单限制。
	var choke: Dictionary = _placement(A_FORK, BastionPrototypeCatalog.OBSTACLE_BARRICADE)
	assert_false(BastionPathGuard.allows_obstacle(bundle, team, [], choke))
	# 封主路中段：绕行分支还在，只是绕远，接受。
	var main: Dictionary = _placement(A_MID, BastionPrototypeCatalog.OBSTACLE_BARRICADE)
	assert_true(BastionPathGuard.allows_obstacle(bundle, team, [], main))
	# 封绕行分支：主路还在，接受。
	var branch: Dictionary = _placement(
		A_BRANCH_NEAR, BastionPrototypeCatalog.OBSTACLE_BARRICADE
	)
	assert_true(BastionPathGuard.allows_obstacle(bundle, team, [], branch))
	# 两个各自合法的放置合起来就是封路：第二个必须被拒。这才是守卫存在的理由。
	assert_false(BastionPathGuard.allows_obstacle(bundle, team, [main], branch))
	# 顺序反过来结论一样：守卫看的是合起来的拓扑，不是单条放置。
	assert_false(BastionPathGuard.allows_obstacle(bundle, team, [branch], main))


func test_slow_tile_only_raises_cost_and_is_always_accepted() -> void:
	var bundle: BastionBlueprintBundle = _graybox()
	var team: int = BastionBlueprintBundle.TEAM_A
	var slow: Dictionary = _placement(A_FORK, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE)
	assert_true(BastionPathGuard.allows_obstacle(bundle, team, [], slow))
	var before: int = _lane_cost(bundle, team, [])
	var after: int = _lane_cost(bundle, team, [slow])
	assert_gt(after, before, "减速地块必须真的加边权，否则它什么也没做")
	assert_eq(after - before, BastionPlayStubs.obstacle_edge_cost_delta(
		BastionPrototypeCatalog.OBSTACLE_SLOW_TILE
	))


func test_diverter_cuts_the_lowest_numbered_exit_and_keeps_a_way_through() -> void:
	var bundle: BastionBlueprintBundle = _graybox()
	var team: int = BastionBlueprintBundle.TEAM_A
	var diverter: Dictionary = _placement(A_FORK, BastionPrototypeCatalog.OBSTACLE_DIVERTER)
	assert_true(BastionPathGuard.allows_obstacle(bundle, team, [], diverter))
	var plain: PackedInt32Array = _lane_path(bundle, team, [])
	var diverted: PackedInt32Array = _lane_path(bundle, team, [diverter])
	assert_ne(diverted, plain, "分流门必须真的换一条路")
	assert_true(diverted.has(A_BRANCH_NEAR), "被挤到的应当是绕行分支")


func test_placement_outside_a_slot_or_off_whitelist_is_refused() -> void:
	var bundle: BastionBlueprintBundle = _graybox()
	var team: int = BastionBlueprintBundle.TEAM_A
	# 出兵点不是障碍槽。
	assert_false(BastionPathGuard.allows_obstacle(
		bundle, team, [], _placement(A_SPAWN, BastionPrototypeCatalog.OBSTACLE_BARRICADE)
	))
	# 分流门不在 41 号槽（节点 6）的白名单里。
	assert_false(BastionPathGuard.allows_obstacle(
		bundle, team, [], _placement(A_BRANCH_NEAR, BastionPrototypeCatalog.OBSTACLE_DIVERTER)
	))
	# 对手防区的障碍槽不归本队放（B 的分叉点确实是一个障碍槽）。
	assert_false(BastionPathGuard.allows_obstacle(
		bundle, team, [], _placement(B_FORK, BastionPrototypeCatalog.OBSTACLE_BARRICADE)
	))
	# 同一个槽不能放两次。
	var once: Dictionary = _placement(
		A_BRANCH_NEAR, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE
	)
	assert_true(BastionPathGuard.allows_obstacle(bundle, team, [], once))
	assert_false(BastionPathGuard.allows_obstacle(bundle, team, [once], once))


func test_obstacles_never_reach_across_into_the_other_lane() -> void:
	var bundle: BastionBlueprintBundle = _graybox()
	var blockade: Dictionary = _placement(A_MID, BastionPrototypeCatalog.OBSTACLE_BARRICADE)
	# A 队防区被封一格，B 队那条路一点没变。
	assert_true(BastionPathGuard.lanes_are_open(
		bundle, BastionBlueprintBundle.TEAM_B, [blockade]
	))
	assert_eq(
		_lane_cost(bundle, BastionBlueprintBundle.TEAM_B, [blockade]),
		_lane_cost(bundle, BastionBlueprintBundle.TEAM_B, [])
	)


func test_towers_cannot_stand_on_a_lane_cell() -> void:
	var bundle: BastionBlueprintBundle = _graybox()
	var team: int = BastionBlueprintBundle.TEAM_A
	for slot_id: int in bundle.build_slot_ids(team):
		assert_true(BastionPathGuard.allows_tower(bundle, team, slot_id))
	# 对手的槽、以及不存在的槽，都不给建。
	assert_false(BastionPathGuard.allows_tower(bundle, team, 33))
	assert_false(BastionPathGuard.allows_tower(bundle, team, 9999))


func test_sealed_blueprint_reports_a_publish_time_problem_code() -> void:
	var bundle: BastionBlueprintBundle = _graybox()
	# 掐掉所有通往 A 队核心的入边，模拟一份自己就封死的蓝图。
	# 故意不动分叉点：wire 层的「分流门要有分支」仍然满足，暴露出来的只有可达性。
	var body: Dictionary = bundle.to_dictionary()
	var edges: Array = body["edges"]
	var kept: Array = []
	for item: Variant in edges:
		var edge: Dictionary = item
		var to_id: int = edge["to_id"]
		if to_id == A_CORE:
			continue
		kept.append(edge)
	body["edges"] = kept
	var sealed: BastionBlueprintBundle = BastionBlueprintBundle.from_dictionary(body)
	assert_not_null(sealed, "本例要测的是可达性，wire 形状仍然合法")
	var codes: PackedStringArray = BastionPathGuard.problems(sealed)
	assert_true(codes.has(BastionBlueprintCodes.LANE_UNREACHABLE), str(codes))
	assert_eq(BastionPathGuard.problems(null), PackedStringArray([
		BastionBlueprintCodes.LANE_UNREACHABLE
	]))


func test_same_placement_sequence_gives_the_same_path_every_time() -> void:
	var bundle: BastionBlueprintBundle = _graybox()
	var team: int = BastionBlueprintBundle.TEAM_A
	var sequence: Array = [
		_placement(A_FORK, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE),
		_placement(A_BRANCH_NEAR, BastionPrototypeCatalog.OBSTACLE_SLOW_TILE),
	]
	var first: PackedInt32Array = _lane_path(bundle, team, sequence)
	var second: PackedInt32Array = _lane_path(_graybox(), team, sequence)
	assert_eq(first, second)
	assert_false(first.is_empty())


# --- helpers ---------------------------------------------------------------

func _graybox() -> BastionBlueprintBundle:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(GRAYBOX_PATH)
	assert_not_null(world)
	var bundle: BastionBlueprintBundle = BastionBlueprintCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _placement(node_id: int, prototype_id: int) -> Dictionary:
	return {"node_id": node_id, "prototype_id": prototype_id}


func _lane_search(
	bundle: BastionBlueprintBundle, team_id: int, placements: Array
) -> Dictionary:
	var lane: Dictionary = BastionPathGuard.lane_graph(bundle, team_id, placements)
	var nodes: PackedInt32Array = lane["nodes"]
	var edges: Array[Dictionary] = lane["edges"]
	var blocked: PackedInt32Array = lane["blocked"]
	var spawn_ids: PackedInt32Array = bundle.spawn_node_ids(team_id)
	return FixedGraphSearch.search(
		nodes,
		edges,
		blocked,
		spawn_ids[0],
		bundle.core_node_id(team_id),
		BastionPlayStubs.SEARCH_MAX_NODES,
		BastionPlayStubs.SEARCH_MAX_EDGES,
		BastionPlayStubs.SEARCH_MAX_EXPANSIONS
	)


func _lane_cost(bundle: BastionBlueprintBundle, team_id: int, placements: Array) -> int:
	return _cost(_lane_search(bundle, team_id, placements))


func _lane_path(
	bundle: BastionBlueprintBundle, team_id: int, placements: Array
) -> PackedInt32Array:
	return _path(_lane_search(bundle, team_id, placements))


func _search(
	nodes: PackedInt32Array,
	edges: Array[Dictionary],
	blocked: PackedInt32Array,
	start_id: int,
	goal_id: int
) -> Dictionary:
	return FixedGraphSearch.search(
		nodes, edges, blocked, start_id, goal_id, BUDGET, BUDGET, BUDGET
	)


func _status(result: Dictionary) -> int:
	var value: int = result["status"]
	return value


func _cost(result: Dictionary) -> int:
	var value: int = result["cost"]
	return value


func _path(result: Dictionary) -> PackedInt32Array:
	var value: PackedInt32Array = result["path"]
	return value
