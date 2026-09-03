class_name AuthoringEditorShellPointer
extends RefCounted

## Editor 3D pointer: pick empty floor for the next place cell, pick a
## placeholder to select, drag XZ (Shift+drag = Y). Writes set_component.
## Touch / mobile drag is D7, not this chapter.

const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")
const HALF: Vector3 = Vector3(0.5, 0.5, 0.5)


static func handle(chrome: AuthoringEditorShellChrome, event: InputEvent) -> void:
	if chrome == null or chrome.window == null or not is_instance_valid(chrome.window):
		return
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null:
		_handle_button(chrome, mouse_button)
		return
	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion != null:
		_handle_motion(chrome, mouse_motion)


static func _handle_button(chrome: AuthoringEditorShellChrome, mouse: InputEventMouseButton) -> void:
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mouse.pressed:
		if chrome.dragging:
			_commit_drag(chrome)
		chrome.dragging = false
		return
	if chrome.window.gui_get_hovered_control() != null:
		return
	if chrome.tools == null or chrome.map == null:
		return
	var camera: Camera3D = chrome.map.get_node_or_null(AuthoringPreviewMap.CAMERA_NAME) as Camera3D
	if camera == null:
		return
	var origin: Vector3 = camera.project_ray_origin(mouse.position)
	var direction: Vector3 = camera.project_ray_normal(mouse.position)
	var picked: Dictionary = ConvertGd.try_entity_from_ray(chrome.map, origin, direction, HALF)
	var ok_raw: Variant = picked.get("ok", false)
	if typeof(ok_raw) == TYPE_BOOL and ok_raw:
		var id_raw: Variant = picked.get("id", 0)
		if typeof(id_raw) == TYPE_INT:
			var entity_id: int = id_raw
			chrome.selected_id = entity_id
			chrome.dragging = true
			chrome.drag_vertical = mouse.shift_pressed
			_cursor_from_entity(chrome, entity_id)
			chrome.sync_guides()
			return
	chrome.selected_id = 0
	chrome.dragging = false
	chrome.tools.try_pick_cell_from_screen(mouse.position)
	chrome.sync_guides()


static func _handle_motion(chrome: AuthoringEditorShellChrome, motion: InputEventMouseMotion) -> void:
	if not chrome.dragging or chrome.selected_id <= 0:
		return
	if chrome.tools == null or chrome.map == null:
		return
	var camera: Camera3D = chrome.map.get_node_or_null(AuthoringPreviewMap.CAMERA_NAME) as Camera3D
	if camera == null:
		return
	var origin: Vector3 = camera.project_ray_origin(motion.position)
	var direction: Vector3 = camera.project_ray_normal(motion.position)
	var host: AuthoringEditorShell = chrome.tools.host
	if host == null:
		return
	var record: SharedComponentRecord = null
	if host.session != null and host.session.world != null:
		record = host.session.world.get_record(chrome.selected_id)
	var pose: Dictionary = ConvertGd.pose_from_record(record)
	if pose.is_empty():
		return
	var cell: int = 1
	if host.session.world.grid != null and host.session.world.grid.cell > 0:
		cell = host.session.world.grid.cell
	var pose_x_raw: Variant = pose.get("x", 0)
	var pose_y_raw: Variant = pose.get("y", 0)
	var pose_z_raw: Variant = pose.get("z", 0)
	if typeof(pose_x_raw) != TYPE_INT or typeof(pose_y_raw) != TYPE_INT or typeof(pose_z_raw) != TYPE_INT:
		return
	var pose_x: int = pose_x_raw
	var pose_y: int = pose_y_raw
	var pose_z: int = pose_z_raw
	var cell_x: int = pose_x / cell
	var cell_y: int = pose_y / cell
	var cell_z: int = pose_z / cell
	if chrome.drag_vertical or motion.shift_pressed:
		cell_y = _cell_y_from_ray(origin, direction, camera, cell_x, cell_z)
	else:
		var floor_hit: Dictionary = ConvertGd.try_cell_xz_from_ray(
			origin, direction, float(cell_y)
		)
		var floor_ok: Variant = floor_hit.get("ok", false)
		if typeof(floor_ok) != TYPE_BOOL or not floor_ok:
			return
		var x_raw: Variant = floor_hit.get("x", cell_x)
		var z_raw: Variant = floor_hit.get("z", cell_z)
		if typeof(x_raw) != TYPE_INT or typeof(z_raw) != TYPE_INT:
			return
		cell_x = x_raw
		cell_z = z_raw
	chrome.tools.cursor.set_cell(cell_x, cell_y, cell_z)
	var placeholder: MeshInstance3D = chrome.map.placeholder_node(chrome.selected_id)
	if placeholder != null:
		placeholder.position = Vector3(float(cell_x), float(cell_y), float(cell_z))
	chrome.sync_guides()


static func _commit_drag(chrome: AuthoringEditorShellChrome) -> void:
	if chrome.tools == null or chrome.tools.host == null or chrome.selected_id <= 0:
		return
	chrome.tools.host.try_move_entity(
		chrome.selected_id,
		chrome.tools.cell_x,
		chrome.tools.floor_index,
		chrome.tools.cell_z
	)
	chrome.sync_guides()


static func _cursor_from_entity(chrome: AuthoringEditorShellChrome, entity_id: int) -> void:
	var host: AuthoringEditorShell = chrome.tools.host
	if host == null or host.session == null or host.session.world == null:
		return
	var record: SharedComponentRecord = host.session.world.get_record(entity_id)
	var pose: Dictionary = ConvertGd.pose_from_record(record)
	if pose.is_empty():
		return
	var cell: int = 1
	if host.session.world.grid != null and host.session.world.grid.cell > 0:
		cell = host.session.world.grid.cell
	var pose_x_raw: Variant = pose.get("x", 0)
	var pose_y_raw: Variant = pose.get("y", 0)
	var pose_z_raw: Variant = pose.get("z", 0)
	if typeof(pose_x_raw) != TYPE_INT or typeof(pose_y_raw) != TYPE_INT or typeof(pose_z_raw) != TYPE_INT:
		return
	var pose_x: int = pose_x_raw
	var pose_y: int = pose_y_raw
	var pose_z: int = pose_z_raw
	chrome.tools.cursor.set_cell(pose_x / cell, pose_y / cell, pose_z / cell)


static func _cell_y_from_ray(
	origin: Vector3, direction: Vector3, camera: Camera3D, cell_x: int, cell_z: int
) -> int:
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var denom: float = direction.dot(right)
	if absf(denom) < 0.0001:
		return roundi(origin.y)
	var plane_point: Vector3 = Vector3(float(cell_x), 0.0, float(cell_z))
	var t: float = (plane_point - origin).dot(right) / denom
	if t <= 0.0:
		return roundi(origin.y)
	var hit: Vector3 = origin + direction * t
	return roundi(hit.y)
