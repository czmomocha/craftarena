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


static func _bag_size(base: int, carries_assets: bool) -> int:
	if carries_assets:
		return base + 2
	return base
