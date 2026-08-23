extends GutTest

## AuthoringWorld：insert-only put、已存在 id 的 replace、remove、revision、拷贝取出、稳定哈希。
## 带 transform 的袋必须落在吸附格上。portal 可悬空，禁止自环和指向无 portal 的已存在实体。
## EditCommand 解码与 Undo 在 AuthoringSession，不在本文件。

const AuthoringGrid := preload("res://src/creator/authoring_grid.gd")
const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const Fixed := preload("res://src/shared/fixed/fixed.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const CELL: int = 65536


func test_starts_empty_at_revision_zero() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_eq(world.revision, 0)
	assert_eq(world.entity_count(), 0)
	assert_false(world.has_entity(1))
	assert_null(world.get_record(1))
	assert_eq(world.grid.cell, CELL)
	assert_eq(world.entity_ids_on_floor(0), [])
	assert_eq(world.portal_links(), [])


func test_put_stores_a_copy_and_bumps_revision() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var components: Dictionary = {
		"transform": {"x": CELL, "y": 2 * CELL, "z": 3 * CELL, "yaw_bam": 0},
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
	assert_eq(stored_x, CELL)


func test_get_record_copy_cannot_mutate_store() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_transform_record(2, 7)))
	var fetched: SharedComponentRecord = world.get_record(2)
	fetched.components["transform"]["y"] = 0
	var again: SharedComponentRecord = world.get_record(2)
	var transform: Dictionary = again.components.get("transform", {})
	var stored_y: int = transform.get("y", 0)
	assert_eq(stored_y, 7 * CELL)


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
	assert_eq(stored_y, 9 * CELL)
	assert_false(world.replace(null))
	assert_false(world.replace(SharedComponentRecord.new()))
	assert_eq(world.revision, 2)
	assert_eq(world.entity_count(), 1)


func test_off_grid_transform_is_rejected_without_write() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var before: PackedByteArray = world.hash_state()
	assert_false(world.put(SharedComponentRecord.create(1, {
		"transform": {"x": 1, "y": 0, "z": 0, "yaw_bam": 0},
	})))
	assert_false(world.put(SharedComponentRecord.create(1, {
		"transform": {"x": 0, "y": CELL + 1, "z": 0, "yaw_bam": 0},
	})))
	assert_true(world.put(_transform_record(1, 0)))
	assert_false(world.replace(SharedComponentRecord.create(1, {
		"transform": {"x": 0, "y": 0, "z": -1, "yaw_bam": 0},
	})))
	var stored: SharedComponentRecord = world.get_record(1)
	var transform: Dictionary = stored.components.get("transform", {})
	var stored_z: int = transform.get("z", -1)
	assert_eq(stored_z, 0)
	assert_eq(world.revision, 1)
	assert_ne(world.hash_state(), before)


func test_bag_without_transform_skips_lattice() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(3, {
		"team": {"team_id": 1},
	})
	assert_true(world.put(record))
	assert_eq(world.entity_ids_on_floor(0), [])
	assert_eq(world.entity_count(), 1)


func test_custom_cell_and_floor_listing() -> void:
	var world: AuthoringWorld = AuthoringWorld.new(AuthoringGrid.create(2))
	assert_eq(world.grid.cell, 2)
	assert_true(world.put(_xyz_record(1, 0, 0, 0)))
	assert_true(world.put(_xyz_record(2, 2, 4, 0)))
	assert_true(world.put(_xyz_record(3, 0, -2, 2)))
	assert_false(world.put(_xyz_record(4, 1, 0, 0)))
	assert_eq(world.entity_ids_on_floor(0), [1])
	assert_eq(world.entity_ids_on_floor(2), [2])
	assert_eq(world.entity_ids_on_floor(-1), [3])
	assert_eq(world.entity_ids_on_floor(1), [])


func test_default_floors_group_by_cell_y() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_transform_record(1, 0)))
	assert_true(world.put(_transform_record(2, 1)))
	assert_true(world.put(_transform_record(3, 1)))
	assert_eq(world.entity_ids_on_floor(0), [1])
	assert_eq(world.entity_ids_on_floor(1), [2, 3])
	assert_eq(world.entity_ids_on_floor(-1), [])


