extends GutTest

## MatchCrateMap: compiled destructible poses → 1 m boxes.
## Snapshot durability hides destroyed or unlisted crates.
## Poses stay on the topology; snapshots never move a box.
## A null / missing / malformed bundle or crate list keeps the last map.

const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const MatchCrateMap := preload("res://src/client/match_crate_map.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchSnapshotFollow := preload("res://src/client/match_snapshot_follow.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_03_PATH: String = "res://content/official/traprush/course_03.json"
const CELL: int = 65536
const EPS: float = 0.0001

var _map: MatchCrateMap = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null


func test_official_course_01_maps_alive_crate() -> void:
	_map = MatchCrateMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_eq(_map.crate_count(), 1)
	assert_eq(_map.crate_total(), 1)
	assert_eq(_map.checkpoint_node_count(), 0)
	assert_eq(_map.standing_node_count(), 0)
	var crate: MeshInstance3D = _map.crate_node(40)
	assert_not_null(crate)
	assert_almost_eq(crate.position.x, 0.0, EPS)
	assert_almost_eq(crate.position.y, 0.0, EPS)
	assert_almost_eq(crate.position.z, 1.0, EPS)
	var box: BoxMesh = crate.mesh as BoxMesh
	assert_not_null(box)
	assert_almost_eq(box.size.x, 1.0, EPS)
	assert_false(_map.allows_settlement())
	assert_false(_map.allows_online_writes())
	var solids: Array = _map.live_solid_boxes()
	assert_eq(solids.size(), 1)
	var solid_raw: Variant = solids[0]
	assert_eq(typeof(solid_raw), TYPE_DICTIONARY)
	var solid: Dictionary = solid_raw
	assert_eq(_int(solid, "x"), 0)
	assert_eq(_int(solid, "y"), 0)
	assert_eq(_int(solid, "z"), CELL)
	assert_eq(_int(solid, "hx"), CELL / 2)
	assert_eq(_int(solid, "hy"), CELL / 2)
	assert_eq(_int(solid, "hz"), CELL / 2)


func test_official_courses_map_distinct_crate_layouts() -> void:
	_map = MatchCrateMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_almost_eq(_map.crate_node(40).position.z, 1.0, EPS)
	assert_true(_map.apply_path(COURSE_03_PATH))
	assert_eq(_map.crate_count(), 1)
	var crate: MeshInstance3D = _map.crate_node(40)
	assert_not_null(crate)
	assert_almost_eq(crate.position.x, 1.0, EPS)
	assert_almost_eq(crate.position.z, 0.0, EPS)


func test_empty_bundle_clears_crates() -> void:
	_map = MatchCrateMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	var empty: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(empty)
	assert_not_null(bundle)
	assert_true(_map.apply_bundle(bundle))
	assert_eq(_map.crate_count(), 0)
	assert_eq(_map.crate_total(), 0)
	assert_eq(_map.live_solid_boxes().size(), 0)
	assert_null(_map.crate_node(40))


func test_null_or_missing_path_keeps_previous_map() -> void:
	_map = MatchCrateMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_false(_map.apply_bundle(null))
	assert_false(_map.apply_path("res://content/official/traprush/missing_course.json"))
	assert_false(_map.apply_path(""))
	assert_eq(_map.crate_count(), 1)
	assert_almost_eq(_map.crate_node(40).position.z, 1.0, EPS)


func test_malformed_destructible_keeps_previous_map() -> void:
	_map = MatchCrateMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	var bundle: SimulationBundle = MatchCrateMap.compile_path(COURSE_01_PATH)
	assert_not_null(bundle)
	bundle.destructibles[0].erase("x")
	assert_false(_map.apply_bundle(bundle))
	assert_eq(_map.crate_count(), 1)
	assert_almost_eq(_map.crate_node(40).position.z, 1.0, EPS)


func test_snapshot_durability_hides_and_restores_without_moving() -> void:
	_map = MatchCrateMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_true(_map.apply_crates([_crate(40, 0)]))
	assert_eq(_map.crate_count(), 0)
	assert_eq(_map.crate_total(), 1)
	assert_eq(_map.live_solid_boxes().size(), 0)
	assert_null(_map.crate_node(40))
	assert_true(_map.apply_crates([_crate(40, 1)]))
	assert_eq(_map.crate_total(), 1)
	var crate: MeshInstance3D = _map.crate_node(40)
	assert_not_null(crate)
	assert_almost_eq(crate.position.x, 0.0, EPS)
	assert_almost_eq(crate.position.z, 1.0, EPS)


func test_empty_or_unlisted_snapshot_hides_topology_crates() -> void:
	_map = MatchCrateMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_true(_map.apply_crates([]))
	assert_eq(_map.crate_count(), 0)
	assert_eq(_map.live_solid_boxes().size(), 0)
	assert_true(_map.apply_crates([_crate(99, 1)]))
	assert_eq(_map.crate_count(), 0)
	assert_null(_map.crate_node(40))


func test_malformed_snapshot_or_follow_keeps_previous_map() -> void:
	_map = MatchCrateMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_false(_map.apply_crates([{"entity_id": 40}]))
	assert_eq(_map.crate_count(), 1)
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(follow.apply_frame(_snapshot(3, [_crate(40, 0)])))
	assert_true(_map.apply_follow(follow))
	assert_eq(_map.crate_count(), 0)
	var empty: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_false(_map.apply_follow(empty))
	assert_eq(_map.crate_count(), 0)
	assert_false(_map.apply_follow(null))
	assert_false(_map.apply_crates([_crate(40, 1), _crate(40, 1)]))
	assert_eq(_map.crate_count(), 0)


func test_follow_without_course_does_not_invent_poses() -> void:
	_map = MatchCrateMap.new()
	add_child(_map)
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(follow.apply_frame(_snapshot(1, [_crate(40, 1)])))
	assert_false(_map.apply_follow(follow))
	assert_eq(_map.crate_count(), 0)


func _crate(entity_id: int, durability: int) -> Dictionary:
	return {
		"entity_id": entity_id,
		"durability": durability,
	}


func _snapshot(tick: int, crates: Array[Dictionary]) -> PackedByteArray:
	var players: Array[Dictionary] = [{
		"x": 0,
		"y": 0,
		"z": 0,
		"yaw_bam": 0,
		"accepted_count": 0,
		"finish_tick": -1,
	}]
	return MatchFrameCodec.encode_snapshot(tick, players, crates)


func _int(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, -1)
	if typeof(raw) != TYPE_INT:
		return -1
	return raw
