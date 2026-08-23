extends GutTest

## AuthoringSession：expected_revision 门禁、失败不写入、place/remove/set_component、Undo/Redo 反向命令。

const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const EditPayload := preload("res://src/creator/edit_payload.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const CELL: int = 65536


func test_place_remove_and_set_component_apply_under_revision_gate() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place(1, 0))))
	assert_eq(session.world.revision, 1)
	assert_true(session.world.has_entity(1))
	assert_true(session.try_apply(_edit(2, 1, _set_component(1, 8))))
	var after_set: SharedComponentRecord = session.world.get_record(1)
	var set_transform: Dictionary = after_set.components.get("transform", {})
	var set_y: int = set_transform.get("y", -1)
	assert_eq(set_y, 8 * CELL)
	assert_true(session.try_apply(_edit(3, 2, {"op": "remove", "entity_id": 1})))
	assert_eq(session.world.entity_count(), 0)
	assert_eq(session.world.revision, 3)


func test_revision_mismatch_and_non_edit_do_not_write() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	var before: PackedByteArray = session.world.hash_state()
	assert_false(session.try_apply(_edit(1, 1, _place(1, 0))))
	assert_false(session.try_apply(_player()))
	assert_false(session.try_apply(null))
	assert_false(session.try_apply(_edit(2, 0, {"op": "place"})))
	assert_false(session.try_apply(_edit(3, 0, {"op": "remove", "entity_id": 1})))
	assert_false(session.try_apply(_edit(4, 0, _set_component(1, 1))))
	assert_eq(session.world.revision, 0)
	assert_eq(session.world.hash_state(), before)
	assert_false(session.can_undo())


func test_duplicate_place_fails_without_partial_write() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place(2, 0))))
	var before: PackedByteArray = session.world.hash_state()
	assert_false(session.try_apply(_edit(2, 1, _place(2, 5))))
	assert_eq(session.world.hash_state(), before)
	var stored: SharedComponentRecord = session.world.get_record(2)
	var transform: Dictionary = stored.components.get("transform", {})
	var stored_y: int = transform.get("y", -1)
	assert_eq(stored_y, 0)


func test_undo_redo_use_inverse_payloads_and_bump_revision() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place(1, 4))))
	assert_true(session.try_apply(_edit(2, 1, _set_component(1, 9))))
	assert_true(session.can_undo())
	assert_false(session.can_redo())
	assert_true(session.undo())
	var after_undo_set: SharedComponentRecord = session.world.get_record(1)
	var undo_set_transform: Dictionary = after_undo_set.components.get("transform", {})
	var y_after_undo_set: int = undo_set_transform.get("y", -1)
	assert_eq(y_after_undo_set, 4 * CELL)
	assert_eq(session.world.revision, 3)
	assert_true(session.undo())
	assert_false(session.world.has_entity(1))
	assert_eq(session.world.revision, 4)
	assert_true(session.can_redo())
	assert_true(session.redo())
	assert_true(session.world.has_entity(1))
	var after_redo_place: SharedComponentRecord = session.world.get_record(1)
	var redo_place_transform: Dictionary = after_redo_place.components.get("transform", {})
	var y_after_redo_place: int = redo_place_transform.get("y", -1)
	assert_eq(y_after_redo_place, 4 * CELL)
	assert_true(session.redo())
	var after_redo_set: SharedComponentRecord = session.world.get_record(1)
	var redo_set_transform: Dictionary = after_redo_set.components.get("transform", {})
	var y_after_redo_set: int = redo_set_transform.get("y", -1)
	assert_eq(y_after_redo_set, 9 * CELL)
	assert_eq(session.world.revision, 6)
	assert_false(session.can_redo())
	assert_true(session.undo())
	assert_true(session.undo())
	assert_false(session.undo())
	assert_eq(session.world.entity_count(), 0)


func test_new_apply_clears_redo() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place(1, 0))))
	assert_true(session.try_apply(_edit(2, 1, _place(2, 0))))
	assert_true(session.undo())
	assert_true(session.can_redo())
	assert_eq(session.world.revision, 3)
	assert_true(session.try_apply(_edit(3, 3, _place(3, 0))))
	assert_false(session.can_redo())
	assert_true(session.world.has_entity(1))
	assert_false(session.world.has_entity(2))
	assert_true(session.world.has_entity(3))


func test_inverse_payload_is_a_valid_edit_envelope() -> void:
	var place_payload: Dictionary = _place(5, 1)
	var inverse: Dictionary = EditPayload.inverse(place_payload, AuthoringWorld.new())
	var command: SharedCommand = SharedCommand.create(
		9, 2, 1, 0, 0, "content-v1", inverse, "trace-inv", SharedCommand.Kind.EDIT
	)
	assert_not_null(command)
	var inverse_op: String = command.payload.get("op", "")
	var inverse_id: int = command.payload.get("entity_id", 0)
	assert_eq(inverse_op, "remove")
	assert_eq(inverse_id, 5)


func _place(entity_id: int, y: int) -> Dictionary:
	return {"op": "place", "record": _record_dict(entity_id, y)}


func _set_component(entity_id: int, y: int) -> Dictionary:
	return {"op": "set_component", "record": _record_dict(entity_id, y)}


func test_off_grid_place_does_not_write_or_push_undo() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	var before: PackedByteArray = session.world.hash_state()
	assert_false(session.try_apply(_edit(1, 0, {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": 1,
			"components": {"transform": {"x": 1, "y": 0, "z": 0, "yaw_bam": 0}},
		},
	})))
	assert_eq(session.world.hash_state(), before)
	assert_false(session.can_undo())


func test_portal_pair_undo_restores_dangling_link() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place_portal(1, 2, 0))))
	assert_true(session.try_apply(_edit(2, 1, _place_portal(2, 1, CELL))))
	var paired: Array[Dictionary] = session.world.portal_links()
	assert_eq(paired.size(), 2)
	var paired_kind: String = paired[0].get("kind", "")
	assert_eq(paired_kind, AuthoringPortalKinds.TWO_WAY)
	assert_true(session.undo())
	var dangling: Array[Dictionary] = session.world.portal_links()
	assert_eq(dangling.size(), 1)
	var dangling_kind: String = dangling[0].get("kind", "")
	assert_eq(dangling_kind, AuthoringPortalKinds.DANGLING)
	assert_true(session.redo())
	assert_eq(session.world.portal_links().size(), 2)
	assert_eq(session.world.entity_ids_on_floor(0), [1, 2])


func _record_dict(entity_id: int, cells_y: int) -> Dictionary:
	return {
		"schema_version": 1,
		"entity_id": entity_id,
		"components": {
			"transform": {"x": 0, "y": cells_y * CELL, "z": 0, "yaw_bam": 0},
		},
	}


func _place_portal(entity_id: int, target_id: int, x: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": 0, "z": 0, "yaw_bam": 0},
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
		"trace-edit",
		SharedCommand.Kind.EDIT
	)


func _player() -> SharedCommand:
	return SharedCommand.create(
		1, 9, 1, 0, 0, "content-v1", {"intent": "MoveIntent", "dx": 1, "dz": 0}, "trace-1", SharedCommand.Kind.PLAYER
	)
