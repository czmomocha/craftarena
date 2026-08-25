class_name MatchPortalLinkMap
extends Node3D

## Presentation mapping for compiled TRAPRUSH portal links (CD-43).
## Source and dest Q48.16 poses become a bar gizmo. two_way / one_way
## use the same colors as Preview. one_way adds a direction marker.
## Dangling bags are omitted by the compiler and are not drawn.
## Checkpoint-order gizmos stay undrawn here; MatchCheckpointOrderMap
## draws them. Authority stays on SimulationBundle; float conversion
## happens only here. Gizmos are not hitboxes. No interpolation,
## prediction, ranking, or course-selection API.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringPortalKindsGd := preload("res://src/creator/authoring_portal_kinds.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const LINK_PREFIX: String = "portal_link_"
const DIR_PREFIX: String = "portal_dir_"
const DANGLE_PREFIX: String = "portal_dangle_"
const LINK_THICKNESS: float = 0.08
const DIR_SIZE: Vector3 = Vector3(0.2, 0.2, 0.2)
const _MIN_LINK_LEN: float = 0.001
const _TWO_WAY_ALBEDO: Color = Color(0.2, 0.75, 0.95)
const _ONE_WAY_ALBEDO: Color = Color(0.95, 0.55, 0.15)

var _link_count: int = 0
var _direction_count: int = 0


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func link_name(entity_id: int) -> String:
	return "%s%d" % [LINK_PREFIX, entity_id]


static func direction_name(entity_id: int) -> String:
	return "%s%d" % [DIR_PREFIX, entity_id]


static func dangle_name(entity_id: int) -> String:
	return "%s%d" % [DANGLE_PREFIX, entity_id]


static func compile_path(path: String) -> SimulationBundle:
	if path.is_empty():
		return null
	var world: AuthoringWorld = AuthoringDocumentGd.load_from_path(path)
	if world == null:
		return null
	return TraprushTopologyCompilerGd.compile(world)


func apply_path(path: String) -> bool:
	return apply_bundle(compile_path(path))


func apply_bundle(bundle: SimulationBundle) -> bool:
	if bundle == null:
		return false
	if not _portals_are_mappable(bundle.portals):
		return false
	_clear_links()
	for portal: Dictionary in bundle.portals:
		_spawn_link(portal)
	return true


func link_count() -> int:
	return _link_count


func direction_count() -> int:
	return _direction_count


func link_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(link_name(entity_id)) as MeshInstance3D


func direction_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(direction_name(entity_id)) as MeshInstance3D


func dangle_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(dangle_name(entity_id)) as MeshInstance3D


func crate_node_count() -> int:
	return 0


func checkpoint_node_count() -> int:
	return 0


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _portals_are_mappable(bags: Array[Dictionary]) -> bool:
	for bag: Dictionary in bags:
		if _poses_from_portal(bag).is_empty():
			return false
	return true


func _poses_from_portal(bag: Dictionary) -> Dictionary:
	if not bag.has("entity_id") or typeof(bag["entity_id"]) != TYPE_INT:
		return {}
	var entity_id: int = bag["entity_id"]
	if entity_id < 1:
		return {}
	if not bag.has("kind") or typeof(bag["kind"]) != TYPE_STRING:
		return {}
	var kind: String = bag["kind"]
	if kind != AuthoringPortalKindsGd.TWO_WAY and kind != AuthoringPortalKindsGd.ONE_WAY:
		return {}
	if not bag.has("x") or typeof(bag["x"]) != TYPE_INT:
		return {}
	if not bag.has("y") or typeof(bag["y"]) != TYPE_INT:
		return {}
	if not bag.has("z") or typeof(bag["z"]) != TYPE_INT:
		return {}
	if not bag.has("dest_x") or typeof(bag["dest_x"]) != TYPE_INT:
		return {}
	if not bag.has("dest_y") or typeof(bag["dest_y"]) != TYPE_INT:
		return {}
	if not bag.has("dest_z") or typeof(bag["dest_z"]) != TYPE_INT:
		return {}
	var x: int = bag["x"]
	var y: int = bag["y"]
	var z: int = bag["z"]
	var dest_x: int = bag["dest_x"]
	var dest_y: int = bag["dest_y"]
	var dest_z: int = bag["dest_z"]
	return {
		"entity_id": entity_id,
		"kind": kind,
		"x": x,
		"y": y,
		"z": z,
		"dest_x": dest_x,
		"dest_y": dest_y,
		"dest_z": dest_z,
	}


func _spawn_link(bag: Dictionary) -> void:
	var poses: Dictionary = _poses_from_portal(bag)
	var entity_id: int = poses["entity_id"]
	var kind: String = poses["kind"]
	var from_x: int = poses["x"]
	var from_y: int = poses["y"]
	var from_z: int = poses["z"]
	var dest_x: int = poses["dest_x"]
	var dest_y: int = poses["dest_y"]
	var dest_z: int = poses["dest_z"]
	var from: Vector3 = Vector3(
		meters_from_fixed(from_x),
		meters_from_fixed(from_y),
		meters_from_fixed(from_z)
	)
	var to: Vector3 = Vector3(
		meters_from_fixed(dest_x),
		meters_from_fixed(dest_y),
		meters_from_fixed(dest_z)
	)
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < _MIN_LINK_LEN:
		return
	var color: Color = _TWO_WAY_ALBEDO
	if kind == AuthoringPortalKindsGd.ONE_WAY:
		color = _ONE_WAY_ALBEDO
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(LINK_THICKNESS, LINK_THICKNESS, length)
	mesh.material = _unshaded(color)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = link_name(entity_id)
	node.mesh = mesh
	node.position = (from + to) * 0.5
	node.set_meta("kind", kind)
	add_child(node)
	_look_toward(node, to)
	_link_count += 1
	if kind != AuthoringPortalKindsGd.ONE_WAY:
		return
	_spawn_direction(entity_id, from, to)


func _spawn_direction(entity_id: int, from: Vector3, to: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = DIR_SIZE
	mesh.material = _unshaded(_ONE_WAY_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = direction_name(entity_id)
	node.mesh = mesh
	node.position = from.lerp(to, 0.8) + Vector3(0.0, 0.15, 0.0)
	add_child(node)
	_direction_count += 1


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


func _clear_links() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		var child_name: String = str(child.name)
		if child_name.begins_with(LINK_PREFIX) or child_name.begins_with(DIR_PREFIX):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_link_count = 0
	_direction_count = 0


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
