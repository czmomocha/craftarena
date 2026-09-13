extends GutTest

## 字体入包：Noto Sans SC 常用 3500 字子集进包并接上运行时。
##
## 这一刀的失败模式不是"字体没显示"，而是"某个字悄悄缺了"——引擎回退字体
## 会画出一个看起来差不多的字，或者干脆画个方框，测试不主动查就发现不了。
## 所以这里的断言全部落在 **覆盖**（每个会被渲染的字符都在 cmap 里），
## 而不是落在"资源能加载"。
##
## 子集范围由人类拍板（常用 3500 字），规格文件与字体同处 `content/ui/fonts/charsets/`，
## 于是"这个子集到底包含什么"这个问题在包里就能回答。

const UiCopyGd := preload("res://src/shared/ui_copy.gd")

const FONT_PATH: String = UiFont.FONT_PATH
const LICENSE_PATH: String = "res://content/ui/fonts/OFL-1.1.txt"
const COMMON_CHARSET_PATH: String = "res://content/ui/fonts/charsets/common_3500.txt"
const SUPPLEMENT_CHARSET_PATH: String = "res://content/ui/fonts/charsets/project_supplement.txt"
const THEME_PATH: String = "res://content/ui/theme/craft_arena.tres"
const CUSTOM_FONT_SETTING: String = "gui/theme/custom_font"

const FAMILY_NAME: String = UiFont.FAMILY_NAME

## OFL 的保留字体名：Google 的 "Noto Sans SC" 与 Adobe 的 "Source"。
## 子集是修改产物，不得沿用二者（CD-11 §8.2 第 3 条）。
const RESERVED_NAMES: Array[String] = ["Noto", "Source"]

## 上游 Noto Sans SC 没有这两个字形，它们仍走引擎系统回退。
## 这不是"待修缺陷"，而是"子集没买 emoji"这一拍板的直接后果，写在这里是为了
## 让下一次有人加 emoji 时，测试会明确告诉他`把它加进这个清单`而不是静默通过。
const KNOWN_MISSING: String = "🔒"

## 单文件 2 MB 预算借自 CD-11 §8.1；本刀不发明新的字体预算数字。
## `build_font_subset.py` 另有一条更紧的 1.5 MB 线，那是子集脚本自己的
## "长太快了去看一眼"警戒线，不是预算；能挡住发布的是这里这一条。
const MAX_FONT_BYTES: int = 2 * 1024 * 1024


func _font() -> Font:
	var res: Resource = load(FONT_PATH)
	return res as Font


## 换行 / 回车 / 制表不是字形：字表文件与 CSV 的行尾会被一起扫进来，
## 把它们算成"缺字"只会让真正的缺字被淹没在噪声里。
func _is_renderable(code: int) -> bool:
	return code >= 0x20 and code != 0x7F


func _missing(font: Font, text: String) -> Array[int]:
	var missing: Array[int] = []
	var seen: Dictionary = {}
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if seen.has(code) or not _is_renderable(code):
			continue
		seen[code] = true
		if not font.has_char(code):
			missing.append(code)
	return missing


func _describe(codes: Array[int]) -> String:
	var parts: Array[String] = []
	for code: int in codes:
		parts.append("U+%04X(%s)" % [code, String.chr(code)])
	return ", ".join(parts)


