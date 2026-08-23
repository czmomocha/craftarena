extends GutTest

## Preview 可达性叠加：rebuild 时只读 evaluate，把问题码标到有 transform 的实体上。
## 不在 try_apply 上拒绝。无 transform 不画。失败补丁不留幽灵。走路可达不是本刀。

const AuthoringPreviewMap := preload("res://src/creator/authoring_preview_map.gd")
const AuthoringPreviewShell := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringReachabilityCodes := preload("res://src/creator/authoring_reachability_codes.gd")
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


func test_publish_ready_checkpoint_has_no_overlay() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_true(_map.reachability_ok())
	assert_eq(_map.reachability_issue_count(), 0)
	assert_eq(_map.overlay_count(), 0)
	assert_eq(_map.unreachable_seg_count(), 0)


func test_dangling_overlay_marks_source_not_origin() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_portal_record(8, 9, 2 * CELL, 0, CELL)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_false(_map.reachability_ok())
	assert_eq(_map.reachability_issue_count(), 1)
	assert_eq(_map.overlay_count(), 1)
	var mark: Label3D = _map.overlay_node(8, AuthoringReachabilityCodes.DANGLING_PORTAL)
	assert_not_null(mark)
	assert_eq(mark.text, AuthoringReachabilityCodes.DANGLING_PORTAL)
	assert_almost_eq(mark.position.x, 2.0, EPS)
	assert_almost_eq(mark.position.y, 1.7, EPS)
	assert_almost_eq(mark.position.z, 1.0, EPS)
	assert_null(_map.overlay_node(1, AuthoringReachabilityCodes.DANGLING_PORTAL))


func test_unreachable_floor_step_draws_marks_and_segment() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_checkpoint_record(2, 1, 0, CELL, 2 * CELL)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_false(_map.reachability_ok())
	assert_eq(_map.overlay_count(), 2)
	assert_eq(_map.unreachable_seg_count(), 1)
	assert_eq(
		_map.overlay_node(1, AuthoringReachabilityCodes.UNREACHABLE_CHECKPOINT).text,
		AuthoringReachabilityCodes.UNREACHABLE_CHECKPOINT
	)
	assert_not_null(_map.overlay_node(2, AuthoringReachabilityCodes.UNREACHABLE_CHECKPOINT))
	var seg: MeshInstance3D = _map.unreachable_seg_node(1, 2)
	assert_not_null(seg)
	assert_almost_eq(seg.position.x, 0.0, EPS)
	assert_almost_eq(seg.position.y, 0.95, EPS)
	assert_almost_eq(seg.position.z, 1.0, EPS)


func test_portal_cycle_marks_all_members() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_portal_record(10, 11, 0, 0, 0)))
	assert_true(world.put(_portal_record(11, 12, CELL, 0, 0)))
	assert_true(world.put(_portal_record(12, 10, 2 * CELL, 0, 0)))
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_false(_map.reachability_ok())
	assert_eq(_map.overlay_count(), 3)
	assert_eq(
		_map.overlay_node(10, AuthoringReachabilityCodes.PORTAL_CYCLE).text,
		AuthoringReachabilityCodes.PORTAL_CYCLE
	)
	assert_not_null(_map.overlay_node(11, AuthoringReachabilityCodes.PORTAL_CYCLE))
	assert_not_null(_map.overlay_node(12, AuthoringReachabilityCodes.PORTAL_CYCLE))


func test_missing_path_and_no_transform_draw_no_marks() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.rebuild(world)
	assert_false(_map.reachability_ok())
	assert_eq(_map.reachability_issue_count(), 1)
	assert_eq(_map.overlay_count(), 0)
	assert_true(world.put(_portal_record_without_transform(8, 9)))
	_map.rebuild(world)
	assert_eq(_map.overlay_count(), 0)
	assert_eq(_map.unreachable_seg_count(), 0)


func test_shell_overlay_and_failed_patch_leaves_no_ghost() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_shell)
	assert_true(_shell.open_from(session))
	assert_false(_shell.map.reachability_ok())
	assert_true(_shell.try_apply_patch(Levels.P2, _edit(1, 0, _place_checkpoint(1, 0, 0, 0, 0))))
	assert_true(_shell.map.reachability_ok())
	assert_eq(_shell.map.overlay_count(), 0)
	assert_true(_shell.try_apply_patch(Levels.P2, _edit(2, 1, _place_portal(8, 99, 2 * CELL, 0, 0))))
	assert_false(_shell.map.reachability_ok())
	assert_eq(_shell.map.overlay_count(), 1)
	assert_eq(_shell.status_label_text().contains("reach_ok=false"), true)
	assert_false(_shell.try_apply_patch(Levels.P2, _edit(3, 2, _place_portal(9, 1, 1, 0, 0))))
	assert_eq(_shell.map.overlay_count(), 1)
	assert_null(_shell.map.overlay_node(9, AuthoringReachabilityCodes.DANGLING_PORTAL))
	assert_false(_shell.allows_settlement())


func _checkpoint_record(entity_id: int, order: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {"order": order, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})


func _portal_record(entity_id: int, target_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
	})


func _portal_record_without_transform(entity_id: int, target_id: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
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
		"trace-preview-reach-overlay",
		SharedCommand.Kind.EDIT
	)
