class_name SimulationBundleDecode
extends RefCounted

## Wire decode for SimulationBundle.from_dictionary.
## Field names and SCHEMA_VERSION stay on the facade (content-validator reads
## that file). Public API stays on SimulationBundle so this file stays under E9.

const BagsGd := preload("res://src/ugc/simulation_bundle_bags.gd")


static func from_dictionary(data: Dictionary) -> SimulationBundle:
	var coerced: Variant = coerce_json_ints(data)
	if typeof(coerced) != TYPE_DICTIONARY:
		return null
	var body: Dictionary = coerced
	if not body.has(SimulationBundle.FIELD_SCHEMA_VERSION) or typeof(body[SimulationBundle.FIELD_SCHEMA_VERSION]) != TYPE_INT:
		return null
	var version: int = body[SimulationBundle.FIELD_SCHEMA_VERSION]
	if version != SimulationBundle.SCHEMA_VERSION and version != SimulationBundle.MIGRATED_FROM_VERSION:
		return null
	var carries_assets: bool = version == SimulationBundle.SCHEMA_VERSION
	var expected_size: int = 11 if carries_assets else 10
	if body.size() != expected_size:
		return null
	if not body.has(SimulationBundle.FIELD_CELL) or typeof(body[SimulationBundle.FIELD_CELL]) != TYPE_INT:
		return null
	var cell: int = body[SimulationBundle.FIELD_CELL]
	if cell < 1:
		return null
	if not body.has(SimulationBundle.FIELD_SOURCE_REVISION) or typeof(body[SimulationBundle.FIELD_SOURCE_REVISION]) != TYPE_INT:
		return null
	var source_revision: int = body[SimulationBundle.FIELD_SOURCE_REVISION]
	if source_revision < 0:
		return null
	if not body.has(SimulationBundle.FIELD_PADS) or typeof(body[SimulationBundle.FIELD_PADS]) != TYPE_ARRAY:
		return null
	if not body.has(SimulationBundle.FIELD_PORTALS) or typeof(body[SimulationBundle.FIELD_PORTALS]) != TYPE_ARRAY:
		return null
	var pads: Array[Dictionary] = []
	var pad_ids: Dictionary[int, bool] = {}
	var raw_pads: Array = body[SimulationBundle.FIELD_PADS]
	for item: Variant in raw_pads:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var bag: Dictionary = item
		var pad: Dictionary = BagsGd.parse_pad(bag, carries_assets)
		if pad.is_empty():
			return null
		var pad_id: int = pad["entity_id"]
		if pad_ids.has(pad_id):
			return null
		pad_ids[pad_id] = true
		pads.append(pad)
	var portals: Array[Dictionary] = []
	var portal_ids: Dictionary[int, bool] = {}
	var raw_portals: Array = body[SimulationBundle.FIELD_PORTALS]
	for item: Variant in raw_portals:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var portal_bag: Dictionary = item
		var portal: Dictionary = BagsGd.parse_portal(portal_bag, carries_assets)
		if portal.is_empty():
			return null
		var portal_id: int = portal["entity_id"]
		if portal_ids.has(portal_id):
			return null
		portal_ids[portal_id] = true
		portals.append(portal)
	if not body.has(SimulationBundle.FIELD_FINISH) or typeof(body[SimulationBundle.FIELD_FINISH]) != TYPE_ARRAY:
		return null
	var finish_list: Array[Dictionary] = []
	var raw_finish: Array = body[SimulationBundle.FIELD_FINISH]
	if raw_finish.size() > 1:
		return null
	for item: Variant in raw_finish:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var finish_bag: Dictionary = item
		var parsed_finish: Dictionary = BagsGd.parse_finish(finish_bag, carries_assets)
		if parsed_finish.is_empty():
			return null
		var finish_id: int = parsed_finish["entity_id"]
		if pad_ids.has(finish_id) or portal_ids.has(finish_id):
			return null
		finish_list.append(parsed_finish)
	if not body.has(SimulationBundle.FIELD_DESTRUCTIBLES) or typeof(body[SimulationBundle.FIELD_DESTRUCTIBLES]) != TYPE_ARRAY:
		return null
	var destructible_list: Array[Dictionary] = []
	var destructible_ids: Dictionary[int, bool] = {}
	var raw_destructibles: Array = body[SimulationBundle.FIELD_DESTRUCTIBLES]
	for item: Variant in raw_destructibles:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var crate_bag: Dictionary = item
		var parsed_crate: Dictionary = BagsGd.parse_destructible(crate_bag, carries_assets)
		if parsed_crate.is_empty():
			return null
		var crate_id: int = parsed_crate["entity_id"]
		if (
			destructible_ids.has(crate_id)
			or pad_ids.has(crate_id)
			or portal_ids.has(crate_id)
		):
			return null
		for finish_item: Dictionary in finish_list:
			var finish_entity: int = finish_item["entity_id"]
			if finish_entity == crate_id:
				return null
		destructible_ids[crate_id] = true
		destructible_list.append(parsed_crate)
	if not body.has(SimulationBundle.FIELD_HAZARDS) or typeof(body[SimulationBundle.FIELD_HAZARDS]) != TYPE_ARRAY:
		return null
	var hazard_list: Array[Dictionary] = []
	var hazard_ids: Dictionary[int, bool] = {}
	var raw_hazards: Array = body[SimulationBundle.FIELD_HAZARDS]
	for item: Variant in raw_hazards:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var hazard_bag: Dictionary = item
		var parsed_hazard: Dictionary = BagsGd.parse_hazard(hazard_bag, carries_assets)
		if parsed_hazard.is_empty():
			return null
		var hazard_id: int = parsed_hazard["entity_id"]
		if (
			hazard_ids.has(hazard_id)
			or pad_ids.has(hazard_id)
			or portal_ids.has(hazard_id)
			or destructible_ids.has(hazard_id)
		):
			return null
		for finish_item: Dictionary in finish_list:
			var finish_entity: int = finish_item["entity_id"]
			if finish_entity == hazard_id:
				return null
		hazard_ids[hazard_id] = true
		hazard_list.append(parsed_hazard)
	if not body.has(SimulationBundle.FIELD_SOLIDS) or typeof(body[SimulationBundle.FIELD_SOLIDS]) != TYPE_ARRAY:
		return null
	var solid_list: Array[Dictionary] = []
	var solid_ids: Dictionary[int, bool] = {}
	var raw_solids: Array = body[SimulationBundle.FIELD_SOLIDS]
	for item: Variant in raw_solids:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var solid_bag: Dictionary = item
		var parsed_solid: Dictionary = BagsGd.parse_solid(solid_bag, carries_assets)
		if parsed_solid.is_empty():
			return null
		var solid_id: int = parsed_solid["entity_id"]
		if (
			solid_ids.has(solid_id)
			or pad_ids.has(solid_id)
			or portal_ids.has(solid_id)
			or destructible_ids.has(solid_id)
			or hazard_ids.has(solid_id)
		):
			return null
		for finish_item: Dictionary in finish_list:
			var finish_entity: int = finish_item["entity_id"]
			if finish_entity == solid_id:
				return null
		solid_ids[solid_id] = true
		solid_list.append(parsed_solid)
	if not body.has(SimulationBundle.FIELD_PICKUPS) or typeof(body[SimulationBundle.FIELD_PICKUPS]) != TYPE_ARRAY:
		return null
	var pickup_list: Array[Dictionary] = []
	var pickup_ids: Dictionary[int, bool] = {}
	var raw_pickups: Array = body[SimulationBundle.FIELD_PICKUPS]
	for item: Variant in raw_pickups:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var pickup_bag: Dictionary = item
		var parsed_pickup: Dictionary = BagsGd.parse_pickup(pickup_bag, carries_assets)
		if parsed_pickup.is_empty():
			return null
		var pickup_id: int = parsed_pickup["entity_id"]
		if (
			pickup_ids.has(pickup_id)
			or pad_ids.has(pickup_id)
			or portal_ids.has(pickup_id)
			or destructible_ids.has(pickup_id)
			or hazard_ids.has(pickup_id)
			or solid_ids.has(pickup_id)
		):
			return null
		for finish_item: Dictionary in finish_list:
			var finish_entity: int = finish_item["entity_id"]
			if finish_entity == pickup_id:
				return null
		pickup_ids[pickup_id] = true
		pickup_list.append(parsed_pickup)
	var occupancy: Array[Dictionary] = []
	occupancy.append_array(pads)
	occupancy.append_array(portals)
	occupancy.append_array(finish_list)
	occupancy.append_array(destructible_list)
	occupancy.append_array(hazard_list)
	occupancy.append_array(solid_list)
	occupancy.append_array(pickup_list)
	var asset_list: Array[Dictionary] = []
	if carries_assets:
		if not body.has(SimulationBundle.FIELD_ASSETS) or typeof(body[SimulationBundle.FIELD_ASSETS]) != TYPE_ARRAY:
			return null
		asset_list = parse_assets(body[SimulationBundle.FIELD_ASSETS])
		if asset_list.is_empty() and not _is_empty_array(body[SimulationBundle.FIELD_ASSETS]):
			return null
	else:
		asset_list = migrated_assets(cell, occupancy.is_empty())
		if asset_list.is_empty() and not occupancy.is_empty():
			return null
	if not references_are_closed(asset_list, occupancy):
		return null
	var bundle: SimulationBundle = SimulationBundle.new()
	bundle.cell = cell
	bundle.source_revision = source_revision
	bundle.assets = asset_list
	bundle.pads = pads
	bundle.portals = portals
	bundle.finish = finish_list
	bundle.destructibles = destructible_list
	bundle.hazards = hazard_list
	bundle.solids = solid_list
	bundle.pickups = pickup_list
	return bundle


