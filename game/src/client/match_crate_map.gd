class_name MatchCrateMap
extends Node3D

## Presentation mapping for compiled TRAPRUSH destructibles (CD-43).
## Topology bags supply Q48.16 poses; the latest snapshot supplies
## durability. Float conversion happens only here. Placeholders are not
## hitboxes. Durability <= 0 or a crate omitted from the snapshot removes
## the box. Snapshots never move a crate. Portal source→dest bars stay
## undrawn here; MatchPortalLinkMap draws them. Checkpoint-order gizmos
## stay undrawn here; MatchCheckpointOrderMap draws them. Standing labels
## stay undrawn here; MatchStandingMap draws them. No interpolation,
## prediction, or course-selection API.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")

const CRATE_PREFIX: String = "crate_"
const PLACEHOLDER_SIZE: Vector3 = Vector3(1.0, 1.0, 1.0)
const _CRATE_ALBEDO: Color = Color(0.85, 0.4, 0.25)

var _has_course: bool = false
var _poses: Array[Dictionary] = []
var _crate_count: int = 0


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func crate_name(entity_id: int) -> String:
	return "%s%d" % [CRATE_PREFIX, entity_id]


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
	if not _bags_are_mappable(bundle.destructibles):
		return false
	_has_course = true
	_poses = _copy_poses(bundle.destructibles)
	_rebuild(_durability_from_bags(bundle.destructibles))
	return true


func apply_follow(follow: MatchSnapshotFollowGd) -> bool:
	if follow == null or not follow.has_snapshot:
		return false
	return apply_crates(follow.crates)


func apply_crates(crates: Array) -> bool:
	if not _has_course:
		return false
	if not _snapshot_is_mappable(crates):
		return false
	_rebuild(_durability_from_snapshot(crates))
	return true


func crate_count() -> int:
	return _crate_count


func crate_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(crate_name(entity_id)) as MeshInstance3D


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
		if not bag.has("durability") or typeof(bag["durability"]) != TYPE_INT:
			return false
		var entity_id: int = pose["entity_id"]
		if seen.has(entity_id):
			return false
		seen[entity_id] = true
	return true


func _snapshot_is_mappable(crates: Array) -> bool:
	var seen: Dictionary = {}
	for raw: Variant in crates:
		if typeof(raw) != TYPE_DICTIONARY:
			return false
		var bag: Dictionary = raw
		if not bag.has("entity_id") or typeof(bag["entity_id"]) != TYPE_INT:
			return false
		var entity_id: int = bag["entity_id"]
		if entity_id < 1:
			return false
		if not bag.has("durability") or typeof(bag["durability"]) != TYPE_INT:
			return false
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


func _durability_from_bags(bags: Array[Dictionary]) -> Dictionary:
	var lookup: Dictionary = {}
	for bag: Dictionary in bags:
		var entity_id: int = bag["entity_id"]
		var durability: int = bag["durability"]
		lookup[entity_id] = durability
	return lookup


func _durability_from_snapshot(crates: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for raw: Variant in crates:
		var bag: Dictionary = raw
		var entity_id: int = bag["entity_id"]
		var durability: int = bag["durability"]
		lookup[entity_id] = durability
	return lookup


func _rebuild(lookup: Dictionary) -> void:
	_clear_crates()
	for pose: Dictionary in _poses:
		var entity_id: int = pose["entity_id"]
		if not lookup.has(entity_id):
			continue
		var durability: int = lookup[entity_id]
		if durability <= 0:
			continue
		_spawn_box(crate_name(entity_id), pose)
	_crate_count = _visible_count()


func _visible_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if str(child.name).begins_with(CRATE_PREFIX):
			count += 1
	return count


func _spawn_box(node_name: String, pose: Dictionary) -> void:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	mesh.material = _unshaded(_CRATE_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))
	add_child(node)


func _clear_crates() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		if str(child.name).begins_with(CRATE_PREFIX):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_crate_count = 0


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
