class_name TraprushEditorPanel
extends VBoxContainer

## TRAPRUSH tool strip on AuthoringEditorShell (CD-32 §1).
## Emits existing EDIT ops only. Bastion panel is not this chapter.
## Floor only changes the next place cell_y. Occupancy place uses the same
## lattice as checkpoints. Place finish writes zone.tags finish; a second
## finish still writes and is not a write gate. Hazard cooldown and crate
## durability are stubs, not product seconds or blast tables. Never settlement.

const PLACE_CHECKPOINT_NAME: String = "PlaceCheckpoint"
const PLACE_PORTAL_NAME: String = "PlacePortal"
const PLACE_SOLID_NAME: String = "PlaceSolid"
const PLACE_HAZARD_NAME: String = "PlaceHazard"
const PLACE_CRATE_NAME: String = "PlaceCrate"
const PLACE_FINISH_NAME: String = "PlaceFinish"
const REMOVE_LAST_NAME: String = "RemoveLast"
const FLOOR_UP_NAME: String = "FloorUp"
const FLOOR_DOWN_NAME: String = "FloorDown"
const HAZARD_COOLDOWN_STUB: int = 1
const CRATE_DURABILITY_STUB: int = 1
const CRATE_REGEN_POLICY_STUB: int = 0

var host: AuthoringEditorShell = null
var floor_index: int = 0
var _next_entity_id: int = 1
var _next_order: int = 0
var _next_cell_x: int = 0
var _pending_portal_id: int = 0


func adopt_world(world: AuthoringWorld) -> void:
	_pending_portal_id = 0
	_next_entity_id = 1
	_next_order = 0
	_next_cell_x = 0
	if world == null:
		return
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
		if stored.components.has(SharedComponentNames.CHECKPOINT):
			var bag: Variant = stored.components[SharedComponentNames.CHECKPOINT]
			if typeof(bag) == TYPE_DICTIONARY:
				var order_bag: Dictionary = bag
				if order_bag.has("order") and typeof(order_bag["order"]) == TYPE_INT:
					var order_val: int = order_bag["order"]
					if order_val > max_order:
						max_order = order_val
		if stored.components.has(SharedComponentNames.TRANSFORM):
			var pose: Variant = stored.components[SharedComponentNames.TRANSFORM]
			if typeof(pose) == TYPE_DICTIONARY:
				var pose_bag: Dictionary = pose
				if pose_bag.has("x") and typeof(pose_bag["x"]) == TYPE_INT:
					var x_val: int = pose_bag["x"]
					var cell_x: int = x_val / cell
					if cell_x > max_cell_x:
						max_cell_x = cell_x
	if max_id > 0:
		_next_entity_id = max_id + 1
	if max_order >= 0:
		_next_order = max_order + 1
	if max_cell_x >= 0:
		_next_cell_x = max_cell_x + 1


func mount(p_host: AuthoringEditorShell) -> void:
	host = p_host
	if get_child_count() > 0:
		return
	var place_row: HBoxContainer = HBoxContainer.new()
	place_row.name = "PlaceRow"
	add_child(place_row)
	_add_button(place_row, PLACE_CHECKPOINT_NAME, "Place checkpoint", place_next_checkpoint)
	_add_button(place_row, PLACE_PORTAL_NAME, "Place portal", place_next_portal)
	_add_button(place_row, REMOVE_LAST_NAME, "Remove last", remove_last)
	var occupancy_row: HBoxContainer = HBoxContainer.new()
	occupancy_row.name = "OccupancyRow"
	add_child(occupancy_row)
	_add_button(occupancy_row, PLACE_SOLID_NAME, "Place solid", place_next_solid)
	_add_button(occupancy_row, PLACE_HAZARD_NAME, "Place hazard", place_next_hazard)
	_add_button(occupancy_row, PLACE_CRATE_NAME, "Place crate", place_next_crate)
	_add_button(occupancy_row, PLACE_FINISH_NAME, "Place finish", place_next_finish)
	var floor_row: HBoxContainer = HBoxContainer.new()
	floor_row.name = "FloorRow"
	add_child(floor_row)
	_add_button(floor_row, FLOOR_UP_NAME, "Floor up", floor_up)
	_add_button(floor_row, FLOOR_DOWN_NAME, "Floor down", floor_down)


func place_next_checkpoint() -> bool:
	if host == null:
		return false
	var entity_id: int = _next_entity_id
	var order: int = _next_order
	var cell_x: int = _next_cell_x
	if not host.try_place_checkpoint(entity_id, order, cell_x, floor_index, 0):
		return false
	_next_entity_id += 1
	_next_order += 1
	_next_cell_x += 1
	return true


func place_next_portal() -> bool:
	if host == null:
		return false
	var entity_id: int = _next_entity_id
	var target_id: int = entity_id + 1
	if _pending_portal_id > 0:
		target_id = _pending_portal_id
	if not host.try_place_portal(entity_id, target_id, _next_cell_x, floor_index, 0):
		return false
	if _pending_portal_id > 0:
		_pending_portal_id = 0
	else:
		_pending_portal_id = entity_id
	_next_entity_id += 1
	_next_cell_x += 1
	return true


func place_next_solid() -> bool:
	if host == null:
		return false
	var entity_id: int = _next_entity_id
	var cell_x: int = _next_cell_x
	if not host.try_place_solid(entity_id, cell_x, floor_index, 0):
		return false
	_next_entity_id += 1
	_next_cell_x += 1
	return true


func place_next_hazard() -> bool:
	if host == null:
		return false
	var entity_id: int = _next_entity_id
	var cell_x: int = _next_cell_x
	if not host.try_place_hazard(entity_id, cell_x, floor_index, 0):
		return false
	_next_entity_id += 1
	_next_cell_x += 1
	return true


func place_next_crate() -> bool:
	if host == null:
		return false
	var entity_id: int = _next_entity_id
	var cell_x: int = _next_cell_x
	if not host.try_place_crate(entity_id, cell_x, floor_index, 0):
		return false
	_next_entity_id += 1
	_next_cell_x += 1
	return true


func place_next_finish() -> bool:
	if host == null:
		return false
	var entity_id: int = _next_entity_id
	var cell_x: int = _next_cell_x
	if not host.try_place_finish(entity_id, cell_x, floor_index, 0):
		return false
	_next_entity_id += 1
	_next_cell_x += 1
	return true


func remove_last() -> bool:
	if host == null or host.session == null or host.session.world == null:
		return false
	var ids: Array[int] = host.session.world.entity_ids()
	if ids.is_empty():
		return false
	var entity_id: int = ids[ids.size() - 1]
	if not host.try_remove(entity_id):
		return false
	if _pending_portal_id == entity_id:
		_pending_portal_id = 0
	return true


func floor_up() -> void:
	floor_index += 1
	_refresh_host_status()


func floor_down() -> void:
	floor_index -= 1
	_refresh_host_status()


func _refresh_host_status() -> void:
	if host != null:
		host.refresh_status()


func _add_button(row: HBoxContainer, node_name: String, text: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	row.add_child(button)
