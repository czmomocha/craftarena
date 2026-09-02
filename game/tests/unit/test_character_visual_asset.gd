extends GutTest

## C4 第 5 章：第一批 `.glb` 入库 + 视觉资产解析链路（纠偏 §3 C4 产出 5、E7 后半）。
## C4 第 6 章追加末节三条：席位节点每帧复用（见「每帧预算」小节）。
##
## 覆盖两个资产：角色（玩家节点）与地块（`solids` 袋 / `zone.tags` 含 solid）。
##
## 这里断言的是**分离已经数值成立**，不是模型好不好看。ADR-0006 §7 此前只能说
## "结构已分离、数值仍相等"，因为唯一内置资产就是占满一格、D4 又定 1 格 = 1 米。
## 现在角色视觉是一个 1.134 m 高的网格、地块是等比缩到一格宽的薄板，而权威胶囊
## 仍是 0.125 格、占位盒仍是 1 米。（角色模型 2026-09-01 换过一次：
## `robot_placeholder.glb` 1.03 m → `char_runner_base.glb` 1.134 m，下面一条
## 断言都没动 —— 它们断言的是关系，不是具体尺寸。）
##
## 冻结期不给占位表现新增强断言（.cursor/rules/chapter-granularity-and-review.mdc
## §3），所以下面没有一句写死 RGB 或模型尺寸的期望值；写死的是**关系**：视觉
## 尺寸不等于权威尺寸、占位盒色值没变、解析失败必须回退、地块缩放由 AABB 推出。

const CharacterAabb := "视觉网格的 AABB"
const EPS: float = 0.0001

var _map: MatchSnapshotMap = null
var _preview: AuthoringPreviewMap = null
var _solids: MatchSolidMap = null


func before_each() -> void:
	_map = MatchSnapshotMap.new()
	add_child_autofree(_map)
	_preview = AuthoringPreviewMap.new()
	add_child_autofree(_preview)
	_solids = MatchSolidMap.new()
	add_child_autofree(_solids)


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
	# CD-51 §5.1：平台资产放 game/content/assets/，格式 .glb。
	for path: String in [
		SharedVisualAssetCatalog.CHARACTER_SCENE_PATH,
		SharedVisualAssetCatalog.TERRAIN_TILE_SCENE_PATH,
	]:
		assert_true(path.begins_with("res://content/assets/"), path)
		assert_true(path.ends_with(".glb"), path)


func test_terrain_tile_asset_is_in_the_repository_and_imports() -> void:
	assert_true(
		SharedVisualAssetCatalog.has_terrain_tile(),
		"地块视觉资产不在包内。跑 README 的「Headless 导入检查」再试"
	)
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_terrain_tile()
	assert_not_null(visual, "地块视觉资产存在但实例化不出 Node3D")
	if visual == null:
		return
	assert_gt(_mesh_instances(visual).size(), 0, "地块资产里没有任何网格")
	visual.free()


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


# --- 脚底对齐胶囊底面，不是 1 米占位盒底 --------------------------------------


func test_character_foot_lift_is_the_capsule_bottom_not_the_box_bottom() -> void:
	assert_almost_eq(
		SharedVisualAssetCatalog.CHARACTER_FOOT_LIFT.y,
		-PlaceholderSpec.CHARACTER_CAPSULE_BOTTOM_M,
		EPS,
		"脚底应对齐胶囊底面"
	)
	assert_ne(
		SharedVisualAssetCatalog.CHARACTER_FOOT_LIFT.y,
		-PlaceholderSpec.METERS_PER_CELL / 2.0,
		"还在沉到 1 米盒底，重力落地后会陷入固体"
	)


func test_match_and_preview_plant_the_visual_on_the_capsule_bottom() -> void:
	assert_true(_map.apply_players([_player_body()]))
	var match_visual: Node3D = _map.visual_node(0)
	assert_not_null(match_visual)
	if match_visual != null:
		assert_almost_eq(
			match_visual.position.y,
			SharedVisualAssetCatalog.CHARACTER_FOOT_LIFT.y,
			EPS
		)
	_preview.show_player_pose({"x": 0, "y": 0, "z": 0})
	var preview_visual: Node3D = _preview.player_visual_node()
	assert_not_null(preview_visual)
	if preview_visual != null:
		assert_almost_eq(
			preview_visual.position.y,
			SharedVisualAssetCatalog.CHARACTER_FOOT_LIFT.y,
			EPS
		)


