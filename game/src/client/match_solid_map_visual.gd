class_name MatchSolidMapVisual
extends RefCounted

## Tile / OccupancyGadget wiring for MatchSolidMap. Public apply stays on
## the map so that file stays under E9. Authority is still the lattice box.

const OccupancyGadgetGd := preload("res://src/shared/occupancy_gadget.gd")
const VISUAL_NAME: String = "visual"


static func spawn_box(
	parent: Node3D,
	node_name: String,
	pose: Dictionary,
	albedo: Color,
	kind: String,
	yaw_bam: int,
	tile_scene_path: String
) -> bool:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PlaceholderSpec.BOX_SIZE
	mesh.material = unshaded(albedo)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = Vector3(
		float(x) / float(Fixed.SCALE),
		float(y) / float(Fixed.SCALE),
		float(z) / float(Fixed.SCALE)
	)
	parent.add_child(node)
	if not kind.is_empty():
		if OccupancyGadgetGd.attach(node, kind, yaw_bam):
			node.layers = 0
		return false
	return attach_tile(node, tile_scene_path)


## 地块在时：挂 `visual` 子节点并让占位盒本体退出渲染层。用 `layers = 0` 而不是
## `visible = false`，因为后者会连带隐藏刚挂上的视觉。不染色：固体不需要区分归属，
## 石色本来就是占位色，地块自带贴图。
static func attach_tile(solid: MeshInstance3D, tile_scene_path: String) -> bool:
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
	return true


static func unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


static func xyz_from_bag(bag: Dictionary) -> Dictionary:
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
	return {"entity_id": entity_id, "x": x, "y": y, "z": z}


static func copy_poses(bags: Array[Dictionary]) -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	for bag: Dictionary in bags:
		poses.append(xyz_from_bag(bag))
	return poses


static func bags_are_mappable(bags: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for bag: Dictionary in bags:
		var pose: Dictionary = xyz_from_bag(bag)
		if pose.is_empty():
			return false
		var entity_id: int = pose["entity_id"]
		if seen.has(entity_id):
			return false
		seen[entity_id] = true
	return true
