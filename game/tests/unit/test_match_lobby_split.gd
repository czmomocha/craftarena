extends GutTest

## C5 第 1 章：大厅壳拆成 L4 协作者。断言的是拆分性质，不是玩法数值。
## 现有 test_match_lobby_shell.gd 仍覆盖公开 API；这里只钉「壳足够薄」
## 和 HUD 行仍是开发期 token。

const MatchLobbyChromeGd := preload("res://src/client/match_lobby_chrome.gd")
const MatchLobbyHudGd := preload("res://src/client/match_lobby_hud.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")

const SHELL_PATH: String = "res://src/client/match_lobby_shell.gd"
const E9_LINE_CAP: int = 400
const COLLABORATOR_PATHS: PackedStringArray = [
	"res://src/client/match_lobby_chrome.gd",
	"res://src/client/match_lobby_director.gd",
	"res://src/client/match_lobby_hud.gd",
	"res://src/client/match_lobby_net.gd",
	"res://src/client/match_lobby_sampler.gd",
	"res://src/client/match_lobby_stage.gd",
	SHELL_PATH,
]


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func test_lobby_l4_files_stay_under_e9_line_cap() -> void:
	for path: String in COLLABORATOR_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_create_binds_l4_collaborators() -> void:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	assert_not_null(shell.chrome)
	assert_not_null(shell.stage)
	assert_not_null(shell.sampler)
	assert_not_null(shell.director)
	assert_eq(shell.director.host, shell)
	shell.free()


func test_hud_format_line_keeps_dev_tokens() -> void:
	var line: String = MatchLobbyHudGd.format_line({
		"join_state": "idle",
		"play_state": "idle",
		"tls": false,
		"mapped_pads": 3,
		"mapped_portals": 5,
		"mapped_finish": 1,
		"mapped_crates": 0,
		"mapped_hazards": 0,
		"mapped_solids": 0,
		"mapped_links": 0,
		"mapped_orders": 0,
		"mapped_sequences": 0,
		"course_id": "course_01",
		"selected_seats": 2,
	})
	assert_true(line.contains("join=idle"))
	assert_true(line.contains("play=idle"))
	assert_true(line.contains("tls=off"))
	assert_true(line.contains("course=3/5/1"))
	assert_false(line.contains("FPS"), "帧率行不在状态行里")


func test_chrome_constants_match_the_facade() -> void:
	assert_eq(MatchLobbyShellGd.TITLE, MatchLobbyChromeGd.TITLE)
	assert_eq(MatchLobbyShellGd.WINDOW_SIZE, MatchLobbyChromeGd.WINDOW_SIZE)
	assert_eq(MatchLobbyShellGd.QUICK_NAME, MatchLobbyChromeGd.QUICK_NAME)
