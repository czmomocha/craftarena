extends GutTest

## C4：按袋类型接上垫 / 门 / 终点 / 箱 / 滚柱视觉。
##
## 冻结期不给占位表现写死尺寸或 RGB 期望值。这里钉的是关系：
## 资产能实例化、贴合锚点对、占位盒 layers=0、进度色 / 危险色走 overlay、
## 解析失败回退、官方课占用半长不变。

const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const EPS: float = 0.0001
const COURSE_01: String = "res://content/official/traprush/course_01.json"
const OCCUPANCY_PATHS: PackedStringArray = [
	SharedVisualAssetCatalog.CHECKPOINT_PAD_SCENE_PATH,
	SharedVisualAssetCatalog.CHECKPOINT_GATE_SCENE_PATH,
	SharedVisualAssetCatalog.FINISH_GATE_SCENE_PATH,
	SharedVisualAssetCatalog.CRATE_SCENE_PATH,
	SharedVisualAssetCatalog.HAZARD_ROLLER_SCENE_PATH,
]
const PACKAGE_KEYS: PackedStringArray = [
	"checkpoint_pad_visual_loadable",
	"checkpoint_gate_visual_loadable",
	"finish_gate_visual_loadable",
	"crate_visual_loadable",
	"hazard_roller_visual_loadable",
]

var _course: MatchCourseMap = null
var _crates: MatchCrateMap = null
var _hazards: MatchHazardMap = null
var _preview: AuthoringPreviewMap = null


func before_each() -> void:
	_course = MatchCourseMap.new()
	add_child_autofree(_course)
	_crates = MatchCrateMap.new()
	add_child_autofree(_crates)
	_hazards = MatchHazardMap.new()
	add_child_autofree(_hazards)
	_preview = AuthoringPreviewMap.new()
	add_child_autofree(_preview)


# --- 入库 ---------------------------------------------------------------------


func test_occupancy_assets_live_under_platform_content_and_import() -> void:
	for path: String in OCCUPANCY_PATHS:
		assert_true(path.begins_with("res://content/assets/"), path)
		assert_true(path.ends_with(".glb"), path)
		assert_true(ResourceLoader.exists(path), "占用视觉不在包内：%s" % path)
		var visual: Node3D = SharedVisualAssetCatalog.try_instantiate(path)
		assert_not_null(visual, "实例化失败：%s" % path)
		if visual == null:
			continue
		assert_gt(_mesh_instances(visual).size(), 0, "没有网格：%s" % path)
		visual.free()


func test_checkpoint_instantiates_pad_and_gate_children() -> void:
	var root: Node3D = SharedVisualAssetCatalog.try_instantiate_checkpoint(
		SharedVisualAssetCatalog.CHECKPOINT_PAD_SCENE_PATH,
		SharedVisualAssetCatalog.CHECKPOINT_GATE_SCENE_PATH
	)
	assert_not_null(root)
	if root == null:
		return
	assert_not_null(root.get_node_or_null("pad"))
	assert_not_null(root.get_node_or_null("gate"))
	root.free()


# --- 贴合 ---------------------------------------------------------------------


func test_pad_uses_tile_fit_top_align() -> void:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_fitted_tile_from(
		SharedVisualAssetCatalog.CHECKPOINT_PAD_SCENE_PATH
	)
	assert_not_null(visual)
	if visual == null:
		return
	var fitted: AABB = _fitted_bounds(visual)
	assert_almost_eq(
		maxf(fitted.size.x, fitted.size.z),
		PlaceholderSpec.METERS_PER_CELL,
		EPS
	)
	assert_almost_eq(
		fitted.position.y + fitted.size.y,
		PlaceholderSpec.METERS_PER_CELL / 2.0,
		EPS,
		"垫的顶面应落在占位盒顶面"
	)
	visual.free()


func test_prop_uses_foot_align_on_box_bottom() -> void:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_fitted_prop(
		SharedVisualAssetCatalog.CRATE_SCENE_PATH
	)
	assert_not_null(visual)
	if visual == null:
		return
	var fitted: AABB = _fitted_bounds(visual)
	assert_almost_eq(
		maxf(fitted.size.x, fitted.size.z),
		PlaceholderSpec.METERS_PER_CELL,
		EPS
	)
	assert_almost_eq(
		fitted.position.y,
		-PlaceholderSpec.METERS_PER_CELL / 2.0,
		EPS,
		"站立物底面应落在占位盒底面"
	)
	assert_almost_eq(visual.scale.x, visual.scale.y, EPS)
	assert_almost_eq(visual.scale.y, visual.scale.z, EPS)
	visual.free()


