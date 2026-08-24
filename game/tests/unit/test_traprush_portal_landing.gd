extends GutTest

## TraprushPortalLanding：follow 落点经 try_set_pose 落地；出口占用则等待，不相位穿透。
## CD-21 §4.2：出口被占用时等待确定性安全落点。max_hops 由调用方传入，本刀不锁定上限。
## 不调用 world.tick()，不从调用方 Dictionary 读客户端坐标。

const PortalLanding := preload("res://src/games/traprush/portal_landing.gd")
const PortalLink := preload("res://src/games/traprush/portal_link.gd")
const PortalGraph := preload("res://src/games/traprush/portal_graph.gd")
const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const FixedResultClass := preload("res://src/shared/fixed/fixed_result.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")

const QUARTER_TURN_BAM: int = 16384


func test_exit_lands_two_way_pair_that_follow_rejects() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var dest_x: int = _whole(3)
	var dest_y: int = _whole(4)
	var dest_z: int = _whole(5)
	var entity_id: int = world.spawn_capsule(0, 0, 0, 8, _whole(1), _whole(2))
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, dest_x, dest_y, dest_z, QUARTER_TURN_BAM))
	graph.add_link(PortalLink.new(2, 1, 0, 0, 0, 0))
	var followed: Dictionary = PortalLanding.try_land(world, entity_id, graph, 1, 1)
	assert_false(_ok(followed))
	_assert_pose(world, entity_id, 0, 0, 0, 8)
	var exited: Dictionary = PortalLanding.try_land_exit(world, entity_id, graph, 1)
	assert_true(_ok(exited))
	assert_true(_landed(exited))
	var dest_raw: Variant = exited.get("dest_id", -1)
	var dest_id: int = dest_raw
	assert_eq(dest_id, 2)
	_assert_pose(world, entity_id, dest_x, dest_y, dest_z, QUARTER_TURN_BAM)
	assert_eq(world.tick_index, 0)


func test_one_hop_lands_and_sets_dest_yaw() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var start_yaw: int = 8
	var dest_x: int = _whole(3)
	var dest_y: int = _whole(4)
	var dest_z: int = _whole(5)
	var entity_id: int = world.spawn_capsule(0, 0, 0, start_yaw, _whole(1), _whole(2))
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, dest_x, dest_y, dest_z, QUARTER_TURN_BAM))
	var result: Dictionary = PortalLanding.try_land(world, entity_id, graph, 1, 1)
	assert_true(_ok(result))
	assert_true(_landed(result))
	_assert_pose(world, entity_id, dest_x, dest_y, dest_z, QUARTER_TURN_BAM)
	assert_eq(world.tick_index, 0)


func test_occupied_capsule_waits_then_lands_when_clear() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var radius: int = _whole(1)
	var start_yaw: int = 8
	var dest_x: int = _whole(4)
	var dest_yaw: int = QUARTER_TURN_BAM
	var mover_id: int = world.spawn_capsule(0, 0, 0, start_yaw, radius, 0)
	var occupant_id: int = world.spawn_capsule(dest_x, 0, 0, 0, radius, 0)
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, dest_x, 0, 0, dest_yaw))
	var waiting: Dictionary = PortalLanding.try_land(world, mover_id, graph, 1, 1)
	assert_true(_ok(waiting))
	assert_false(_landed(waiting))
	_assert_pose(world, mover_id, 0, 0, 0, start_yaw)
	_assert_pose(world, occupant_id, dest_x, 0, 0, 0)
	assert_eq(world.tick_index, 0)
	assert_true(world.try_set_pose(occupant_id, _whole(20), 0, 0, 0))
	var landed: Dictionary = PortalLanding.try_land(world, mover_id, graph, 1, 1)
	assert_true(_ok(landed))
	assert_true(_landed(landed))
	_assert_pose(world, mover_id, dest_x, 0, 0, dest_yaw)
	assert_eq(world.tick_index, 0)


func test_static_box_at_exit_waits_without_moving() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var start_x: int = _whole(10)
	var start_yaw: int = 8
	var mover_id: int = world.spawn_capsule(start_x, 0, 0, start_yaw, _whole(1), _whole(2))
	assert_eq(world.spawn_static_box(0, 0, 0, _whole(1), _whole(1), _whole(1)), 1)
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, 0, 0, 0, QUARTER_TURN_BAM))
	var waiting: Dictionary = PortalLanding.try_land(world, mover_id, graph, 1, 1)
	assert_true(_ok(waiting))
	assert_false(_landed(waiting))
	_assert_pose(world, mover_id, start_x, 0, 0, start_yaw)
	assert_eq(world.tick_index, 0)


