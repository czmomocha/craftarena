class_name AuthoringReachability
extends RefCounted

## Publish-time TRAPRUSH path / portal-cycle check on an AuthoringWorld.
## Does not run on EditCommand try_apply. Dangling is legal while authoring.
## two_way pairs are landings, not follow-chain cycles. Walkable holes are later.

const Codes := preload("res://src/creator/authoring_reachability_codes.gd")


static func evaluate(world: AuthoringWorld) -> Dictionary:
	var issues: Array[Dictionary] = []
	_collect_portal_issues(world, issues)
	_collect_path_issues(world, issues)
	issues.sort_custom(_issue_sort)
	return _result(issues)


static func _result(issues: Array[Dictionary]) -> Dictionary:
	return {
		"ok": issues.is_empty(),
		"issues": issues,
	}


static func _collect_portal_issues(world: AuthoringWorld, issues: Array[Dictionary]) -> void:
	var one_way: Dictionary[int, int] = {}
	var links: Array[Dictionary] = world.portal_links()
	for link: Dictionary in links:
		var kind: String = link.get("kind", "")
		var source_id: int = link.get("source_id", 0)
		if kind == AuthoringPortalKinds.DANGLING:
			issues.append(_issue(Codes.DANGLING_PORTAL, [source_id]))
			continue
		if kind == AuthoringPortalKinds.ONE_WAY:
			var dest_id: int = link.get("dest_id", 0)
			one_way[source_id] = dest_id
	_collect_one_way_cycles(one_way, issues)


static func _collect_one_way_cycles(one_way: Dictionary[int, int], issues: Array[Dictionary]) -> void:
	var permanent: Dictionary[int, bool] = {}
	var starts: Array[int] = []
	for source_id: int in one_way:
		starts.append(source_id)
	starts.sort()
	for start_id: int in starts:
		if permanent.has(start_id):
			continue
		var stack: Array[int] = []
		var in_stack: Dictionary[int, int] = {}
		var current_id: int = start_id
		while true:
			if in_stack.has(current_id):
				var cut: int = in_stack[current_id]
				var cycle_ids: Array[int] = []
				var index: int = cut
				while index < stack.size():
					cycle_ids.append(stack[index])
					index += 1
				cycle_ids.sort()
				issues.append(_issue(Codes.PORTAL_CYCLE, cycle_ids))
				break
			if permanent.has(current_id):
				break
			if not one_way.has(current_id):
				break
			in_stack[current_id] = stack.size()
			stack.append(current_id)
			current_id = one_way[current_id]
		for seen_id: int in stack:
			permanent[seen_id] = true


static func _collect_path_issues(world: AuthoringWorld, issues: Array[Dictionary]) -> void:
	var by_order: Dictionary[int, Array] = {}
	var floor_of: Dictionary[int, Dictionary] = {}
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null:
			continue
		if not record.components.has(SharedComponentNames.CHECKPOINT):
			continue
		var raw: Variant = record.components[SharedComponentNames.CHECKPOINT]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = raw
		if typeof(body.get("order", null)) != TYPE_INT:
			continue
		var order: int = body["order"]
		if not by_order.has(order):
			var grouped: Array[int] = []
			by_order[order] = grouped
		var group: Array = by_order[order]
		group.append(entity_id)
		floor_of[entity_id] = _floor_of(world, record)
	if by_order.is_empty():
		issues.append(_issue(Codes.MISSING_MANDATORY_PATH, []))
		return
	var unique_orders: Array[int] = []
	var order_keys: Array = by_order.keys()
	order_keys.sort()
	for order_value: Variant in order_keys:
		var order: int = order_value
		var group: Array = by_order[order]
		var grouped_ids: Array[int] = []
		for grouped_id_value: Variant in group:
			var grouped_id: int = grouped_id_value
			grouped_ids.append(grouped_id)
		grouped_ids.sort()
		if grouped_ids.size() != 1:
			issues.append(_issue(Codes.DUPLICATE_CHECKPOINT_ORDER, grouped_ids))
			continue
		unique_orders.append(order)
	if unique_orders.size() < 2:
		return
	var floor_next: Dictionary[int, Array] = _floor_graph(world)
	var index: int = 0
	while index + 1 < unique_orders.size():
		var from_order: int = unique_orders[index]
		var to_order: int = unique_orders[index + 1]
		var from_ids: Array = by_order[from_order]
		var to_ids: Array = by_order[to_order]
		var from_id: int = from_ids[0]
		var to_id: int = to_ids[0]
		if not _checkpoint_step_ok(from_id, to_id, floor_of, floor_next):
			issues.append(_issue(Codes.UNREACHABLE_CHECKPOINT, [from_id, to_id]))
		index += 1