# --- 对局映射 -----------------------------------------------------------------


func test_course_pads_and_finish_get_visuals_and_hide_placeholder() -> void:
	assert_true(_course.apply_path(COURSE_01))
	assert_gt(_course.visual_count(), 0)
	var pad: MeshInstance3D = _course.pad_node(1)
	assert_not_null(pad)
	if pad == null:
		return
	assert_not_null(_course.visual_node(1))
	assert_eq(pad.layers, 0)
	assert_eq((pad.mesh as BoxMesh).size, MatchCourseMap.PLACEHOLDER_SIZE)
	var finish: MeshInstance3D = _course.finish_node(30)
	assert_not_null(finish)
	if finish == null:
		return
	assert_not_null(finish.get_node_or_null(MatchCourseMap.VISUAL_NAME))
	assert_eq(finish.layers, 0)
	assert_null(_course.portal_node(10).get_node_or_null(MatchCourseMap.VISUAL_NAME))
	assert_eq(_course.portal_node(10).layers, 1)


func test_course_progress_overlay_follows_pad_albedo() -> void:
	assert_true(_course.apply_path(COURSE_01))
	_course.apply_own_progress(1)
	assert_eq(_box_albedo(_course.pad_node(1)), MatchCourseMap.ACCEPTED_ALBEDO)
	var overlay: Color = _overlay_albedo(_course.visual_node(1))
	assert_almost_eq(overlay.a, SharedVisualAssetCatalog.SEAT_TINT_ALPHA, 0.001)
	assert_almost_eq(overlay.r, MatchCourseMap.ACCEPTED_ALBEDO.r, 0.001)
	_course.apply_own_progress(1)
	assert_eq(_overlay_albedo(_course.visual_node(1)), overlay)


func test_finish_progress_overlay_follows_finish_albedo() -> void:
	assert_true(_course.apply_path(COURSE_01))
	_course.apply_own_progress(3, 1)
	assert_eq(_box_albedo(_course.finish_node(30)), MatchCourseMap.FINISH_ACCEPTED_ALBEDO)
	var overlay: Color = _overlay_albedo(_course.visual_node(30))
	assert_almost_eq(overlay.a, SharedVisualAssetCatalog.SEAT_TINT_ALPHA, 0.001)
	assert_almost_eq(overlay.r, MatchCourseMap.FINISH_ACCEPTED_ALBEDO.r, 0.001)


func test_course_falls_back_when_occupancy_paths_are_empty() -> void:
	_course.pad_scene_path = ""
	_course.gate_scene_path = ""
	_course.finish_scene_path = ""
	assert_true(_course.apply_path(COURSE_01))
	assert_eq(_course.visual_count(), 0)
	assert_null(_course.visual_node(1))
	assert_eq(_course.pad_node(1).layers, 1)
	assert_eq(_course.finish_node(30).layers, 1)


func test_crates_keep_orange_overlay_and_authoritative_boxes() -> void:
	assert_true(_crates.apply_path(COURSE_01))
	var crate: MeshInstance3D = _crates.crate_node(40)
	assert_not_null(crate)
	if crate == null:
		return
	assert_not_null(_crates.visual_node(40))
	assert_eq(crate.layers, 0)
	var overlay: Color = _overlay_albedo(_crates.visual_node(40))
	assert_almost_eq(overlay.r, PlaceholderSpec.CRATE_ALBEDO.r, 0.001)
	assert_eq(_crates.live_solid_boxes().size(), 1)
	var box: Dictionary = _crates.live_solid_boxes()[0]
	var half_x: int = box.get("hx", 0)
	assert_eq(half_x, PlaceholderSpec.CELL / 2)


func test_crate_nodes_are_reused_with_the_same_visual() -> void:
	assert_true(_crates.apply_path(COURSE_01))
	var first_crate: MeshInstance3D = _crates.crate_node(40)
	var first_visual: Node3D = _crates.visual_node(40)
	assert_true(_crates.apply_path(COURSE_01))
	assert_eq(_crates.crate_node(40), first_crate)
	assert_eq(_crates.visual_node(40), first_visual)


func test_crates_fall_back_without_an_asset() -> void:
	_crates.crate_scene_path = ""
	assert_true(_crates.apply_path(COURSE_01))
	assert_null(_crates.visual_node(40))
	assert_eq(_crates.crate_node(40).layers, 1)


