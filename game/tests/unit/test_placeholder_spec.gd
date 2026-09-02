extends GutTest

## C4 第 1 章：占位几何与色板收敛到 PlaceholderSpec 一处。
## C4 第 6 章追加：D4 相机 45° 与 UI 基准 1920×1080 的接线断言（在下方三条）。
##
## 这里断言的是**接线**，不是色值。冻结期不给占位表现新增强断言
## （.cursor/rules/chapter-granularity-and-review.mdc §3），所以下面没有一句
## 写死 RGB；写死的是「每个消费方读的就是 spec 那一份」。
## 最后两条扫源码，防止下一章又在某个 map 里写回一个 Color(...)——
## 散落一次不会报错，只会让 Preview 和对局慢慢变成两套配色。

const MatchServerGd := preload("res://src/server/match_server.gd")

const SCAN_DIRS: Array[String] = ["res://src/client", "res://src/creator"]
## 包内材质自检要构造一个与色板无关的颜色再读回来，见 package_check.gd。
const COLOR_LITERAL_ALLOWED: Array[String] = ["res://src/client/package_check.gd"]
## C4 第 6 章接线前那个 AI 自选偏移 Vector3(6, 8, 6) 的长度 √136。D4 只给了
## 角度、没给距离，所以「距离一位都没动」本身要有断言守着。
const CAMERA_DISTANCE_BEFORE_D4: float = 11.661903789690601
const ANGLE_EPSILON: float = 0.0001


func test_visual_maps_read_the_spec() -> void:
	assert_eq(MatchSolidMap.PLACEHOLDER_SIZE, PlaceholderSpec.BOX_SIZE)
	assert_eq(MatchSolidMap.SOLID_ALBEDO, PlaceholderSpec.SOLID_ALBEDO)
	assert_eq(MatchHazardMap.PLACEHOLDER_SIZE, PlaceholderSpec.BOX_SIZE)
	assert_eq(MatchHazardMap.HAZARD_ALBEDO, PlaceholderSpec.HAZARD_ALBEDO)
	assert_eq(MatchCrateMap.PLACEHOLDER_SIZE, PlaceholderSpec.BOX_SIZE)
	assert_eq(MatchCourseMap.PLACEHOLDER_SIZE, PlaceholderSpec.BOX_SIZE)
	assert_eq(MatchCourseMap.PENDING_ALBEDO, PlaceholderSpec.PAD_PENDING_ALBEDO)
	assert_eq(MatchCourseMap.ACCEPTED_ALBEDO, PlaceholderSpec.PAD_ACCEPTED_ALBEDO)
	assert_eq(MatchCourseMap.CURRENT_ALBEDO, PlaceholderSpec.PAD_CURRENT_ALBEDO)
	assert_eq(MatchCourseMap.FINISH_PENDING_ALBEDO, PlaceholderSpec.FINISH_PENDING_ALBEDO)
	assert_eq(MatchCourseMap.FINISH_CURRENT_ALBEDO, PlaceholderSpec.FINISH_CURRENT_ALBEDO)
	assert_eq(MatchCourseMap.FINISH_ACCEPTED_ALBEDO, PlaceholderSpec.FINISH_ACCEPTED_ALBEDO)
	assert_eq(MatchSnapshotMap.PLACEHOLDER_SIZE, PlaceholderSpec.BOX_SIZE)
	assert_eq(MatchSnapshotMap.CAMERA_OFFSET, PlaceholderSpec.CAMERA_OFFSET)
	assert_eq(MatchSnapshotMap.CAMERA_FOV_DEG, PlaceholderSpec.CAMERA_FOV_DEG)
	assert_eq(MatchSnapshotMap.OWN_ALBEDO, PlaceholderSpec.OWN_ALBEDO)
	assert_eq(MatchSnapshotMap.REMOTE_ALBEDO, PlaceholderSpec.REMOTE_ALBEDO)