static func parse_assets(value: Variant) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return parsed
	var items: Array = value
	var previous_id: int = 0
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var entry: Dictionary = item
		if not SharedGameplayAssetCatalog.entry_is_valid(entry):
			return []
		var asset_id: int = entry["asset_id"]
		if asset_id <= previous_id:
			return []
		previous_id = asset_id
		parsed.append(entry.duplicate(true))
	return parsed


static func migrated_assets(cell: int, occupancy_is_empty: bool) -> Array[Dictionary]:
	var migrated: Array[Dictionary] = []
	if occupancy_is_empty:
		return migrated
	var entry: Dictionary = SharedGameplayAssetCatalog.try_entry(
		SharedGameplayAssetCatalog.LATTICE_CELL_ID,
		SharedGameplayAssetCatalog.LATTICE_CELL_VERSION,
		cell
	)
	if entry.is_empty():
		return migrated
	migrated.append(entry)
	return migrated


static func references_are_closed(
	asset_list: Array[Dictionary], occupancy: Array[Dictionary]
) -> bool:
	var versions: Dictionary[int, int] = {}
	for entry: Dictionary in asset_list:
		var asset_id: int = entry["asset_id"]
		var entry_version: int = entry["gameplay_version"]
		versions[asset_id] = entry_version
	var referenced: Dictionary[int, bool] = {}
	for bag: Dictionary in occupancy:
		var bag_asset: int = bag["asset_id"]
		var bag_version: int = bag["gameplay_version"]
		if not versions.has(bag_asset):
			return false
		var known_version: int = versions[bag_asset]
		if known_version != bag_version:
			return false
		referenced[bag_asset] = true
	for entry: Dictionary in asset_list:
		var listed_id: int = entry["asset_id"]
		if not referenced.has(listed_id):
			return false
	return true


static func coerce_json_ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			var number: float = value
			if not is_finite(number):
				return value
			var as_int: int = int(number)
			if float(as_int) != number:
				return value
			return as_int
		TYPE_ARRAY:
			var items: Array = value
			var next_items: Array = []
			for item: Variant in items:
				next_items.append(coerce_json_ints(item))
			return next_items
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var next_body: Dictionary = {}
			for key: Variant in source:
				next_body[key] = coerce_json_ints(source[key])
			return next_body
		_:
			return value


static func _is_empty_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var items: Array = value
	return items.is_empty()
