extends GutTest

## MatchHazardMap: compiled hazard poses → 1 m boxes.
## Tick solid half shows the box; open half hides it.
## Poses stay on the topology; snapshots never move a box.
## A null / missing / malformed bundle keeps the last map.

const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const HazardCycle := preload("res://src/games/traprush/hazard_cycle.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchHazardMap := preload("res://src/client/match_hazard_map.gd")
const MatchLocalPredict := preload("res://src/client/match_local_predict.gd")
const MatchSnapshotFollow := preload("res://src/client/match_snapshot_follow.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_03_PATH: String = "res://content/official/traprush/course_03.json"
const CELL: int = 65536
const HALF: int = 32768
const EPS: float = 0.0001
const HAZARD_ID: int = 50

var _map: MatchHazardMap = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null


func test_official_courses_map_one_hazard() -> void:
	_map = MatchHazardMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_eq(_map.hazard_count(), 1)
	assert_eq(_map.hazard_total(), 1)
	assert_eq(_map.live_solid_boxes().size(), 1)
	assert_eq(_map.crate_node_count(), 0)
	assert_null(_map.hazard_node(50))
	var node: MeshInstance3D = _map.hazard_node(60)
	assert_not_null(node)
	assert_almost_eq(node.position.z, -2.0, EPS)
	assert_eq(_albedo(node), MatchHazardMap.HAZARD_ALBEDO)
	assert_true(_map.apply_path(COURSE_03_PATH))
	assert_eq(_map.hazard_count(), 1)
	assert_eq(_map.hazard_total(), 1)
	assert_false(_map.allows_settlement())
	assert_false(_map.allows_online_writes())


func test_compiled_hazard_maps_solid_at_tick_zero() -> void:
	_map = MatchHazardMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_hazard_bundle(1)))
	assert_eq(_map.hazard_count(), 1)
	assert_eq(_map.hazard_total(), 1)
	var node: MeshInstance3D = _map.hazard_node(HAZARD_ID)
	assert_not_null(node)
	assert_almost_eq(node.position.x, 1.0, EPS)
	assert_almost_eq(node.position.y, 0.0, EPS)
	assert_almost_eq(node.position.z, 0.0, EPS)
	var box: BoxMesh = node.mesh as BoxMesh
	assert_not_null(box)
	assert_almost_eq(box.size.x, 1.0, EPS)
	assert_eq(_albedo(node), MatchHazardMap.HAZARD_ALBEDO)
	var solids: Array = _map.live_solid_boxes()
	assert_eq(solids.size(), 1)
	var solid_raw: Variant = solids[0]
	assert_eq(typeof(solid_raw), TYPE_DICTIONARY)
	var solid: Dictionary = solid_raw
	assert_eq(_int(solid, "x"), CELL)
	assert_eq(_int(solid, "y"), 0)
	assert_eq(_int(solid, "z"), 0)
	assert_eq(_int(solid, "hx"), HALF)
	assert_eq(_int(solid, "hy"), HALF)
	assert_eq(_int(solid, "hz"), HALF)


func test_tick_hides_open_half_and_restores_without_moving() -> void:
	_map = MatchHazardMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_hazard_bundle(1)))
	assert_true(HazardCycle.is_solid(0, 1))
	assert_false(HazardCycle.is_solid(1, 1))
	assert_true(_map.apply_tick(1))
	assert_eq(_map.hazard_count(), 0)
	assert_eq(_map.hazard_total(), 1)
	assert_eq(_map.live_solid_boxes().size(), 0)
	assert_null(_map.hazard_node(HAZARD_ID))
	assert_true(_map.apply_tick(2))
	assert_eq(_map.hazard_total(), 1)
	var node: MeshInstance3D = _map.hazard_node(HAZARD_ID)
	assert_not_null(node)
	assert_almost_eq(node.position.x, 1.0, EPS)
	assert_eq(_map.live_solid_boxes().size(), 1)


func test_always_solid_when_cooldown_below_one() -> void:
	_map = MatchHazardMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_hazard_bundle(0)))
	assert_true(_map.apply_tick(7))
	assert_eq(_map.hazard_count(), 1)
	assert_eq(_map.live_solid_boxes().size(), 1)


