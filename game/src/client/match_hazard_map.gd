class_name MatchHazardMap
extends Node3D

## Presentation mapping for compiled TRAPRUSH period hazards (CD-43).
## Topology bags supply Q48.16 poses and cooldown_ticks. Visibility follows
## TraprushHazardCycle.is_solid(tick, cooldown_ticks): solid half shows the
## 1 m box, open half removes it. Tick 0 is the solid half for cooldown>=1.
## Float conversion happens only here. Placeholders are not hitboxes.
## live_solid_boxes() returns compiled Q48.16 centers plus cell/2 half-extents
## for currently solid hazards (authoring lattice, not the 1 m placeholder).
## Snapshots never move a hazard; v1 frames have no hazard bag, only tick.
## Official courses compile zero hazards. No interpolation or prediction API.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const HazardCycleGd := preload("res://src/games/traprush/hazard_cycle.gd")
const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const HAZARD_PREFIX: String = "hazard_"
const PLACEHOLDER_SIZE: Vector3 = Vector3(1.0, 1.0, 1.0)
const HAZARD_ALBEDO: Color = Color(0.82, 0.18, 0.48)

var _has_course: bool = false
var _cell: int = 0
var _tick: int = 0
var _poses: Array[Dictionary] = []
var _live_solids: Array[Dictionary] = []
var _hazard_count: int = 0


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func hazard_name(entity_id: int) -> String:
	return "%s%d" % [HAZARD_PREFIX, entity_id]


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
	if not _bags_are_mappable(bundle.hazards):
		return false
	_has_course = true
	_cell = bundle.cell
	_poses = _copy_poses(bundle.hazards)
	_tick = 0
	_rebuild()
	return true


func apply_follow(follow: MatchSnapshotFollowGd) -> bool:
	if follow == null or not follow.has_snapshot:
		return false
	return apply_tick(follow.tick)


func apply_tick(tick: int) -> bool:
	if not _has_course:
		return false
	if tick < 0:
		return false
	_tick = tick
	_rebuild()
	return true


func hazard_count() -> int:
	return _hazard_count


func hazard_total() -> int:
	return _poses.size()


func hazard_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(hazard_name(entity_id)) as MeshInstance3D


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
		if not bag.has("cooldown_ticks") or typeof(bag["cooldown_ticks"]) != TYPE_INT:
			return false
		var cooldown_ticks: int = bag["cooldown_ticks"]
		if cooldown_ticks < 0:
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
		"cooldown_ticks": bag.get("cooldown_ticks", -1),
	}


func _copy_poses(bags: Array[Dictionary]) -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	for bag: Dictionary in bags:
		poses.append(_xyz_from_bag(bag))
	return poses


func _rebuild() -> void:
	_clear_hazards()
	_live_solids = []
	for pose: Dictionary in _poses:
		var cooldown_raw: Variant = pose.get("cooldown_ticks", -1)
		if typeof(cooldown_raw) != TYPE_INT:
			continue
		var cooldown_ticks: int = cooldown_raw
		if not HazardCycleGd.is_solid(_tick, cooldown_ticks):
			continue
		_live_solids.append({
			"x": pose["x"],
			"y": pose["y"],
			"z": pose["z"],
		})
		var entity_id: int = pose["entity_id"]
		_spawn_box(hazard_name(entity_id), pose)
	_hazard_count = _visible_count()


func _visible_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if str(child.name).begins_with(HAZARD_PREFIX):
			count += 1
	return count


func _spawn_box(node_name: String, pose: Dictionary) -> void:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	mesh.material = _unshaded(HAZARD_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))
	add_child(node)


func _clear_hazards() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		if str(child.name).begins_with(HAZARD_PREFIX):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_hazard_count = 0


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