func test_settled_pose_puts_visual_feet_on_the_solid_top() -> void:
	# 官方课立足固体在出生点正下一格：中心 -1 格、半长半格 ⇒ 顶面 -0.5 m。
	# 落地后胶囊中心 = 顶面 + 底面偏移。脚底世界 Y 必须等于顶面。
	var solid_center: int = -PlaceholderSpec.CELL
	var solid_half: int = PlaceholderSpec.CELL / 2
	var solid_top: int = solid_center + solid_half
	var bottom: int = PlaceholderSpec.CHARACTER_HEIGHT / 2 + PlaceholderSpec.CHARACTER_RADIUS
	var pose_y: int = solid_top + bottom
	var body: Dictionary = _player_body()
	body["y"] = pose_y
	assert_true(_map.apply_players([body]))
	var player: MeshInstance3D = _map.player_node(0)
	var visual: Node3D = _map.visual_node(0)
	assert_not_null(player)
	assert_not_null(visual)
	if player == null or visual == null:
		return
	var foot_world_y: float = player.position.y + visual.position.y
	var solid_top_m: float = float(solid_top) / float(PlaceholderSpec.CELL)
	assert_almost_eq(
		foot_world_y,
		solid_top_m,
		EPS,
		"落地后脚底应与固体顶面齐平"
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


# --- 每帧预算：席位节点必须被复用，不是每帧重新 instantiate -------------------


## `MatchLobbyShell._process` 每帧调一次 `apply_players`。这条断言钉住的是
## **同一个实例被留下来了**，而不是"结果看起来一样"。
##
## 为什么要断言身份而不是耗时：耗时断言在 CI 上不稳，且 [CD-53 §1.1] 不建自动
## 性能门禁。但"节点是不是同一个对象"是确定性的，而它恰好等价于"这一帧有没有
## 重新 `PackedScene.instantiate()` 一个 3000 三角面的角色"。
## 开发机实测：全清全建 2 席 12.76 ms/帧，复用 0.015 ms/帧。
func test_apply_players_reuses_seat_nodes_across_frames() -> void:
	assert_true(_map.apply_players([_player_body(), _player_body()]))
	var first_seat: MeshInstance3D = _map.player_node(0)
	var first_visual: Node3D = _map.visual_node(0)
	var first_face: MeshInstance3D = _map.facing_node(0)
	assert_not_null(first_visual)
	# 连续 5 帧同样的快照
	for _frame: int in 5:
		assert_true(_map.apply_players([_player_body(), _player_body()]))
	assert_same(_map.player_node(0), first_seat, "席位节点被重建了")
	assert_same(_map.visual_node(0), first_visual, "角色视觉实例被重建了")
	assert_same(_map.facing_node(0), first_face, "朝向标记被重建了")
	assert_eq(_map.visual_count(), 2, "复用不该让视觉计数漂移")
	assert_eq(_map.player_count(), 2)


## 复用不能让位姿或座位色变成过期值——那会让"省了开销"变成"画错了"。
func test_reused_seat_node_still_tracks_pose_and_seat_colour() -> void:
	_map.follow_slot = 0
	assert_true(_map.apply_players([_player_body(), _player_body()]))
	var seat: MeshInstance3D = _map.player_node(1)
	assert_eq(_seat_albedo(seat), MatchSnapshotMap.REMOTE_ALBEDO)
	# 第 1 席动了，并且镜头改跟第 1 席
	_map.follow_slot = 1
	var moved: Dictionary = _player_body()
	moved["x"] = 3 * Fixed.SCALE
	moved["yaw_bam"] = Fixed.BAM_TURN / 4
	assert_true(_map.apply_players([_player_body(), moved]))
	assert_same(_map.player_node(1), seat, "这条测的是复用路径，节点不该换")
	assert_almost_eq(seat.position.x, 3.0, 0.0001, "复用节点没跟上新位置")
	assert_almost_eq(seat.rotation.y, TAU / 4.0, 0.0001, "复用节点没跟上新朝向")
	assert_eq(_seat_albedo(seat), MatchSnapshotMap.OWN_ALBEDO, "follow_slot 变了但座位色没改")
	assert_almost_eq(
		_overlay_albedo(_map.visual_node(1)).r,
		MatchSnapshotMap.OWN_ALBEDO.r,
		0.001,
		"视觉薄膜没跟着座位色改"
	)


## 席位数变化才增删。变少要真的删掉尾部，否则上一场的人会留在场上。
func test_seat_count_changes_add_and_remove_nodes() -> void:
	assert_true(_map.apply_players([_player_body(), _player_body(), _player_body()]))
	assert_eq(_map.player_count(), 3)
	var kept: MeshInstance3D = _map.player_node(0)
	assert_true(_map.apply_players([_player_body()]))
	assert_eq(_map.player_count(), 1)
	assert_same(_map.player_node(0), kept, "缩到 1 席时第 0 席不该被牵连重建")
	assert_null(_map.player_node(1), "第 1 席没被删掉")
	assert_null(_map.player_node(2), "第 2 席没被删掉")
	assert_eq(_map.visual_count(), 1, "删席位时视觉计数没跟着减")
	assert_true(_map.apply_players([]))
	assert_eq(_map.player_count(), 0)
	assert_eq(_map.visual_count(), 0)
	assert_null(_map.player_node(0))


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


func test_preview_wires_known_kinds_and_plain_stays_a_box() -> void:
	# 按**袋类型**接线：solid 铺地块（不 overlay），机关与箱子挂占用视觉并
	# 保留 D4 危险色 overlay，没有组件的实体仍是占位盒。
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_solid(11)))
	assert_true(world.put(_record_hazard(12)))
	assert_true(world.put(_record_crate(13)))
	assert_true(world.put(_record_plain(14)))
	_preview.rebuild(world)

	var solid: MeshInstance3D = _preview.placeholder_node(11)
	assert_not_null(solid)
	if solid != null:
		assert_not_null(_preview.placeholder_visual_node(11), "solid 没铺上地块")
		assert_eq(solid.layers, 0, "铺了地块的固体，占位盒本体应退出渲染层")
		assert_eq((solid.mesh as BoxMesh).size, AuthoringPreviewMap.PLACEHOLDER_SIZE)

	for entity_id: int in [12, 13]:
		var occupied: MeshInstance3D = _preview.placeholder_node(entity_id)
		assert_not_null(occupied, "entity %d 没画出来" % entity_id)
		if occupied == null:
			continue
		assert_not_null(
			_preview.placeholder_visual_node(entity_id),
			"entity %d 应挂占用视觉" % entity_id
		)
		assert_eq(occupied.layers, 0, "entity %d 的占位盒应退出渲染层" % entity_id)

	var plain: MeshInstance3D = _preview.placeholder_node(14)
	assert_not_null(plain)
	if plain != null:
		assert_null(_preview.placeholder_visual_node(14), "无组件实体不该挂占用视觉")
		assert_eq(plain.layers, 1, "无组件实体的占位盒必须自己可见")


