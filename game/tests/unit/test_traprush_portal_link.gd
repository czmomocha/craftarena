extends GutTest

## TraprushPortalLink / TraprushPortalGraph：出口落点为 Q48.16，传送链 hops 由调用方传入。
## CD-21 §4.2：出口有稳定 ID、朝向、安全落点；链长有上限，禁止无限循环。上限数值未锁定。

const PortalLink := preload("res://src/games/traprush/portal_link.gd")
const PortalGraph := preload("res://src/games/traprush/portal_graph.gd")

const ONE_METER_Q48_16: int = 65536
const QUARTER_TURN_BAM: int = 16384


func test_link_stores_fixed_point_landing_not_float_meters() -> void:
	var link: PortalLink = PortalLink.new(1, 2, ONE_METER_Q48_16, 0, -ONE_METER_Q48_16, QUARTER_TURN_BAM)
	assert_eq(link.source_id, 1)
	assert_eq(link.dest_id, 2)
	assert_eq(link.x, ONE_METER_Q48_16)
	assert_eq(link.y, 0)
	assert_eq(link.z, -ONE_METER_Q48_16)
	assert_eq(link.dest_yaw_bam, QUARTER_TURN_BAM)
	var pose: Dictionary = link.apply()
	var dest_id: int = pose.get("dest_id", 0)
	var x: int = pose.get("x", 0)
	var y: int = pose.get("y", 0)
	var z: int = pose.get("z", 0)
	var yaw: int = pose.get("dest_yaw_bam", 0)
	assert_eq(dest_id, 2)
	assert_eq(x, ONE_METER_Q48_16)
	assert_eq(y, 0)
	assert_eq(z, -ONE_METER_Q48_16)
	assert_eq(yaw, QUARTER_TURN_BAM)


func test_exit_lands_two_way_pair_that_follow_rejects() -> void:
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, ONE_METER_Q48_16, 131072, 0, 0))
	graph.add_link(PortalLink.new(2, 1, 0, 0, 0, QUARTER_TURN_BAM))
	var followed: Dictionary = graph.follow(1, 1)
	assert_false(_ok(followed))
	var exited: Dictionary = graph.try_exit(1)
	assert_true(_ok(exited))
	assert_eq(_int_field(exited, "dest_id"), 2)
	assert_eq(_int_field(exited, "x"), ONE_METER_Q48_16)
	assert_eq(_int_field(exited, "y"), 131072)
	assert_eq(_int_field(exited, "z"), 0)
	var reverse: Dictionary = graph.try_exit(2)
	assert_true(_ok(reverse))
	assert_eq(_int_field(reverse, "dest_id"), 1)
	assert_false(_ok(graph.try_exit(9)))


func test_follow_one_hop_lands_on_dest() -> void:
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, ONE_METER_Q48_16, 131072, 0, 0))
	var landed: Dictionary = graph.follow(1, 1)
	assert_true(_ok(landed))
	assert_eq(_int_field(landed, "dest_id"), 2)
	assert_eq(_int_field(landed, "x"), ONE_METER_Q48_16)
	assert_eq(_int_field(landed, "y"), 131072)
	assert_eq(_int_field(landed, "z"), 0)
	assert_eq(_int_field(landed, "dest_yaw_bam"), 0)


func test_follow_two_hops_when_caller_allows_two() -> void:
	var graph: PortalGraph = _chain_three()
	var too_short: Dictionary = graph.follow(1, 1)
	assert_false(_ok(too_short))
	var landed: Dictionary = graph.follow(1, 2)
	assert_true(_ok(landed))
	assert_eq(_int_field(landed, "dest_id"), 3)
	assert_eq(_int_field(landed, "x"), 3 * ONE_METER_Q48_16)
	var extra_budget: Dictionary = graph.follow(1, 3)
	assert_true(_ok(extra_budget))
	assert_eq(_int_field(extra_budget, "dest_id"), 3)


func test_follow_fails_when_chain_exceeds_max_hops() -> void:
	var graph: PortalGraph = _chain_three()
	graph.add_link(PortalLink.new(3, 4, 4 * ONE_METER_Q48_16, 0, 0, 0))
	var two: Dictionary = graph.follow(1, 2)
	assert_false(_ok(two))
	var three: Dictionary = graph.follow(1, 3)
	assert_true(_ok(three))
	assert_eq(_int_field(three, "dest_id"), 4)


func test_follow_fails_on_cycle_back_to_visited_portal_id() -> void:
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, ONE_METER_Q48_16, 0, 0, 0))
	graph.add_link(PortalLink.new(2, 1, 0, ONE_METER_Q48_16, 0, 0))
	var cycled: Dictionary = graph.follow(1, 3)
	assert_false(_ok(cycled))
	var self_loop: PortalGraph = PortalGraph.new()
	self_loop.add_link(PortalLink.new(8, 8, 0, 0, 0, 0))
	var looped: Dictionary = self_loop.follow(8, 1)
	assert_false(_ok(looped))


func test_follow_unknown_start_or_non_positive_hops_fails() -> void:
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, 0, 0, 0, 0))
	assert_false(_ok(graph.follow(9, 1)))
	assert_false(_ok(graph.follow(1, 0)))
	assert_false(_ok(graph.follow(1, -1)))


func _chain_three() -> PortalGraph:
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, ONE_METER_Q48_16, 0, 0, 0))
	graph.add_link(PortalLink.new(2, 3, 3 * ONE_METER_Q48_16, 0, 0, QUARTER_TURN_BAM))
	return graph


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _int_field(result: Dictionary, key: String) -> int:
	var value: int = result.get(key, 0)
	return value
