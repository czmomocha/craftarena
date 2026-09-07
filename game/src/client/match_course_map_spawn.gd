class_name MatchCourseMapSpawn
extends RefCounted

## Birth-pad marker for MatchCourseMap (F-line FC). Not occupancy.


static func attach(map: MatchCourseMap) -> void:
	if map == null:
		return
	var spawn_id: int = 0
	for entity_raw: Variant in map._pad_orders.keys():
		if typeof(entity_raw) != TYPE_INT:
			continue
		var entity_id: int = entity_raw
		if map._order_of(entity_id) != 0:
			continue
		spawn_id = entity_id
		break
	if spawn_id < 1:
		return
	var pad: MeshInstance3D = map.pad_node(spawn_id)
	if pad == null:
		return
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_fitted_prop(map.spawn_scene_path)
	if visual == null:
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.22
		mesh.height = 0.55
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.name = MatchCourseMap.SPAWN_NAME
		marker.mesh = mesh
		marker.position = Vector3(0.0, 0.7, 0.0)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = PlaceholderSpec.SPAWN_MARKER_ALBEDO
		mesh.material = material
		pad.add_child(marker)
		return
	visual.name = MatchCourseMap.SPAWN_NAME
	visual.position = Vector3(0.0, 0.2, 0.0)
	pad.add_child(visual)
	SharedVisualAssetCatalog.tint(visual, PlaceholderSpec.SPAWN_MARKER_ALBEDO)
