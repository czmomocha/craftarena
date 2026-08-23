extends GutTest

## AuthoringWorld：insert-only put、已存在 id 的 replace、remove、revision、拷贝取出、稳定哈希。
## EditCommand 解码与 Undo 在 AuthoringSession，不在本文件。

const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")


func test_starts_empty_at_revision_zero() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_eq(world.revision, 0)
	assert_eq(world.entity_count(), 0)
	assert_false(world.has_entity(1))
	assert_null(world.get_record(1))


func test_put_stores_a_copy_and_bumps_revision() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var components: Dictionary = {
		"transform": {"x": 1, "y": 2, "z": 3, "yaw_bam": 0},
	}
	var record: SharedComponentRecord = SharedComponentRecord.create(4, components)
	assert_true(world.put(record))
	assert_eq(world.revision, 1)
	assert_eq(world.entity_count(), 1)
	assert_true(world.has_entity(4))
	components["transform"]["x"] = 99
	record.components["transform"]["x"] = 88
	var stored: SharedComponentRecord = world.get_record(4)
	assert_not_null(stored)
	assert_eq(stored.entity_id, 4)
	var stored_transform: Dictionary = stored.components.get("transform", {})
	var stored_x: int = stored_transform.get("x", 0)
	assert_eq(stored_x, 1)


func test_get_record_copy_cannot_mutate_store() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_transform_record(2, 7)))
	var fetched: SharedComponentRecord = world.get_record(2)
	fetched.components["transform"]["y"] = 0
	var again: SharedComponentRecord = world.get_record(2)
	var transform: Dictionary = again.components.get("transform", {})
	var stored_y: int = transform.get("y", 0)
	assert_eq(stored_y, 7)


func test_duplicate_or_null_put_does_not_bump_revision() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_transform_record(1, 0)))
	assert_eq(world.revision, 1)
	assert_false(world.put(null))
	assert_false(world.put(_transform_record(1, 5)))
	assert_false(world.put(SharedComponentRecord.new()))
	assert_eq(world.revision, 1)
	assert_eq(world.entity_count(), 1)
	var stored: SharedComponentRecord = world.get_record(1)
	var transform: Dictionary = stored.components.get("transform", {})
	var stored_y: int = transform.get("y", -1)
	assert_eq(stored_y, 0)


func test_remove_unknown_fails_and_known_bumps_revision() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_false(world.remove(1))
	assert_eq(world.revision, 0)
	assert_true(world.put(_transform_record(3, 0)))
	assert_true(world.put(_transform_record(5, 1)))
	assert_eq(world.revision, 2)
	assert_true(world.remove(3))
	assert_eq(world.revision, 3)
	assert_false(world.has_entity(3))
	assert_null(world.get_record(3))
	assert_true(world.has_entity(5))
	assert_eq(world.entity_count(), 1)
	assert_false(world.remove(3))
	assert_eq(world.revision, 3)


func test_hash_state_is_stable_and_ignores_insert_order() -> void:
	var left: AuthoringWorld = AuthoringWorld.new()
	var right: AuthoringWorld = AuthoringWorld.new()
	assert_eq(left.hash_state(), right.hash_state())
	assert_eq(left.hash_state().size(), 32)
	assert_true(left.put(_transform_record(2, 1)))
	assert_true(left.put(_transform_record(1, 0)))
	assert_true(right.put(_transform_record(1, 0)))
	assert_true(right.put(_transform_record(2, 1)))
	assert_eq(left.revision, 2)
	assert_eq(right.revision, 2)
	assert_eq(left.hash_state(), right.hash_state())


func test_failed_mutation_does_not_change_hash() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_transform_record(1, 0)))
	var before: PackedByteArray = world.hash_state()
	assert_false(world.put(_transform_record(1, 9)))
	assert_false(world.remove(9))
	assert_eq(world.hash_state(), before)
	assert_true(world.put(_transform_record(2, 0)))
	assert_ne(world.hash_state(), before)


func test_replace_overwrites_existing_and_rejects_unknown() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_false(world.replace(_transform_record(1, 4)))
	assert_eq(world.revision, 0)
	assert_true(world.put(_transform_record(1, 0)))
	assert_eq(world.revision, 1)
	assert_true(world.replace(_transform_record(1, 9)))
	assert_eq(world.revision, 2)
	var stored: SharedComponentRecord = world.get_record(1)
	var transform: Dictionary = stored.components.get("transform", {})
	var stored_y: int = transform.get("y", -1)
	assert_eq(stored_y, 9)
	assert_false(world.replace(null))
	assert_false(world.replace(SharedComponentRecord.new()))
	assert_eq(world.revision, 2)
	assert_eq(world.entity_count(), 1)


func _transform_record(entity_id: int, y: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": 0, "y": y, "z": 0, "yaw_bam": 0},
	})