func test_preview_solid_falls_back_to_the_placeholder_box() -> void:
	_preview.tile_scene_path = ""
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_record_solid(11)))
	_preview.rebuild(world)
	var solid: MeshInstance3D = _preview.placeholder_node(11)
	assert_not_null(solid)
	if solid == null:
		return
	assert_null(_preview.placeholder_visual_node(11))
	assert_eq(solid.layers, 1)
	assert_eq(_seat_albedo(solid), AuthoringPreviewMap.SOLID_ALBEDO)


# --- 地块贴合：缩放由 AABB 推出，不是写死的 -----------------------------------


func test_tile_is_scaled_from_its_own_aabb_to_exactly_one_cell() -> void:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_terrain_tile()
	assert_not_null(visual)
	if visual == null:
		return
	var raw: AABB = SharedVisualAssetCatalog.local_bounds(visual)
	# 前提：样本本身不能已经是一格宽，否则缩放系数为 1，这条用例什么也没验证。
	# 两个方向都成立：比一格宽的是**缩小**（floor_tile 1.84 m，
	# 贴合实测 0.5427），比一格窄的是**放大**（block_static 0.768 m，
	# 贴合实测 1.3017）。原先只断言了前者，换了资产才发现后者从未被覆盖。
	var raw_widest: float = maxf(raw.size.x, raw.size.z)
	assert_ne(
		raw_widest,
		PlaceholderSpec.METERS_PER_CELL,
		"样本本来就恰好一格宽，贴合逻辑没被这条用例覆盖"
	)
	assert_true(SharedVisualAssetCatalog.fit_tile_on_cell(visual))
	var fitted: AABB = _fitted_bounds(visual)
	assert_almost_eq(
		maxf(fitted.size.x, fitted.size.z),
		PlaceholderSpec.METERS_PER_CELL,
		EPS,
		"水平最长边应恰好一格"
	)
	# 等比：厚度按同一个系数走，所以宽高比贴合前后不变。只压 x/z 会把板厚留在
	# 原尺寸、砖面比例被压扁——那正是这条规则要避免的。
	var fitted_widest: float = maxf(fitted.size.x, fitted.size.z)
	assert_almost_eq(
		raw.size.y / raw_widest,
		fitted.size.y / fitted_widest,
		EPS,
		"贴合必须等比，厚薄关系要保住"
	)
	# 等比：三轴同一个系数，模型自己的厚薄比例不被压扁。
	assert_almost_eq(visual.scale.x, visual.scale.y, EPS)
	assert_almost_eq(visual.scale.y, visual.scale.z, EPS)
	visual.free()


