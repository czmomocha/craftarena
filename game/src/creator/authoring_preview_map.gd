class_name AuthoringPreviewMap
extends Node3D

## Presentation mapping for AuthoringPreview (CD-32 §3). Authority stays on
## AuthoringWorld Q48.16; float conversion happens only here. One 1×1×1 m
## BoxMesh per entity with transform; not a hitbox. Rebuild after every patch.

const CAMERA_NAME: String = "PreviewCamera"
const LIGHT_NAME: String = "PreviewLight"
const PLACEHOLDER_PREFIX: String = "entity_"
const PLACEHOLDER_SIZE: Vector3 = Vector3(1.0, 1.0, 1.0)
const _CAMERA_POS: Vector3 = Vector3(6.0, 8.0, 6.0)
const _LIGHT_ROT_DEG: Vector3 = Vector3(-50.0, -30.0, 0.0)
const _STUB_ALBEDO: Color = Color(0.85, 0.7, 0.25)


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func yaw_radians_from_bam(yaw_bam: int) -> float:
	return TAU * float(yaw_bam) / float(Fixed.BAM_TURN)


static func pose_from_record(record: SharedComponentRecord) -> Dictionary:
	if record == null:
		return {}
	if not record.components.has(SharedComponentNames.TRANSFORM):
		return {}
	var raw: Variant = record.components[SharedComponentNames.TRANSFORM]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	if typeof(body.get("x", null)) != TYPE_INT:
		return {}
	if typeof(body.get("y", null)) != TYPE_INT:
		return {}
	if typeof(body.get("z", null)) != TYPE_INT:
		return {}
	if typeof(body.get("yaw_bam", null)) != TYPE_INT:
		return {}
	var x: int = body["x"]
	var y: int = body["y"]
	var z: int = body["z"]
	var yaw_bam: int = body["yaw_bam"]
	return {"x": x, "y": y, "z": z, "yaw_bam": yaw_bam}


static func placeholder_name(entity_id: int) -> String:
	return "%s%d" % [PLACEHOLDER_PREFIX, entity_id]


func ensure_rig() -> void:
	var camera: Camera3D = get_node_or_null(CAMERA_NAME) as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = CAMERA_NAME
		camera.position = _CAMERA_POS
		camera.current = true
		add_child(camera)
		if is_inside_tree():
			camera.look_at(Vector3.ZERO)
	var light: DirectionalLight3D = get_node_or_null(LIGHT_NAME) as DirectionalLight3D
	if light == null:
		light = DirectionalLight3D.new()
		light.name = LIGHT_NAME
		light.rotation_degrees = _LIGHT_ROT_DEG
		add_child(light)


func rebuild(world: AuthoringWorld) -> void:
	ensure_rig()
	_clear_placeholders()
	if world == null:
		return
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		var pose: Dictionary = pose_from_record(record)
		if pose.is_empty():
			continue
		_spawn_placeholder(entity_id, pose)


func mapped_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is MeshInstance3D:
			count += 1
	return count


func placeholder_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(placeholder_name(entity_id)) as MeshInstance3D


func _clear_placeholders() -> void:
	var doomed: Array[Node] = []
	for child: Node in get_children():
		if child is MeshInstance3D:
			doomed.append(child)
	for child: Node in doomed:
		remove_child(child)
		child.free()


func _spawn_placeholder(entity_id: int, pose: Dictionary) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _STUB_ALBEDO
	mesh.material = material
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = placeholder_name(entity_id)
	node.mesh = mesh
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var yaw_bam: int = pose["yaw_bam"]
	node.position = Vector3(
		meters_from_fixed(x),
		meters_from_fixed(y),
		meters_from_fixed(z)
	)
	node.rotation.y = yaw_radians_from_bam(yaw_bam)
	add_child(node)
