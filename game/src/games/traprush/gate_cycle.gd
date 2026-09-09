class_name TraprushGateCycle
extends RefCounted

## 踩区开关门与开关传送（可玩性深化第四 / 六批）。
##
## CD-21 §5.1 触发型障碍写的是「交互、踩区或规则图」。InteractIntent 要新增
## 命令帧 id，快照要带开合状态，两处都是协议不兼容（宪法第十八条）。本刀只做
## **踩区**：开合是当前占用的纯函数，不写 `interactable.state`，不进快照帧。
##
## 一组 `link_group` 在这一拍打开，当且仅当：
## 1. 有胶囊被该组开关**支撑**（压力板），或
## 2. 有胶囊与该组门盒相交（门洞传感器，含当前非固体的门——人正在穿过去）。
## 走开后同一拍关上。走进已关的门会被挡住；关在身上则按 crush 复位。
##
## **不新增组件。** 开关 / 门都是固体 + `zone.tags` 的 `switch` / `gate` +
## 已有 `interactable.link_group`。`state` 作者填 0，运行时不读。
## 与 conveyor / launch / mover 同实体拒绝：一块既载人又当墙的地板没有
## 可解释的先后。


static func entries_from(bags: Array, solid_ids: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var ids: Array[int] = []
	var by_id: Dictionary = {}
	for raw: Variant in bags:
		if typeof(raw) != TYPE_DICTIONARY:
			return []
		var bag: Dictionary = raw
		var entity_raw: Variant = bag.get("entity_id", null)
		var group_raw: Variant = bag.get("link_group", null)
		if typeof(entity_raw) != TYPE_INT or typeof(group_raw) != TYPE_INT:
			return []
		var entity_id: int = entity_raw
		var link_group: int = group_raw
		if link_group < 0 or by_id.has(entity_id) or not solid_ids.has(entity_id):
			return []
		var box_raw: Variant = solid_ids[entity_id]
		if typeof(box_raw) != TYPE_INT:
			return []
		var box_id: int = box_raw
		if box_id < 1:
			return []
		by_id[entity_id] = {"box_id": box_id, "link_group": link_group}
		ids.append(entity_id)
	ids.sort()
	for entity_id: int in ids:
		var body: Dictionary = by_id[entity_id]
		entries.append({
			"entity_id": entity_id,
			"box_id": body["box_id"],
			"link_group": body["link_group"],
		})
	return entries


## 被支撑的开关组 ∪ 正穿门洞的组。
static func occupied_groups(
	world: SimulationWorld,
	switches: Array[Dictionary],
	gates: Array[Dictionary],
	capsule_ids: PackedInt32Array,
	support_dy: int
) -> Dictionary:
	var occupied: Dictionary = {}
	if world == null:
		return occupied
	for capsule_id: int in capsule_ids:
		var supports: PackedInt32Array = world.supporting_solid_static_boxes(
			capsule_id, support_dy
		)
		for switch_entry: Dictionary in switches:
			var switch_box: int = switch_entry["box_id"]
			if supports.has(switch_box):
				occupied[switch_entry["link_group"]] = true
		for gate_entry: Dictionary in gates:
			var gate_box: int = gate_entry["box_id"]
			if world.overlaps_static_box(capsule_id, gate_box):
				occupied[gate_entry["link_group"]] = true
	return occupied


## 按占用切换门固体。返回被关上的门夹住的胶囊（调用方 crush 复位）。
static func apply(
	world: SimulationWorld,
	switches: Array[Dictionary],
	gates: Array[Dictionary],
	capsule_ids: PackedInt32Array,
	support_dy: int
) -> PackedInt32Array:
	var crushed: PackedInt32Array = PackedInt32Array()
	if world == null or gates.is_empty():
		return crushed
	var occupied: Dictionary = occupied_groups(
		world, switches, gates, capsule_ids, support_dy
	)
	for gate_entry: Dictionary in gates:
		var box_id: int = gate_entry["box_id"]
		var link_group: int = gate_entry["link_group"]
		var open: bool = occupied.get(link_group, false)
		if not world.set_static_box_solid(box_id, not open):
			return PackedInt32Array()
	for capsule_id: int in capsule_ids:
		for gate_entry: Dictionary in gates:
			var box_id: int = gate_entry["box_id"]
			if not world.is_static_box_solid(box_id):
				continue
			if world.overlaps_static_box(capsule_id, box_id):
				if not crushed.has(capsule_id):
					crushed.append(capsule_id)
				break
	return crushed


static func portal_is_open(
	entity_id: int, portal_switches: Array[Dictionary], occupied: Dictionary
) -> bool:
	for entry: Dictionary in portal_switches:
		var switch_id: int = entry["entity_id"]
		if switch_id != entity_id:
			continue
		var link_group: int = entry["link_group"]
		return occupied.get(link_group, false)
	return true


static func open_portal_ids(
	portal_switches: Array[Dictionary], occupied: Dictionary
) -> PackedInt32Array:
	var open_ids: PackedInt32Array = PackedInt32Array()
	for entry: Dictionary in portal_switches:
		var link_group: int = entry["link_group"]
		if occupied.get(link_group, false):
			var entity_id: int = entry["entity_id"]
			open_ids.append(entity_id)
	return open_ids


static func open_entity_ids(world: SimulationWorld, gates: Array[Dictionary]) -> PackedInt32Array:
	var open_ids: PackedInt32Array = PackedInt32Array()
	if world == null:
		return open_ids
	for gate_entry: Dictionary in gates:
		var box_id: int = gate_entry["box_id"]
		if world.is_static_box_solid(box_id):
			continue
		var entity_id: int = gate_entry["entity_id"]
		open_ids.append(entity_id)
	return open_ids


## 表现层重算：没有 SimulationWorld 时（线上快照）用胶囊 AABB + 向下探针
## 近似权威占用。Solo 应读会话的 `open_entity_ids`，不要走这条。
static func presentation_occupied_groups(
	switches: Array[Dictionary],
	gates: Array[Dictionary],
	players: Array,
	cell: int,
	radius: int,
	height: int,
	support_dy: int
) -> Dictionary:
	var occupied: Dictionary = {}
	if cell < 1 or radius < 1 or height < 1:
		return occupied
	var half: int = cell / 2
	var cap_hy: int = height / 2 + radius
	for player_raw: Variant in players:
		if typeof(player_raw) != TYPE_DICTIONARY:
			continue
		var player: Dictionary = player_raw
		if typeof(player.get("x", null)) != TYPE_INT:
			continue
		if typeof(player.get("y", null)) != TYPE_INT:
			continue
		if typeof(player.get("z", null)) != TYPE_INT:
			continue
		var px: int = player["x"]
		var py: int = player["y"]
		var pz: int = player["z"]
		var cap_bottom: int = py - cap_hy
		for switch_entry: Dictionary in switches:
			if _presentation_supported(px, pz, cap_bottom, switch_entry, half, radius, support_dy):
				occupied[switch_entry["link_group"]] = true
		for gate_entry: Dictionary in gates:
			if _presentation_overlaps(px, py, pz, radius, cap_hy, gate_entry, half):
				occupied[gate_entry["link_group"]] = true
	return occupied


static func presentation_open_entity_ids(
	switches: Array[Dictionary],
	gates: Array[Dictionary],
	players: Array,
	cell: int,
	radius: int,
	height: int,
	support_dy: int
) -> PackedInt32Array:
	var open_ids: PackedInt32Array = PackedInt32Array()
	var occupied: Dictionary = presentation_occupied_groups(
		switches, gates, players, cell, radius, height, support_dy
	)
	for gate_entry: Dictionary in gates:
		var link_group: int = gate_entry["link_group"]
		if occupied.get(link_group, false):
			var entity_id: int = gate_entry["entity_id"]
			open_ids.append(entity_id)
	return open_ids


static func _presentation_supported(
	px: int,
	pz: int,
	cap_bottom: int,
	box: Dictionary,
	half: int,
	radius: int,
	support_dy: int
) -> bool:
	if typeof(box.get("x", null)) != TYPE_INT:
		return false
	if typeof(box.get("y", null)) != TYPE_INT:
		return false
	if typeof(box.get("z", null)) != TYPE_INT:
		return false
	var sx: int = box["x"]
	var sy: int = box["y"]
	var sz: int = box["z"]
	if absi(px - sx) >= radius + half:
		return false
	if absi(pz - sz) >= radius + half:
		return false
	var box_min: int = sy - half
	var box_max: int = sy + half
	var probe_min: int = cap_bottom + support_dy
	return probe_min < box_max and cap_bottom > box_min


static func _presentation_overlaps(
	px: int, py: int, pz: int, radius: int, cap_hy: int, box: Dictionary, half: int
) -> bool:
	if typeof(box.get("x", null)) != TYPE_INT:
		return false
	if typeof(box.get("y", null)) != TYPE_INT:
		return false
	if typeof(box.get("z", null)) != TYPE_INT:
		return false
	var sx: int = box["x"]
	var sy: int = box["y"]
	var sz: int = box["z"]
	if absi(px - sx) >= radius + half:
		return false
	if absi(pz - sz) >= radius + half:
		return false
	return absi(py - sy) < cap_hy + half