func test_empty_bundle_clears_hazards() -> void:
	_map = MatchHazardMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_hazard_bundle(1)))
	var empty: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(empty)
	assert_not_null(bundle)
	assert_true(_map.apply_bundle(bundle))
	assert_eq(_map.hazard_count(), 0)
	assert_eq(_map.hazard_total(), 0)
	assert_eq(_map.live_solid_boxes().size(), 0)
	assert_null(_map.hazard_node(HAZARD_ID))


func test_null_or_missing_path_keeps_previous_map() -> void:
	_map = MatchHazardMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_hazard_bundle(1)))
	assert_false(_map.apply_bundle(null))
	assert_false(_map.apply_path("res://content/official/traprush/missing_course.json"))
	assert_false(_map.apply_path(""))
	assert_eq(_map.hazard_count(), 1)
	assert_almost_eq(_map.hazard_node(HAZARD_ID).position.x, 1.0, EPS)


func test_malformed_hazard_keeps_previous_map() -> void:
	_map = MatchHazardMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_hazard_bundle(1)))
	var bundle: SimulationBundle = _hazard_bundle(1)
	bundle.hazards[0].erase("x")
	assert_false(_map.apply_bundle(bundle))
	assert_eq(_map.hazard_count(), 1)
	var negative: SimulationBundle = _hazard_bundle(1)
	negative.hazards[0]["cooldown_ticks"] = -1
	assert_false(_map.apply_bundle(negative))
	assert_eq(_map.hazard_count(), 1)


func test_follow_tick_toggles_and_missing_follow_keeps_map() -> void:
	_map = MatchHazardMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_hazard_bundle(1)))
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(follow.apply_frame(_snapshot(1)))
	assert_true(_map.apply_follow(follow))
	assert_eq(_map.hazard_count(), 0)
	var empty: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_false(_map.apply_follow(empty))
	assert_eq(_map.hazard_count(), 0)
	assert_false(_map.apply_follow(null))
	assert_false(_map.apply_tick(-1))
	assert_eq(_map.hazard_count(), 0)


func test_follow_without_course_does_not_invent_poses() -> void:
	_map = MatchHazardMap.new()
	add_child(_map)
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(follow.apply_frame(_snapshot(0)))
	assert_false(_map.apply_follow(follow))
	assert_eq(_map.hazard_count(), 0)


func test_live_solid_boxes_block_own_slot_overlay() -> void:
	_map = MatchHazardMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_hazard_bundle(1)))
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(1)
	assert_true(predict.try_add_move(CELL, 0))
	var blocked: Dictionary = predict.try_apply(
		[_player(0, 0, 0)],
		[_player(0, 0, 0)],
		_map.live_solid_boxes()
	)
	assert_true(_ok(blocked))
	assert_eq(_int(_first(blocked), "x"), 0)
	assert_eq(predict.dx, CELL)
	assert_true(_map.apply_tick(1))
	var opened: Dictionary = predict.try_apply(
		[_player(0, 0, 0)],
		[_player(0, 0, 0)],
		_map.live_solid_boxes()
	)
	assert_true(_ok(opened))
	assert_eq(_int(_first(opened), "x"), CELL)


func _hazard_bundle(cooldown_ticks: int) -> SimulationBundle:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_hazard_record(HAZARD_ID, CELL, 0, 0, cooldown_ticks)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _checkpoint_record(entity_id: int, order: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": order,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})


func _hazard_record(
	entity_id: int,
	x: int,
	y: int,
	z: int,
	cooldown_ticks: int
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": cooldown_ticks},
	})


func _player(x: int, y: int, z: int) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"z": z,
		"yaw_bam": 0,
		"accepted_count": 0,
		"finish_tick": -1,
	}


func _snapshot(tick: int) -> PackedByteArray:
	var players: Array[Dictionary] = [_player(0, 0, 0)]
	return MatchFrameCodec.encode_snapshot(tick, players, [])


func _ok(applied: Dictionary) -> bool:
	var raw: Variant = applied.get("ok", false)
	return raw == true


func _players(applied: Dictionary) -> Array:
	var raw: Variant = applied.get("players", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw


func _first(applied: Dictionary) -> Dictionary:
	var players: Array = _players(applied)
	if players.is_empty():
		return {}
	var raw: Variant = players[0]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func _int(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, -1)
	if typeof(raw) != TYPE_INT:
		return -1
	return raw


func _albedo(node: MeshInstance3D) -> Color:
	var box: BoxMesh = node.mesh as BoxMesh
	var material: StandardMaterial3D = box.material as StandardMaterial3D
	return material.albedo_color