func test_portal_may_dangle_then_become_two_way() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_portal_record(1, 2, 0, 0)))
	var dangling: Array[Dictionary] = world.portal_links()
	assert_eq(dangling.size(), 1)
	assert_eq(_link_int(dangling[0], "source_id"), 1)
	assert_eq(_link_int(dangling[0], "dest_id"), 2)
	assert_eq(_link_str(dangling[0], "kind"), AuthoringPortalKinds.DANGLING)
	assert_false(_link_bool(dangling[0], "dest_present"))
	assert_true(world.put(_portal_record(2, 1, CELL, Fixed.BAM_QUARTER)))
	var paired: Array[Dictionary] = world.portal_links()
	assert_eq(paired.size(), 2)
	assert_eq(_link_str(paired[0], "kind"), AuthoringPortalKinds.TWO_WAY)
	assert_eq(_link_str(paired[1], "kind"), AuthoringPortalKinds.TWO_WAY)
	assert_eq(_link_int(paired[0], "x"), CELL)
	assert_eq(_link_int(paired[0], "dest_yaw_bam"), Fixed.BAM_QUARTER)
	assert_eq(_link_int(paired[1], "x"), 0)
	assert_eq(_link_int(paired[1], "dest_yaw_bam"), 0)


func test_one_way_link_and_remove_dest_returns_to_dangling() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_portal_record(1, 2, 0, 0)))
	assert_true(world.put(_portal_record(2, 9, CELL, 1)))
	var links: Array[Dictionary] = world.portal_links()
	assert_eq(_link_str(links[0], "kind"), AuthoringPortalKinds.ONE_WAY)
	assert_eq(_link_str(links[1], "kind"), AuthoringPortalKinds.DANGLING)
	assert_eq(_link_int(links[0], "x"), CELL)
	assert_eq(_link_int(links[0], "dest_yaw_bam"), 1)
	assert_true(world.remove(2))
	var after: Array[Dictionary] = world.portal_links()
	assert_eq(after.size(), 1)
	assert_eq(_link_str(after[0], "kind"), AuthoringPortalKinds.DANGLING)
	assert_false(_link_bool(after[0], "dest_present"))


func test_self_loop_and_non_portal_target_are_rejected() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_false(world.put(_portal_record(1, 1, 0, 0)))
	assert_eq(world.revision, 0)
	assert_true(world.put(_transform_record(3, 0)))
	assert_false(world.put(_portal_record(4, 3, CELL, 0)))
	assert_eq(world.entity_count(), 1)
	assert_eq(world.revision, 1)


func test_cannot_strip_portal_from_an_existing_dest() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_portal_record(1, 2, 0, 0)))
	assert_true(world.put(_portal_record(2, 1, CELL, 0)))
	assert_false(world.replace(_transform_record(2, 0)))
	var dest: SharedComponentRecord = world.get_record(2)
	assert_true(dest.components.has("portal"))
	assert_true(world.remove(1))
	assert_true(world.replace(_transform_record(2, 0)))
	assert_eq(world.portal_links(), [])


func _transform_record(entity_id: int, cells_y: int) -> SharedComponentRecord:
	return _xyz_record(entity_id, 0, cells_y * CELL, 0)


func _xyz_record(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
	})


func _portal_record(entity_id: int, target_id: int, x: int, yaw_bam: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": 0, "z": 0, "yaw_bam": 0},
		"portal": {"target_id": target_id, "yaw_bam": yaw_bam, "cooldown_ticks": 0},
	})


func _link_int(link: Dictionary, key: String) -> int:
	var value: int = link.get(key, 0)
	return value


func _link_str(link: Dictionary, key: String) -> String:
	var value: String = link.get(key, "")
	return value


func _link_bool(link: Dictionary, key: String) -> bool:
	var value: bool = link.get(key, false)
	return value
