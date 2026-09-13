extends GutTest

## 字体覆盖：**现扫仓库**，而不是信任入库的字表。
##
## `test_font_packaging.gd` 断言的是「字体覆盖了 `project_supplement.txt`」。
## 那条链有个缺口：补集由 `tools/font-subset/collect_project_chars.py` 生成，
## 而那个脚本不进 CI（需要 Python + fontTools，加依赖属宪法第十八条）。
## 于是「改一句文案」→「补集没重跑」→「GUT 全绿」→「玩家看见豆腐块」这条路
## 一直是通的：GUT 只验已登记的字，没有任何东西验登记表是不是新的。
##
## 这个文件把那一环补上：直接扫 `res://` 下会被渲染的源文件，逐字符问字体
## 有没有字形。**它不读补集**，所以补集过期不会让它变绿——它问的是
## 「仓库现在用到的字，这份字体画不画得出来」，那才是玩家真正遇到的问题。
##
## 与 Python 扫描器的关系：那边仍是**生成**补集的地方（切子集要有输入）；
## 这边只**校验**，不生成，也不要求两者字符集完全一致。补集可以比实际用字多
## （注释里的字、删掉的文案），那不是错误；少了才是。

const UiFontGd := preload("res://src/shared/ui_font.gd")

## 与 `collect_project_chars.py` 的 `SCAN_DIRS` 对齐。不扫 `res://tests/`：
## 测试文案不入包，把它算进来只会让子集为了测试断言而变大。
const SCAN_DIRS: Array[String] = [
	"res://src",
	"res://content/locale",
	"res://content/official",
]

## 与 `collect_project_chars.py` 的 `SCAN_SUFFIXES` 对齐。
const SCAN_SUFFIXES: Array[String] = ["gd", "tscn", "tres", "csv", "json"]

## 与 `collect_project_chars.py` 的 `SKIP_DIR_NAMES` 对齐。
const SKIP_DIRS: Array[String] = [".godot", "addons", "_source_refs", "export"]

## 上游不含 emoji，这一个字符必然缺形（CD-11 §8.2 第 3 条已登记，CD-63 §2 第 6 项未决）。
## 写成白名单而不是"忽略所有 emoji"：再出现第二个 emoji 时这条测试必须红，
## 好让下一个人**显式**决定它是加进子集还是加进这个名单。
const ALLOWED_MISSING: Array[String] = ["🔒"]


func _font() -> Font:
	var res: Resource = load(UiFontGd.FONT_PATH)
	return res as Font


## 换行 / 回车 / 制表不是字形。字表与 CSV 的行尾会被一起读进来，
## 把它们算成缺字只会让真正的缺字淹没在噪声里。
func _is_renderable(code: int) -> bool:
	return code >= 0x20 and code != 0x7F


func _collect_files(root: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var path: String = root.path_join(entry)
		if dir.current_is_dir():
			if not SKIP_DIRS.has(entry):
				_collect_files(path, out)
		elif SCAN_SUFFIXES.has(entry.get_extension()):
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _allowed_codes() -> Dictionary:
	var allowed: Dictionary = {}
	for text: String in ALLOWED_MISSING:
		allowed[text.unicode_at(0)] = true
	return allowed


func test_every_rendered_char_in_the_repo_has_a_glyph() -> void:
	var font: Font = _font()
	assert_not_null(font, "入包字体必须能加载")
	if font == null:
		return

	var files: Array[String] = []
	for root: String in SCAN_DIRS:
		_collect_files(root, files)
	# 目录名写错、或者以后有人挪走 `src/`，都会让这条测试静默地什么都不扫。
	assert_gt(files.size(), 100, "扫到的源文件太少，SCAN_DIRS 多半已经失效")

	var allowed: Dictionary = _allowed_codes()
	var seen: Dictionary = {}
	var missing: Dictionary = {}
	for path: String in files:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var text: String = file.get_as_text()
		file.close()
		for index: int in text.length():
			var code: int = text.unicode_at(index)
			# ASCII 由 build_font_subset.py 的 ASCII_PRINTABLE 整段保证，
			# 跳过它能把这条测试的循环体砍掉绝大部分。
			if code < 0x80 or seen.has(code):
				continue
			seen[code] = true
			if not _is_renderable(code) or allowed.has(code):
				continue
			if not font.has_char(code):
				if not missing.has(code):
					missing[code] = []
				var holders: Array = missing[code]
				holders.append(path)

	var report: Array[String] = []
	for code: int in missing:
		var holders: Array = missing[code]
		report.append("U+%04X(%s) 首见于 %s" % [code, String.chr(code), holders[0]])
	assert_eq(
		report,
		[] as Array[String],
		(
			"仓库里有字画不出来：%s\n"
			+ "修法二选一：改掉那个字符，或重跑子集"
			+ "（python3 tools/font-subset/collect_project_chars.py"
			+ " && python3 tools/font-subset/build_font_subset.py"
			+ " && \"$GODOT4\" --headless --path game --import）。"
		) % ", ".join(report)
	)


func test_the_scan_would_actually_catch_a_missing_glyph() -> void:
	# 反例。上面那条只有在 has_char 会返回 false 时才有意义，而它现在的期望值是
	# 空数组——一个什么都没扫到的循环同样给出空数组。这里证明两件事：
	# 白名单里的字符确实缺形（否则白名单是僵尸条目），探针汉字确实在。
	var font: Font = _font()
	assert_not_null(font)
	if font == null:
		return
	for text: String in ALLOWED_MISSING:
		assert_false(
			font.has_char(text.unicode_at(0)),
			"%s 在白名单里却有字形了——子集换过，请把它从 ALLOWED_MISSING 删掉" % text
		)
	assert_true(font.has_char(UiFontGd.PROBE_CHAR.unicode_at(0)), "探针汉字必须在子集里")
