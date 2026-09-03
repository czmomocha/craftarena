class_name AuthoringPreviewMapFloor
extends RefCounted

## Editor-only presentation grid. Not occupancy, not authority.
## Colours live in PlaceholderSpec (CI gate); cell size still comes from 1 m = 1 cell (D4).

const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")
const FLOOR_NAME: String = "EditGuide_Floor"
const GRID_NAME: String = "EditGuide_Grid"
const CURSOR_NAME: String = "EditGuide_Cursor"
const SELECT_NAME: String = "EditGuide_Select"
const HALF_CELLS: int = 64


static func is_guide_name(node_name: String) -> bool:
	return node_name.begins_with("EditGuide_")


func sync(
	map: AuthoringPreviewMap,
	floor_y: int,
	cursor_x: int,
	cursor_z: int,
	selected_id: int
) -> void:
	if map == null:
		return
	var plane_y: float = float(floor_y) - 0.5
	_sync_fill(map, plane_y)
	_sync_grid(map, plane_y)
	_sync_cursor(map, cursor_x, floor_y, cursor_z)
	_sync_select(map, selected_id)


func hide(map: AuthoringPreviewMap) -> void:
	if map == null:
		return
	_free_named(map, FLOOR_NAME)
	_free_named(map, GRID_NAME)
	_free_named(map, CURSOR_NAME)
	_free_named(map, SELECT_NAME)


func _sync_fill(map: AuthoringPreviewMap, plane_y: float) -> void:
	var node: MeshInstance3D = map.get_node_or_null(FLOOR_NAME) as MeshInstance3D
	if node == null:
		node = MeshInstance3D.new()
		node.name = FLOOR_NAME
		var box: BoxMesh = BoxMesh.new()
		var extent: float = float(HALF_CELLS * 2)
		box.size = Vector3(extent, 0.02, extent)
		box.material = ConvertGd.unshaded(PlaceholderSpec.EDIT_GUIDE_FLOOR_FILL_ALBEDO)
		node.mesh = box
		map.add_child(node)
	node.position = Vector3(0.0, plane_y, 0.0)
	node.visible = true


func _sync_grid(map: AuthoringPreviewMap, plane_y: float) -> void:
	var node: MeshInstance3D = map.get_node_or_null(GRID_NAME) as MeshInstance3D
	if node == null:
		node = MeshInstance3D.new()
		node.name = GRID_NAME
		map.add_child(node)
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var limit: int = HALF_CELLS
	var y: float = plane_y + 0.02
	var i: int = -limit
	while i <= limit:
		var f: float = float(i)
		mesh.surface_add_vertex(Vector3(float(-limit), y, f))
		mesh.surface_add_vertex(Vector3(float(limit), y, f))
		mesh.surface_add_vertex(Vector3(f, y, float(-limit)))
		mesh.surface_add_vertex(Vector3(f, y, float(limit)))
		i += 1
	mesh.surface_end()
	node.mesh = mesh
	node.material_override = ConvertGd.unshaded(PlaceholderSpec.EDIT_GUIDE_GRID_LINE_ALBEDO)
	node.visible = true


func _sync_cursor(map: AuthoringPreviewMap, cell_x: int, cell_y: int, cell_z: int) -> void:
	var node: MeshInstance3D = map.get_node_or_null(CURSOR_NAME) as MeshInstance3D
	if node == null:
		node = MeshInstance3D.new()
		node.name = CURSOR_NAME
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(1.02, 0.06, 1.02)
		box.material = ConvertGd.unshaded(PlaceholderSpec.EDIT_GUIDE_CURSOR_ALBEDO)
		node.mesh = box
		map.add_child(node)
	node.position = Vector3(float(cell_x), float(cell_y) - 0.47, float(cell_z))
	node.visible = true


func _sync_select(map: AuthoringPreviewMap, selected_id: int) -> void:
	var node: MeshInstance3D = map.get_node_or_null(SELECT_NAME) as MeshInstance3D
	if selected_id <= 0:
		if node != null:
			node.visible = false
		return
	var target: MeshInstance3D = map.placeholder_node(selected_id)
	if target == null:
		if node != null:
			node.visible = false
		return
	if node == null:
		node = MeshInstance3D.new()
		node.name = SELECT_NAME
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(1.12, 1.12, 1.12)
		box.material = ConvertGd.unshaded(PlaceholderSpec.EDIT_GUIDE_SELECT_ALBEDO)
		node.mesh = box
		map.add_child(node)
	node.position = target.position
	node.visible = true


func _free_named(map: AuthoringPreviewMap, node_name: String) -> void:
	var node: Node = map.get_node_or_null(node_name)
	if node == null:
		return
	map.remove_child(node)
	node.free()
