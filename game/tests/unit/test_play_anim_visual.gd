extends GutTest

## 路线 A（人类 2026-09-05 拍板）：C4 表现动画状态接到角色 visual 上。
## clip 映射 4 态 + 程序化姿态 4 态，两张表合起来恰好覆盖契约八态。
##
## 与 test_character_visual_asset.gd 同一哲学：断言**关系**（覆盖完整性、
## clip 名、transform 相对基准的变化），不写死任何姿态角度或模型尺寸
## （冻结期不给占位表现新增强断言）。

const EPS: float = 0.0001

var _map: MatchSnapshotMap = null
var _preview: AuthoringPreviewMap = null


func before_each() -> void:
	_map = MatchSnapshotMap.new()
	add_child_autofree(_map)
	_preview = AuthoringPreviewMap.new()
	add_child_autofree(_preview)


# --- 两张表恰好覆盖契约八态 -----------------------------------------------------


func test_clip_and_pose_tables_cover_every_contract_state() -> void:
	for state: String in PlayAnimState.NAMES:
		assert_true(
			PlayAnimVisual.covers(state),
			"契约状态 %s 既没有 clip 也没有姿态，视觉会静止" % state
		)
	assert_eq(
		PlayAnimVisual.CLIP_BY_STATE.size() + PlayAnimVisual.POSE_PITCH_DEG.size(),
		PlayAnimState.NAMES.size(),
		"两张表的条数之和应恰好等于八态，不允许一个状态两边都有"
	)


func test_clip_map_values_are_playable_in_the_character_asset() -> void:
	# 真资产断言：cat 入库并导入后，映射的每个 clip 都真的能播。
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_character()
	assert_not_null(visual, "角色视觉资产实例化失败，先跑 Headless 导入检查")
	if visual == null:
		return
	var player: AnimationPlayer = _animation_player(visual)
	assert_not_null(player, "cat 资产里没有 AnimationPlayer，clip 映射无从谈起")
	if player == null:
		visual.free()
		return
	for state: String in PlayAnimVisual.CLIP_BY_STATE:
		var clip: String = PlayAnimVisual.CLIP_BY_STATE[state]
		assert_true(
			player.has_animation(clip),
			"契约状态 %s 映射的 clip「%s」在资产里不存在" % [state, clip]
		)
	visual.free()


# --- clip 态与姿态态的行为 ------------------------------------------------------


func test_clip_state_plays_the_mapped_animation() -> void:
	var visual: Node3D = _fake_visual_with_clips(["idle", "run", "dance"])
	assert_true(PlayAnimVisual.apply(visual, PlayAnimState.IDLE))
	var player: AnimationPlayer = _animation_player(visual)
	assert_eq(player.current_animation, "idle")
	assert_true(PlayAnimVisual.apply(visual, PlayAnimState.RUN))
	assert_eq(player.current_animation, "run")
	visual.free()


func test_clip_state_restores_the_base_transform_after_a_pose() -> void:
	var visual: Node3D = _fake_visual_with_clips(["idle"])
	assert_true(PlayAnimVisual.apply(visual, PlayAnimState.LAND))
	assert_ne(visual.transform, _base(visual), "姿态态没有产生偏移")
	assert_true(PlayAnimVisual.apply(visual, PlayAnimState.IDLE))
	assert_almost_eq(visual.transform.origin.y, _base(visual).origin.y, EPS, "clip 态没回到基准")
	assert_almost_eq(visual.rotation_degrees.x, 0.0, EPS, "姿态残留了俯仰")
	visual.free()


func test_pose_state_offsets_transform_and_stops_the_clip() -> void:
	var visual: Node3D = _fake_visual_with_clips(["idle"])
	assert_true(PlayAnimVisual.apply(visual, PlayAnimState.IDLE))
	assert_true(PlayAnimVisual.apply(visual, PlayAnimState.LAND))
	var player: AnimationPlayer = _animation_player(visual)
	assert_eq(player.current_animation, "", "姿态态必须停掉 clip")
	assert_ne(visual.transform.origin.y, _base(visual).origin.y, "LAND 的下压没生效")
	assert_ne(visual.rotation_degrees.x, 0.0, "LAND 的俯仰没生效")
	visual.free()


