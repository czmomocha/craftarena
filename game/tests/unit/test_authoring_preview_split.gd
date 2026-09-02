extends GutTest

## C5 第 4 章：AuthoringPreview 拆成 bootstrap / intents / scan / view。
## 断言的是拆分性质与 E9 行数，不是玩法数值。现有
## test_authoring_preview*.gd 仍覆盖公开 API。

const AuthoringPreviewGd := preload("res://src/creator/authoring_preview.gd")

const E9_LINE_CAP: int = 400
const PREVIEW_PATHS: PackedStringArray = [
	"res://src/creator/authoring_preview.gd",
	"res://src/creator/authoring_preview_bootstrap.gd",
	"res://src/creator/authoring_preview_intents.gd",
	"res://src/creator/authoring_preview_scan.gd",
	"res://src/creator/authoring_preview_view.gd",
]


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func test_preview_files_stay_under_e9_line_cap() -> void:
	for path: String in PREVIEW_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_new_preview_owns_collaborators() -> void:
	var preview: AuthoringPreviewGd = AuthoringPreviewGd.new()
	assert_not_null(preview.intents)
	assert_not_null(preview.scan)
	assert_not_null(preview.view)
	assert_false(preview.connected)
	assert_false(preview.is_playing())
	assert_false(preview.allows_settlement())
	assert_false(preview.allows_online_writes())
