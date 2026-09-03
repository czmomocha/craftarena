extends GutTest

## C5 第 5 章：AuthoringPreviewMap 拆成 convert / occupancy / gizmos / overlay / player。
## 断言的是拆分性质与 E9 行数，不是玩法数值。现有
## test_authoring_preview*.gd 仍覆盖公开 API。

const AuthoringPreviewMapGd := preload("res://src/creator/authoring_preview_map.gd")

const E9_LINE_CAP: int = 400
const MAP_PATHS: PackedStringArray = [
	"res://src/creator/authoring_preview_map.gd",
	"res://src/creator/authoring_preview_map_convert.gd",
	"res://src/creator/authoring_preview_map_occupancy.gd",
	"res://src/creator/authoring_preview_map_gizmos.gd",
	"res://src/creator/authoring_preview_map_overlay.gd",
	"res://src/creator/authoring_preview_map_player.gd",
	"res://src/creator/authoring_preview_map_floor.gd",
]


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func test_map_files_stay_under_e9_line_cap() -> void:
	for path: String in MAP_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_new_map_owns_collaborators() -> void:
	var map: AuthoringPreviewMapGd = AuthoringPreviewMapGd.new()
	assert_not_null(map.occupancy)
	assert_not_null(map.gizmos)
	assert_not_null(map.overlay)
	assert_not_null(map.player_marks)
	assert_eq(map.mapped_count(), 0)
	assert_true(map.reachability_ok())
	map.free()
