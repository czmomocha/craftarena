class_name MatchSolidMap
extends Node3D

## Presentation mapping for compiled TRAPRUSH always-solid occupancy (CD-43).
## Topology bags supply Q48.16 poses. Boxes stay visible; they never toggle.
## Float conversion happens only here. Placeholders are not hitboxes.
## live_solid_boxes() returns compiled Q48.16 centers plus cell/2 half-extents
## (authoring lattice, not the 1 m placeholder). Snapshots never move a solid;
## v1 frames have no solid bag. Official courses compile path floors.
## No interpolation or prediction API. Box size and colour come from
## PlaceholderSpec; this file keeps the names but no longer owns the values.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const SOLID_PREFIX: String = "solid_"
const PLACEHOLDER_SIZE: Vector3 = PlaceholderSpec.BOX_SIZE
const SOLID_ALBEDO: Color = PlaceholderSpec.SOLID_ALBEDO

var _has_course: bool = false
var _cell: int = 0
var _poses: Array[Dictionary] = []
var _live_solids: Array[Dictionary] = []
var _solid_count: int = 0


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func solid_name(entity_id: int) -> String:
	return "%s%d" % [SOLID_PREFIX, entity_id]


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
	if not _bags_are_mappable(bundle.solids):
		return false
	_has_course = true
	_cell = bundle.cell
	_poses = _copy_poses(bundle.solids)
	_rebuild()
	return true


func solid_count() -> int:
	return _solid_count


func solid_total() -> int:
	return _poses.size()


func solid_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(solid_name(entity_id)) as MeshInstance3D


func live_solid_boxes() -> Array:
	var boxes: Array = []
	if _cell < 1:
		return boxes
	var half: int = _cell / 2
	for pose: Dictionary in _live_solids:
		boxes.append({
			"x": pose["x"],
			"y": pose["y"],
			"z": pose["z"],
			"hx": half,
			"hy": half,
			"hz": half,
		})
	return boxes


func crate_node_count() -> int:
	return 0


func hazard_node_count() -> int:
	return 0


func link_node_count() -> int:
	return 0


func checkpoint_node_count() -> int:
	return 0


func standing_node_count() -> int:
	return 0


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _bags_are_mappable(bags: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for bag: Dictionary in bags:
		var pose: Dictionary = _xyz_from_bag(bag)
		if pose.is_empty():
			return false
		var entity_id: int = pose["entity_id"]
		if seen.has(entity_id):
			return false
		seen[entity_id] = true
	return true


func _xyz_from_bag(bag: Dictionary) -> Dictionary:
	if not bag.has("entity_id") or typeof(bag["entity_id"]) != TYPE_INT:
		return {}
	var entity_id: int = bag["entity_id"]
	if entity_id < 1:
		return {}
	if not bag.has("x") or typeof(bag["x"]) != TYPE_INT:
		return {}
	if not bag.has("y") or typeof(bag["y"]) != TYPE_INT:
		return {}
	if not bag.has("z") or typeof(bag["z"]) != TYPE_INT:
		return {}
	var x: int = bag["x"]
	var y: int = bag["y"]
	var z: int = bag["z"]
	return {
		"entity_id": entity_id,
		"x": x,
		"y": y,
		"z": z,
	}


func _copy_poses(bags: Array[Dictionary]) -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	for bag: Dictionary in bags:
		poses.append(_xyz_from_bag(bag))
	return poses


func _rebuild() -> void:
	_clear_solids()
	_live_solids = []
	for pose: Dictionary in _poses:
		_live_solids.append({
			"x": pose["x"],
			"y": pose["y"],
			"z": pose["z"],
		})
		var entity_id: int = pose["entity_id"]
		_spawn_box(solid_name(entity_id), pose)
	_solid_count = _visible_count()


func _visible_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if str(child.name).begins_with(SOLID_PREFIX):
			count += 1
	return count


func _spawn_box(node_name: String, pose: Dictionary) -> void:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	mesh.material = _unshaded(SOLID_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))
	add_child(node)


func _clear_solids() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		if str(child.name).begins_with(SOLID_PREFIX):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_solid_count = 0


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
