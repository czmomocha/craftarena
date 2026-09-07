class_name TraprushEditorPanelBatch
extends HBoxContainer

## Box fill / copy / paste / delete-by-id. Existing EDIT ops only (F-line FG).

const MARK_NAME: String = "MarkCorner"
const FILL_NAME: String = "FillSolids"
const COPY_NAME: String = "CopyEntity"
const PASTE_NAME: String = "PasteEntity"
const DELETE_NAME: String = "DeleteSelected"
const SELECT_NAME: String = "SelectBox"

var host: AuthoringEditorShell = null
var panel: TraprushEditorPanel = null
var mark_x: int = 0
var mark_y: int = 0
var mark_z: int = 0
var has_mark: bool = false
var clipboard: Dictionary = {}


func mount(p_host: AuthoringEditorShell, p_panel: TraprushEditorPanel) -> void:
	host = p_host
	panel = p_panel
	if get_child_count() > 0:
		return
	name = "BatchRow"
	_add_button(MARK_NAME, UiCopy.MARK_CORNER, mark_corner)
	_add_button(FILL_NAME, UiCopy.FILL_SOLIDS, fill_solids)
	_add_button(COPY_NAME, UiCopy.COPY_ENTITY, copy_entity)
	_add_button(PASTE_NAME, UiCopy.PASTE_ENTITY, paste_entity)
	_add_button(DELETE_NAME, UiCopy.DELETE_SELECTED, delete_selected)
	_add_button(SELECT_NAME, UiCopy.SELECT_BOX, select_box_pressed)


func mark_corner() -> void:
	if panel == null or panel.cursor == null:
		return
	mark_x = panel.cursor.cell_x
	mark_y = panel.cursor.cell_y
	mark_z = panel.cursor.cell_z
	has_mark = true


func fill_solids() -> bool:
	if not has_mark or panel == null or panel.cursor == null or host == null:
		return false
	var x0: int = mini(mark_x, panel.cursor.cell_x)
	var x1: int = maxi(mark_x, panel.cursor.cell_x)
	var y0: int = mini(mark_y, panel.cursor.cell_y)
	var y1: int = maxi(mark_y, panel.cursor.cell_y)
	var z0: int = mini(mark_z, panel.cursor.cell_z)
	var z1: int = maxi(mark_z, panel.cursor.cell_z)
	if (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1) > 64:
		return false
	var placed: bool = false
	var y: int = y0
	while y <= y1:
		var z: int = z0
		while z <= z1:
			var x: int = x0
			while x <= x1:
				var entity_id: int = panel._peek_entity_id()
				if host.try_place_solid(entity_id, x, y, z):
					panel._commit_entity_id(entity_id)
					placed = true
				x += 1
			z += 1
		y += 1
	return placed


func copy_entity() -> bool:
	if host == null or host.chrome == null or host.session == null:
		return false
	var entity_id: int = host.chrome.selected_id
	if entity_id < 1 or host.session.world == null:
		return false
	var record: SharedComponentRecord = host.session.world.get_record(entity_id)
	if record == null:
		return false
	clipboard = record.to_dictionary()
	return not clipboard.is_empty()


func paste_entity() -> bool:
	if clipboard.is_empty() or panel == null or panel.cursor == null or host == null:
		return false
	if host.session == null or host.session.world == null or host.session.world.grid == null:
		return false
	var cell: int = host.session.world.grid.cell
	var next: Dictionary = clipboard.duplicate(true)
	var entity_id: int = panel._peek_entity_id()
	next["entity_id"] = entity_id
	var components_raw: Variant = next.get("components", {})
	if typeof(components_raw) != TYPE_DICTIONARY:
		return false
	var components: Dictionary = components_raw
	var transform_raw: Variant = components.get(SharedComponentNames.TRANSFORM, {})
	if typeof(transform_raw) != TYPE_DICTIONARY:
		return false
	var transform_bag: Dictionary = transform_raw
	var transform: Dictionary = transform_bag.duplicate(true)
	transform["x"] = panel.cursor.cell_x * cell
	transform["y"] = panel.cursor.cell_y * cell
	transform["z"] = panel.cursor.cell_z * cell
	components[SharedComponentNames.TRANSFORM] = transform
	next["components"] = components
	if not host.try_edit({"op": "place", "record": next}):
		return false
	panel._commit_entity_id(entity_id)
	panel._select_placed(entity_id)
	return true


func delete_selected() -> bool:
	if host == null or host.chrome == null:
		return false
	var entity_id: int = host.chrome.selected_id
	if entity_id < 1:
		return false
	if not host.try_remove(entity_id):
		return false
	host.chrome.selected_id = 0
	return true


func select_box_pressed() -> void:
	select_box()


func select_box() -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	if not has_mark or panel == null or panel.cursor == null:
		return ids
	if host == null or host.session == null or host.session.world == null:
		return ids
	var cell: int = 1
	if host.session.world.grid != null and host.session.world.grid.cell > 0:
		cell = host.session.world.grid.cell
	var x0: int = mini(mark_x, panel.cursor.cell_x) * cell
	var x1: int = maxi(mark_x, panel.cursor.cell_x) * cell
	var y0: int = mini(mark_y, panel.cursor.cell_y) * cell
	var y1: int = maxi(mark_y, panel.cursor.cell_y) * cell
	var z0: int = mini(mark_z, panel.cursor.cell_z) * cell
	var z1: int = maxi(mark_z, panel.cursor.cell_z) * cell
	for entity_id: int in host.session.world.entity_ids():
		var record: SharedComponentRecord = host.session.world.get_record(entity_id)
		if record == null or not record.components.has(SharedComponentNames.TRANSFORM):
			continue
		var raw: Variant = record.components[SharedComponentNames.TRANSFORM]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var pose: Dictionary = raw
		var x: int = PlayClock.dict_int(pose, "x", 0)
		var y: int = PlayClock.dict_int(pose, "y", 0)
		var z: int = PlayClock.dict_int(pose, "z", 0)
		if x < x0 or x > x1 or y < y0 or y > y1 or z < z0 or z > z1:
			continue
		ids.append(entity_id)
	if ids.size() > 0 and host.chrome != null:
		host.chrome.selected_id = ids[0]
		host.chrome.sync_guides()
	return ids


func _add_button(node_name: String, copy_key: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = UiCopy.text(copy_key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	add_child(button)
