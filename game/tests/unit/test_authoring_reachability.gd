extends GutTest

## AuthoringReachability：发布前通路与传送循环。编辑期悬空仍合法，不在 try_apply 上跑。
## two_way 配对是落点；one_way 回到已访问节点才是循环。不锁 hop 上限，不走路洞。

const AuthoringReachability := preload("res://src/creator/authoring_reachability.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const Codes := preload("res://src/creator/authoring_reachability_codes.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const CELL: int = 65536


func test_empty_world_misses_mandatory_path() -> void:
	var empty: Dictionary = AuthoringReachability.evaluate(AuthoringWorld.new())
	assert_false(_ok(empty))
	assert_eq(_codes(empty), PackedStringArray([Codes.MISSING_MANDATORY_PATH]))
	assert_eq(_issue_ids(empty, Codes.MISSING_MANDATORY_PATH), [])


func test_single_checkpoint_same_floor_is_publish_ready() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0)))
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result))
	var issues: Array = result.get("issues", [])
	assert_eq(issues.size(), 0)


func test_dangling_portal_fails_publish_but_place_still_writes() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0)))
	assert_true(world.put(_portal(8, 9, 0, 0)))
	assert_eq(world.revision, 2)
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_eq(_codes(result), PackedStringArray([Codes.DANGLING_PORTAL]))
	assert_eq(_issue_ids(result, Codes.DANGLING_PORTAL), [8])


func test_two_way_pair_is_not_a_publish_cycle() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0)))
	assert_true(world.put(_checkpoint(2, 1, 1)))
	assert_true(world.put(_portal(10, 11, 0, 0)))
	assert_true(world.put(_portal(11, 10, CELL, 1)))
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result))


func test_one_way_chain_back_to_start_is_a_publish_cycle() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0)))
	assert_true(world.put(_portal(10, 11, 0, 0)))
	assert_true(world.put(_portal(11, 12, CELL, 0)))
	assert_true(world.put(_portal(12, 10, 2 * CELL, 0)))
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_eq(_codes(result), PackedStringArray([Codes.PORTAL_CYCLE]))
	assert_eq(_issue_ids(result, Codes.PORTAL_CYCLE), [10, 11, 12])


func test_duplicate_checkpoint_order_is_rejected() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0)))
	assert_true(world.put(_checkpoint(2, 0, 0)))
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_eq(_codes(result), PackedStringArray([Codes.DUPLICATE_CHECKPOINT_ORDER]))
	assert_eq(_issue_ids(result, Codes.DUPLICATE_CHECKPOINT_ORDER), [1, 2])


func test_next_floor_without_portal_is_unreachable() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0)))
	assert_true(world.put(_checkpoint(2, 1, 1)))
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_eq(_codes(result), PackedStringArray([Codes.UNREACHABLE_CHECKPOINT]))
	assert_eq(_issue_ids(result, Codes.UNREACHABLE_CHECKPOINT), [1, 2])


func test_dangling_exit_still_connects_floors_but_fails_publish() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0)))
	assert_true(world.put(_checkpoint(2, 1, 1)))
	assert_true(world.put(_portal(10, 11, 0, 0)))
	assert_true(world.put(_portal(11, 99, CELL, 1)))
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_eq(_codes(result), PackedStringArray([Codes.DANGLING_PORTAL]))
	assert_eq(_issue_ids(result, Codes.DANGLING_PORTAL), [11])
	assert_eq(_issue_ids(result, Codes.UNREACHABLE_CHECKPOINT), [])


func test_one_way_into_paired_exit_connects_next_floor() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0)))
	assert_true(world.put(_checkpoint(2, 1, 1)))
	assert_true(world.put(_portal(10, 11, 0, 0)))
	assert_true(world.put(_portal(11, 12, CELL, 1)))
	assert_true(world.put(_portal(12, 11, 2 * CELL, 1)))
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result))


func test_one_way_floor_jump_does_not_work_backwards() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 1)))
	assert_true(world.put(_checkpoint(2, 1, 0)))
	assert_true(world.put(_portal(10, 11, 0, 0)))
	assert_true(world.put(_portal(11, 12, CELL, 1)))
	assert_true(world.put(_portal(12, 11, 2 * CELL, 1)))
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_eq(_codes(result), PackedStringArray([Codes.UNREACHABLE_CHECKPOINT]))
	assert_eq(_issue_ids(result, Codes.UNREACHABLE_CHECKPOINT), [1, 2])


func test_checkpoint_without_transform_cannot_bridge_floors() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0)))
	assert_true(world.put(SharedComponentRecord.create(2, {
		"checkpoint": {"order": 1, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})))
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_false(_ok(result))
	assert_eq(_codes(result), PackedStringArray([Codes.UNREACHABLE_CHECKPOINT]))
	assert_eq(_issue_ids(result, Codes.UNREACHABLE_CHECKPOINT), [1, 2])


func test_try_apply_does_not_run_reachability() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place_checkpoint(1, 0, 0))))
	assert_true(session.try_apply(_edit(2, 1, _place_portal(8, 9, 0))))
	assert_eq(session.world.revision, 2)
	assert_true(session.world.has_entity(8))
	var published: Dictionary = session.evaluate_reachability()
	assert_false(_ok(published))
	assert_eq(_codes(published), PackedStringArray([Codes.DANGLING_PORTAL]))


func test_same_floor_sequence_does_not_need_portals() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint(1, 0, 0)))
	assert_true(world.put(_checkpoint(2, 1, 0)))
	assert_true(world.put(_checkpoint(3, 2, 0)))
	var result: Dictionary = AuthoringReachability.evaluate(world)
	assert_true(_ok(result))


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _codes(result: Dictionary) -> PackedStringArray:
	var packed: PackedStringArray = PackedStringArray()
	var issues: Array = result.get("issues", [])
	for issue_value: Variant in issues:
		var issue: Dictionary = issue_value
		var code: String = issue.get("code", "")
		packed.append(code)
	return packed


func _issue_ids(result: Dictionary, code: String) -> Array[int]:
	var ids: Array[int] = []
	var issues: Array = result.get("issues", [])
	for issue_value: Variant in issues:
		var issue: Dictionary = issue_value
		var issue_code: String = issue.get("code", "")
		if issue_code != code:
			continue
		var raw_ids: Array = issue.get("entity_ids", [])
		for raw_id: Variant in raw_ids:
			var entity_id: int = raw_id
			ids.append(entity_id)
		return ids
	return ids


func _checkpoint(entity_id: int, order: int, floor_index: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": 0, "y": floor_index * CELL, "z": 0, "yaw_bam": 0},
		"checkpoint": {"order": order, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})


func _portal(entity_id: int, target_id: int, x: int, floor_index: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": floor_index * CELL, "z": 0, "yaw_bam": 0},
		"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
	})


func _place_checkpoint(entity_id: int, order: int, floor_index: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": 0, "y": floor_index * CELL, "z": 0, "yaw_bam": 0},
				"checkpoint": {"order": order, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
			},
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
		"trace-reach",
		SharedCommand.Kind.EDIT
	)
