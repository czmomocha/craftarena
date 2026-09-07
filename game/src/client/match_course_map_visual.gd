class_name MatchCourseMapVisual
extends RefCounted

## Occupancy visual attach / progress tint for MatchCourseMap (F-line FC).


static func attach(map: MatchCourseMap, node: MeshInstance3D, kind: String, color: Color) -> bool:
	if map == null or node == null:
		return false
	var visual: Node3D = null
	if kind == "checkpoint":
		visual = SharedVisualAssetCatalog.try_instantiate_checkpoint(
			map.pad_scene_path,
			map.gate_scene_path
		)
	elif kind == "finish":
		visual = SharedVisualAssetCatalog.try_instantiate_fitted_prop(map.finish_scene_path)
	elif kind == "portal":
		visual = SharedVisualAssetCatalog.try_instantiate_fitted_prop(map.portal_scene_path)
	if visual == null:
		return false
	visual.name = MatchCourseMap.VISUAL_NAME
	node.add_child(visual)
	SharedVisualAssetCatalog.tint(visual, color)
	node.layers = 0
	return true


## 进度色每帧都会被对局壳写一次。盒子材质没变就不重套 overlay，避免每帧
## `StandardMaterial3D.new()`。
static func tint(node: MeshInstance3D, color: Color) -> void:
	if node == null:
		return
	var box: BoxMesh = node.mesh as BoxMesh
	if box == null:
		return
	var material: StandardMaterial3D = box.material as StandardMaterial3D
	if material == null:
		return
	if material.albedo_color == color:
		return
	material.albedo_color = color
	var visual: Node3D = node.get_node_or_null(MatchCourseMap.VISUAL_NAME) as Node3D
	if visual != null:
		SharedVisualAssetCatalog.tint(visual, color)


static func unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
