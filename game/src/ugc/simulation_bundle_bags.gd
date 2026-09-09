class_name SimulationBundleBags
extends RefCounted

## Occupancy-bag parsers for SimulationBundle.from_dictionary.
## Public decode stays on SimulationBundle so this file can stay under E9.

const PickupKinds := preload("res://src/ugc/traprush_pickup_kinds.gd")


static func parse_pad(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(8, carries_assets):
		return {}
	if not int_at_least(body, "entity_id", 1):
		return {}
	if not is_int_field(body, "x"):
		return {}
	if not is_int_field(body, "y"):
		return {}
	if not is_int_field(body, "z"):
		return {}
	if not int_at_least(body, "order", 0):
		return {}
	if not is_int_field(body, "respawn_dx"):
		return {}
	if not is_int_field(body, "respawn_dy"):
		return {}
	if not is_int_field(body, "respawn_dz"):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"order": body["order"],
		"respawn_dx": body["respawn_dx"],
		"respawn_dy": body["respawn_dy"],
		"respawn_dz": body["respawn_dz"],
	}
	if not merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func parse_portal(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(10, carries_assets):
		return {}
	if not int_at_least(body, "entity_id", 1):
		return {}
	if not int_at_least(body, "target_id", 1):
		return {}
	if not body.has("kind") or typeof(body["kind"]) != TYPE_STRING:
		return {}
	var kind: String = body["kind"]
	if kind != AuthoringPortalKinds.TWO_WAY and kind != AuthoringPortalKinds.ONE_WAY:
		return {}
	if not is_int_field(body, "x"):
		return {}
	if not is_int_field(body, "y"):
		return {}
	if not is_int_field(body, "z"):
		return {}
	if not is_int_field(body, "dest_x"):
		return {}
	if not is_int_field(body, "dest_y"):
		return {}
	if not is_int_field(body, "dest_z"):
		return {}
	if not is_int_field(body, "dest_yaw_bam"):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"target_id": body["target_id"],
		"kind": kind,
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"dest_x": body["dest_x"],
		"dest_y": body["dest_y"],
		"dest_z": body["dest_z"],
		"dest_yaw_bam": body["dest_yaw_bam"],
	}
	if not merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func parse_finish(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(4, carries_assets):
		return {}
	if not int_at_least(body, "entity_id", 1):
		return {}
	if not is_int_field(body, "x"):
		return {}
	if not is_int_field(body, "y"):
		return {}
	if not is_int_field(body, "z"):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
	}
	if not merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func parse_destructible(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(5, carries_assets):
		return {}
	if not int_at_least(body, "entity_id", 1):
		return {}
	if not is_int_field(body, "x"):
		return {}
	if not is_int_field(body, "y"):
		return {}
	if not is_int_field(body, "z"):
		return {}
	if not int_at_least(body, "durability", 0):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"durability": body["durability"],
	}
	if not merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func parse_hazard(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(5, carries_assets):
		return {}
	if not int_at_least(body, "entity_id", 1):
		return {}
	if not is_int_field(body, "x"):
		return {}
	if not is_int_field(body, "y"):
		return {}
	if not is_int_field(body, "z"):
		return {}
	if not int_at_least(body, "cooldown_ticks", 0):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"cooldown_ticks": body["cooldown_ticks"],
	}
	if not merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func parse_solid(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(4, carries_assets):
		return {}
	if not int_at_least(body, "entity_id", 1):
		return {}
	if not is_int_field(body, "x"):
		return {}
	if not is_int_field(body, "y"):
		return {}
	if not is_int_field(body, "z"):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
	}
	if not merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func parse_pickup(body: Dictionary, carries_assets: bool) -> Dictionary:
	if body.size() != _bag_size(5, carries_assets):
		return {}
	if not int_at_least(body, "entity_id", 1):
		return {}
	if not is_int_field(body, "x"):
		return {}
	if not is_int_field(body, "y"):
		return {}
	if not is_int_field(body, "z"):
		return {}
	if not body.has("kind") or typeof(body["kind"]) != TYPE_STRING:
		return {}
	var kind: String = body["kind"]
	if not PickupKinds.contains(kind):
		return {}
	var parsed: Dictionary = {
		"entity_id": body["entity_id"],
		"x": body["x"],
		"y": body["y"],
		"z": body["z"],
		"kind": kind,
	}
	if not merge_asset_ref(body, parsed, carries_assets):
		return {}
	return parsed


