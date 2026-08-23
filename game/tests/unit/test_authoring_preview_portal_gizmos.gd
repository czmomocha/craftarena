extends GutTest

## Preview 传送连线 gizmos：two_way / one_way 画线；dangling 只在源点打标。
## 不把悬空画到原点。无 transform 的 portal 不画。检查点顺序不是本刀。

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


func test_two_way_pair_draws_two_links_no_dangle() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_portal_record(1, 2, 0, 0, 0)))
	assert_true(world.put(_portal_record(2, 1, 2 * CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.mapped_count(), 2)
	assert_eq(_map.link_count(), 2)
	assert_eq(_map.dangle_count(), 0)
	var link: MeshInstance3D = _map.link_node(1)
	assert_not_null(link)
	assert_almost_eq(link.position.x, 1.0, EPS)
	assert_almost_eq(link.position.y, 0.0, EPS)
	assert_almost_eq(link.position.z, 0.0, EPS)
	assert_null(_map.direction_node(1))
	assert_null(_map.dangle_node(1))


func test_one_way_draws_link_and_direction_marker() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_portal_record(1, 2, 0, 0, 0)))
	assert_true(world.put(_portal_record(2, 9, 2 * CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.link_count(), 1)
	assert_eq(_map.dangle_count(), 1)
	var link: MeshInstance3D = _map.link_node(1)
	assert_almost_eq(link.position.x, 1.0, EPS)
	assert_not_null(_map.direction_node(1))
	assert_almost_eq(_map.direction_node(1).position.x, 1.6, EPS)
	assert_almost_eq(_map.direction_node(1).position.y, 0.15, EPS)
	assert_null(_map.link_node(2))
	assert_almost_eq(_map.dangle_node(2).position.x, 2.0, EPS)
	assert_almost_eq(_map.dangle_node(2).position.y, 0.7, EPS)


func test_dangling_marks_source_not_origin() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_portal_record(1, 99, 2 * CELL, 0, CELL)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.link_count(), 0)
	assert_eq(_map.dangle_count(), 1)
	assert_null(_map.link_node(1))
	var dangle: MeshInstance3D = _map.dangle_node(1)
	assert_almost_eq(dangle.position.x, 2.0, EPS)
	assert_almost_eq(dangle.position.y, 0.7, EPS)
	assert_almost_eq(dangle.position.z, 1.0, EPS)
	assert_eq(_map.mapped_count(), 1)


func test_portal_without_transform_draws_nothing() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(SharedComponentRecord.create(1, {
		"portal": {"target_id": 9, "yaw_bam": 0, "cooldown_ticks": 0},
	})))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.mapped_count(), 0)
	assert_eq(_map.link_count(), 0)
	assert_eq(_map.dangle_count(), 0)


func test_remove_dest_rebuilds_to_dangle_without_ghost_link() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_portal_record(1, 2, 0, 0, 0)))
	assert_true(world.put(_portal_record(2, 1, CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.link_count(), 2)
	assert_true(world.remove(2))
	_map.rebuild(world)
	assert_eq(_map.mapped_count(), 1)
	assert_eq(_map.link_count(), 0)
	assert_eq(_map.dangle_count(), 1)
	assert_null(_map.link_node(1))
	assert_null(_map.link_node(2))
	assert_not_null(_map.dangle_node(1))


func test_shell_patch_links_and_failed_patch_leaves_no_ghost() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_shell)
	assert_true(_shell.open_from(session))
	assert_eq(_shell.map.link_count(), 0)
	assert_true(_shell.try_apply_patch(Levels.P2, _edit(1, 0, _place_portal(1, 99, CELL, 0, 0))))
	assert_eq(_shell.map.dangle_count(), 1)
	assert_almost_eq(_shell.map.dangle_node(1).position.x, 1.0, EPS)
	assert_almost_eq(_shell.map.dangle_node(1).position.y, 0.7, EPS)
	assert_false(_shell.try_apply_patch(Levels.P2, _edit(2, 1, _place_portal(2, 1, 1, 0, 0))))
	assert_eq(_shell.map.mapped_count(), 1)
	assert_eq(_shell.map.link_count(), 0)
	assert_eq(_shell.map.dangle_count(), 1)
	assert_null(_shell.map.placeholder_node(2))
	assert_false(_shell.allows_settlement())


func _portal_record(entity_id: int, target_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
	})


func _place_portal(entity_id: int, target_id: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
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
		"trace-preview-portal-gizmo",
		SharedCommand.Kind.EDIT
	)
