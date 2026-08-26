class_name TraprushHazardCycle
extends RefCounted

## 周期机关固体切换：与灰盒 try_commit_tick 同一公式，用已有
## hazard.cooldown_ticks 当半周期，不发明 period 字段。
## cooldown_ticks < 1 时始终固体（避免除零）。不读 damage / knockback，
## 不挤出、不伤害。只在调用方推进 tick 之后调用。不结算。


static func is_solid(tick_index: int, cooldown_ticks: int) -> bool:
	if cooldown_ticks < 1:
		return true
	return ((tick_index / cooldown_ticks) % 2) == 0


static func entries_from(hazards: Array, hazard_ids: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item: Variant in hazards:
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var bag: Dictionary = item
		if typeof(bag.get("entity_id", null)) != TYPE_INT:
			return []
		if typeof(bag.get("cooldown_ticks", null)) != TYPE_INT:
			return []
		var entity_id: int = bag["entity_id"]
		if not hazard_ids.has(entity_id):
			return []
		var box_raw: Variant = hazard_ids[entity_id]
		if typeof(box_raw) != TYPE_INT:
			return []
		var box_id: int = box_raw
		if box_id < 1:
			return []
		var cooldown_ticks: int = bag["cooldown_ticks"]
		if cooldown_ticks < 0:
			return []
		entries.append({
			"box_id": box_id,
			"cooldown_ticks": cooldown_ticks,
		})
	return entries


static func apply(world: SimulationWorld, entries: Array) -> bool:
	if world == null:
		return false
	for item: Variant in entries:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var entry: Dictionary = item
		if typeof(entry.get("box_id", null)) != TYPE_INT:
			return false
		if typeof(entry.get("cooldown_ticks", null)) != TYPE_INT:
			return false
		var box_id: int = entry["box_id"]
		var cooldown_ticks: int = entry["cooldown_ticks"]
		if not world.set_static_box_solid(box_id, is_solid(world.tick_index, cooldown_ticks)):
			return false
	return true
