class_name MatchCrateBreak
extends RefCounted

## Presentation-only shatter when a compiled destructible leaves the live
## set (CD-21 §5.2). Fragments are not occupancy and never enter authority.
## Lifetime and size live on PlaceholderSpec.

const PREFIX: String = "break_"


static func node_name(entity_id: int) -> String:
	return "%s%d" % [PREFIX, entity_id]


static func spawn_from_crate(parent: Node3D, crate: Node3D) -> void:
	if parent == null or crate == null:
		return
	var entity_id: int = entity_id_of(crate)
	if entity_id < 1:
		return
	var existing: Node = parent.get_node_or_null(node_name(entity_id))
	if existing != null:
		existing.free()
	var root: Node3D = Node3D.new()
	root.name = node_name(entity_id)
	root.position = crate.position
	root.set_meta("age", 0.0)
	var albedo: Color = PlaceholderSpec.CRATE_ALBEDO
	var mesh_node: MeshInstance3D = crate as MeshInstance3D
	if mesh_node != null:
		var box: BoxMesh = mesh_node.mesh as BoxMesh
		if box != null:
			var material: StandardMaterial3D = box.material as StandardMaterial3D
			if material != null:
				albedo = material.albedo_color
	var offsets: Array[Vector3] = [
		Vector3(0.18, 0.14, 0.12),
		Vector3(-0.16, 0.1, -0.14),
		Vector3(0.12, -0.08, -0.16),
		Vector3(-0.14, -0.1, 0.18),
	]
	for offset: Vector3 in offsets:
		var piece: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = PlaceholderSpec.BREAK_FX_SIZE
		mesh.material = _unshaded(albedo)
		piece.mesh = mesh
		piece.position = offset
		root.add_child(piece)
	parent.add_child(root)


static func tick(parent: Node3D, delta: float) -> void:
	if parent == null or delta <= 0.0:
		return
	var life: float = PlaceholderSpec.BREAK_FX_SECONDS
	if life <= 0.0:
		return
	var stale: Array[Node] = []
	for child: Node in parent.get_children():
		if not str(child.name).begins_with(PREFIX):
			continue
		var age_raw: Variant = child.get_meta("age", 0.0)
		var age: float = 0.0
		if typeof(age_raw) == TYPE_FLOAT:
			var age_float: float = age_raw
			age = age_float
		elif typeof(age_raw) == TYPE_INT:
			var age_int: int = age_raw
			age = float(age_int)
		age += delta
		child.set_meta("age", age)
		var t: float = clampf(age / life, 0.0, 1.0)
		var node: Node3D = child as Node3D
		if node != null:
			var scale: float = 1.0 - t
			node.scale = Vector3(scale, scale, scale)
		if age >= life:
			stale.append(child)
	for node: Node in stale:
		parent.remove_child(node)
		node.free()


static func entity_id_of(crate: Node3D) -> int:
	var node_name: String = str(crate.name)
	if not node_name.begins_with("crate_"):
		return 0
	var raw: String = node_name.substr(6)
	if not raw.is_valid_int():
		return 0
	return int(raw)


static func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
