extends GutTest

## Presentation-only cutaway: solids above the followed player are faded when
## they cover the player's column or sit between the camera and the player.
## A floor that is only ahead of the player must stay opaque.
## `live_solid_boxes` must stay unchanged so prediction and authority do not
## see the cutaway.

const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const MatchSolidMap := preload("res://src/client/match_solid_map.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const CELL: int = 65536
const COURSE_07_PATH: String = "res://content/official/traprush/course_07.json"
const FLOOR_ID: int = 70
const OVERHEAD_ID: int = 71
const SIGHT_ID: int = 72
const FAR_ID: int = 73
const AHEAD_ID: int = 74

var _map: MatchSolidMap = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null


func test_ids_for_cutaway_fades_column_and_sight_line_only() -> void:
	var poses: Array[Dictionary] = []
	poses.append({"entity_id": FLOOR_ID, "x": 0, "y": 0, "z": 0})
	poses.append({"entity_id": OVERHEAD_ID, "x": 0, "y": CELL, "z": 0})
	poses.append({"entity_id": SIGHT_ID, "x": CELL, "y": CELL, "z": CELL})
	poses.append({"entity_id": FAR_ID, "x": 8 * CELL, "y": 2 * CELL, "z": -8 * CELL})
	poses.append({"entity_id": AHEAD_ID, "x": -10 * CELL, "y": CELL, "z": -10 * CELL})
	var hidden: Dictionary = MatchSolidMapOcclusion.ids_for_cutaway(
		poses, CELL, Vector3(6.0, 8.0, 6.0), Vector3.ZERO
	)
	assert_false(hidden.has(FLOOR_ID), "supporting floor stays visible")
	assert_true(hidden.has(OVERHEAD_ID), "platform covering the player's head is faded")
	assert_true(hidden.has(SIGHT_ID), "solid on the camera-to-player line is faded")
	assert_false(hidden.has(AHEAD_ID), "upper floor only ahead of the player stays opaque")
	assert_false(hidden.has(FAR_ID), "unrelated high solid stays visible")


func test_update_fades_only_presentation_and_clear_restores_it() -> void:
	_map = MatchSolidMap.new()
	add_child(_map)
	assert_true(_map.apply_bundle(_occlusion_bundle()))
	assert_eq(_map.live_solid_boxes().size(), 5)
	assert_true(_map.solid_node(OVERHEAD_ID).visible)
	assert_true(_map.solid_node(SIGHT_ID).visible)
	var camera: Vector3 = Vector3(6.0, 8.0, 6.0)
	var focus: Vector3 = Vector3.ZERO
	var hidden_count: int = _map.occlusion.update(_map, camera, focus, true)
	assert_eq(hidden_count, 2)
	assert_eq(_map.occlusion.count(), 2)
	assert_true(_map.solid_node(OVERHEAD_ID).visible)
	assert_true(_map.solid_node(SIGHT_ID).visible)
	_assert_faded(OVERHEAD_ID)
	_assert_opaque(AHEAD_ID)
	assert_true(_map.solid_node(FLOOR_ID).visible)
	assert_true(_map.solid_node(FAR_ID).visible)
	_assert_opaque(FLOOR_ID)
	_assert_opaque(FAR_ID)
	assert_eq(_map.live_solid_boxes().size(), 5, "cutaway never edits authority occupancy")
	_map.occlusion.clear(_map)
	assert_eq(_map.occlusion.count(), 0)
	assert_true(_map.solid_node(OVERHEAD_ID).visible)
	assert_true(_map.solid_node(SIGHT_ID).visible)
	_assert_opaque(OVERHEAD_ID)
	_assert_opaque(AHEAD_ID)
	_map.occlusion.update(_map, camera, focus, true)
	assert_true(_map.solid_node(OVERHEAD_ID).visible)
	_assert_faded(OVERHEAD_ID)
	assert_eq(
		_map.occlusion.update(_map, camera, focus, false),
		0
	)
	assert_true(_map.solid_node(OVERHEAD_ID).visible)
	_assert_opaque(OVERHEAD_ID)


func test_course_07_next_band_stays_opaque_at_spawn() -> void:
	_map = MatchSolidMap.new()
	add_child(_map)
	assert_true(_map.apply_path(COURSE_07_PATH))
	var next_band_id: int = _entity_at(_map._poses, 50, -5, 50)
	var support_id: int = _entity_at(_map._poses, 60, -7, 60)
	assert_gt(next_band_id, 0)
	assert_gt(support_id, 0)
	var hidden_count: int = _map.occlusion.update(
		_map, Vector3(66.0, 2.0, 66.0), Vector3(60.0, -6.0, 60.0), true
	)
	assert_eq(hidden_count, 0, "nothing occludes the spawn, so nothing is faded")
	assert_true(_map.solid_node(next_band_id).visible)
	_assert_opaque(next_band_id)
	assert_true(_map.solid_node(support_id).visible)
	_assert_opaque(support_id)
	assert_eq(_map.live_solid_boxes().size(), _map.solid_total())


func _assert_faded(entity_id: int) -> void:
	var node: MeshInstance3D = _map.solid_node(entity_id)
	assert_not_null(node)
	if node == null:
		return
	var visual: Node3D = node.get_node_or_null("visual") as Node3D
	if visual != null:
		assert_false(visual.visible, "detailed tile is replaced by the ghost")
	assert_eq(node.layers, 1, "placeholder box is rendered for the cutaway")
	assert_almost_eq(node.transparency, 0.0, 0.0001, "Compatibility ignores this property")
	var material: StandardMaterial3D = node.material_override as StandardMaterial3D
	assert_not_null(material)
	if material != null:
		assert_almost_eq(
			material.albedo_color.a,
			1.0 - MatchSolidMapOcclusion.CUTAWAY_TRANSPARENCY,
			0.0001
		)


func _assert_opaque(entity_id: int) -> void:
	var node: MeshInstance3D = _map.solid_node(entity_id)
	assert_not_null(node)
	if node == null:
		return
	var visual: Node3D = node.get_node_or_null("visual") as Node3D
	if visual != null:
		assert_true(visual.visible, "detailed tile returns after the cutaway")
		assert_eq(node.layers, 0)
	assert_null(node.material_override)


func _occlusion_bundle() -> SimulationBundle:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0)))
	assert_true(world.put(_solid_record(FLOOR_ID, 0, 0, 0)))
	assert_true(world.put(_solid_record(OVERHEAD_ID, 0, CELL, 0)))
	assert_true(world.put(_solid_record(SIGHT_ID, CELL, CELL, CELL)))
	assert_true(world.put(_solid_record(FAR_ID, 8 * CELL, 2 * CELL, -8 * CELL)))
	assert_true(world.put(_solid_record(AHEAD_ID, -10 * CELL, CELL, -10 * CELL)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	return bundle


func _checkpoint_record(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": 0,
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


func _entity_at(poses: Array[Dictionary], x: int, y: int, z: int) -> int:
	for pose: Dictionary in poses:
		var x_raw: Variant = pose.get("x", -1)
		var y_raw: Variant = pose.get("y", -1)
		var z_raw: Variant = pose.get("z", -1)
		if typeof(x_raw) != TYPE_INT or typeof(y_raw) != TYPE_INT or typeof(z_raw) != TYPE_INT:
			continue
		var pose_x: int = x_raw
		var pose_y: int = y_raw
		var pose_z: int = z_raw
		if pose_x != x * CELL:
			continue
		if pose_y != y * CELL:
			continue
		if pose_z == z * CELL:
			var id_raw: Variant = pose.get("entity_id", 0)
			if typeof(id_raw) == TYPE_INT:
				var entity_id: int = id_raw
				return entity_id
	return 0
