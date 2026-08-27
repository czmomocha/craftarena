class_name TraprushPickupAccept
extends RefCounted

## 占用扫描授予爆破球 / 冲刺。每个 pickup 实体每玩家只拾一次；每种最多持有 1 个。
## 已持有该 kind 时不标记 taken，用掉后仍可拾另一个同 kind 实体。
## 不消耗世界占用盒（非固体拾取盒一直在）。不发明槽位、替换或叠加。Never settlement.

const PickupKinds := preload("res://src/ugc/traprush_pickup_kinds.gd")


static func try_grant(
	world: SimulationWorld,
	capsule_id: int,
	pickup_ids: Dictionary,
	pickup_kinds: Dictionary,
	taken: Dictionary,
	bomb: int,
	dash: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null:
		return failed
	var next_taken: Dictionary = taken.duplicate()
	var next_bomb: int = bomb
	var next_dash: int = dash
	var ids: Array[int] = []
	for key: Variant in pickup_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		ids.append(entity_id)
	ids.sort()
	for entity_id: int in ids:
		if next_taken.has(entity_id):
			continue
		var box_raw: Variant = pickup_ids[entity_id]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		if not world.overlaps_static_box(capsule_id, box_id):
			continue
		var kind_raw: Variant = pickup_kinds.get(entity_id, "")
		if typeof(kind_raw) != TYPE_STRING:
			continue
		var kind: String = kind_raw
		if kind == PickupKinds.BOMB:
			if next_bomb >= 1:
				continue
			next_bomb += 1
			next_taken[entity_id] = true
		elif kind == PickupKinds.DASH:
			if next_dash >= 1:
				continue
			next_dash += 1
			next_taken[entity_id] = true
	return {
		"ok": true,
		"bomb": next_bomb,
		"dash": next_dash,
		"taken": next_taken,
	}
