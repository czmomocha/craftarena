extends GutTest

## C4 第 5 章：第一个 `.glb` 入库 + 视觉资产解析链路（纠偏 §3 C4 产出 5、E7 后半）。
##
## 这里断言的是**分离已经数值成立**，不是模型好不好看。ADR-0006 §7 此前只能说
## "结构已分离、数值仍相等"，因为唯一内置资产就是占满一格、D4 又定 1 格 = 1 米。
## 现在角色视觉是一个 1.03 m 高、0.74 × 0.61 m 粗的网格，而权威胶囊仍是
## 0.125 格、占位盒仍是 1 米——三者互不相等。
##
## 冻结期不给占位表现新增强断言（.cursor/rules/chapter-granularity-and-review.mdc
## §3），所以下面没有一句写死 RGB 或模型尺寸的期望值；写死的是**关系**：视觉
## 尺寸不等于权威尺寸、占位盒色值没变、解析失败必须回退。

const CharacterAabb := "视觉网格的 AABB"

var _map: MatchSnapshotMap = null
var _preview: AuthoringPreviewMap = null


func before_each() -> void:
	_map = MatchSnapshotMap.new()
	add_child_autofree(_map)
	_preview = AuthoringPreviewMap.new()
	add_child_autofree(_preview)


# --- 资产入库本身 -------------------------------------------------------------


func test_character_asset_is_in_the_repository_and_imports() -> void:
	assert_true(
		SharedVisualAssetCatalog.has_character(),
		"角色视觉资产不在包内。跑 README 的「Headless 导入检查」再试"
	)
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_character()
	assert_not_null(visual, "角色视觉资产存在但实例化不出 Node3D")
	if visual == null:
		return
	assert_gt(_mesh_instances(visual).size(), 0, "视觉资产里没有任何网格")
	visual.free()


func test_asset_path_lives_under_platform_content() -> void:
	# CD-51 §5.1：平台资产放 game/content/，格式 .glb。
	assert_true(SharedVisualAssetCatalog.CHARACTER_SCENE_PATH.begins_with("res://content/"))
	assert_true(SharedVisualAssetCatalog.CHARACTER_SCENE_PATH.ends_with(".glb"))


# --- 视觉与权威碰撞在数值上真的分开了 ----------------------------------------


func test_visual_mesh_differs_from_authoritative_capsule_and_placeholder_box() -> void:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_character()
	assert_not_null(visual)
	if visual == null:
		return
	var bounds: AABB = _visual_bounds(visual)
	visual.free()
	assert_gt(bounds.size.y, 0.0, CharacterAabb)

	# 权威胶囊（Q48.16 → 米）与视觉高度必须不同：一个是裁决用的，一个是看的。
	var capsule_height_m: float = float(PlaceholderSpec.CHARACTER_HEIGHT) / float(Fixed.SCALE)
	assert_ne(bounds.size.y, capsule_height_m, "视觉高度恰好等于权威胶囊高，分离没有生效")

	# 也不等于它替换掉的那个 1 米占位盒。
	assert_ne(bounds.size.y, PlaceholderSpec.BOX_SIZE.y, "视觉高度恰好等于占位盒")
	assert_ne(bounds.size.x, PlaceholderSpec.BOX_SIZE.x, "视觉宽度恰好等于占位盒")


func test_visual_asset_does_not_enter_the_gameplay_asset_catalog() -> void:
	# ADR-0006 Q4：视觉不进 bundle、也不进 GameplayAsset 目录，所以换模型不产生
	# 新内容版本。这条守的是"有人日后把视觉塞进权威目录"。
	var collision: Dictionary = SharedGameplayAssetCatalog.try_collision(
		SharedGameplayAssetCatalog.LATTICE_CELL_ID,
		SharedGameplayAssetCatalog.LATTICE_CELL_VERSION,
		PlaceholderSpec.CELL
	)
	assert_false(collision.is_empty(), "内置资产取不到碰撞")
	assert_false(collision.has("visual"), "权威碰撞袋里出现了视觉字段")
	assert_false(collision.has("mesh"), "权威碰撞袋里出现了网格字段")
	var entry: Dictionary = SharedGameplayAssetCatalog.try_entry(
		SharedGameplayAssetCatalog.LATTICE_CELL_ID,
		SharedGameplayAssetCatalog.LATTICE_CELL_VERSION,
		PlaceholderSpec.CELL
	)
	assert_eq(
		entry.keys().size(),
		4,
		"assets 袋的键数变了。视觉不该进 bundle（ADR-0006 Q4）"
	)


# --- 对局映射：接上视觉，但既有可读性一条不丢 --------------------------------


func test_match_player_gets_a_visual_child_and_hides_the_placeholder_mesh() -> void:
	_map.follow_slot = 0
	assert_true(_map.apply_players([_player_body(), _player_body()]))
	assert_eq(_map.visual_count(), 2, "两个席位都该拿到视觉")
	for slot: int in [0, 1]:
		var player: MeshInstance3D = _map.player_node(slot)
		assert_not_null(player)
		if player == null:
			continue
		assert_not_null(_map.visual_node(slot), "席位 %d 没有 visual 子节点" % slot)
		assert_eq(player.layers, 0, "占位盒本体应退出渲染层")
		# 网格与座位色材质必须原样留着：名次、朝向与预测都还读这个节点。
		assert_not_null(player.mesh, "占位盒的网格被删了")
		assert_eq((player.mesh as BoxMesh).size, MatchSnapshotMap.PLACEHOLDER_SIZE)
		assert_not_null(_map.facing_node(slot), "朝向标记丢了")


