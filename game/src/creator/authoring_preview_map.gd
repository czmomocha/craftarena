class_name AuthoringPreviewMap
extends Node3D

## Presentation mapping for AuthoringPreview (CD-32 §3). Authority stays on
## AuthoringWorld Q48.16; float conversion happens only here. One 1×1×1 m
## BoxMesh per entity with transform; portal_link gizmos from classified
## links. Placeholders and gizmos are not hitboxes. Rebuild after every patch.

const CAMERA_NAME: String = "PreviewCamera"
const LIGHT_NAME: String = "PreviewLight"
const PLACEHOLDER_PREFIX: String = "entity_"
const LINK_PREFIX: String = "portal_link_"
const DANGLE_PREFIX: String = "portal_dangle_"
const DIR_PREFIX: String = "portal_dir_"
const PLACEHOLDER_SIZE: Vector3 = Vector3(1.0, 1.0, 1.0)
const LINK_THICKNESS: float = 0.08
const DANGLE_SIZE: Vector3 = Vector3(0.35, 0.35, 0.35)
const DIR_SIZE: Vector3 = Vector3(0.2, 0.2, 0.2)
const DANGLE_LIFT: float = 0.7
const _MIN_LINK_LEN: float = 0.001
const _CAMERA_POS: Vector3 = Vector3(6.0, 8.0, 6.0)
const _LIGHT_ROT_DEG: Vector3 = Vector3(-50.0, -30.0, 0.0)
const _STUB_ALBEDO: Color = Color(0.85, 0.7, 0.25)
const _TWO_WAY_ALBEDO: Color = Color(0.2, 0.75, 0.95)
const _ONE_WAY_ALBEDO: Color = Color(0.95, 0.55, 0.15)
const _DANGLE_ALBEDO: Color = Color(0.9, 0.25, 0.35)


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


static func meters_from_pose(pose: Dictionary) -> Vector3:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	return Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))


static func placeholder_name(entity_id: int) -> String:
	return "%s%d" % [PLACEHOLDER_PREFIX, entity_id]


static func link_name(source_id: int) -> String:
	return "%s%d" % [LINK_PREFIX, source_id]


static func dangle_name(source_id: int) -> String:
	return "%s%d" % [DANGLE_PREFIX, source_id]


static func direction_name(source_id: int) -> String:
	return "%s%d" % [DIR_PREFIX, source_id]


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
	_clear_meshes()
	if world == null:
		return
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		var pose: Dictionary = pose_from_record(record)
		if pose.is_empty():
			continue
		_spawn_placeholder(entity_id, pose)
	_spawn_portal_gizmos(world)


func mapped_count() -> int:
	return _count_prefix(PLACEHOLDER_PREFIX)


func link_count() -> int:
	return _count_prefix(LINK_PREFIX)


func dangle_count() -> int:
	return _count_prefix(DANGLE_PREFIX)


func placeholder_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(placeholder_name(entity_id)) as MeshInstance3D


func link_node(source_id: int) -> MeshInstance3D:
	return get_node_or_null(link_name(source_id)) as MeshInstance3D


func dangle_node(source_id: int) -> MeshInstance3D:
	return get_node_or_null(dangle_name(source_id)) as MeshInstance3D


func direction_node(source_id: int) -> MeshInstance3D:
	return get_node_or_null(direction_name(source_id)) as MeshInstance3D


func _count_prefix(prefix: String) -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is MeshInstance3D and str(child.name).begins_with(prefix):
			count += 1
	return count


func _clear_meshes() -> void:
	var doomed: Array[Node] = []
	for child: Node in get_children():
		if child is MeshInstance3D:
			doomed.append(child)
	for child: Node in doomed:
		remove_child(child)
		child.free()


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _spawn_placeholder(entity_id: int, pose: Dictionary) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	mesh.material = _unshaded(_STUB_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = placeholder_name(entity_id)
	node.mesh = mesh
	node.position = meters_from_pose(pose)
	var yaw_bam: int = pose["yaw_bam"]
	node.rotation.y = yaw_radians_from_bam(yaw_bam)
	add_child(node)


func _spawn_portal_gizmos(world: AuthoringWorld) -> void:
	var links: Array[Dictionary] = world.portal_links()
	for link: Dictionary in links:
		if typeof(link.get("source_id", null)) != TYPE_INT:
			continue
		if typeof(link.get("kind", null)) != TYPE_STRING:
			continue
		var source_id: int = link["source_id"]
		var kind: String = link["kind"]
		var source_record: SharedComponentRecord = world.get_record(source_id)
		var source_pose: Dictionary = pose_from_record(source_record)
		if source_pose.is_empty():
			continue
		var from: Vector3 = meters_from_pose(source_pose)
		if kind == AuthoringPortalKinds.DANGLING:
			_spawn_dangle(source_id, from)
			continue
		if typeof(link.get("dest_id", null)) != TYPE_INT:
			continue
		var dest_id: int = link["dest_id"]
		var dest_pose: Dictionary = pose_from_record(world.get_record(dest_id))
		if dest_pose.is_empty():
			_spawn_dangle(source_id, from)
			continue
		var to: Vector3 = meters_from_pose(dest_pose)
		_spawn_link(source_id, kind, dest_id, from, to)
		if kind == AuthoringPortalKinds.ONE_WAY:
			_spawn_direction(source_id, from, to)


func _spawn_dangle(source_id: int, from: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = DANGLE_SIZE
	mesh.material = _unshaded(_DANGLE_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = dangle_name(source_id)
	node.mesh = mesh
	node.position = from + Vector3(0.0, DANGLE_LIFT, 0.0)
	add_child(node)


func _spawn_link(
	source_id: int,
	kind: String,
	dest_id: int,
	from: Vector3,
	to: Vector3
) -> void:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < _MIN_LINK_LEN:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(LINK_THICKNESS, LINK_THICKNESS, length)
	var color: Color = _TWO_WAY_ALBEDO
	if kind == AuthoringPortalKinds.ONE_WAY:
		color = _ONE_WAY_ALBEDO
	mesh.material = _unshaded(color)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = link_name(source_id)
	node.mesh = mesh
	node.position = (from + to) * 0.5
	node.set_meta("kind", kind)
	node.set_meta("dest_id", dest_id)
	add_child(node)
	_look_toward(node, to)


func _spawn_direction(source_id: int, from: Vector3, to: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = DIR_SIZE
	mesh.material = _unshaded(_ONE_WAY_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = direction_name(source_id)
	node.mesh = mesh
	node.position = from.lerp(to, 0.8) + Vector3(0.0, 0.15, 0.0)
	add_child(node)


func _look_toward(node: Node3D, target: Vector3) -> void:
	if not node.is_inside_tree():
		return
	var delta: Vector3 = target - node.position
	if delta.length_squared() < 0.0000001:
		return
	var up: Vector3 = Vector3.UP
	if absf(delta.normalized().dot(Vector3.UP)) > 0.999:
		up = Vector3.FORWARD
	node.look_at(target, up)
