class_name TraprushGrayboxLayout
extends RefCounted

## Layout readers for TraprushGrayboxCourse.assemble.
## Public API stays on the course facade so this file can stay under E9.

const PortalLink := preload("res://src/games/traprush/portal_link.gd")


static func _require_int(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": 0}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_INT:
		return {"ok": false, "value": 0}
	var number: int = raw
	return {"ok": true, "value": number}


static func _require_actor_id(source: Dictionary) -> Dictionary:
	var read: Dictionary = _require_int(source, "actor_id")
	if not _flag(read):
		return {"ok": false, "value": 0}
	var actor_id: int = _value(read)
	if not SharedIds.is_valid(actor_id):
		return {"ok": false, "value": 0}
	return {"ok": true, "value": actor_id}


static func _require_nonempty_string(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": ""}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_STRING:
		return {"ok": false, "value": ""}
	var text: String = raw
	if text.is_empty():
		return {"ok": false, "value": ""}
	return {"ok": true, "value": text}


static func _require_nested(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": {}}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "value": {}}
	var nested: Dictionary = raw
	return {"ok": true, "value": nested}


static func _require_box(source: Dictionary, key: String) -> Dictionary:
	var nested_read: Dictionary = _require_nested(source, key)
	if not _flag(nested_read):
		return {"ok": false}
	var box: Dictionary = nested_read["value"]
	return _require_box_fields(box)


static func _require_box_fields(box: Dictionary) -> Dictionary:
	var x_read: Dictionary = _require_int(box, "x")
	var y_read: Dictionary = _require_int(box, "y")
	var z_read: Dictionary = _require_int(box, "z")
	var half_x_read: Dictionary = _require_int(box, "half_x")
	var half_y_read: Dictionary = _require_int(box, "half_y")
	var half_z_read: Dictionary = _require_int(box, "half_z")
	if (
		not _flag(x_read)
		or not _flag(y_read)
		or not _flag(z_read)
		or not _flag(half_x_read)
		or not _flag(half_y_read)
		or not _flag(half_z_read)
	):
		return {"ok": false}
	return {
		"ok": true,
		"x": _value(x_read),
		"y": _value(y_read),
		"z": _value(z_read),
		"half_x": _value(half_x_read),
		"half_y": _value(half_y_read),
		"half_z": _value(half_z_read),
	}


static func _require_box_list(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": []}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_ARRAY:
		return {"ok": false, "value": []}
	var items: Array = raw
	var boxes: Array[Dictionary] = []
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false, "value": []}
		var box_source: Dictionary = item
		var box: Dictionary = _require_box_fields(box_source)
		if not _flag(box):
			return {"ok": false, "value": []}
		boxes.append({
			"x": _int_at(box, "x"),
			"y": _int_at(box, "y"),
			"z": _int_at(box, "z"),
			"half_x": _int_at(box, "half_x"),
			"half_y": _int_at(box, "half_y"),
			"half_z": _int_at(box, "half_z"),
		})
	return {"ok": true, "value": boxes}


static func _require_pose_fields(source: Dictionary) -> Dictionary:
	var x_read: Dictionary = _require_int(source, "x")
	var y_read: Dictionary = _require_int(source, "y")
	var z_read: Dictionary = _require_int(source, "z")
	var yaw_read: Dictionary = _require_int(source, "yaw_bam")
	if not _flag(x_read) or not _flag(y_read) or not _flag(z_read) or not _flag(yaw_read):
		return {"ok": false}
	return {
		"ok": true,
		"x": _value(x_read),
		"y": _value(y_read),
		"z": _value(z_read),
		"yaw_bam": _value(yaw_read),
	}


static func _require_named_pose(source: Dictionary, key: String) -> Dictionary:
	var nested_read: Dictionary = _require_nested(source, key)
	if not _flag(nested_read):
		return {"ok": false}
	var pose_source: Dictionary = nested_read["value"]
	return _require_pose_fields(pose_source)


static func _require_portal(source: Dictionary, key: String) -> Dictionary:
	var nested_read: Dictionary = _require_nested(source, key)
	if not _flag(nested_read):
		return {"ok": false}
	var portal: Dictionary = nested_read["value"]
	var source_read: Dictionary = _require_int(portal, "source_id")
	var dest_read: Dictionary = _require_int(portal, "dest_id")
	var x_read: Dictionary = _require_int(portal, "x")
	var y_read: Dictionary = _require_int(portal, "y")
	var z_read: Dictionary = _require_int(portal, "z")
	var yaw_read: Dictionary = _require_int(portal, "dest_yaw_bam")
	if (
		not _flag(source_read)
		or not _flag(dest_read)
		or not _flag(x_read)
		or not _flag(y_read)
		or not _flag(z_read)
		or not _flag(yaw_read)
	):
		return {"ok": false}
	return {
		"ok": true,
		"source_id": _value(source_read),
		"dest_id": _value(dest_read),
		"x": _value(x_read),
		"y": _value(y_read),
		"z": _value(z_read),
		"dest_yaw_bam": _value(yaw_read),
	}


static func _require_id_array(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": PackedInt32Array()}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_ARRAY:
		return {"ok": false, "value": PackedInt32Array()}
	var items: Array = raw
	var packed: PackedInt32Array = PackedInt32Array()
	packed.resize(items.size())
	for index: int in range(items.size()):
		var item: Variant = items[index]
		if typeof(item) != TYPE_INT:
			return {"ok": false, "value": PackedInt32Array()}
		var number: int = item
		packed[index] = number
	return {"ok": true, "value": packed}


static func _require_pose_list(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": []}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_ARRAY:
		return {"ok": false, "value": []}
	var items: Array = raw
	var poses: Array[Dictionary] = []
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false, "value": []}
		var pose_source: Dictionary = item
		var pose: Dictionary = _require_pose_fields(pose_source)
		if not _flag(pose):
			return {"ok": false, "value": []}
		poses.append({
			"x": _int_at(pose, "x"),
			"y": _int_at(pose, "y"),
			"z": _int_at(pose, "z"),
			"yaw_bam": _int_at(pose, "yaw_bam"),
		})
	return {"ok": true, "value": poses}


static func _ids_from(ids_read: Dictionary) -> Array[int]:
	var packed: PackedInt32Array = ids_read["value"]
	var ids: Array[int] = []
	ids.resize(packed.size())
	for index: int in range(packed.size()):
		ids[index] = packed[index]
	return ids


static func _pose_from(pose_read: Dictionary) -> Dictionary:
	return {
		"x": _int_at(pose_read, "x"),
		"y": _int_at(pose_read, "y"),
		"z": _int_at(pose_read, "z"),
		"yaw_bam": _int_at(pose_read, "yaw_bam"),
	}


static func _poses_from(poses_read: Dictionary) -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	var raw: Variant = poses_read["value"]
	if typeof(raw) != TYPE_ARRAY:
		return poses
	var items: Array = raw
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var pose: Dictionary = item
		poses.append(pose)
	return poses


static func _boxes_from(boxes_read: Dictionary) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	var raw: Variant = boxes_read["value"]
	if typeof(raw) != TYPE_ARRAY:
		return boxes
	var items: Array = raw
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var box: Dictionary = item
		boxes.append(box)
	return boxes


static func _portal_from(portal_read: Dictionary) -> TraprushPortalLink:
	return PortalLink.new(
		_int_at(portal_read, "source_id"),
		_int_at(portal_read, "dest_id"),
		_int_at(portal_read, "x"),
		_int_at(portal_read, "y"),
		_int_at(portal_read, "z"),
		_int_at(portal_read, "dest_yaw_bam")
	)


static func _int_at(source: Dictionary, key: String) -> int:
	var number: int = source.get(key, 0)
	return number


static func _flag(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


static func _value(result: Dictionary) -> int:
	var number: int = result.get("value", 0)
	return number


static func _text(result: Dictionary) -> String:
	var raw: Variant = result.get("value", "")
	if typeof(raw) != TYPE_STRING:
		return ""
	var text: String = raw
	return text