func _read_charset(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到字表 %s" % path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func test_font_and_licence_ship() -> void:
	assert_true(FileAccess.file_exists(FONT_PATH), "子集字体必须入库")
	assert_true(FileAccess.file_exists(LICENSE_PATH), "OFL 全文必须随字体分发")


func test_font_loads_as_a_font() -> void:
	var font: Font = _font()
	assert_not_null(font, "字体必须能被 res:// 解析成 Font")
	if font == null:
		return
	assert_gt(font.get_supported_chars().length(), 3000, "子集的字符数不像常用 3500 字")


func test_reserved_font_names_are_gone() -> void:
	# OFL 的保留字体名约束：子集产物不得沿用原字体名。这是一项许可证义务，
	# 也是"这个文件到底是不是改过的"唯一在包里能查到的痕迹。
	var font: Font = _font()
	assert_not_null(font)
	if font == null:
		return
	var name: String = font.get_font_name()
	assert_eq(name, FAMILY_NAME, "子集的 family 必须是项目自己的名字")
	for reserved: String in RESERVED_NAMES:
		assert_false(name.contains(reserved), "保留字体名 %s 不得出现在子集里" % reserved)


func test_project_setting_points_at_the_font() -> void:
	# 自绘大厅 / HUD / Label3D 都没有挂 theme，靠这一项全局兜底。
	var value: String = str(ProjectSettings.get_setting(CUSTOM_FONT_SETTING, ""))
	assert_eq(value, FONT_PATH, "gui/theme/custom_font 必须指向入包的子集字体")


func test_a_plain_control_actually_uses_the_subset() -> void:
	# 设置写了不等于生效。这条问的是运行时：一个没挂任何 theme 的 Control
	# 拿到的默认字体是不是入包那份。自绘大厅与 HUD 正是这种 Control，
	# 所以这条比上面那条更接近"玩家到底看没看见这个字体"。
	var control: Control = Control.new()
	add_child_autofree(control)
	var font: Font = control.get_theme_default_font()
	assert_not_null(font, "没挂 theme 的 Control 必须拿到全局兜底字体")
	if font == null:
		return
	assert_eq(font.get_font_name(), FAMILY_NAME, "运行时默认字体不是入包的那份子集")


func test_ui_theme_default_font_is_the_same_font() -> void:
	var theme: Theme = load(THEME_PATH) as Theme
	assert_not_null(theme, "产品 UI 主题必须能加载")
	if theme == null:
		return
	var font: Font = theme.get_default_font()
	assert_not_null(font, "主题此前没有内置字体，中文全靠引擎回退；本刀补上")
	if font == null:
		return
	assert_eq(font.get_font_name(), FAMILY_NAME, "主题用的必须是入包的那份子集")


func test_locale_table_is_fully_covered() -> void:
	# 每一行 UI 文案都要能被画出来。这条是"字体入包"真正的产品判据：
	# 键表在变，字体不会跟着变，所以覆盖必须是跑出来的，不是一次性的。
	UiCopyGd.reset_for_tests()
	assert_true(UiCopyGd.ensure_loaded())
	var font: Font = _font()
	assert_not_null(font)
	if font == null:
		return
	var missing: Array[int] = []
	for key: String in UiCopyGd.ALL_KEYS:
		for locale: String in ["en", "zh_CN"]:
			var text: String = UiCopyGd.text(key, locale)
			missing.append_array(_missing(font, text))
	assert_eq(missing, [] as Array[int], "本地化表缺字：%s" % _describe(missing))


func test_common_3500_charset_is_covered() -> void:
	var font: Font = _font()
	assert_not_null(font)
	if font == null:
		return
	var text: String = _read_charset(COMMON_CHARSET_PATH)
	assert_gt(text.length(), 0)
	var missing: Array[int] = _missing(font, text)
	assert_eq(
		missing,
		[] as Array[int],
		"常用字表缺字：%s（子集不是按这张表切的）" % _describe(missing)
	)


func test_project_supplement_is_covered() -> void:
	# 补集 = 仓库里所有会被渲染的非 ASCII 字符（.gd / .tscn / .csv / .json）。
	# 表外但项目用到的字必须在这里被抓到，否则改一句文案就悄悄缺字。
	var font: Font = _font()
	assert_not_null(font)
	if font == null:
		return
	var text: String = _read_charset(SUPPLEMENT_CHARSET_PATH)
	assert_gt(text.length(), 0)
	var missing: Array[int] = []
	for code: int in _missing(font, text):
		if code != KNOWN_MISSING.unicode_at(0):
			missing.append(code)
	assert_eq(
		missing,
		[] as Array[int],
		"项目用字缺字形：%s（重写子集见 tools/font-subset/README.md）" % _describe(missing)
	)


func test_coverage_assertions_are_not_vacuous() -> void:
	# 反例：上面三条"零缺字"只有在 has_char 真的会返回 false 时才有意义。
	# 上游不含 emoji，所以 🔒 必然缺；子集按常用字切，所以探针汉字必然在。
	# 这两条一起红，说明的不是"缺字"，而是覆盖测试本身失效了。
	#
	# 正例用的是 `UiFont.PROBE_CHAR` 常量而不是 `UiCopy` 取出来的文案：
	# 本地化表坏掉时 `UiCopy.text()` 返回键名，首字符是 ASCII，
	# 于是这条正例会退化成"任何字体都有 c"，反而把反例测试自己变成恒真。
	var font: Font = _font()
	assert_not_null(font)
	if font == null:
		return
	assert_false(font.has_char(KNOWN_MISSING.unicode_at(0)), "🔒 本该缺字形，has_char 却说有")
	assert_true(font.has_char(UiFont.PROBE_CHAR.unicode_at(0)), "探针汉字必须在子集里")


func test_subset_stays_inside_the_single_file_budget() -> void:
	var file: FileAccess = FileAccess.open(FONT_PATH, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var bytes: int = file.get_length()
	file.close()
	assert_lt(bytes, MAX_FONT_BYTES, "子集超了单文件预算（CD-11 §8.1 的 2 MB）")
	assert_gt(bytes, 0)