func test_hazards_keep_magenta_overlay() -> void:
	assert_true(_hazards.apply_path(COURSE_01))
	var hazard: MeshInstance3D = _hazards.hazard_node(60)
	assert_not_null(hazard)
	if hazard == null:
		return
	assert_not_null(_hazards.visual_node(60))
	assert_eq(hazard.layers, 0)
	var overlay: Color = _overlay_albedo(_hazards.visual_node(60))
	assert_almost_eq(overlay.r, PlaceholderSpec.HAZARD_ALBEDO.r, 0.001)


func test_hazards_fall_back_without_an_asset() -> void:
	_hazards.hazard_scene_path = ""
	assert_true(_hazards.apply_path(COURSE_01))
	assert_null(_hazards.visual_node(60))
	assert_eq(_hazards.hazard_node(60).layers, 1)


# --- Preview ------------------------------------------------------------------


func test_preview_wires_occupancy_by_component() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_checkpoint(1, 0, 0, 0)))
	assert_true(world.put(_record_finish(2, 65536, 0, 0)))
	assert_true(world.put(_record_crate(3, 0, 0, 65536)))
	assert_true(world.put(_record_hazard(4, 0, 0, -65536)))
	_preview.rebuild(world)
	assert_not_null(_preview.placeholder_visual_node(1))
	assert_not_null(_preview.placeholder_visual_node(2))
	assert_not_null(_preview.placeholder_visual_node(3))
	assert_not_null(_preview.placeholder_visual_node(4))
	assert_eq(_preview.placeholder_node(1).layers, 0)
	assert_eq(_box_albedo(_preview.placeholder_node(1)), PlaceholderSpec.PAD_PENDING_ALBEDO)
	assert_eq(_box_albedo(_preview.placeholder_node(3)), PlaceholderSpec.CRATE_ALBEDO)
	assert_eq(_box_albedo(_preview.placeholder_node(4)), PlaceholderSpec.HAZARD_ALBEDO)


func test_preview_rebuilds_when_occupancy_path_changes() -> void:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_checkpoint(8, 0, 0, 0)))
	_preview.rebuild(world)
	assert_eq(_preview.rebuild_count(), 1)
	_preview.pad_scene_path = ""
	_preview.gate_scene_path = ""
	_preview.rebuild(world)
	assert_eq(_preview.rebuild_count(), 2)
	assert_null(_preview.placeholder_visual_node(8))
	assert_eq(_preview.placeholder_node(8).layers, 1)


# --- 包内自检 -----------------------------------------------------------------


func test_package_check_covers_occupancy_visuals() -> void:
	var report: Dictionary = PackageCheck.report()
	var checks: Dictionary = report["checks"]
	for key: String in PACKAGE_KEYS:
		assert_true(checks.has(key), "包内自检没查 %s" % key)
		var loadable: bool = checks.get(key, false)
		assert_true(loadable, "源码工程里 %s 就已经不成立" % key)
	var crate_path: String = report.get("crate_visual_path", "")
	assert_eq(crate_path, SharedVisualAssetCatalog.CRATE_SCENE_PATH)


# --- helpers ------------------------------------------------------------------


func _record_checkpoint(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {"order": 0, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
	})


func _record_finish(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": 32768, "hy": 32768, "hz": 32768},
			"tags": ["finish"],
		},
	})


func _record_crate(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"destructible": {"durability": 1, "regen_policy_id": 0},
	})


func _record_hazard(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": 1},
	})


func _fitted_bounds(visual: Node3D) -> AABB:
	return visual.transform * SharedVisualAssetCatalog.local_bounds(visual)


func _box_albedo(node: MeshInstance3D) -> Color:
	if node == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	var box: BoxMesh = node.mesh as BoxMesh
	if box == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	var material: StandardMaterial3D = box.material as StandardMaterial3D
	if material == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	return material.albedo_color


func _overlay_albedo(visual: Node3D) -> Color:
	if visual == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	for instance: MeshInstance3D in _mesh_instances(visual):
		var overlay: StandardMaterial3D = instance.material_overlay as StandardMaterial3D
		if overlay != null:
			return overlay.albedo_color
	return Color(0.0, 0.0, 0.0, 0.0)


func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var instance: MeshInstance3D = root as MeshInstance3D
	if instance != null:
		found.append(instance)
	for child: Node in root.get_children():
		found.append_array(_mesh_instances(child))
	return found