func test_follow_failure_does_not_move() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var start_x: int = 1
	var start_y: int = 2
	var start_z: int = 3
	var start_yaw: int = 4
	var entity_id: int = world.spawn_capsule(start_x, start_y, start_z, start_yaw)
	var cycled: PortalGraph = PortalGraph.new()
	cycled.add_link(PortalLink.new(1, 2, _whole(9), 0, 0, QUARTER_TURN_BAM))
	cycled.add_link(PortalLink.new(2, 1, 0, _whole(9), 0, 0))
	var cycle_result: Dictionary = PortalLanding.try_land(world, entity_id, cycled, 1, 3)
	assert_false(_ok(cycle_result))
	assert_false(cycle_result.has("landed"))
	_assert_pose(world, entity_id, start_x, start_y, start_z, start_yaw)
	var two_hop: PortalGraph = PortalGraph.new()
	two_hop.add_link(PortalLink.new(1, 2, _whole(1), 0, 0, 0))
	two_hop.add_link(PortalLink.new(2, 3, _whole(3), 0, 0, QUARTER_TURN_BAM))
	var hops_result: Dictionary = PortalLanding.try_land(world, entity_id, two_hop, 1, 1)
	assert_false(_ok(hops_result))
	_assert_pose(world, entity_id, start_x, start_y, start_z, start_yaw)
	var unknown: Dictionary = PortalLanding.try_land(world, entity_id, two_hop, 9, 2)
	assert_false(_ok(unknown))
	_assert_pose(world, entity_id, start_x, start_y, start_z, start_yaw)
	assert_eq(world.tick_index, 0)


func test_thin_wall_between_start_and_exit_still_teleports() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var radius: int = _whole(1)
	var dest_x: int = _whole(10)
	var dest_yaw: int = QUARTER_TURN_BAM
	var mover_id: int = world.spawn_capsule(0, 0, 0, 8, radius, _whole(2))
	assert_eq(world.spawn_static_box(_whole(5), 0, 0, 1, _whole(1), _whole(1)), 1)
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, dest_x, 0, 0, dest_yaw))
	var result: Dictionary = PortalLanding.try_land(world, mover_id, graph, 1, 1)
	assert_true(_ok(result))
	assert_true(_landed(result))
	_assert_pose(world, mover_id, dest_x, 0, 0, dest_yaw)
	assert_eq(world.tick_index, 0)


func test_null_world_graph_or_missing_pose_fails() -> void:
	var graph: PortalGraph = PortalGraph.new()
	graph.add_link(PortalLink.new(1, 2, _whole(3), 0, 0, QUARTER_TURN_BAM))
	var null_world: Dictionary = PortalLanding.try_land(null, 1, graph, 1, 1)
	assert_false(_ok(null_world))
	assert_false(null_world.has("landed"))
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(1, 2, 3, 4)
	var null_graph: Dictionary = PortalLanding.try_land(world, entity_id, null, 1, 1)
	assert_false(_ok(null_graph))
	_assert_pose(world, entity_id, 1, 2, 3, 4)
	var empty_graph: PortalGraph = PortalGraph.new()
	var empty_result: Dictionary = PortalLanding.try_land(world, entity_id, empty_graph, 1, 1)
	assert_false(_ok(empty_result))
	_assert_pose(world, entity_id, 1, 2, 3, 4)
	var missing: Dictionary = PortalLanding.try_land(world, 99, graph, 1, 1)
	assert_false(_ok(missing))
	_assert_pose(world, entity_id, 1, 2, 3, 4)
	assert_eq(world.tick_index, 0)


func _assert_pose(world: SimulationWorld, entity_id: int, x: int, y: int, z: int, yaw: int) -> void:
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	var pose_yaw: int = pose.get("yaw", -1)
	assert_eq(pose_x, x)
	assert_eq(pose_y, y)
	assert_eq(pose_z, z)
	assert_eq(pose_yaw, yaw)


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _landed(result: Dictionary) -> bool:
	var flag: bool = result.get("landed", false)
	return flag


func _whole(units: int) -> int:
	var converted: FixedResultClass = FixedClass.try_from_whole(units)
	assert_true(converted.ok)
	return converted.value
