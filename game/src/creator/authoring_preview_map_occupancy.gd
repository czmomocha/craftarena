class_name AuthoringPreviewMapOccupancy
extends RefCounted

const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")

## Occupancy placeholders for AuthoringPreviewMap: one BoxMesh per transform,
## plus kind visuals (tile / checkpoint / finish / crate / hazard).
## Hazard visibility is a per-instance overlay; it does not write authority.


func spawn_placeholder(
	map: AuthoringPreviewMap,
	entity_id: int,
	pose: Dictionary,
	record: SharedComponentRecord
) -> void:
	var albedo: Color = PlaceholderSpec.ENTITY_STUB_ALBEDO
	var kind: String = ""
	if record != null and record.components.has(SharedComponentNames.HAZARD):
		albedo = AuthoringPreviewMap.HAZARD_ALBEDO
		kind = "hazard"
	elif record != null and _record_has_solid_tag(record):
		albedo = AuthoringPreviewMap.SOLID_ALBEDO
		kind = "tile"
	elif record != null and record.components.has(SharedComponentNames.DESTRUCTIBLE):
		albedo = AuthoringPreviewMap.CRATE_ALBEDO
		kind = "crate"
	elif record != null and _record_has_finish_tag(record):
		albedo = AuthoringPreviewMap.FINISH_ALBEDO
		kind = "finish"
	elif record != null and record.components.has(SharedComponentNames.CHECKPOINT):
		albedo = PlaceholderSpec.PAD_PENDING_ALBEDO
		kind = "checkpoint"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = AuthoringPreviewMap.PLACEHOLDER_SIZE
	mesh.material = ConvertGd.unshaded(albedo)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = ConvertGd.placeholder_name(entity_id)
	node.mesh = mesh
	node.position = ConvertGd.meters_from_pose(pose)
	var yaw_bam: int = pose["yaw_bam"]
	node.rotation.y = ConvertGd.yaw_radians_from_bam(yaw_bam)
	map.add_child(node)
	_attach_kind_visual(map, node, kind, albedo)


## 按组件 / zone 标签接占用视觉，与对局袋类型对齐。机关与箱子走 overlay，
## 不铺成地块：D4 已把危险色定成可读性的一部分。
func _attach_kind_visual(
	map: AuthoringPreviewMap,
	placeholder: MeshInstance3D,
	kind: String,
	albedo: Color
) -> bool:
	var visual: Node3D = null
	if kind == "tile":
		visual = SharedVisualAssetCatalog.try_instantiate_fitted_tile_from(map.tile_scene_path)
	elif kind == "checkpoint":
		visual = SharedVisualAssetCatalog.try_instantiate_checkpoint(
			map.pad_scene_path,
			map.gate_scene_path
		)
	elif kind == "finish":
		visual = SharedVisualAssetCatalog.try_instantiate_fitted_prop(map.finish_scene_path)
	elif kind == "crate":
		visual = SharedVisualAssetCatalog.try_instantiate_fitted_prop(map.crate_scene_path)
	elif kind == "hazard":
		visual = SharedVisualAssetCatalog.try_instantiate_fitted_prop(map.hazard_scene_path)
	if visual == null:
		return false
	visual.name = AuthoringPreviewMap.VISUAL_NAME
	placeholder.add_child(visual)
	if kind != "tile":
		SharedVisualAssetCatalog.tint(visual, albedo)
	placeholder.layers = 0
	return true


## 逐实例改显隐，不动世界。因此它改过之后世界指纹仍然没变：想让占位盒回到
## 默认可见，调用方必须 invalidate() 再 rebuild()（Preview 在开玩 / 停玩切换时做）。
func apply_hazard_visibility(map: AuthoringPreviewMap, solid_by_entity: Dictionary) -> void:
	for key: Variant in solid_by_entity.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		var node: MeshInstance3D = map.placeholder_node(entity_id)
		if node == null:
			continue
		var solid_raw: Variant = solid_by_entity[entity_id]
		if typeof(solid_raw) != TYPE_BOOL:
			continue
		var solid: bool = solid_raw
		node.visible = solid


func record_has_finish_tag(record: SharedComponentRecord) -> bool:
	return _record_has_finish_tag(record)


func _record_has_solid_tag(record: SharedComponentRecord) -> bool:
	return _record_has_zone_tag(record, "solid")


func _record_has_finish_tag(record: SharedComponentRecord) -> bool:
	return _record_has_zone_tag(record, "finish")


func _record_has_zone_tag(record: SharedComponentRecord, tag_name: String) -> bool:
	if not record.components.has(SharedComponentNames.ZONE):
		return false
	var raw: Variant = record.components[SharedComponentNames.ZONE]
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var zone: Dictionary = raw
	var tags_raw: Variant = zone.get("tags", [])
	if typeof(tags_raw) != TYPE_ARRAY:
		return false
	var tags: Array = tags_raw
	for item: Variant in tags:
		if typeof(item) != TYPE_STRING:
			continue
		var tag: String = item
		if tag == tag_name:
			return true
	return false