func test_tile_top_face_lands_on_the_placeholder_box_top() -> void:
	# 踩得到的那个平面。对齐占位盒而不是权威 AABB：视觉不读裁决数据（Q4 = A）。
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_fitted_tile()
	assert_not_null(visual)
	if visual == null:
		return
	var fitted: AABB = _fitted_bounds(visual)
	assert_almost_eq(
		fitted.position.y + fitted.size.y,
		PlaceholderSpec.METERS_PER_CELL / 2.0,
		EPS,
		"顶面没落在占位盒顶面，踩上去会浮空或半埋"
	)
	# 水平居中，否则铺成一条路会整体偏移半格。
	assert_almost_eq(fitted.position.x + fitted.size.x / 2.0, 0.0, EPS)
	assert_almost_eq(fitted.position.z + fitted.size.z / 2.0, 0.0, EPS)
	visual.free()


func test_fit_refuses_a_degenerate_visual() -> void:
	# 没有网格 ⇒ AABB 为零 ⇒ 算不出缩放。放弃贴合，而不是除以 0。
	var empty: Node3D = Node3D.new()
	assert_false(SharedVisualAssetCatalog.fit_tile_on_cell(empty))
	assert_eq(SharedVisualAssetCatalog.local_bounds(empty).size, Vector3.ZERO)
	empty.free()
	assert_false(SharedVisualAssetCatalog.fit_tile_on_cell(null))


func test_local_bounds_accounts_for_child_transforms() -> void:
	# 今天两个资产都是「根下一个单位变换的 Mesh」，下一个未必是。
	var root: Node3D = Node3D.new()
	var child: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	child.mesh = box
	child.position = Vector3(10.0, 0.0, 0.0)
	root.add_child(child)
	var bounds: AABB = SharedVisualAssetCatalog.local_bounds(root)
	assert_almost_eq(bounds.position.x, 9.0, EPS, "子节点位移没算进 AABB")
	assert_almost_eq(bounds.size.x, 2.0, EPS)
	root.free()


# --- 对局固体映射 ------------------------------------------------------------


func test_match_solids_get_tiles_and_keep_authoritative_half_extents() -> void:
	assert_true(_solids.apply_path(OfficialTraprushCourses.document_path(
		OfficialTraprushCourses.COURSE_01
	)))
	assert_gt(_solids.solid_total(), 0, "course_01 应该有始终固体")
	assert_eq(_solids.visual_count(), _solids.solid_total(), "每个固体都该铺上地块")
	# 权威半长与视觉无关：本席预测读的还是编译拓扑那一份。
	var boxes: Array = _solids.live_solid_boxes()
	assert_eq(boxes.size(), _solids.solid_total())
	for raw: Variant in boxes:
		var box: Dictionary = raw
		var half_x: int = box.get("hx", 0)
		var half_y: int = box.get("hy", 0)
		var half_z: int = box.get("hz", 0)
		assert_eq(half_x, PlaceholderSpec.CELL / 2)
		assert_eq(half_y, PlaceholderSpec.CELL / 2)
		assert_eq(half_z, PlaceholderSpec.CELL / 2)


