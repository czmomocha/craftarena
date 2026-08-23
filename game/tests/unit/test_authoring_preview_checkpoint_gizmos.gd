extends GutTest

## Preview 检查点顺序 gizmos：有 transform 的 checkpoint 显示 order。
## 唯一 order 按升序连线；重复 order 只打标不进顺序链。无 transform 不画。

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


func test_unique_orders_draw_markers_and_sequence() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_checkpoint_record(2, 1, 2 * CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.checkpoint_count(), 2)
	assert_eq(_map.sequence_count(), 1)
	assert_eq(_map.checkpoint_node(1).text, "0")
	assert_eq(_map.checkpoint_node(2).text, "1")
	assert_eq(_map.checkpoint_node(1).modulate, Color(0.35, 0.9, 0.4))
	assert_almost_eq(_map.checkpoint_node(1).position.y, 1.15, EPS)
	var seq: MeshInstance3D = _map.sequence_node(1, 2)
	assert_not_null(seq)
	assert_almost_eq(seq.position.x, 1.0, EPS)
	assert_almost_eq(seq.position.y, 0.25, EPS)


func test_order_gap_still_connects_unique_stops() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_checkpoint_record(3, 2, 2 * CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.sequence_count(), 1)
	assert_not_null(_map.sequence_node(1, 3))


func test_duplicate_order_marks_without_sequence() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 1, 0, 0, 0)))
	assert_true(world.put(_checkpoint_record(2, 1, 2 * CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.checkpoint_count(), 2)
	assert_eq(_map.sequence_count(), 0)
	assert_eq(_map.checkpoint_node(1).text, "1")
	assert_eq(_map.checkpoint_node(2).text, "1")
	assert_eq(_map.checkpoint_node(1).modulate, Color(0.95, 0.3, 0.85))
	assert_null(_map.sequence_node(1, 2))


func test_checkpoint_without_transform_draws_nothing() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(SharedComponentRecord.create(1, {
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.mapped_count(), 0)
	assert_eq(_map.checkpoint_count(), 0)
	assert_eq(_map.sequence_count(), 0)


func test_remove_rebuilds_without_ghost_sequence() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_checkpoint_record(2, 1, CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_eq(_map.sequence_count(), 1)
	assert_true(world.remove(2))
	_map.rebuild(world)
	assert_eq(_map.checkpoint_count(), 1)
	assert_eq(_map.sequence_count(), 0)
	assert_null(_map.checkpoint_node(2))
	assert_null(_map.sequence_node(1, 2))


func test_shell_patch_sequence_and_failed_patch_leaves_no_ghost() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_shell)
	assert_true(_shell.open_from(session))
	assert_true(_shell.try_apply_patch(Levels.P2, _edit(1, 0, _place_checkpoint(1, 0, 0, 0, 0))))
	assert_eq(_shell.map.checkpoint_count(), 1)
	assert_false(_shell.try_apply_patch(Levels.P2, _edit(2, 1, _place_checkpoint(2, 1, 1, 0, 0))))
	assert_eq(_shell.map.checkpoint_count(), 1)
	assert_eq(_shell.map.sequence_count(), 0)
	assert_null(_shell.map.checkpoint_node(2))
	assert_false(_shell.allows_settlement())


func _checkpoint_record(entity_id: int, order: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {"order": order, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})


func _place_checkpoint(entity_id: int, order: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"checkpoint": {"order": order, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
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
		"trace-preview-checkpoint-gizmo",
		SharedCommand.Kind.EDIT
	)
