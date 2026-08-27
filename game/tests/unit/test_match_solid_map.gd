extends GutTest

## MatchSolidMap: compiled always-solid poses → 1 m stone boxes.
## Boxes stay visible; they never toggle with tick.
## A null / missing / malformed bundle keeps the last map.

const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const MatchLocalPredict := preload("res://src/client/match_local_predict.gd")
const MatchSolidMap := preload("res://src/client/match_solid_map.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_03_PATH: String = "res://content/official/traprush/course_03.json"
const CELL: int = 65536
const HALF: int = 32768
const EPS: float = 0.0001
const SOLID_ID: int = 70

var _map: MatchSolidMap = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null


func test_official_courses_map_path_floors() -> void:
	_map = MatchSolidMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_01_PATH))
	assert_eq(_map.solid_count(), 8)
	assert_eq(_map.solid_total(), 8)
	assert_eq(_map.live_solid_boxes().size(), 8)
	assert_eq(_map.crate_node_count(), 0)
	assert_eq(_map.hazard_node_count(), 0)
	var node: MeshInstance3D = _map.solid_node(70)
	assert_not_null(node)
	assert_almost_eq(node.position.x, -1.0, EPS)
	assert_eq(_albedo(node), MatchSolidMap.SOLID_ALBEDO)
	var footing: MeshInstance3D = _map.solid_node(80)
	assert_not_null(footing)
	assert_almost_eq(footing.position.x, 0.0, EPS)
	assert_almost_eq(footing.position.y, -1.0, EPS)
	assert_almost_eq(footing.position.z, 0.0, EPS)
	assert_true(_map.apply_path(COURSE_03_PATH))
	assert_eq(_map.solid_count(), 14)
	assert_eq(_map.solid_total(), 14)
	assert_false(_map.allows_online_writes())


func test_compiled_solid_maps_always_visible() -> void:
	_map = MatchSolidMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_solid_bundle()))
	assert_eq(_map.solid_count(), 1)
	assert_eq(_map.solid_total(), 1)
	var node: MeshInstance3D = _map.solid_node(SOLID_ID)
	assert_not_null(node)
	assert_almost_eq(node.position.x, 1.0, EPS)
	assert_almost_eq(node.position.y, 0.0, EPS)
	assert_almost_eq(node.position.z, 0.0, EPS)
	var box: BoxMesh = node.mesh as BoxMesh
	assert_not_null(box)
	assert_almost_eq(box.size.x, 1.0, EPS)
	assert_eq(_albedo(node), MatchSolidMap.SOLID_ALBEDO)
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


func test_empty_bundle_clears_solids() -> void:
	_map = MatchSolidMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_solid_bundle()))
	var empty: AuthoringWorld = AuthoringWorld.new()
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(empty)
	assert_not_null(bundle)
	assert_true(_map.apply_bundle(bundle))
	assert_eq(_map.solid_count(), 0)
	assert_eq(_map.solid_total(), 0)
	assert_eq(_map.live_solid_boxes().size(), 0)
	assert_null(_map.solid_node(SOLID_ID))


func test_null_or_missing_path_keeps_previous_map() -> void:
	_map = MatchSolidMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_solid_bundle()))
	assert_false(_map.apply_bundle(null))
	assert_eq(_map.solid_count(), 1)
	assert_false(_map.apply_path(""))
	assert_eq(_map.solid_count(), 1)
	assert_not_null(_map.solid_node(SOLID_ID))


func test_live_solid_boxes_block_own_slot_overlay() -> void:
	_map = MatchSolidMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_solid_bundle()))
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


func _solid_bundle() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_solid_record(SOLID_ID, CELL, 0, 0)))
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


func _solid_record(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	var half: int = CELL / 2
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": [TraprushTopologyCompiler.SOLID_ZONE_TAG],
		},
	})


func _player(slot: int, x: int, z: int) -> Dictionary:
	return {
		"slot": slot,
		"x": x,
		"y": 0,
		"z": z,
		"yaw_bam": 0,
		"accepted_count": 0,
		"finish_tick": -1,
	}


func _first(result: Dictionary) -> Dictionary:
	var players_raw: Variant = result.get("players", [])
	if typeof(players_raw) != TYPE_ARRAY:
		return {}
	var players: Array = players_raw
	if players.is_empty():
		return {}
	var raw: Variant = players[0]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func _ok(result: Dictionary) -> bool:
	return result.get("ok", false)


func _int(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	return raw


func _albedo(node: MeshInstance3D) -> Color:
	var box: BoxMesh = node.mesh as BoxMesh
	var material: StandardMaterial3D = box.material as StandardMaterial3D
	return material.albedo_color