func test_match_solid_keeps_its_placeholder_mesh_and_colour() -> void:
	assert_true(_solids.apply_path(OfficialTraprushCourses.document_path(
		OfficialTraprushCourses.COURSE_01
	)))
	var entity_id: int = _first_solid_entity_id()
	assert_gt(entity_id, 0)
	var node: MeshInstance3D = _solids.solid_node(entity_id)
	assert_not_null(node)
	if node == null:
		return
	assert_not_null(_solids.visual_node(entity_id))
	assert_eq(node.layers, 0)
	assert_eq((node.mesh as BoxMesh).size, MatchSolidMap.PLACEHOLDER_SIZE)
	assert_eq(_seat_albedo(node), MatchSolidMap.SOLID_ALBEDO)


func test_match_solids_fall_back_to_placeholder_boxes() -> void:
	_solids.tile_scene_path = ""
	assert_true(_solids.apply_path(OfficialTraprushCourses.document_path(
		OfficialTraprushCourses.COURSE_01
	)))
	assert_eq(_solids.visual_count(), 0)
	var entity_id: int = _first_solid_entity_id()
	assert_gt(entity_id, 0)
	assert_null(_solids.visual_node(entity_id))
	assert_eq(_solids.solid_node(entity_id).layers, 1)


func test_match_solid_visual_count_resets_on_rebuild() -> void:
	var path: String = OfficialTraprushCourses.document_path(
		OfficialTraprushCourses.COURSE_01
	)
	assert_true(_solids.apply_path(path))
	var first: int = _solids.visual_count()
	assert_gt(first, 0)
	assert_true(_solids.apply_path(path))
	assert_eq(_solids.visual_count(), first, "重建后视觉计数应重算而不是累加")


# --- 包内自检覆盖到它 --------------------------------------------------------


func test_package_check_covers_both_visual_assets() -> void:
	var report: Dictionary = PackageCheck.report()
	var checks: Dictionary = report["checks"]
	for key: String in ["character_visual_loadable", "terrain_tile_visual_loadable"]:
		assert_true(checks.has(key), "包内自检没查 %s" % key)
		var loadable: bool = checks.get(key, false)
		assert_true(loadable, "源码工程里 %s 就已经不成立" % key)
	var character_path: String = report.get("character_visual_path", "")
	assert_eq(character_path, SharedVisualAssetCatalog.CHARACTER_SCENE_PATH)
	var tile_path: String = report.get("terrain_tile_visual_path", "")
	assert_eq(tile_path, SharedVisualAssetCatalog.TERRAIN_TILE_SCENE_PATH)


# --- helpers -----------------------------------------------------------------


func _player_body() -> Dictionary:
	return {"x": 0, "y": 0, "z": 0, "yaw_bam": 0}


func _record_plain(entity_id: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
	})


func _record_solid(entity_id: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": 32768, "hy": 32768, "hz": 32768},
			"tags": ["solid"],
		},
	})


func _record_hazard(entity_id: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": 1},
	})


func _record_crate(entity_id: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": 0, "y": 0, "z": 0, "yaw_bam": 0},
		"destructible": {"durability": 1, "regen_policy_id": 0},
	})


## 贴合把缩放写在节点上，所以要把节点 transform 也算进去才是"最终看到的大小"。
func _fitted_bounds(visual: Node3D) -> AABB:
	return visual.transform * SharedVisualAssetCatalog.local_bounds(visual)


func _first_solid_entity_id() -> int:
	for child: Node in _solids.get_children():
		var name_text: String = str(child.name)
		if not name_text.begins_with(MatchSolidMap.SOLID_PREFIX):
			continue
		return int(name_text.trim_prefix(MatchSolidMap.SOLID_PREFIX))
	return 0


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
