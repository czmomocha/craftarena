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
##
## 当 `tile_scene_path` 能解析出地块视觉（SharedVisualAssetCatalog）时，每个固体
## 节点多挂一个 `visual` 子节点，占位盒自身退出渲染（`layers = 0`）但网格与石色
## 原样保留——`live_solid_boxes()` 给的是编译拓扑的权威半长，与视觉无关，本席预测
## 读的还是同一份。视觉解析失败就是今天的行为，一个石色 1 米盒。
##
## 只有**始终固体**铺地块。周期机关走 MatchHazardMap（洋红）、可破坏箱走
## MatchCrateMap（橙），两者都不铺：D4 已把危险色定成可读性的一部分。

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const SOLID_PREFIX: String = "solid_"
const VISUAL_NAME: String = "visual"
const PLACEHOLDER_SIZE: Vector3 = PlaceholderSpec.BOX_SIZE
const SOLID_ALBEDO: Color = PlaceholderSpec.SOLID_ALBEDO

## 空字符串或解析失败 ⇒ 回退占位盒。是变量而不是常量，好让测试两条分支都能跑。
var tile_scene_path: String = SharedVisualAssetCatalog.TERRAIN_TILE_SCENE_PATH
var _has_course: bool = false
var _cell: int = 0
var _poses: Array[Dictionary] = []
var _live_solids: Array[Dictionary] = []
var _solid_count: int = 0
var _visual_count: int = 0


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


func visual_node(entity_id: int) -> Node3D:
	var solid: MeshInstance3D = solid_node(entity_id)
	if solid == null:
		return null
	return solid.get_node_or_null(VISUAL_NAME) as Node3D


## 有多少个固体真的铺上了地块。0 表示全部回退到占位盒。
func visual_count() -> int:
	return _visual_count


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
	_attach_visual(node)


## 地块在时：挂 `visual` 子节点并让占位盒本体退出渲染层。用 `layers = 0` 而不是
## `visible = false`，因为后者会连带隐藏刚挂上的视觉。不染色：固体不需要区分归属，
## 石色本来就是占位色，地块自带贴图。
func _attach_visual(solid: MeshInstance3D) -> bool:
	if tile_scene_path.is_empty():
		return false
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate(tile_scene_path)
	if visual == null:
		return false
	if not SharedVisualAssetCatalog.fit_tile_on_cell(visual):
		visual.free()
		return false
	visual.name = VISUAL_NAME
	solid.add_child(visual)
	solid.layers = 0
	_visual_count += 1
	return true


func _clear_solids() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		if str(child.name).begins_with(SOLID_PREFIX):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_solid_count = 0
	_visual_count = 0


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
