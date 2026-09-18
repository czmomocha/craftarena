class_name AuthoringEditorTransformGizmo
extends RefCounted

## Unity-style translate gizmo on the selected Authoring entity.
## Presentation only. Writes go through existing try_move_entity.

const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")
const ROOT_NAME: String = "EditGuide_Gizmo"
const AXIS_X: String = "x"
const AXIS_Y: String = "y"
const AXIS_Z: String = "z"
const AXIS_LEN: float = 1.55
const AXIS_HALF: float = 0.07
const PICK_PAD: float = 0.12


static func sync(map: AuthoringPreviewMap, selected_id: int) -> void:
	if map == null:
		return
	var root: Node3D = map.get_node_or_null(ROOT_NAME) as Node3D
	if selected_id <= 0:
		if root != null:
			root.visible = false
		return
	var target: MeshInstance3D = map.placeholder_node(selected_id)
	if target == null:
		if root != null:
			root.visible = false
		return
	if root == null:
		root = _make_root()
		map.add_child(root)
	root.position = target.position
	root.visible = true


static func try_pick_axis(
	map: AuthoringPreviewMap, origin: Vector3, direction: Vector3
) -> String:
	if map == null:
		return ""
	var root: Node3D = map.get_node_or_null(ROOT_NAME) as Node3D
	if root == null or not root.visible:
		return ""
	var best_t: float = 256.0
	var best_axis: String = ""
	for axis: String in [AXIS_X, AXIS_Y, AXIS_Z]:
		var aabb: AABB = _axis_aabb(root.position, axis)
		var t: float = ConvertGd.ray_aabb_t(origin, direction, aabb)
		if t < 0.0 or t >= best_t:
			continue
		best_t = t
		best_axis = axis
	return best_axis


static func cell_along_axis(
	origin: Vector3,
	direction: Vector3,
	axis: String,
	cell_x: int,
	cell_y: int,
	cell_z: int
) -> Vector3i:
	var pivot: Vector3 = Vector3(float(cell_x), float(cell_y), float(cell_z))
	var axis_dir: Vector3 = _axis_dir(axis)
	var hit: Vector3 = _closest_on_axis(origin, direction, pivot, axis_dir)
	var next_x: int = cell_x
	var next_y: int = cell_y
	var next_z: int = cell_z
	if axis == AXIS_X:
		next_x = roundi(hit.x)
	elif axis == AXIS_Y:
		next_y = roundi(hit.y)
	else:
		next_z = roundi(hit.z)
	return Vector3i(next_x, next_y, next_z)


static func _make_root() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = ROOT_NAME
	root.add_child(_axis_mesh(AXIS_X, PlaceholderSpec.EDIT_GIZMO_X_ALBEDO))
	root.add_child(_axis_mesh(AXIS_Y, PlaceholderSpec.EDIT_GIZMO_Y_ALBEDO))
	root.add_child(_axis_mesh(AXIS_Z, PlaceholderSpec.EDIT_GIZMO_Z_ALBEDO))
	return root


static func _axis_mesh(axis: String, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "Axis_%s" % axis
	var box: BoxMesh = BoxMesh.new()
	if axis == AXIS_X:
		box.size = Vector3(AXIS_LEN, AXIS_HALF * 2.0, AXIS_HALF * 2.0)
		node.position = Vector3(AXIS_LEN * 0.5, 0.0, 0.0)
	elif axis == AXIS_Y:
		box.size = Vector3(AXIS_HALF * 2.0, AXIS_LEN, AXIS_HALF * 2.0)
		node.position = Vector3(0.0, AXIS_LEN * 0.5, 0.0)
	else:
		box.size = Vector3(AXIS_HALF * 2.0, AXIS_HALF * 2.0, AXIS_LEN)
		node.position = Vector3(0.0, 0.0, AXIS_LEN * 0.5)
	box.material = ConvertGd.unshaded(color)
	node.mesh = box
	return node


static func _axis_aabb(origin: Vector3, axis: String) -> AABB:
	var pad: float = AXIS_HALF + PICK_PAD
	if axis == AXIS_X:
		return AABB(origin + Vector3(0.0, -pad, -pad), Vector3(AXIS_LEN, pad * 2.0, pad * 2.0))
	if axis == AXIS_Y:
		return AABB(origin + Vector3(-pad, 0.0, -pad), Vector3(pad * 2.0, AXIS_LEN, pad * 2.0))
	return AABB(origin + Vector3(-pad, -pad, 0.0), Vector3(pad * 2.0, pad * 2.0, AXIS_LEN))


static func _axis_dir(axis: String) -> Vector3:
	if axis == AXIS_X:
		return Vector3.RIGHT
	if axis == AXIS_Y:
		return Vector3.UP
	return Vector3.FORWARD


static func _closest_on_axis(
	origin: Vector3, direction: Vector3, pivot: Vector3, axis_dir: Vector3
) -> Vector3:
	var d: Vector3 = direction.normalized()
	var w0: Vector3 = origin - pivot
	var a: float = d.dot(d)
	var b: float = d.dot(axis_dir)
	var c: float = axis_dir.dot(axis_dir)
	var d_w: float = d.dot(w0)
	var e: float = axis_dir.dot(w0)
	var denom: float = a * c - b * b
	var s: float = 0.0
	if absf(denom) > 0.0001:
		s = (a * e - b * d_w) / denom
	return pivot + axis_dir * s