## C4 第 6 章：D4「相机斜 45°」接线。这里断言的是**角度**，不是三个浮点分量——
## 写死 (5.83, 8.24, 5.83) 只会在下次有人改距离时变成一条谁都不敢动的红线。
func test_camera_rig_is_the_d4_forty_five_degree_angle() -> void:
	var offset: Vector3 = PlaceholderSpec.CAMERA_OFFSET
	var horizontal: float = sqrt(offset.x * offset.x + offset.z * offset.z)
	var pitch_deg: float = rad_to_deg(atan2(offset.y, horizontal))
	var yaw_deg: float = rad_to_deg(atan2(offset.x, offset.z))
	assert_almost_eq(pitch_deg, PlaceholderSpec.CAMERA_PITCH_DEG, ANGLE_EPSILON)
	assert_almost_eq(yaw_deg, PlaceholderSpec.CAMERA_YAW_DEG, ANGLE_EPSILON)
	assert_eq(PlaceholderSpec.CAMERA_PITCH_DEG, 45.0, "D4：斜 45°")
	assert_eq(PlaceholderSpec.CAMERA_YAW_DEG, 45.0, "D4：斜 45°")


## D4 只回答了角度。距离与 FOV 没答 ⇒ 维持接线前的值，不许 AI 顺手选一个。
func test_camera_distance_and_fov_are_unchanged_placeholders() -> void:
	assert_almost_eq(
		PlaceholderSpec.CAMERA_OFFSET.length(),
		CAMERA_DISTANCE_BEFORE_D4,
		ANGLE_EPSILON
	)
	assert_almost_eq(PlaceholderSpec.CAMERA_DISTANCE, CAMERA_DISTANCE_BEFORE_D4, ANGLE_EPSILON)
	assert_eq(PlaceholderSpec.CAMERA_FOV_DEG, 75.0, "Godot Camera3D 默认 FOV，D4 未给")


## D4 的 UI 基准只有一份数，三处窗口读同一个常量。窗口实例上的 content_scale
## 由两个壳自己的测试验（test_match_lobby_shell / test_authoring_preview_shell）。
func test_ui_base_size_is_the_d4_baseline() -> void:
	assert_eq(PlaceholderSpec.UI_BASE_SIZE, Vector2i(1920, 1080))


func test_preview_map_reads_the_same_spec_as_the_match_maps() -> void:
	assert_eq(AuthoringPreviewMap.PLACEHOLDER_SIZE, MatchSolidMap.PLACEHOLDER_SIZE)
	assert_eq(AuthoringPreviewMap.HAZARD_ALBEDO, MatchHazardMap.HAZARD_ALBEDO)
	assert_eq(AuthoringPreviewMap.SOLID_ALBEDO, MatchSolidMap.SOLID_ALBEDO)
	assert_eq(AuthoringPreviewMap.FINISH_ALBEDO, MatchCourseMap.FINISH_PENDING_ALBEDO)
	assert_eq(AuthoringPreviewMap.CRATE_ALBEDO, PlaceholderSpec.CRATE_ALBEDO)


func test_authoritative_geometry_reads_the_spec() -> void:
	assert_eq(TraprushPlayStubs.CAPSULE_RADIUS, PlaceholderSpec.CHARACTER_RADIUS)
	assert_eq(TraprushPlayStubs.CAPSULE_HEIGHT, PlaceholderSpec.CHARACTER_HEIGHT)
	assert_eq(MatchServerGd.SPAWN_STRIDE, PlaceholderSpec.SPAWN_STRIDE)


