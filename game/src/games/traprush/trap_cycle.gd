class_name TraprushTrapCycle
extends RefCounted

## 地刺 / 喷火 / 压板（可玩性深化第七批）。CD-21 §7 白名单剩余三项机关。
## **不新增组件、不改协议帧。** 开合 / 命中都不进快照。
##
## 地刺：固体 + `zone.tags` 的 `spike`。被支撑 ⇒ 环境失败（hazard）。
## 喷火：周期机关 + `zone.tags` 的 `flame`。盒子永远非固体；半周期「开」时
## 重叠 ⇒ 环境失败。与滚柱的差别是**挡路 vs 穿过去会被烫**。
## 压板：竖直 `mover` + `zone.tags` 的 `crusher`。重叠且不是它的乘客 ⇒ crush。


static func id_entries_from(bags: Array, box_ids: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw: Variant in bags:
		if typeof(raw) != TYPE_DICTIONARY:
			return []
		var bag: Dictionary = raw
		if typeof(bag.get("entity_id", null)) != TYPE_INT:
			return []
		var entity_id: int = bag["entity_id"]
		if entity_id < 1 or seen.has(entity_id) or not box_ids.has(entity_id):
			return []
		var box_raw: Variant = box_ids[entity_id]
		if typeof(box_raw) != TYPE_INT:
			return []
		var box_id: int = box_raw
		if box_id < 1:
			return []
		seen[entity_id] = true
		entries.append({"entity_id": entity_id, "box_id": box_id})
	return entries


static func flame_entries_from(bags: Array, hazard_cycle: Array[Dictionary]) -> Array[Dictionary]:
	var by_id: Dictionary = {}
	for item: Dictionary in hazard_cycle:
		if typeof(item.get("entity_id", null)) != TYPE_INT:
			return []
		if typeof(item.get("box_id", null)) != TYPE_INT:
			return []
		if typeof(item.get("cooldown_ticks", null)) != TYPE_INT:
			return []
		by_id[item["entity_id"]] = item
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw: Variant in bags:
		if typeof(raw) != TYPE_DICTIONARY:
			return []
		var bag: Dictionary = raw
		if typeof(bag.get("entity_id", null)) != TYPE_INT:
			return []
		var entity_id: int = bag["entity_id"]
		if entity_id < 1 or seen.has(entity_id) or not by_id.has(entity_id):
			return []
		seen[entity_id] = true
		var hazard: Dictionary = by_id[entity_id]
		entries.append({
			"entity_id": entity_id,
			"box_id": hazard["box_id"],
			"cooldown_ticks": hazard["cooldown_ticks"],
		})
	return entries


static func keep_flames_nonsolid(world: SimulationWorld, flames: Array[Dictionary]) -> bool:
	if world == null:
		return false
	for entry: Dictionary in flames:
		var box_id: int = entry["box_id"]
		if not world.set_static_box_solid(box_id, false):
			return false
	return true


static func spike_hits(
	world: SimulationWorld,
	spikes: Array[Dictionary],
	capsule_ids: PackedInt32Array,
	support_dy: int
) -> PackedInt32Array:
	var hits: PackedInt32Array = PackedInt32Array()
	if world == null or spikes.is_empty():
		return hits
	for capsule_id: int in capsule_ids:
		var supports: PackedInt32Array = world.supporting_solid_static_boxes(
			capsule_id, support_dy
		)
		for spike: Dictionary in spikes:
			var box_id: int = spike["box_id"]
			if supports.has(box_id):
				if not hits.has(capsule_id):
					hits.append(capsule_id)
				break
	return hits


static func flame_hits(
	world: SimulationWorld, flames: Array[Dictionary], capsule_ids: PackedInt32Array
) -> PackedInt32Array:
	var hits: PackedInt32Array = PackedInt32Array()
	if world == null or flames.is_empty():
		return hits
	for capsule_id: int in capsule_ids:
		for flame: Dictionary in flames:
			var cooldown_ticks: int = flame["cooldown_ticks"]
			if not TraprushHazardCycle.is_solid(world.tick_index, cooldown_ticks):
				continue
			var box_id: int = flame["box_id"]
			if world.overlaps_static_box(capsule_id, box_id):
				if not hits.has(capsule_id):
					hits.append(capsule_id)
				break
	return hits


static func crusher_hits(
	world: SimulationWorld,
	crushers: Array[Dictionary],
	capsule_ids: PackedInt32Array,
	support_dy: int
) -> PackedInt32Array:
	var hits: PackedInt32Array = PackedInt32Array()
	if world == null or crushers.is_empty():
		return hits
	for capsule_id: int in capsule_ids:
		var supports: PackedInt32Array = world.supporting_solid_static_boxes(
			capsule_id, support_dy
		)
		for crusher: Dictionary in crushers:
			var box_id: int = crusher["box_id"]
			if not world.is_static_box_solid(box_id):
				continue
			if not world.overlaps_static_box(capsule_id, box_id):
				continue
			if supports.has(box_id):
				continue
			if not hits.has(capsule_id):
				hits.append(capsule_id)
			break
	return hits


static func flame_is_on(entity_id: int, flames: Array[Dictionary], tick_index: int) -> bool:
	for flame: Dictionary in flames:
		if flame["entity_id"] != entity_id:
			continue
		var cooldown_ticks: int = flame["cooldown_ticks"]
		return TraprushHazardCycle.is_solid(tick_index, cooldown_ticks)
	return false