func test_pose_offsets_are_not_all_identical() -> void:
	# 四个补缺姿态如果数值全一样，等于只有一个姿态。断言的是互不相同，
	# 不是具体角度（角度未定稿，见 PlayAnimVisual 头注释）。
	var seen: Array = []
	for state: String in PlayAnimVisual.POSE_PITCH_DEG:
		var pose: Array = [
			PlayAnimVisual.POSE_PITCH_DEG[state],
			PlayAnimVisual.POSE_LIFT.get(state, 0.0),
		]
		assert_false(seen.has(pose), "姿态 %s 与前面的姿态完全相同" % state)
		seen.append(pose)


# --- 贴合缩放与姿态的关系 --------------------------------------------------------


func test_character_fit_scales_down_and_lands_feet_on_the_capsule_bottom() -> void:
	# 角色贴合：等比缩到 CHARACTER_VISUAL_CELL_SPAN 格宽、水平居中、脚底落在
	# 权威胶囊底面。断言的是**关系**，不是任何具体系数或模型尺寸。
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_character()
	assert_not_null(visual, "角色视觉资产实例化失败，先跑 Headless 导入检查")
	if visual == null:
		return
	add_child_autofree(visual)
	var raw: AABB = SharedVisualAssetCatalog.local_bounds(visual)
	assert_true(SharedVisualAssetCatalog.fit_character_on_cell(visual))
	var span: float = (
		PlaceholderSpec.METERS_PER_CELL * PlaceholderSpec.CHARACTER_VISUAL_CELL_SPAN
	)
	var fitted: AABB = visual.transform * raw
	assert_almost_eq(
		maxf(fitted.size.x, fitted.size.z),
		span,
		EPS,
		"水平最长边没有缩到 CHARACTER_VISUAL_CELL_SPAN 格"
	)
	assert_almost_eq(
		fitted.position.y,
		-PlaceholderSpec.CHARACTER_CAPSULE_BOTTOM_M,
		EPS,
		"脚底没落在权威胶囊底面"
	)
	assert_almost_eq(fitted.position.x + fitted.size.x / 2.0, 0.0, EPS, "X 没有居中")
	assert_almost_eq(fitted.position.z + fitted.size.z / 2.0, 0.0, EPS, "Z 没有居中")
	# 等比：三轴同一系数。
	assert_almost_eq(visual.scale.x, visual.scale.y, EPS, "缩放不是等比")
	assert_almost_eq(visual.scale.y, visual.scale.z, EPS, "缩放不是等比")


func test_pose_keeps_the_fitted_scale() -> void:
	# 这是本刀最容易回归的一条：姿态态直接写 transform，如果基准由常量重建
	# （Basis() 无缩放），角色会在起跳那一拍突然变大。
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_character()
	assert_not_null(visual)
	if visual == null:
		return
	add_child_autofree(visual)
	assert_true(SharedVisualAssetCatalog.fit_character_on_cell(visual))
	var fitted_scale: Vector3 = visual.scale
	assert_lt(fitted_scale.x, 1.0, "这只资产本该被缩小，用例前提不成立")
	assert_true(PlayAnimVisual.apply(visual, PlayAnimState.JUMP))
	assert_almost_eq(visual.scale.x, fitted_scale.x, EPS, "姿态态抹掉了贴合缩放")
	assert_almost_eq(visual.scale.y, fitted_scale.y, EPS, "姿态态抹掉了贴合缩放")
	assert_ne(visual.rotation_degrees.x, 0.0, "姿态俯仰没生效")
	assert_true(PlayAnimVisual.apply(visual, PlayAnimState.IDLE))
	assert_almost_eq(visual.scale.x, fitted_scale.x, EPS, "clip 态抹掉了贴合缩放")


func test_base_transform_falls_back_when_the_visual_was_never_fitted() -> void:
	# 裸 Node3D（没走贴合）仍要有基准：不缩放 + 脚底抬到胶囊底面。
	var visual: Node3D = Node3D.new()
	var base: Transform3D = SharedVisualAssetCatalog.character_base_transform(visual)
	assert_almost_eq(base.origin.y, SharedVisualAssetCatalog.CHARACTER_FOOT_LIFT.y, EPS)
	assert_almost_eq(base.basis.get_scale().x, 1.0, EPS, "未贴合的基准不该带缩放")
	visual.free()


# --- 安全降级 -------------------------------------------------------------------