static func _checkpoint_step_ok(
	from_id: int,
	to_id: int,
	floor_of: Dictionary[int, Dictionary],
	floor_next: Dictionary[int, Array]
) -> bool:
	if not floor_of.has(from_id) or not floor_of.has(to_id):
		return false
	var from_floor: Dictionary = floor_of[from_id]
	var to_floor: Dictionary = floor_of[to_id]
	var from_ok: bool = from_floor.get("ok", false)
	var to_ok: bool = to_floor.get("ok", false)
	if not from_ok or not to_ok:
		return false
	var start_floor: int = from_floor["floor"]
	var dest_floor: int = to_floor["floor"]
	return _floor_reachable(start_floor, dest_floor, floor_next)


static func _floor_graph(world: AuthoringWorld) -> Dictionary[int, Array]:
	var floor_next: Dictionary[int, Array] = {}
	var links: Array[Dictionary] = world.portal_links()
	for link: Dictionary in links:
		var kind: String = link.get("kind", "")
		if kind == AuthoringPortalKinds.DANGLING:
			continue
		var source_id: int = link.get("source_id", 0)
		var dest_id: int = link.get("dest_id", 0)
		var source_record: SharedComponentRecord = world.get_record(source_id)
		var dest_record: SharedComponentRecord = world.get_record(dest_id)
		if source_record == null or dest_record == null:
			continue
		var source_floor: Dictionary = _floor_of(world, source_record)
		var dest_floor: Dictionary = _floor_of(world, dest_record)
		var source_ok: bool = source_floor.get("ok", false)
		var dest_ok: bool = dest_floor.get("ok", false)
		if not source_ok or not dest_ok:
			continue
		var from_floor: int = source_floor["floor"]
		var to_floor: int = dest_floor["floor"]
		if not floor_next.has(from_floor):
			var outgoing: Array[int] = []
			floor_next[from_floor] = outgoing
		var nexts: Array = floor_next[from_floor]
		var to_floor_value: int = to_floor
		if not nexts.has(to_floor_value):
			nexts.append(to_floor_value)
	return floor_next


static func _floor_reachable(from_floor: int, to_floor: int, floor_next: Dictionary[int, Array]) -> bool:
	if from_floor == to_floor:
		return true
	var seen: Dictionary[int, bool] = {}
	var queue: Array[int] = [from_floor]
	seen[from_floor] = true
	var index: int = 0
	while index < queue.size():
		var current: int = queue[index]
		index += 1
		if not floor_next.has(current):
			continue
		var nexts: Array = floor_next[current]
		for next_value: Variant in nexts:
			var next_floor: int = next_value
			if seen.has(next_floor):
				continue
			if next_floor == to_floor:
				return true
			seen[next_floor] = true
			queue.append(next_floor)
	return false


static func _floor_of(world: AuthoringWorld, record: SharedComponentRecord) -> Dictionary:
	if record == null:
		return {"ok": false}
	if not record.components.has(SharedComponentNames.TRANSFORM):
		return {"ok": false}
	var raw: Variant = record.components[SharedComponentNames.TRANSFORM]
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false}
	var body: Dictionary = raw
	if typeof(body.get("y", null)) != TYPE_INT:
		return {"ok": false}
	var y: int = body["y"]
	return {"ok": true, "floor": world.grid.floor_index(y)}


static func _issue(code: String, entity_ids: Array[int]) -> Dictionary:
	var ids: Array[int] = entity_ids.duplicate()
	ids.sort()
	return {
		"code": code,
		"entity_ids": ids,
	}


static func _issue_sort(left: Dictionary, right: Dictionary) -> bool:
	var left_code: String = left.get("code", "")
	var right_code: String = right.get("code", "")
	if left_code != right_code:
		return left_code < right_code
	var left_ids: Array = left.get("entity_ids", [])
	var right_ids: Array = right.get("entity_ids", [])
	var index: int = 0
	while index < left_ids.size() and index < right_ids.size():
		var left_id: int = left_ids[index]
		var right_id: int = right_ids[index]
		if left_id != right_id:
			return left_id < right_id
		index += 1
	return left_ids.size() < right_ids.size()