static func parse_mover(body: Dictionary) -> Dictionary:
	if body.size() != 4:
		return {}
	if not int_at_least(body, "entity_id", 1):
		return {}
	if not is_int_field(body, "speed"):
		return {}
	if not body.has("loop") or typeof(body["loop"]) != TYPE_BOOL:
		return {}
	if not body.has("path") or typeof(body["path"]) != TYPE_ARRAY:
		return {}
	var path_raw: Array = body["path"]
	if path_raw.size() < 2:
		return {}
	var path: Array = []
	for item: Variant in path_raw:
		if typeof(item) != TYPE_DICTIONARY:
			return {}
		var point: Dictionary = item
		if not is_int_field(point, "x") or not is_int_field(point, "y") or not is_int_field(point, "z"):
			return {}
		if point.size() != 3:
			return {}
		path.append({"x": point["x"], "y": point["y"], "z": point["z"]})
	if not path_is_axial(path):
		return {}
	return {
		"entity_id": body["entity_id"],
		"speed": body["speed"],
		"loop": body["loop"],
		"path": path,
	}


static func path_is_axial(path: Array) -> bool:
	var index: int = 1
	while index < path.size():
		var prev: Dictionary = path[index - 1]
		var cur: Dictionary = path[index]
		var diffs: int = 0
		if not is_int_field(prev, "x") or not is_int_field(cur, "x"):
			return false
		if not is_int_field(prev, "y") or not is_int_field(cur, "y"):
			return false
		if not is_int_field(prev, "z") or not is_int_field(cur, "z"):
			return false
		var px: int = _int_at(prev, "x")
		var py: int = _int_at(prev, "y")
		var pz: int = _int_at(prev, "z")
		var cx: int = _int_at(cur, "x")
		var cy: int = _int_at(cur, "y")
		var cz: int = _int_at(cur, "z")
		if px != cx:
			diffs += 1
		if py != cy:
			diffs += 1
		if pz != cz:
			diffs += 1
		if diffs != 1:
			return false
		index += 1
	return true


## 电梯路径：每段只许改 Y。水平往返不是电梯，那是已有 `mover`。
static func path_is_vertical(path: Array) -> bool:
	if not path_is_axial(path):
		return false
	var index: int = 1
	while index < path.size():
		var prev: Dictionary = path[index - 1]
		var cur: Dictionary = path[index]
		if _int_at(prev, "x") != _int_at(cur, "x"):
			return false
		if _int_at(prev, "z") != _int_at(cur, "z"):
			return false
		if _int_at(prev, "y") == _int_at(cur, "y"):
			return false
		index += 1
	return true


static func merge_asset_ref(body: Dictionary, out: Dictionary, carries_assets: bool) -> bool:
	if not carries_assets:
		out["asset_id"] = SharedGameplayAssetCatalog.LATTICE_CELL_ID
		out["gameplay_version"] = SharedGameplayAssetCatalog.LATTICE_CELL_VERSION
		return true
	if not int_at_least(body, "asset_id", 1):
		return false
	if not int_at_least(body, "gameplay_version", 1):
		return false
	out["asset_id"] = body["asset_id"]
	out["gameplay_version"] = body["gameplay_version"]
	return true


static func int_at_least(body: Dictionary, key: String, minimum: int) -> bool:
	if not is_int_field(body, key):
		return false
	var value: int = body[key]
	return value >= minimum


static func is_int_field(body: Dictionary, key: String) -> bool:
	return body.has(key) and typeof(body[key]) == TYPE_INT


static func _int_at(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, null)
	if typeof(raw) != TYPE_INT:
		return 0
	var value: int = raw
	return value


static func _bag_size(base: int, carries_assets: bool) -> int:
	if carries_assets:
		return base + 2
	return base
