extends GutTest

## AuthoringPreview：编辑会话保持打开；安全点应用 P0–P2；失败整份回滚；永不结算。
## P3 等 Rule VM；P4 只置 needs_restart。不建窗口，不编 SimulationBundle。

const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const Levels := preload("res://src/creator/preview_patch_levels.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const CELL: int = 65536


func test_connect_snapshots_authoring_and_leaves_editor_open() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place_transform(1, 0))))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_true(preview.connected)
	assert_true(preview.is_safe_point())
	assert_true(preview.world.has_entity(1))
	assert_eq(preview.world.revision, 1)
	assert_eq(preview.preview_revision, 0)
	assert_true(session.try_apply(_edit(2, 1, _place_transform(2, 0))))
	assert_true(session.world.has_entity(2))
	assert_false(preview.world.has_entity(2))
	assert_false(preview.allows_settlement())
	assert_false(preview.allows_online_writes())


func test_p2_place_then_p1_set_stay_connected() -> void:
	var preview: AuthoringPreview = _connected_empty()
	assert_true(preview.try_apply_patch(Levels.P2, _edit(1, 0, _place_health(8, 3))))
	assert_eq(preview.preview_revision, 1)
	assert_true(preview.world.has_entity(8))
	assert_true(preview.try_apply_patch(Levels.P1, _edit(2, 1, _set_health(8, 7))))
	assert_eq(preview.preview_revision, 2)
	assert_true(preview.connected)
	assert_false(preview.needs_restart)
	var stored: SharedComponentRecord = preview.world.get_record(8)
	var health: Dictionary = stored.components.get("health", {})
	var current: int = health.get("current", -1)
	assert_eq(current, 7)
	assert_false(preview.allows_settlement())


func test_p0_replication_patch_does_not_restart() -> void:
	var preview: AuthoringPreview = _connected_empty()
	assert_true(preview.try_apply_patch(Levels.P2, _edit(1, 0, _place_replication(4, 0))))
	assert_true(preview.try_apply_patch(Levels.P0, _edit(2, 1, _set_replication(4, 3))))
	assert_eq(preview.preview_revision, 2)
	var stored: SharedComponentRecord = preview.world.get_record(4)
	var replication: Dictionary = stored.components.get("replication", {})
	var policy_id: int = replication.get("policy_id", -1)
	assert_eq(policy_id, 3)


func test_underclassified_p1_for_place_is_rejected() -> void:
	var preview: AuthoringPreview = _connected_empty()
	var before: PackedByteArray = preview.world.hash_state()
	assert_false(preview.try_apply_patch(Levels.P1, _edit(1, 0, _place_health(1, 1))))
	assert_eq(preview.world.hash_state(), before)
	assert_eq(preview.preview_revision, 0)


func test_overclassified_p2_for_p1_set_is_allowed() -> void:
	var preview: AuthoringPreview = _connected_empty()
	assert_true(preview.try_apply_patch(Levels.P2, _edit(1, 0, _place_health(1, 1))))
	assert_true(preview.try_apply_patch(Levels.P2, _edit(2, 1, _set_health(1, 4))))
	var stored: SharedComponentRecord = preview.world.get_record(1)
	var health: Dictionary = stored.components.get("health", {})
	var current: int = health.get("current", -1)
	assert_eq(current, 4)


func test_failed_place_rolls_back_preview_not_authoring() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place_transform(1, 0))))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	var authoring_hash: PackedByteArray = session.world.hash_state()
	var preview_hash: PackedByteArray = preview.world.hash_state()
	assert_false(preview.try_apply_patch(Levels.P2, _edit(2, 1, {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": 2,
			"components": {"transform": {"x": 1, "y": 0, "z": 0, "yaw_bam": 0}},
		},
	})))
	assert_eq(preview.world.hash_state(), preview_hash)
	assert_eq(session.world.hash_state(), authoring_hash)
	assert_eq(preview.preview_revision, 0)
	assert_false(preview.world.has_entity(2))


func test_unsafe_tick_rejects_then_applies_at_safe_point() -> void:
	var preview: AuthoringPreview = _connected_empty()
	assert_true(preview.enter_tick())
	assert_false(preview.is_safe_point())
	assert_false(preview.try_apply_patch(Levels.P2, _edit(1, 0, _place_health(1, 1))))
	assert_false(preview.world.has_entity(1))
	preview.leave_tick()
	assert_true(preview.is_safe_point())
	assert_true(preview.try_apply_patch(Levels.P2, _edit(1, 0, _place_health(1, 1))))
	assert_true(preview.world.has_entity(1))


func test_p3_is_refused_and_p4_requires_restart() -> void:
	var preview: AuthoringPreview = _connected_empty()
	assert_false(preview.try_apply_patch(Levels.P3, _edit(1, 0, _place_health(1, 1))))
	assert_false(preview.needs_restart)
	assert_false(preview.world.has_entity(1))
	assert_false(preview.try_apply_patch(Levels.P4, _edit(1, 0, _place_health(1, 1))))
	assert_true(preview.needs_restart)
	assert_false(preview.is_safe_point())
	assert_false(preview.try_apply_patch(Levels.P2, _edit(1, 0, _place_health(1, 1))))
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(preview.connect_from(session))
	assert_false(preview.needs_restart)
	assert_true(preview.try_apply_patch(Levels.P2, _edit(1, 0, _place_health(1, 1))))


func test_revision_mismatch_and_unknown_level_do_not_write() -> void:
	var preview: AuthoringPreview = _connected_empty()
	assert_false(preview.try_apply_patch(Levels.P2, _edit(1, 3, _place_health(1, 1))))
	assert_false(preview.try_apply_patch("p9", _edit(1, 0, _place_health(1, 1))))
	assert_eq(preview.world.entity_count(), 0)
	assert_eq(preview.preview_revision, 0)


func _connected_empty() -> AuthoringPreview:
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(AuthoringSession.new()))
	return preview


func _place_transform(entity_id: int, cells_y: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": 0, "y": cells_y * CELL, "z": 0, "yaw_bam": 0},
			},
		},
	}


func _place_health(entity_id: int, current: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"health": {"current": current, "maximum": 10, "invuln_ticks": 0},
			},
		},
	}


func _set_health(entity_id: int, current: int) -> Dictionary:
	return {
		"op": "set_component",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"health": {"current": current, "maximum": 10, "invuln_ticks": 0},
			},
		},
	}


func _place_replication(entity_id: int, policy_id: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"replication": {"policy_id": policy_id},
			},
		},
	}


func _set_replication(entity_id: int, policy_id: int) -> Dictionary:
	return {
		"op": "set_component",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"replication": {"policy_id": policy_id},
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
		"trace-preview",
		SharedCommand.Kind.EDIT
	)
