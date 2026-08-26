extends GutTest

## AuthoringPreviewMap：定点 transform 映射到米制占位盒；无 transform 不画。
## 占位盒是表现桩，不是碰撞体。失败补丁按回滚后的世界重建。

const AuthoringPreviewMap := preload("res://src/creator/authoring_preview_map.gd")
const AuthoringPreviewShell := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const Levels := preload("res://src/creator/preview_patch_levels.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const CELL: int = 65536
const EPS: float = 0.0001

var _map: AuthoringPreviewMap = null
var _shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_meters_and_yaw_conversion() -> void:
	assert_almost_eq(AuthoringPreviewMap.meters_from_fixed(CELL), 1.0, EPS)
	assert_almost_eq(AuthoringPreviewMap.meters_from_fixed(2 * CELL), 2.0, EPS)
	assert_almost_eq(AuthoringPreviewMap.meters_from_fixed(0), 0.0, EPS)
	assert_almost_eq(
		AuthoringPreviewMap.yaw_radians_from_bam(16384),
		PI / 2.0,
		EPS
	)
	assert_almost_eq(AuthoringPreviewMap.yaw_radians_from_bam(0), 0.0, EPS)


func test_rebuild_maps_transform_skips_health() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_transform(1, CELL, 0, 0, 0)))
	assert_true(world.put(_record_health(2, 3)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.mapped_count(), 1)
	var node: MeshInstance3D = _map.placeholder_node(1)
	assert_not_null(node)
	assert_null(_map.placeholder_node(2))
	assert_almost_eq(node.position.x, 1.0, EPS)
	assert_almost_eq(node.position.y, 0.0, EPS)
	assert_almost_eq(node.position.z, 0.0, EPS)
	var box: BoxMesh = node.mesh as BoxMesh
	assert_not_null(box)
	assert_almost_eq(box.size.x, 1.0, EPS)
	assert_almost_eq(box.size.y, 1.0, EPS)
	assert_almost_eq(box.size.z, 1.0, EPS)
	var camera: Camera3D = _map.get_node_or_null(AuthoringPreviewMap.CAMERA_NAME) as Camera3D
	assert_not_null(camera)
	assert_true(camera.current)


func test_yaw_maps_to_rotation_y() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_transform(1, 0, CELL, 2 * CELL, 16384)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	var node: MeshInstance3D = _map.placeholder_node(1)
	assert_almost_eq(node.position.y, 1.0, EPS)
	assert_almost_eq(node.position.z, 2.0, EPS)
	assert_almost_eq(node.rotation.y, PI / 2.0, EPS)


func test_remove_rebuilds_without_stale_node() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_transform(1, 0, 0, 0, 0)))
	assert_true(world.put(_record_transform(2, CELL, 0, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.mapped_count(), 2)
	assert_true(world.remove(2))
	_map.rebuild(world)
	assert_eq(_map.mapped_count(), 1)
	assert_not_null(_map.placeholder_node(1))
	assert_null(_map.placeholder_node(2))


func test_shell_open_maps_existing_transforms() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place_transform(1, CELL, 0, 0, 0))))
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_shell)
	assert_true(_shell.open_from(session))
	assert_true(_shell.window.own_world_3d)
	assert_eq(_shell.map.mapped_count(), 1)
	var node: MeshInstance3D = _shell.map.placeholder_node(1)
	assert_almost_eq(node.position.x, 1.0, EPS)


func test_patch_rebuilds_and_failed_patch_leaves_no_ghost() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_shell)
	assert_true(_shell.open_from(session))
	assert_eq(_shell.map.mapped_count(), 0)
	assert_true(_shell.try_apply_patch(Levels.P2, _edit(1, 0, _place_transform(3, 0, 0, CELL, 0))))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_almost_eq(_shell.map.placeholder_node(3).position.z, 1.0, EPS)
	assert_false(_shell.try_apply_patch(Levels.P2, _edit(2, 1, _place_off_lattice(4))))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_null(_shell.map.placeholder_node(4))
	assert_false(_shell.allows_settlement())
	assert_true(_shell.try_apply_patch(Levels.P2, _edit(3, 1, {"op": "remove", "entity_id": 3})))
	assert_eq(_shell.map.mapped_count(), 0)
	assert_eq(_shell.preview.world.entity_count(), 0)


func test_hazard_placeholder_uses_hazard_albedo() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_hazard(6, CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	var node: MeshInstance3D = _map.placeholder_node(6)
	assert_not_null(node)
	assert_eq(_placeholder_albedo(node), AuthoringPreviewMap.HAZARD_ALBEDO)
	_map.apply_hazard_visibility({6: false})
	assert_false(node.visible)
	_map.apply_hazard_visibility({6: true})
	assert_true(node.visible)


func test_solid_placeholder_uses_solid_albedo() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_solid(7, 0, -CELL, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	var node: MeshInstance3D = _map.placeholder_node(7)
	assert_not_null(node)
	assert_eq(_placeholder_albedo(node), AuthoringPreviewMap.SOLID_ALBEDO)
	assert_true(node.visible)


func _record_transform(entity_id: int, x: int, y: int, z: int, yaw_bam: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": yaw_bam},
	})


func _record_health(entity_id: int, current: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"health": {"current": current, "maximum": 10, "invuln_ticks": 0},
	})


func _record_hazard(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": 1},
	})


func _record_solid(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	var half: int = CELL / 2
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": ["solid"],
		},
	})


func _placeholder_albedo(node: MeshInstance3D) -> Color:
	var box: BoxMesh = node.mesh as BoxMesh
	var material: StandardMaterial3D = box.material as StandardMaterial3D
	return material.albedo_color


func _place_transform(entity_id: int, x: int, y: int, z: int, yaw_bam: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": yaw_bam},
			},
		},
	}


func _place_off_lattice(entity_id: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": 1, "y": 0, "z": 0, "yaw_bam": 0},
			},
		},
	}


func _edit(command_id: int, expected_revision: int, payload: Dictionary) -> SharedCommand:
	return SharedCommand.create(
		command_id,
		2,
		command_id,
		0,
		expected_revision,
		"content-v1",
		payload,
		"trace-preview-map",
		SharedCommand.Kind.EDIT
	)
