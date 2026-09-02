extends GutTest

## C5 第 11 章：AuthoringEditorShell 拆成 chrome / place / follow。
## 断言的是拆分性质与 E9 行数，不是玩法数值。现有
## test_authoring_editor_shell.gd 仍覆盖公开 API。

const AuthoringEditorShellGd := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNamesGd := preload("res://src/creator/authoring_surface_names.gd")

const E9_LINE_CAP: int = 400
const SHELL_PATHS: PackedStringArray = [
	"res://src/creator/authoring_editor_shell.gd",
	"res://src/creator/authoring_editor_shell_chrome.gd",
	"res://src/creator/authoring_editor_shell_place.gd",
	"res://src/creator/authoring_editor_shell_follow.gd",
]


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func test_editor_shell_files_stay_under_e9_line_cap() -> void:
	for path: String in SHELL_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_new_editor_shell_owns_collaborators() -> void:
	var shell: AuthoringEditorShellGd = AuthoringEditorShellGd.create(AuthoringSurfaceNamesGd.INTERNAL_DEV)
	assert_not_null(shell)
	assert_not_null(shell.chrome)
	assert_eq(shell.window, null)
	assert_false(shell.allows_settlement())
	assert_false(shell.allows_online_writes())
	shell.free()