func test_apply_without_an_animation_player_degrades_to_the_base_pose() -> void:
	# 旧静态网格（char_runner_base 那代）没有 AnimationPlayer：clip 态降级为
	# 回基准静止，不许崩。这正是"宁可静止也不出不了人"的回退。
	var visual: Node3D = Node3D.new()
	assert_true(PlayAnimVisual.apply(visual, PlayAnimState.IDLE))
	assert_true(PlayAnimVisual.apply(visual, PlayAnimState.JUMP))
	visual.free()


func test_apply_rejects_unknown_states_and_null_visuals() -> void:
	var visual: Node3D = Node3D.new()
	assert_false(PlayAnimVisual.apply(visual, "backflip"))
	assert_eq(visual.transform, Transform3D.IDENTITY, "未知状态不许动 transform")
	assert_false(PlayAnimVisual.apply(null, PlayAnimState.IDLE))
	visual.free()


# --- 对局与 Preview 的真实接线 --------------------------------------------------


func test_match_set_anim_state_drives_the_character_visual() -> void:
	assert_true(_map.apply_players([_player_body()]))
	var visual: Node3D = _map.visual_node(0)
	assert_not_null(visual)
	if visual == null:
		return
	var base: Transform3D = SharedVisualAssetCatalog.character_base_transform(visual)
	assert_almost_eq(
		visual.position.y,
		base.origin.y,
		EPS,
		"attach 定位与 PlayAnimVisual 的基准不同源，姿态会叠加漂移"
	)
	var player: AnimationPlayer = _animation_player(visual)
	assert_not_null(player, "cat 视觉里应能找到 AnimationPlayer")
	if player == null:
		return
	assert_true(_map.set_anim_state(0, PlayAnimState.RUN))
	assert_eq(player.current_animation, "run", "对局侧 set_anim_state 没驱动 clip")
	assert_true(_map.set_anim_state(0, PlayAnimState.JUMP))
	assert_eq(player.current_animation, "", "对局侧姿态态没停 clip")
	assert_ne(visual.rotation_degrees.x, 0.0, "对局侧姿态偏移没生效")
	assert_almost_eq(
		visual.position.y,
		base.origin.y,
		EPS,
		"姿态偏移应叠加在基准上，不是替换基准"
	)
	assert_almost_eq(
		visual.scale.x,
		base.basis.get_scale().x,
		EPS,
		"对局侧姿态抹掉了贴合缩放"
	)


func test_preview_set_anim_state_drives_the_character_visual() -> void:
	_preview.show_player_pose({"x": 0, "y": 0, "z": 0})
	var player_node: MeshInstance3D = _preview.player_node()
	assert_not_null(player_node)
	if player_node == null:
		return
	var visual: Node3D = _preview.player_visual_node()
	assert_not_null(visual)
	if visual == null:
		return
	var player: AnimationPlayer = _animation_player(visual)
	assert_not_null(player)
	if player == null:
		return
	assert_true(_preview.set_anim_state(PlayAnimState.IDLE))
	assert_eq(player.current_animation, "idle", "Preview 侧 set_anim_state 没驱动 clip")


func test_visual_falls_back_when_the_character_asset_is_missing() -> void:
	# 与 test_character_visual_asset 同款回退：路径指空时占位盒自己上，
	# set_anim_state 仍写契约读出（Label），visual 缺失不崩。
	_map.character_scene_path = ""
	assert_true(_map.apply_players([_player_body()]))
	assert_true(_map.set_anim_state(0, PlayAnimState.RUN))
	assert_eq(_map.anim_state(0), PlayAnimState.RUN)
	assert_eq(_map.visual_count(), 0)


# --- helpers -----------------------------------------------------------------


func _base(visual: Node3D) -> Transform3D:
	return SharedVisualAssetCatalog.character_base_transform(visual)


func _player_body() -> Dictionary:
	return {"x": 0, "y": 0, "z": 0, "yaw_bam": 0}


## 造一个带 AnimationPlayer 的最小 visual：clip 名按需塞进动画库。
func _fake_visual_with_clips(clips: Array) -> Node3D:
	var root: Node3D = Node3D.new()
	var player: AnimationPlayer = AnimationPlayer.new()
	var library: AnimationLibrary = AnimationLibrary.new()
	for clip: String in clips:
		var animation: Animation = Animation.new()
		animation.length = 1.0
		library.add_animation(clip, animation)
	player.add_animation_library("", library)
	root.add_child(player)
	add_child_autofree(root)
	return root


func _animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child: Node in root.get_children():
		var found: AnimationPlayer = _animation_player(child)
		if found != null:
			return found
	return null
