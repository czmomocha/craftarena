class_name MatchCourseMap
extends Node3D

## Presentation mapping for compiled TRAPRUSH topology (CD-43).
## Pads, classified portals, and finish occupancy become 1 m boxes at the
## Q48.16 poses. Authority stays on SimulationBundle; float conversion
## happens only here. Placeholders are not hitboxes. Destructibles have
## poses in the bundle but stay undrawn here; MatchCrateMap draws them.
## Portal source→dest bars stay undrawn here; MatchPortalLinkMap draws them.
## Checkpoint-order labels and sequence bars stay undrawn here;
## MatchCheckpointOrderMap draws them.
## No interpolation, prediction, ranking, or course-selection API.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const PAD_PREFIX: String = "pad_"
const PORTAL_PREFIX: String = "portal_"
const FINISH_PREFIX: String = "finish_"
const PLACEHOLDER_SIZE: Vector3 = Vector3(1.0, 1.0, 1.0)
const _PAD_ALBEDO: Color = Color(0.35, 0.9, 0.4)
const _TWO_WAY_ALBEDO: Color = Color(0.2, 0.75, 0.95)
const _ONE_WAY_ALBEDO: Color = Color(0.95, 0.55, 0.15)
const _FINISH_ALBEDO: Color = Color(0.95, 0.82, 0.2)

var _pad_count: int = 0
var _portal_count: int = 0
var _finish_count: int = 0


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func pad_name(entity_id: int) -> String:
	return "%s%d" % [PAD_PREFIX, entity_id]


static func portal_name(entity_id: int) -> String:
	return "%s%d" % [PORTAL_PREFIX, entity_id]


static func finish_name(entity_id: int) -> String:
	return "%s%d" % [FINISH_PREFIX, entity_id]


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
	if not _bags_are_mappable(bundle.pads):
		return false
	if not _portals_are_mappable(bundle.portals):
		return false
	if not _bags_are_mappable(bundle.finish):
		return false
	_clear_course()
	for pad: Dictionary in bundle.pads:
		var pad_id: int = pad["entity_id"]
		_spawn_box(pad_name(pad_id), pad, _PAD_ALBEDO)
	for portal: Dictionary in bundle.portals:
		var portal_id: int = portal["entity_id"]
		_spawn_box(portal_name(portal_id), portal, _portal_color(portal))
	for finish: Dictionary in bundle.finish:
		var finish_id: int = finish["entity_id"]
		_spawn_box(finish_name(finish_id), finish, _FINISH_ALBEDO)
	_pad_count = bundle.pads.size()
	_portal_count = bundle.portals.size()
	_finish_count = bundle.finish.size()
	return true


func pad_count() -> int:
	return _pad_count


func portal_count() -> int:
	return _portal_count


func finish_count() -> int:
	return _finish_count


func crate_node_count() -> int:
	return 0


func link_node_count() -> int:
	return 0


func checkpoint_node_count() -> int:
	return 0


func pad_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(pad_name(entity_id)) as MeshInstance3D


func portal_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(portal_name(entity_id)) as MeshInstance3D


func finish_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(finish_name(entity_id)) as MeshInstance3D


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _bags_are_mappable(bags: Array[Dictionary]) -> bool:
	for bag: Dictionary in bags:
		if _xyz_from_bag(bag).is_empty():
			return false
	return true


func _portals_are_mappable(bags: Array[Dictionary]) -> bool:
	for bag: Dictionary in bags:
		if _xyz_from_bag(bag).is_empty():
			return false
		if not bag.has("kind") or typeof(bag["kind"]) != TYPE_STRING:
			return false
		var kind: String = bag["kind"]
		if kind != AuthoringPortalKinds.TWO_WAY and kind != AuthoringPortalKinds.ONE_WAY:
			return false
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


func _portal_color(bag: Dictionary) -> Color:
	var kind: String = bag["kind"]
	if kind == AuthoringPortalKinds.ONE_WAY:
		return _ONE_WAY_ALBEDO
	return _TWO_WAY_ALBEDO


func _spawn_box(node_name: String, bag: Dictionary, color: Color) -> void:
	var pose: Dictionary = _xyz_from_bag(bag)
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	mesh.material = _unshaded(color)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))
	add_child(node)


func _clear_course() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		var child_name: String = str(child.name)
		if (
			child_name.begins_with(PAD_PREFIX)
			or child_name.begins_with(PORTAL_PREFIX)
			or child_name.begins_with(FINISH_PREFIX)
		):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_pad_count = 0
	_portal_count = 0
	_finish_count = 0


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
