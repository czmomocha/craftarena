class_name TraprushEditorPanelIds
extends RefCounted

## 工具条的 id / order / 光标续号扫描。
## 公开 API 仍在 `TraprushEditorPanel` 上，本文件只是让它低于 E9 400 行。


## 导入一份世界之后，下一个实体 id、下一个检查点 order、光标该落在哪一列。
## 扫的是世界本身而不是记一个计数器：导入是整体替换，任何自己维护的下一个 id
## 在导入后都是错的。
static func adopt_state(world: AuthoringWorld) -> Dictionary:
	var state: Dictionary = {"next_entity_id": 1, "next_order": 0, "next_x": 0}
	if world == null:
		return state
	var cell: int = 1
	if world.grid != null and world.grid.cell > 0:
		cell = world.grid.cell
	var max_id: int = 0
	var max_order: int = -1
	var max_cell_x: int = -1
	for entity_id: int in world.entity_ids():
		if entity_id > max_id:
			max_id = entity_id
		var stored: SharedComponentRecord = world.get_record(entity_id)
		if stored == null:
			continue
		max_order = maxi(max_order, _checkpoint_order(stored))
		max_cell_x = maxi(max_cell_x, _transform_cell_x(stored, cell))
	if max_id > 0:
		state["next_entity_id"] = max_id + 1
	if max_order >= 0:
		state["next_order"] = max_order + 1
	if max_cell_x >= 0:
		state["next_x"] = max_cell_x + 1
	return state


## 悬空传送门已经占住的目标 id。续号时要跳过它们，否则新实体会把一条本来
## 悬空的连线悄悄接上。
static func dangling_target_ids(world: AuthoringWorld) -> Dictionary:
	var reserved: Dictionary = {}
	if world == null:
		return reserved
	for link_value: Variant in world.portal_links():
		if typeof(link_value) != TYPE_DICTIONARY:
			continue
		var link: Dictionary = link_value
		if str(link.get("kind", "")) != AuthoringPortalKinds.DANGLING:
			continue
		var dest_raw: Variant = link.get("dest_id", null)
		if typeof(dest_raw) != TYPE_INT:
			continue
		var dest_id: int = dest_raw
		if dest_id > 0:
			reserved[dest_id] = true
	return reserved


## 成对放置的第二扇门该用哪个 id：第一扇门写下的 `target_id`。
## 拿不到（不存在、不是 portal、目标已被占）返回 0，调用方回退到续号。
static func pending_pair_entity_id(world: AuthoringWorld, pending_portal_id: int) -> int:
	if pending_portal_id <= 0 or world == null:
		return 0
	var record: SharedComponentRecord = world.get_record(pending_portal_id)
	if record == null or not record.components.has(SharedComponentNames.PORTAL):
		return 0
	var raw: Variant = record.components[SharedComponentNames.PORTAL]
	if typeof(raw) != TYPE_DICTIONARY:
		return 0
	var portal: Dictionary = raw
	var target_raw: Variant = portal.get("target_id", null)
	if typeof(target_raw) != TYPE_INT:
		return 0
	var target_id: int = target_raw
	if target_id <= 0 or world.has_entity(target_id):
		return 0
	return target_id


static func place_next_portal(panel: TraprushEditorPanel, gated: bool) -> bool:
	if panel.host == null or panel.cursor == null:
		return false
	var entity_id: int = 0
	var target_id: int = 0
	if panel._pending_portal_id > 0:
		entity_id = panel._pending_pair_entity_id()
		if entity_id <= 0:
			entity_id = panel._peek_entity_id()
		target_id = panel._pending_portal_id
	else:
		entity_id = panel._peek_entity_id()
		target_id = entity_id + 1
		while panel._world_has(target_id):
			target_id += 1
	var placed: bool = false
	if gated:
		placed = panel.host.try_place_gated_portal(
			entity_id, target_id, panel.cursor.cell_x, panel.cursor.cell_y, panel.cursor.cell_z
		)
	else:
		placed = panel.host.try_place_portal(
			entity_id, target_id, panel.cursor.cell_x, panel.cursor.cell_y, panel.cursor.cell_z
		)
	if not placed:
		return false
	panel._commit_entity_id(entity_id)
	if panel._pending_portal_id > 0:
		panel._pending_portal_id = 0
	else:
		panel._pending_portal_id = entity_id
	panel.cursor.bump_x()
	panel._select_placed(entity_id)
	return true


static func _checkpoint_order(record: SharedComponentRecord) -> int:
	if not record.components.has(SharedComponentNames.CHECKPOINT):
		return -1
	var raw: Variant = record.components[SharedComponentNames.CHECKPOINT]
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	var bag: Dictionary = raw
	if typeof(bag.get("order", null)) != TYPE_INT:
		return -1
	var order: int = bag["order"]
	return order


static func _transform_cell_x(record: SharedComponentRecord, cell: int) -> int:
	if not record.components.has(SharedComponentNames.TRANSFORM):
		return -1
	var raw: Variant = record.components[SharedComponentNames.TRANSFORM]
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	var bag: Dictionary = raw
	if typeof(bag.get("x", null)) != TYPE_INT:
		return -1
	var x_value: int = bag["x"]
	return x_value / cell
