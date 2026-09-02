class_name SharedVisualAssetFit
extends RefCounted

## Fit / bounds / seat-tint helpers for SharedVisualAssetCatalog.
## Public fit_* / tint / local_bounds stay on the catalog facade.

const SEAT_TINT_ALPHA: float = 0.42
const _MIN_EXTENT: float = 0.0001


static func tint(root: Node, color: Color) -> int:
	if root == null:
		return 0
	var overlay: StandardMaterial3D = seat_tint(color)
	return _apply_overlay(root, overlay)


static func seat_tint(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, SEAT_TINT_ALPHA)
	return material


static func fit_tile_on_cell(visual: Node3D) -> bool:
	if visual == null:
		return false
	var bounds: AABB = local_bounds(visual)
	var widest: float = maxf(bounds.size.x, bounds.size.z)
	if widest < _MIN_EXTENT:
		return false
	var factor: float = PlaceholderSpec.METERS_PER_CELL / widest
	visual.scale = Vector3(factor, factor, factor)
	var scaled: AABB = AABB(bounds.position * factor, bounds.size * factor)
	var top: float = scaled.position.y + scaled.size.y
	var centre_x: float = scaled.position.x + scaled.size.x / 2.0
	var centre_z: float = scaled.position.z + scaled.size.z / 2.0
	visual.position = Vector3(
		-centre_x,
		PlaceholderSpec.METERS_PER_CELL / 2.0 - top,
		-centre_z
	)
	return true


static func fit_prop_on_cell(visual: Node3D) -> bool:
	if visual == null:
		return false
	var bounds: AABB = local_bounds(visual)
	var widest: float = maxf(bounds.size.x, bounds.size.z)
	if widest < _MIN_EXTENT:
		return false
	var factor: float = PlaceholderSpec.METERS_PER_CELL / widest
	visual.scale = Vector3(factor, factor, factor)
	var scaled: AABB = AABB(bounds.position * factor, bounds.size * factor)
	var centre_x: float = scaled.position.x + scaled.size.x / 2.0
	var centre_z: float = scaled.position.z + scaled.size.z / 2.0
	visual.position = Vector3(
		-centre_x,
		-PlaceholderSpec.METERS_PER_CELL / 2.0 - scaled.position.y,
		-centre_z
	)
	return true


static func local_bounds(root: Node3D) -> AABB:
	if root == null:
		return AABB()
	return _bounds(root, Transform3D.IDENTITY, true)


static func _bounds(node: Node, accumulated: Transform3D, is_root: bool) -> AABB:
	var here: Transform3D = accumulated
	var spatial: Node3D = node as Node3D
	if spatial != null and not is_root:
		here = accumulated * spatial.transform
	var result: AABB = AABB()
	var seen: bool = false
	var instance: MeshInstance3D = node as MeshInstance3D
	if instance != null and instance.mesh != null:
		result = here * instance.get_aabb()
		seen = true
	for child: Node in node.get_children():
		var child_bounds: AABB = _bounds(child, here, false)
		if child_bounds.size == Vector3.ZERO:
			continue
		if not seen:
			result = child_bounds
			seen = true
			continue
		result = result.merge(child_bounds)
	return result


static func _apply_overlay(node: Node, overlay: StandardMaterial3D) -> int:
	var count: int = 0
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		geometry.material_overlay = overlay
		count += 1
	for child: Node in node.get_children():
		count += _apply_overlay(child, overlay)
	return count
