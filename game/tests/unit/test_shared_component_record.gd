extends GutTest

## Component Schema v1：CD-42 §1 组件名与 §1.2 字段；拒绝未知组件、浮点和槽位字段。

const SharedComponentNames := preload("res://src/shared/schema/component_names.gd")
const SharedCollisionShapeKinds := preload("res://src/shared/schema/collision_shape_kinds.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const SharedTowerTargetPriorities := preload("res://src/shared/schema/tower_target_priorities.gd")
const StateHasher := preload("res://src/shared/protocol/state_hasher.gd")


func test_catalog_lists_the_eighteen_locked_components() -> void:
	assert_eq(SharedComponentNames.ALL.size(), 18)
	assert_true(SharedComponentNames.contains("transform"))
	assert_true(SharedComponentNames.contains("inventory"))
	assert_true(SharedComponentNames.contains("tower"))
	assert_false(SharedComponentNames.contains("script"))
	assert_false(SharedComponentNames.contains("NodePath"))


func test_collision_kinds_match_cd42_primitives() -> void:
	assert_eq(SharedCollisionShapeKinds.ALL.size(), 4)
	assert_true(SharedCollisionShapeKinds.contains("box"))
	assert_true(SharedCollisionShapeKinds.contains("platform_prefab"))
	assert_false(SharedCollisionShapeKinds.contains("mesh"))


func test_tower_priorities_match_cd22_whitelist() -> void:
	assert_eq(SharedTowerTargetPriorities.ALL.size(), 4)
	assert_true(SharedTowerTargetPriorities.contains("front"))
	assert_true(SharedTowerTargetPriorities.contains("nearest"))
	assert_true(SharedTowerTargetPriorities.contains("strongest"))
	assert_true(SharedTowerTargetPriorities.contains("weakest"))
	assert_false(SharedTowerTargetPriorities.contains("closest"))


func test_valid_transform_record_is_accepted() -> void:
	var record: SharedComponentRecord = SharedComponentRecord.create(1, {
		"transform": {"x": 0, "y": 65536, "z": -2, "yaw_bam": 16384},
	})
	assert_not_null(record)
	assert_eq(record.schema_version, 1)
	assert_eq(record.entity_id, 1)
	var transform: Dictionary = record.components.get("transform", {})
	var stored_y: int = transform.get("y", 0)
	assert_eq(stored_y, 65536)


func test_empty_component_bag_is_allowed() -> void:
	var record: SharedComponentRecord = SharedComponentRecord.create(7, {})
	assert_not_null(record)
	assert_eq(record.components.size(), 0)


func test_zero_entity_id_is_rejected() -> void:
	assert_null(SharedComponentRecord.create(0, {}))
	assert_null(SharedComponentRecord.create(-1, {}))


func test_unknown_component_is_rejected() -> void:
	assert_null(SharedComponentRecord.create(1, {"script": {}}))
	assert_null(SharedComponentRecord.create(1, {"Transform3D": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0}}))


func test_float_fields_are_rejected() -> void:
	assert_null(SharedComponentRecord.create(1, {
		"transform": {"x": 0.5, "y": 0, "z": 0, "yaw_bam": 0},
	}))
	assert_null(SharedComponentRecord.create(1, {
		"velocity": {"vx": 1.0, "vy": 0, "vz": 0},
	}))


func test_extra_transform_field_is_rejected() -> void:
	assert_null(SharedComponentRecord.create(1, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0, "pitch": 1},
	}))


func test_health_maximum_must_be_at_least_one() -> void:
	assert_null(SharedComponentRecord.create(1, {
		"health": {"current": 0, "maximum": 0, "invuln_ticks": 0},
	}))


func test_inventory_accepts_canonical_item_state_without_slots() -> void:
	var record: SharedComponentRecord = SharedComponentRecord.create(3, {
		"inventory": {"item_state": {"held": [2, 2]}},
	})
	assert_not_null(record)
	assert_null(SharedComponentRecord.create(3, {
		"inventory": {"item_state": {}, "slot_count": 4},
	}))
	assert_null(SharedComponentRecord.create(3, {
		"inventory": {"slots": []},
	}))
	assert_null(SharedComponentRecord.create(3, {
		"inventory": {"item_state": {"mass": 1.25}},
	}))


func test_zone_shape_whitelist_and_tags() -> void:
	var box_ok: SharedComponentRecord = SharedComponentRecord.create(4, {
		"zone": {
			"shape": {"kind": "box", "hx": 65536, "hy": 65536, "hz": 65536},
			"tags": ["hazard"],
		},
	})
	assert_not_null(box_ok)
	assert_null(SharedComponentRecord.create(4, {
		"zone": {
			"shape": {"kind": "mesh", "hx": 1, "hy": 1, "hz": 1},
			"tags": ["hazard"],
		},
	}))
	assert_null(SharedComponentRecord.create(4, {
		"zone": {
			"shape": {"kind": "box", "hx": 1, "hy": 1, "hz": 1},
			"tags": [""],
		},
	}))


func test_traprush_and_bastion_components_round_trip() -> void:
	var components: Dictionary = {
		"checkpoint": {"order": 2, "respawn_dx": 0, "respawn_dy": 65536, "respawn_dz": 0},
		"portal": {"target_id": 9, "yaw_bam": 0, "cooldown_ticks": 0},
		"destructible": {"durability": 3, "regen_policy_id": 0},
		"tower": {
			"level": 1,
			"attack_range": 65536,
			"cooldown_ticks": 12,
			"target_priority": "nearest",
		},
		"replication": {"policy_id": 0},
	}
	var record: SharedComponentRecord = SharedComponentRecord.create(11, components)
	assert_not_null(record)
	var wire: Dictionary = record.to_dictionary()
	var restored: SharedComponentRecord = SharedComponentRecord.from_dictionary(wire)
	assert_not_null(restored)
	assert_eq(restored.entity_id, 11)
	assert_null(SharedComponentRecord.from_dictionary({
		"schema_version": 2,
		"entity_id": 11,
		"components": {},
	}))
	assert_null(SharedComponentRecord.create(11, {
		"tower": {
			"level": 1,
			"attack_range": 65536,
			"cooldown_ticks": 12,
			"target_priority": "closest",
		},
	}))


func test_caller_cannot_mutate_stored_components() -> void:
	var components: Dictionary = {
		"transform": {"x": 1, "y": 2, "z": 3, "yaw_bam": 0},
	}
	var record: SharedComponentRecord = SharedComponentRecord.create(1, components)
	components["transform"]["x"] = 99
	var stored_transform: Dictionary = record.components.get("transform", {})
	var stored_x: int = stored_transform.get("x", 0)
	assert_eq(stored_x, 1)


func test_feed_hasher_is_stable() -> void:
	var left: StateHasher = StateHasher.new()
	var right: StateHasher = StateHasher.new()
	var body: Dictionary = {
		"health": {"current": 3, "maximum": 5, "invuln_ticks": 0},
		"team": {"team_id": 1},
	}
	SharedComponentRecord.create(8, body).feed_hasher(left)
	SharedComponentRecord.create(8, body).feed_hasher(right)
	assert_eq(left.digest_hex(), right.digest_hex())
	assert_eq(left.digest_hex().length(), 64)
