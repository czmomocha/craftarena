extends GutTest

## EditPayload：CD-42 §3.3 的 place / remove / set_component 形状。未知键、浮点和坏实体袋拒绝。

const EditOpNames := preload("res://src/shared/commands/edit_op_names.gd")
const EditPayload := preload("res://src/creator/edit_payload.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")

const CELL: int = 65536


func test_place_and_set_component_decode_a_v1_record() -> void:
	var record: Dictionary = _record_dict(4, 1)
	var placed: EditPayload = EditPayload.decode({"op": "place", "record": record})
	assert_true(placed.ok)
	assert_eq(placed.op, EditOpNames.PLACE)
	assert_eq(placed.entity_id, 4)
	assert_eq(placed.record.entity_id, 4)
	var updated: EditPayload = EditPayload.decode({"op": "set_component", "record": record})
	assert_true(updated.ok)
	assert_eq(updated.op, EditOpNames.SET_COMPONENT)


func test_remove_decodes_entity_id() -> void:
	var decoded: EditPayload = EditPayload.decode({"op": "remove", "entity_id": 7})
	assert_true(decoded.ok)
	assert_eq(decoded.op, EditOpNames.REMOVE)
	assert_eq(decoded.entity_id, 7)
	assert_null(decoded.record)


func test_unknown_keys_and_bad_bags_are_rejected() -> void:
	assert_false(EditPayload.decode({"op": "place"}).ok)
	assert_false(EditPayload.decode({"op": "place", "record": _record_dict(1, 0), "x": 1}).ok)
	assert_false(EditPayload.decode({"op": "remove"}).ok)
	assert_false(EditPayload.decode({"op": "remove", "entity_id": 0}).ok)
	assert_false(EditPayload.decode({"op": "remove", "entity_id": 1, "record": _record_dict(1, 0)}).ok)
	assert_false(EditPayload.decode({
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": 1,
			"components": {"transform": {"x": 0.5, "y": 0, "z": 0, "yaw_bam": 0}},
		},
	}).ok)
	assert_false(EditPayload.decode({"op": "spawn_script", "entity_id": 1}).ok)


func test_inverse_place_is_remove_and_remove_restores_record() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	var place_payload: Dictionary = {"op": "place", "record": _record_dict(2, 3)}
	var inverse_place: Dictionary = EditPayload.inverse(place_payload, world)
	var inverse_place_op: String = inverse_place.get("op", "")
	var inverse_place_id: int = inverse_place.get("entity_id", 0)
	assert_eq(inverse_place_op, "remove")
	assert_eq(inverse_place_id, 2)
	assert_true(world.put(SharedComponentRecord.from_dictionary(_record_dict(2, 3))))
	var inverse_remove: Dictionary = EditPayload.inverse({"op": "remove", "entity_id": 2}, world)
	var inverse_remove_op: String = inverse_remove.get("op", "")
	assert_eq(inverse_remove_op, "place")
	var restored: Dictionary = inverse_remove.get("record", {})
	var bag: SharedComponentRecord = SharedComponentRecord.from_dictionary(restored)
	assert_not_null(bag)
	assert_eq(bag.entity_id, 2)
	var transform: Dictionary = bag.components.get("transform", {})
	var stored_y: int = transform.get("y", -1)
	assert_eq(stored_y, 3 * CELL)


func test_inverse_set_component_restores_previous_bag() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(SharedComponentRecord.from_dictionary(_record_dict(1, 0))))
	var next_payload: Dictionary = {"op": "set_component", "record": _record_dict(1, 9)}
	var inverse: Dictionary = EditPayload.inverse(next_payload, world)
	var inverse_op: String = inverse.get("op", "")
	assert_eq(inverse_op, "set_component")
	var previous: Dictionary = inverse.get("record", {})
	var bag: SharedComponentRecord = SharedComponentRecord.from_dictionary(previous)
	var transform: Dictionary = bag.components.get("transform", {})
	var stored_y: int = transform.get("y", -1)
	assert_eq(stored_y, 0)


func _record_dict(entity_id: int, cells_y: int) -> Dictionary:
	return {
		"schema_version": 1,
		"entity_id": entity_id,
		"components": {
			"transform": {"x": 0, "y": cells_y * CELL, "z": 0, "yaw_bam": 0},
		},
	}
