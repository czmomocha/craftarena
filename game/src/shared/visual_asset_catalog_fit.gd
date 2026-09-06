class_name SharedVisualAssetFit
extends RefCounted

## Fit / bounds / seat-tint helpers for SharedVisualAssetCatalog.
## Public fit_* / tint / local_bounds stay on the catalog facade.

const SEAT_TINT_ALPHA: float = 0.42
const _MIN_EXTENT: float = 0.0001
## 角色贴合结果的落点。见 `fit_character_on_cell` 第 3 点。
const CHARACTER_BASE_META: String = "character_base_transform"


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


## 角色贴合。与 `fit_prop_on_cell` 同族（等比、水平居中、脚底对齐），三点不同：
##
## 1. 水平缩到 `CELL * CHARACTER_VISUAL_CELL_SPAN` 而不是整格——角色不是静物，
##    占满一格会贴边（理由见 spec 那条常量）；
## 2. 脚底对齐**权威胶囊底面**（`CHARACTER_CAPSULE_BOTTOM_M`）而不是 1 米占位盒
##    底面。盒比胶囊高，对齐盒底会让角色在重力落地后陷进固体顶面；
## 3. 结果同时写进 `visual.transform` **与** `CHARACTER_BASE_META`。第二处是给
##    `PlayAnimVisual` 读的：姿态态要在这个基准上叠加俯仰，而基准现在含 scale，
##    没法再由一个常量重建。两边读同一份，否则姿态会把缩放抹掉、角色一跳变大。
static func fit_character_on_cell(visual: Node3D) -> bool:
	if visual == null:
		return false
	var bounds: AABB = local_bounds(visual)
	var widest: float = maxf(bounds.size.x, bounds.size.z)
	if widest < _MIN_EXTENT:
		return false
	var span: float = PlaceholderSpec.METERS_PER_CELL * PlaceholderSpec.CHARACTER_VISUAL_CELL_SPAN
	var factor: float = span / widest
	var scaled: AABB = AABB(bounds.position * factor, bounds.size * factor)
	var base: Transform3D = Transform3D(
		Basis().scaled(Vector3(factor, factor, factor)),
		Vector3(
			-(scaled.position.x + scaled.size.x / 2.0),
			-PlaceholderSpec.CHARACTER_CAPSULE_BOTTOM_M - scaled.position.y,
			-(scaled.position.z + scaled.size.z / 2.0)
		)
	)
	visual.transform = base
	visual.set_meta(CHARACTER_BASE_META, base)
	return true


## 角色 visual 的基准 transform。贴合过就读回贴合结果，没贴合过（旧路径、
## 测试里的裸 Node3D）回落到"不缩放 + 脚底抬到胶囊底面"的老基准。
## `PlayAnimVisual` 与 attach 都经这里取基准，保证两者同源。
static func character_base_transform(visual: Node3D) -> Transform3D:
	if visual != null and visual.has_meta(CHARACTER_BASE_META):
		var stored: Variant = visual.get_meta(CHARACTER_BASE_META)
		if typeof(stored) == TYPE_TRANSFORM3D:
			return stored
	return Transform3D(
		Basis(),
		Vector3(0.0, -PlaceholderSpec.CHARACTER_CAPSULE_BOTTOM_M, 0.0)
	)


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
