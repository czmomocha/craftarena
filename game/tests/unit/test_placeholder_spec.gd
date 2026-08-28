extends GutTest

## C4 第 1 章：占位几何与色板收敛到 PlaceholderSpec 一处。
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
	assert_eq(MatchSnapshotMap.OWN_ALBEDO, PlaceholderSpec.OWN_ALBEDO)
	assert_eq(MatchSnapshotMap.REMOTE_ALBEDO, PlaceholderSpec.REMOTE_ALBEDO)


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
