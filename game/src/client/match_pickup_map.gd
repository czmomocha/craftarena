class_name MatchPickupMap
extends Node3D

## Presentation mapping for compiled TRAPRUSH pickups (F-line FC).
## Authority already grants on overlap; this file only draws bomb / dash
## so the three shells can see them. Placeholders are not hitboxes.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const PickupKindsGd := preload("res://src/ugc/traprush_pickup_kinds.gd")

const PICKUP_PREFIX: String = "pickup_"
const VISUAL_NAME: String = "visual"
const PLACEHOLDER_SIZE: Vector3 = PlaceholderSpec.BOX_SIZE

var bomb_scene_path: String = SharedVisualAssetCatalog.PICKUP_BOMB_SCENE_PATH
var dash_scene_path: String = SharedVisualAssetCatalog.PICKUP_DASH_SCENE_PATH
var _has_course: bool = false
var _poses: Array[Dictionary] = []
var _pickup_count: int = 0


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func pickup_name(entity_id: int) -> String:
	return "%s%d" % [PICKUP_PREFIX, entity_id]


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
	if not _bags_are_mappable(bundle.pickups):
		return false
	_has_course = true
	_poses = _copy_poses(bundle.pickups)
	_rebuild()
	return true


func pickup_count() -> int:
	return _pickup_count


func pickup_total() -> int:
	return _poses.size()


func pickup_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(pickup_name(entity_id)) as MeshInstance3D


func visual_node(entity_id: int) -> Node3D:
	var node: MeshInstance3D = pickup_node(entity_id)
	if node == null:
		return null
	return node.get_node_or_null(VISUAL_NAME) as Node3D


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
	if not bag.has("kind") or typeof(bag["kind"]) != TYPE_STRING:
		return {}
	var kind: String = bag["kind"]
	if not PickupKindsGd.contains(kind):
		return {}
	var asset_id: int = SharedGameplayAssetCatalog.LATTICE_CELL_ID
	if bag.has("asset_id") and typeof(bag["asset_id"]) == TYPE_INT:
		asset_id = bag["asset_id"]
	return {
		"entity_id": entity_id,
		"x": bag["x"],
		"y": bag["y"],
		"z": bag["z"],
		"kind": kind,
		"asset_id": asset_id,
	}


func _copy_poses(bags: Array[Dictionary]) -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	for bag: Dictionary in bags:
		poses.append(_xyz_from_bag(bag))
	return poses


func _rebuild() -> void:
	_clear()
	for pose: Dictionary in _poses:
		_spawn_box(pickup_name(PlayClock.dict_int(pose, "entity_id", 0)), pose)
	_pickup_count = _poses.size()


func _spawn_box(node_name: String, pose: Dictionary) -> void:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var kind: String = pose["kind"]
	var albedo: Color = PlaceholderSpec.PICKUP_BOMB_ALBEDO
	var scene_path: String = bomb_scene_path
	var bag_kind: String = SharedVisualAssetCatalogIds.BAG_PICKUP_BOMB
	if kind == PickupKindsGd.DASH:
		albedo = PlaceholderSpec.PICKUP_DASH_ALBEDO
		scene_path = dash_scene_path
		bag_kind = SharedVisualAssetCatalogIds.BAG_PICKUP_DASH
	var asset_id: int = pose["asset_id"]
	var resolved: String = SharedVisualAssetCatalog.scene_for(asset_id, bag_kind)
	if resolved != "":
		scene_path = resolved
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE * 0.45
	mesh.material = _unshaded(albedo)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))
	add_child(node)
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_fitted_prop(scene_path)
	if visual == null:
		return
	visual.name = VISUAL_NAME
	node.add_child(visual)
	SharedVisualAssetCatalog.tint(visual, albedo)
	node.layers = 0


func _clear() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		if str(child.name).begins_with(PICKUP_PREFIX):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_pickup_count = 0


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
