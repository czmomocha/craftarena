extends GutTest

## C4 本地化键：CSV 表 + UiCopy。不入字体、不改 HUD 字段名、不改协议。

const UiCopyGd := preload("res://src/shared/ui_copy.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const MatchOfflineSessionGd := preload("res://src/client/match_offline_session.gd")

const CD13_ZH: String = "离线试玩，成绩不上传"
const CD13_EN: String = "Offline play, scores are not uploaded"


func before_each() -> void:
	UiCopyGd.reset_for_tests()


## 每个声明出来的键常量都必须登记进 `ALL_KEYS`。
##
## 这里以前写的是 `assert_eq(ALL_KEYS.size(), 108)`。那个数字抓不到任何东西：
## 漏登记时 size 不变，断言照样绿；而正常加一个键反倒要改测试。真正的失败模式
## 是「加了 `const X` 却忘了往 `ALL_KEYS` 里加一行」——漏登记的键不会被字体缺字
## 断言和导出自检看到，于是缺翻译、缺字形都无人过问。这条直接比对两者。
func test_every_declared_key_is_registered() -> void:
	var script: GDScript = load("res://src/shared/ui_copy.gd") as GDScript
	assert_not_null(script)
	if script == null:
		return
	var registered: PackedStringArray = UiCopyGd.ALL_KEYS
	var declared: Array[String] = []
	for name: Variant in script.get_script_constant_map():
		var value: Variant = script.get_script_constant_map()[name]
		if typeof(value) != TYPE_STRING:
			continue
		var text: String = value
		if not text.begins_with("craft_arena."):
			continue
		declared.append(text)
		assert_true(registered.has(text), "常量 %s = %s 没登记进 ALL_KEYS" % [name, text])
	assert_gt(declared.size(), 0, "一个键常量都没扫到，反射方式多半失效了")

	var seen: Dictionary = {}
	for key: String in registered:
		assert_false(seen.has(key), "ALL_KEYS 里 %s 重复登记" % key)
		seen[key] = true


func test_table_covers_every_key_in_both_locales() -> void:
	assert_true(UiCopyGd.ensure_loaded())
	assert_true(UiCopyGd.has_locale("en"))
	assert_true(UiCopyGd.has_locale("zh_CN"))
	assert_gt(UiCopyGd.ALL_KEYS.size(), 0)
	for key: String in UiCopyGd.ALL_KEYS:
		assert_true(key.begins_with("craft_arena."), key)
		var english: String = UiCopyGd.text(key, "en")
		var chinese: String = UiCopyGd.text(key, "zh_CN")
		assert_ne(english, key, "en 缺 %s" % key)
		assert_ne(chinese, key, "zh_CN 缺 %s" % key)
		assert_ne(english, chinese, "%s 中英撞车" % key)


func test_offline_banner_zh_is_the_cd13_sentence() -> void:
	assert_eq(UiCopyGd.text(UiCopyGd.OFFLINE_BANNER, "zh_CN"), CD13_ZH)
	assert_eq(UiCopyGd.text(UiCopyGd.OFFLINE_BANNER, "en"), CD13_EN)
	assert_eq(MatchOfflineSessionGd.BANNER_KEY, UiCopyGd.OFFLINE_BANNER)
	# The exported `.gdc` copy-on-assign bug looks like "file present, key
	# returned". This assertion is the editor-side twin of package-check.
	assert_true(UiCopyGd.has_locale("zh_CN"))
	assert_ne(UiCopyGd.text(UiCopyGd.OFFLINE_BANNER, "zh_CN"), UiCopyGd.OFFLINE_BANNER)


func test_loader_uses_engine_csv_line() -> void:
	var file: FileAccess = FileAccess.open("res://src/shared/ui_copy.gd", FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var source: String = file.get_as_text()
	file.close()
	assert_true(
		source.contains("get_csv_line"),
		"导出后的 .gdc 里手写拆行会拆出 0 行，生产路径必须走 get_csv_line"
	)
	assert_false(
		source.contains("source.substr(i, 1)"),
		"不要把已证伪的按字符拆行器留在生产路径"
	)


func test_quoted_comma_survives_csv() -> void:
	assert_true(UiCopyGd.text(UiCopyGd.OFFLINE_BANNER, "en").contains(","))


func test_missing_key_returns_the_key() -> void:
	assert_eq(UiCopyGd.text("craft_arena.ui.does_not_exist", "en"), "craft_arena.ui.does_not_exist")


func test_zh_prefix_maps_to_zh_cn() -> void:
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_TW")
	assert_eq(UiCopyGd.effective_locale(), "zh_CN")
	TranslationServer.set_locale("en_US")
	assert_eq(UiCopyGd.effective_locale(), "en")
	TranslationServer.set_locale(previous)


func test_lobby_buttons_read_the_table() -> void:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	add_child_autofree(shell)
	assert_true(shell.open())
	var quick: Button = shell.window.get_node("VBoxContainer/MatchActions/%s" % MatchLobbyShellGd.QUICK_NAME) as Button
	assert_not_null(quick)
	if quick != null:
		assert_eq(quick.text, UiCopyGd.text(UiCopyGd.QUICK_PLAY))
	assert_eq(shell.window.title, UiCopyGd.text(UiCopyGd.WINDOW_TRAPRUSH))
	var server: LineEdit = shell.window.get_node("VBoxContainer/ServerActions/%s" % MatchLobbyShellGd.SERVER_NAME) as LineEdit
	assert_not_null(server)
	if server != null:
		assert_eq(server.placeholder_text, UiCopyGd.text(UiCopyGd.SERVER_HOST))


func test_src_has_no_cd13_banner_literal() -> void:
	var offenders: Array[String] = []
	for dir_path: String in ["res://src/client", "res://src/creator", "res://src/shared"]:
		offenders.append_array(_scan_literal(dir_path, CD13_ZH))
	assert_eq(offenders, [] as Array[String], "CD-13 那句只能住在 locale CSV")


func _scan_literal(dir_path: String, needle: String) -> Array[String]:
	var offenders: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	assert_not_null(dir, "扫不到 %s" % dir_path)
	if dir == null:
		return offenders
	for name: String in dir.get_files():
		if not name.ends_with(".gd"):
			continue
		var file_path: String = "%s/%s" % [dir_path, name]
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		assert_not_null(file, "读不到 %s" % file_path)
		if file == null:
			continue
		var lines: PackedStringArray = file.get_as_text().split("\n")
		file.close()
		for index: int in lines.size():
			var line: String = lines[index]
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("#"):
				continue
			if line.contains(needle):
				offenders.append("%s:%d" % [file_path, index + 1])
	for name: String in dir.get_directories():
		offenders.append_array(_scan_literal("%s/%s" % [dir_path, name], needle))
	return offenders