## 脚底偏移从胶囊柱高/半径推导，不是 1 米盒底。改高度只改 PlaceholderSpec
## 这一处，视觉 catalog 读注入后的米数。
func test_capsule_bottom_metres_are_derived_from_height_and_radius() -> void:
	var expected: float = (
		float(PlaceholderSpec.CHARACTER_HEIGHT / 2 + PlaceholderSpec.CHARACTER_RADIUS)
		/ float(PlaceholderSpec.CELL)
		* PlaceholderSpec.METERS_PER_CELL
	)
	assert_almost_eq(
		PlaceholderSpec.CHARACTER_CAPSULE_BOTTOM_M,
		expected,
		ANGLE_EPSILON
	)
	assert_ne(
		PlaceholderSpec.CHARACTER_CAPSULE_BOTTOM_M,
		PlaceholderSpec.METERS_PER_CELL / 2.0,
		"胶囊底面不应等于 1 米盒半高，否则重力落地后脚会陷入固体"
	)
	assert_almost_eq(
		SharedVisualAssetCatalog.CHARACTER_FOOT_LIFT.y,
		-PlaceholderSpec.CHARACTER_CAPSULE_BOTTOM_M,
		ANGLE_EPSILON,
		"角色视觉必须读 spec 注入的胶囊底面，不要另写一份半格"
	)


func test_one_cell_is_one_presentation_metre() -> void:
	assert_eq(PlaceholderSpec.CELL, AuthoringGrid.with_default_cell().cell)
	assert_eq(PlaceholderSpec.CELL, Fixed.SCALE)
	assert_eq(PlaceholderSpec.BOX_SIZE.x, PlaceholderSpec.METERS_PER_CELL)
	assert_eq(PlaceholderSpec.BOX_SIZE.y, PlaceholderSpec.METERS_PER_CELL)
	assert_eq(PlaceholderSpec.BOX_SIZE.z, PlaceholderSpec.METERS_PER_CELL)


func test_both_shells_default_to_the_same_presentation_steps() -> void:
	var lobby: MatchLobbyShell = autofree(MatchLobbyShell.new())
	var preview: AuthoringPreviewShell = autofree(AuthoringPreviewShell.new())
	assert_eq(lobby.play_move_step, PlaceholderSpec.MOVE_STEP)
	assert_eq(lobby.play_interp_step, PlaceholderSpec.INTERP_STEP)
	assert_eq(preview.play_move_step, PlaceholderSpec.MOVE_STEP)
	assert_eq(preview.play_move_step, lobby.play_move_step)


func test_no_colour_literal_outside_the_spec() -> void:
	var offenders: Array[String] = _scan(RegEx.create_from_string("Color\\s*\\("), COLOR_LITERAL_ALLOWED)
	assert_eq(offenders, [] as Array[String], "色值必须住在 PlaceholderSpec，不要写回表现映射")


func test_no_one_metre_box_literal_outside_the_spec() -> void:
	var offenders: Array[String] = _scan(
		RegEx.create_from_string("Vector3\\s*\\(\\s*1\\.0\\s*,\\s*1\\.0\\s*,\\s*1\\.0\\s*\\)"),
		[] as Array[String]
	)
	assert_eq(offenders, [] as Array[String], "1 米占位盒必须读 PlaceholderSpec.BOX_SIZE")


func _scan(pattern: RegEx, allowed: Array[String]) -> Array[String]:
	var offenders: Array[String] = []
	for dir_path: String in SCAN_DIRS:
		for file_path: String in _gd_files(dir_path):
			if allowed.has(file_path):
				continue
			var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
			assert_not_null(file, "读不到 %s" % file_path)
			if file == null:
				continue
			var lines: PackedStringArray = file.get_as_text().split("\n")
			file.close()
			for index: int in lines.size():
				if pattern.search(lines[index]) != null:
					offenders.append("%s:%d" % [file_path, index + 1])
	return offenders


func _gd_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	assert_not_null(dir, "扫不到目录 %s" % dir_path)
	if dir == null:
		return found
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			found.append("%s/%s" % [dir_path, name])
	for name: String in dir.get_directories():
		found.append_array(_gd_files("%s/%s" % [dir_path, name]))
	found.sort()
	return found
