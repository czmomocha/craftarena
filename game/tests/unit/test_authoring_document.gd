extends GutTest

## AuthoringDocument：桌面/Web 同一份 JSON 快照。表面名不入库。v1 无 Rule VM 图。

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const CELL: int = 65536


func test_empty_world_roundtrip_keeps_revision_and_cell() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var encoded: Dictionary = AuthoringDocument.encode(world)
	var version: int = encoded.get("schema_version", 0)
	var cell: int = encoded.get("cell", 0)
	var revision: int = encoded.get("revision", -1)
	var entities: Array = encoded.get("entities", [])
	assert_eq(version, 1)
	assert_eq(cell, CELL)
	assert_eq(revision, 0)
	assert_eq(entities, [])
	assert_false(encoded.has("surface"))
	var loaded: AuthoringWorld = AuthoringDocument.decode(encoded)
	assert_not_null(loaded)
	assert_eq(loaded.hash_state(), world.hash_state())
	assert_eq(loaded.revision, 0)
	assert_eq(loaded.grid.cell, CELL)


func test_entities_roundtrip_sorted_and_without_aliasing() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_xyz(2, CELL)))
	assert_true(world.put(_xyz(1, 0)))
	var encoded: Dictionary = AuthoringDocument.encode(world)
	var entities: Array = encoded.get("entities", [])
	assert_eq(entities.size(), 2)
	var first: Dictionary = entities[0]
	var first_id: int = first.get("entity_id", 0)
	assert_eq(first_id, 1)
	var loaded: AuthoringWorld = AuthoringDocument.decode(encoded)
	assert_not_null(loaded)
	assert_eq(loaded.entity_ids(), [1, 2])
	assert_eq(loaded.revision, 2)
	assert_eq(loaded.hash_state(), world.hash_state())
	var stored: SharedComponentRecord = loaded.get_record(1)
	stored.components["transform"]["y"] = 0
	var original: SharedComponentRecord = world.get_record(1)
	var transform: Dictionary = original.components.get("transform", {})
	var stored_y: int = transform.get("y", -1)
	assert_eq(stored_y, 0)


func test_json_text_roundtrip() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_xyz(4, CELL)))
	var encoded: Dictionary = AuthoringDocument.encode(world)
	var text: String = JSON.stringify(encoded)
	var parsed: Variant = JSON.parse_string(text)
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	var body: Dictionary = parsed
	var loaded: AuthoringWorld = AuthoringDocument.decode(body)
	assert_not_null(loaded)
	assert_eq(loaded.hash_state(), world.hash_state())


func test_dangling_portal_document_is_legal() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_portal(5, 99, 0)))
	var loaded: AuthoringWorld = AuthoringDocument.decode(AuthoringDocument.encode(world))
	assert_not_null(loaded)
	assert_true(loaded.has_entity(5))


func test_rejects_extra_keys_wrong_version_and_negative_revision() -> void:
	assert_null(AuthoringDocument.decode({
		"schema_version": 1,
		"cell": CELL,
		"revision": 0,
		"entities": [],
		"surface": "web_light",
	}))
	assert_null(AuthoringDocument.decode({
		"schema_version": 2,
		"cell": CELL,
		"revision": 0,
		"entities": [],
	}))
	assert_null(AuthoringDocument.decode({
		"schema_version": 1,
		"cell": CELL,
		"revision": -1,
		"entities": [],
	}))
	assert_null(AuthoringDocument.decode({}))
	assert_null(AuthoringDocument.decode(AuthoringDocument.encode(null)))
	assert_null(AuthoringDocument.decode({
		"schema_version": 1.5,
		"cell": CELL,
		"revision": 0,
		"entities": [],
	}))


func test_rejects_duplicate_ids_off_lattice_and_illegal_portals() -> void:
	var duplicate: Dictionary = {
		"schema_version": 1,
		"cell": CELL,
		"revision": 2,
		"entities": [_bag(1, 0), _bag(1, CELL)],
	}
	assert_null(AuthoringDocument.decode(duplicate))
	var off_lattice: Dictionary = {
		"schema_version": 1,
		"cell": CELL,
		"revision": 1,
		"entities": [{
			"schema_version": 1,
			"entity_id": 1,
			"components": {"transform": {"x": 0, "y": CELL, "z": -2, "yaw_bam": 0}},
		}],
	}
	assert_null(AuthoringDocument.decode(off_lattice))
	var self_loop: Dictionary = {
		"schema_version": 1,
		"cell": CELL,
		"revision": 1,
		"entities": [_portal_bag(3, 3, 0)],
	}
	assert_null(AuthoringDocument.decode(self_loop))
	var dest_without_portal: Dictionary = {
		"schema_version": 1,
		"cell": CELL,
		"revision": 2,
		"entities": [_portal_bag(1, 2, 0), _bag(2, CELL)],
	}
	assert_null(AuthoringDocument.decode(dest_without_portal))


func _xyz(entity_id: int, y: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": 0, "y": y, "z": 0, "yaw_bam": 0},
	})


func _portal(entity_id: int, target_id: int, x: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": 0, "z": 0, "yaw_bam": 0},
		"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
	})


func _bag(entity_id: int, y: int) -> Dictionary:
	return {
		"schema_version": 1,
		"entity_id": entity_id,
		"components": {"transform": {"x": 0, "y": y, "z": 0, "yaw_bam": 0}},
	}


func _portal_bag(entity_id: int, target_id: int, x: int) -> Dictionary:
	return {
		"schema_version": 1,
		"entity_id": entity_id,
		"components": {
			"transform": {"x": x, "y": 0, "z": 0, "yaw_bam": 0},
			"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
		},
	}
