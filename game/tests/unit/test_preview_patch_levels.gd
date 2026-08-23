extends GutTest

## PreviewPatchLevels：CD-33 等级名；袋到等级的映射是 CD-32。place/remove 为 P2。

const Levels := preload("res://src/creator/preview_patch_levels.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")


func test_level_whitelist_and_rank() -> void:
	assert_eq(Levels.ALL.size(), 5)
	assert_true(Levels.contains(Levels.P0))
	assert_true(Levels.contains(Levels.P4))
	assert_false(Levels.contains("p5"))
	assert_eq(Levels.rank(Levels.P0), 0)
	assert_eq(Levels.rank(Levels.P2), 2)
	assert_eq(Levels.rank("nope"), -1)


func test_place_and_remove_classify_as_p2() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_eq(Levels.classify(_edit(0, _place_health(1, 3)), world), Levels.P2)
	assert_true(world.put(SharedComponentRecord.create(1, _health(3))))
	assert_eq(Levels.classify(_edit(1, {"op": "remove", "entity_id": 1}), world), Levels.P2)


func test_set_component_uses_union_of_old_and_new_keys() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(SharedComponentRecord.create(2, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"health": {"current": 1, "maximum": 2, "invuln_ticks": 0},
	})))
	assert_eq(Levels.classify(_edit(1, _set_health(2, 2)), world), Levels.P2)
	var health_only: AuthoringWorld = AuthoringWorld.new()
	assert_true(health_only.put(SharedComponentRecord.create(3, _health(4))))
	assert_eq(Levels.classify(_edit(1, _set_health(3, 8)), health_only), Levels.P1)
	assert_eq(Levels.classify(_edit(1, _set_replication(3, 1)), health_only), Levels.P1)


func test_replication_only_set_is_p0() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(SharedComponentRecord.create(4, _replication(0))))
	assert_eq(Levels.classify(_edit(1, _set_replication(4, 2)), world), Levels.P0)


func _health(current: int) -> Dictionary:
	return {"health": {"current": current, "maximum": 10, "invuln_ticks": 0}}


func _replication(policy_id: int) -> Dictionary:
	return {"replication": {"policy_id": policy_id}}


func _place_health(entity_id: int, current: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": _health(current),
		},
	}


func _set_health(entity_id: int, current: int) -> Dictionary:
	return {
		"op": "set_component",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": _health(current),
		},
	}


func _set_replication(entity_id: int, policy_id: int) -> Dictionary:
	return {
		"op": "set_component",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": _replication(policy_id),
		},
	}


func _edit(expected_revision: int, payload: Dictionary) -> SharedCommand:
	return SharedCommand.create(
		1, 2, 1, 0, expected_revision, "content-v1", payload, "trace-level", SharedCommand.Kind.EDIT
	)
