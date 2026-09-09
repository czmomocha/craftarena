class_name SimulationBundleOptional
extends RefCounted

## Optional occupancy-bag parsers (movers stay on bags). Decode calls this
## so simulation_bundle_bags.gd stays under E9. Geometry lives in solids or
## destructibles; these bags only carry behaviour.

const BagsGd := preload("res://src/ugc/simulation_bundle_bags.gd")


## 传送带袋。几何不在这里——传送带同时写进 `solids`，本袋只带方向，
## 与 `movers` 同一条约定（见 `TraprushConveyorCycle` 文件头）。
static func parse_conveyor(body: Dictionary) -> Dictionary:
	return parse_yaw_bag(body)


## 弹射垫袋。形状与传送带相同（entity_id + yaw_bam），语义不同：
## 传送带每 tick 推，弹射垫是支撑上升沿弹一次。见 `TraprushLaunchCycle`。
static func parse_launch(body: Dictionary) -> Dictionary:
	return parse_yaw_bag(body)


static func parse_link_bag(body: Dictionary) -> Dictionary:
	if body.size() != 2:
		return {}
	if not BagsGd.int_at_least(body, "entity_id", 1):
		return {}
	if not BagsGd.int_at_least(body, "link_group", 0):
		return {}
	return {
		"entity_id": body["entity_id"],
		"link_group": body["link_group"],
	}


static func parse_optional_field(
	body: Dictionary, field: String, id_set: Dictionary, mode: String
) -> Dictionary:
	if not body.has(field):
		var empty: Array[Dictionary] = []
		return {"ok": true, "items": empty}
	var raw: Variant = body[field]
	if typeof(raw) != TYPE_ARRAY:
		var failed: Array[Dictionary] = []
		return {"ok": false, "items": failed}
	var items: Array = raw
	return parse_optional_solid_refs(items, id_set, mode)


static func parse_id_bag(body: Dictionary) -> Dictionary:
	if body.size() != 1:
		return {}
	if not BagsGd.int_at_least(body, "entity_id", 1):
		return {}
	return {"entity_id": body["entity_id"]}


static func parse_optional_solid_refs(
	raw: Array, solid_ids: Dictionary, mode: String
) -> Dictionary:
	var items: Array[Dictionary] = []
	var seen: Dictionary[int, bool] = {}
	for item: Variant in raw:
		if typeof(item) != TYPE_DICTIONARY:
			return {"ok": false, "items": items}
		var bag: Dictionary = item
		var parsed: Dictionary = {}
		if mode == "link":
			parsed = parse_link_bag(bag)
		elif mode == "id":
			parsed = parse_id_bag(bag)
		else:
			parsed = parse_yaw_bag(bag)
		if parsed.is_empty():
			return {"ok": false, "items": items}
		var entity_id: int = parsed["entity_id"]
		if not solid_ids.has(entity_id) or seen.has(entity_id):
			return {"ok": false, "items": items}
		seen[entity_id] = true
		items.append(parsed)
	return {"ok": true, "items": items}


static func parse_yaw_bag(body: Dictionary) -> Dictionary:
	if body.size() != 2:
		return {}
	if not BagsGd.int_at_least(body, "entity_id", 1):
		return {}
	if not BagsGd.is_int_field(body, "yaw_bam"):
		return {}
	var yaw_bam: int = body["yaw_bam"]
	if yaw_bam < 0 or yaw_bam >= Fixed.BAM_TURN:
		return {}
	return {
		"entity_id": body["entity_id"],
		"yaw_bam": yaw_bam,
	}


static func assign_trap_bags(
	bundle: SimulationBundle,
	body: Dictionary,
	solid_ids: Dictionary,
	hazard_ids: Dictionary,
	destructible_ids: Dictionary
) -> bool:
	var parsed_spikes: Dictionary = parse_optional_field(
		body, SimulationBundle.FIELD_SPIKES, solid_ids, "id"
	)
	if not parsed_spikes.get("ok", false):
		return false
	var parsed_flames: Dictionary = parse_optional_field(
		body, SimulationBundle.FIELD_FLAMES, hazard_ids, "id"
	)
	if not parsed_flames.get("ok", false):
		return false
	var parsed_crushers: Dictionary = parse_optional_field(
		body, SimulationBundle.FIELD_CRUSHERS, solid_ids, "id"
	)
	if not parsed_crushers.get("ok", false):
		return false
	bundle.spikes = parsed_spikes["items"]
	bundle.flames = parsed_flames["items"]
	bundle.crushers = parsed_crushers["items"]
	var parsed_rollers: Dictionary = parse_optional_field(
		body, SimulationBundle.FIELD_ROLLERS, hazard_ids, "id"
	)
	if not parsed_rollers.get("ok", false):
		return false
	var parsed_rubbles: Dictionary = parse_optional_field(
		body, SimulationBundle.FIELD_RUBBLES, destructible_ids, "id"
	)
	if not parsed_rubbles.get("ok", false):
		return false
	var parsed_cores: Dictionary = parse_optional_field(
		body, SimulationBundle.FIELD_OBSTACLE_CORES, destructible_ids, "id"
	)
	if not parsed_cores.get("ok", false):
		return false
	bundle.rollers = parsed_rollers["items"]
	bundle.rubbles = parsed_rubbles["items"]
	bundle.obstacle_cores = parsed_cores["items"]
	var parsed_pendulums: Dictionary = parse_optional_field(
		body, SimulationBundle.FIELD_PENDULUMS, solid_ids, "id"
	)
	if not parsed_pendulums.get("ok", false):
		return false
	var parsed_ices: Dictionary = parse_optional_field(
		body, SimulationBundle.FIELD_ICES, solid_ids, "yaw"
	)
	if not parsed_ices.get("ok", false):
		return false
	bundle.pendulums = parsed_pendulums["items"]
	bundle.ices = parsed_ices["items"]
	return true