func test_match_player_keeps_own_and_remote_seat_colours() -> void:
	_map.follow_slot = 1
	assert_true(_map.apply_players([_player_body(), _player_body()]))
	assert_eq(_seat_albedo(_map.player_node(0)), MatchSnapshotMap.REMOTE_ALBEDO)
	assert_eq(_seat_albedo(_map.player_node(1)), MatchSnapshotMap.OWN_ALBEDO)


func test_visual_carries_the_seat_colour_as_an_overlay() -> void:
	# 模型自带灰白外壳，本席/远端如果只靠模型就分不出来。薄膜是叠加的，
	# 不改模型自己的材质，所以两个席位可以共用同一份导入资源。
	_map.follow_slot = 0
	assert_true(_map.apply_players([_player_body(), _player_body()]))
	var own: Color = _overlay_albedo(_map.visual_node(0))
	var remote: Color = _overlay_albedo(_map.visual_node(1))
	assert_ne(own, remote, "两个席位的视觉薄膜同色，分色没生效")
	assert_almost_eq(own.a, SharedVisualAssetCatalog.SEAT_TINT_ALPHA, 0.001)
	assert_almost_eq(own.r, MatchSnapshotMap.OWN_ALBEDO.r, 0.001)
	assert_almost_eq(remote.r, MatchSnapshotMap.REMOTE_ALBEDO.r, 0.001)


func test_match_player_falls_back_to_the_placeholder_box_without_an_asset() -> void:
	_map.character_scene_path = ""
	assert_true(_map.apply_players([_player_body()]))
	assert_eq(_map.visual_count(), 0)
	assert_null(_map.visual_node(0))
	var player: MeshInstance3D = _map.player_node(0)
	assert_not_null(player)
	if player == null:
		return
	assert_eq(player.layers, 1, "没有视觉时占位盒必须自己可见")
	assert_eq(_seat_albedo(player), MatchSnapshotMap.OWN_ALBEDO if _map.follow_slot == 0 else MatchSnapshotMap.REMOTE_ALBEDO)


func test_match_player_falls_back_when_the_path_is_not_a_scene() -> void:
	_map.character_scene_path = "res://content/official/traprush/course_01.json"
	assert_true(_map.apply_players([_player_body()]))
	assert_eq(_map.visual_count(), 0, "非场景资源不该被当成视觉挂上去")
	assert_eq(_map.player_node(0).layers, 1)


func test_visual_count_resets_between_snapshots() -> void:
	assert_true(_map.apply_players([_player_body(), _player_body()]))
	assert_eq(_map.visual_count(), 2)
	assert_true(_map.apply_players([_player_body()]))
	assert_eq(_map.visual_count(), 1, "重建后视觉计数没跟着收回")


# --- Preview 与对局读同一份 --------------------------------------------------


func test_preview_player_marker_uses_the_same_asset_as_the_match() -> void:
	assert_eq(_preview.character_scene_path, _map.character_scene_path)
	_preview.show_player_pose({"x": 0, "y": 0, "z": 0})
	var marker: MeshInstance3D = _preview.player_node()
	assert_not_null(marker)
	if marker == null:
		return
	assert_not_null(_preview.player_visual_node(), "Preview 玩家标记没有 visual 子节点")
	assert_eq(marker.layers, 0)
	assert_eq((marker.mesh as BoxMesh).size, AuthoringPreviewMap.PLACEHOLDER_SIZE)


func test_preview_player_marker_falls_back_to_the_placeholder_box() -> void:
	_preview.character_scene_path = ""
	_preview.show_player_pose({"x": 0, "y": 0, "z": 0})
	var marker: MeshInstance3D = _preview.player_node()
	assert_not_null(marker)
	if marker == null:
		return
	assert_null(_preview.player_visual_node())
	assert_eq(marker.layers, 1)


func test_preview_entity_placeholders_stay_boxes() -> void:
	# 实体占位盒**有意**不接视觉：一期唯一内置资产被 7 类袋共用，接上去会把
	# 路面地板也变成同一个模型。理由见 SharedVisualAssetCatalog 文件头。
	var world: AuthoringWorld = AuthoringWorld.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(7, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
	})
	assert_true(world.put(record))
	_preview.rebuild(world)
	var placeholder: MeshInstance3D = _preview.placeholder_node(7)
	assert_not_null(placeholder)
	if placeholder == null:
		return
	assert_eq(placeholder.layers, 1)
	assert_eq(placeholder.get_child_count(), 0, "实体占位盒不该长出视觉子节点")


# --- 包内自检覆盖到它 --------------------------------------------------------


func test_package_check_covers_the_character_visual() -> void:
	var report: Dictionary = PackageCheck.report()
	var checks: Dictionary = report["checks"]
	assert_true(checks.has("character_visual_loadable"), "包内自检没查视觉资产")
	var loadable: bool = checks.get("character_visual_loadable", false)
	assert_true(loadable, "源码工程里视觉资产就已经加载不出来")
	var reported_path: String = report.get("character_visual_path", "")
	assert_eq(reported_path, SharedVisualAssetCatalog.CHARACTER_SCENE_PATH)


# --- helpers -----------------------------------------------------------------


func _player_body() -> Dictionary:
	return {"x": 0, "y": 0, "z": 0, "yaw_bam": 0}


func _seat_albedo(node: MeshInstance3D) -> Color:
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


func _visual_bounds(root: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var first: bool = true
	for instance: MeshInstance3D in _mesh_instances(root):
		var box: AABB = instance.get_aabb()
		if first:
			bounds = box
			first = false
			continue
		bounds = bounds.merge(box)
	return bounds
