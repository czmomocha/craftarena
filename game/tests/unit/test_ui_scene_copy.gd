extends GutTest

## 产品 UI 基础包的文案接线：场景里不留中文，运行时从 `UiCopy` 填。
##
## 人类 2026-09-13 拍板两件事：键按屏分前缀（`craft_arena.s3.*` / `craft_arena.card.*`），
## 以及 `.tscn` 的 `text` 清空、在 `_ready()` 里填。后者的好处正是这个文件要钉住的：
## **漏接一个键会显示为空白**，而不是继续显示一句翻译器够不到的中文。
##
## 这里只覆盖**已迁移**的两个场景。S1 / S2 仍有硬编码中文，是下一刀的事，
## 清单见 `PENDING_SCENES`——写在代码里而不是只写在文档里，因为文档不会在
## 有人「顺手」把 S1 也接了一半的时候提醒任何人。

const UiCopyGd := preload("res://src/shared/ui_copy.gd")

const S3_SCENE: String = "res://src/client/ui/scenes/s3_workshop.tscn"
const CARD_SCENE: String = "res://src/client/ui/scenes/components/content_card.tscn"

## 已迁移：这些场景的 `text` / `placeholder_text` 必须零中文。
const MIGRATED_SCENES: Array[String] = [S3_SCENE, CARD_SCENE]

## 未迁移：UI 接线第一批的剩余前置。列在这里是为了让「还欠着什么」可执行，
## 迁完一个就从这里挪到上面那个数组。
const PENDING_SCENES: Array[String] = [
	"res://src/client/ui/scenes/s1_lobby.tscn",
	"res://src/client/ui/scenes/s2_matchmaking.tscn",
]

## 本刀新增的键。分屏前缀的落点，两种 locale 都必须有真值。
const S3_KEYS: Array[String] = [
	UiCopyGd.S3_TITLE,
	UiCopyGd.S3_TAB_LATEST,
	UiCopyGd.S3_TAB_RATING,
	UiCopyGd.S3_TAB_PLAYS,
	UiCopyGd.S3_TAB_VERIFIED,
	UiCopyGd.S3_SORT,
	UiCopyGd.S3_TAG_FILTER,
	UiCopyGd.S3_SEARCH_PLACEHOLDER,
	UiCopyGd.S3_NOTE,
]

const CARD_KEYS: Array[String] = [
	UiCopyGd.CARD_UNVERIFIED_BADGE,
	UiCopyGd.CARD_ACTION_EDIT_REUSE,
	UiCopyGd.CARD_PLAYS_COUNT,
]


func before_each() -> void:
	UiCopyGd.reset_for_tests()
	assert_true(UiCopyGd.ensure_loaded(), "本地化表必须可读")


func _has_cjk(text: String) -> bool:
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


## 读 `.tscn` 源文本而不是实例化后遍历节点：清空的判据是「场景文件里没有」，
## 实例化之后 `_ready()` 已经把文案填回去了，那时候再查只会永远通过。
func _authored_cjk_lines(path: String) -> Array[String]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到场景 %s" % path)
	if file == null:
		return []
	var found: Array[String] = []
	while not file.eof_reached():
		var line: String = file.get_line()
		var is_copy: bool = line.begins_with("text = ") or line.begins_with("placeholder_text = ")
		if is_copy and _has_cjk(line):
			found.append(line)
	file.close()
	return found


func test_migrated_scenes_author_no_chinese() -> void:
	for path: String in MIGRATED_SCENES:
		assert_eq(
			_authored_cjk_lines(path),
			[] as Array[String],
			"%s 仍有硬编码中文；文案应走 UiCopy 键，场景里留空" % path
		)


func test_the_scan_is_not_vacuous() -> void:
	# 反例：上面那条的期望值是空数组，而一个什么都没读到的扫描同样给出空数组。
	# 未迁移的两个场景现在必然含中文，所以它们同时为空 = 扫描函数坏了，不是迁移干净了。
	# S1 / S2 迁完之后这条会红，那时把它们移进 MIGRATED_SCENES 即可。
	for path: String in PENDING_SCENES:
		assert_gt(
			_authored_cjk_lines(path).size(),
			0,
			"%s 已经没有中文了？把它移进 MIGRATED_SCENES" % path
		)


func test_new_keys_resolve_in_both_locales() -> void:
	var keys: Array[String] = S3_KEYS.duplicate()
	keys.append_array(CARD_KEYS)
	for key: String in keys:
		for locale: String in ["en", "zh_CN"]:
			var value: String = UiCopyGd.text(key, locale)
			# 缺键时 UiCopy 返回键名本身，所以「等于键名」就是「没翻译」。
			assert_ne(value, key, "%s 缺 %s 翻译" % [key, locale])
			assert_false(value.strip_edges().is_empty(), "%s 的 %s 是空串" % [key, locale])


## 「键要登记进 `ALL_KEYS`」由 `test_ui_copy.gd` 的
## `test_every_declared_key_is_registered` 统一覆盖，这里不再重复一遍窄版本。


func test_plays_count_is_a_format_string() -> void:
	# 次数由数据给，量词由本地化表给。这条钉住那个 `%s`：一旦有人把它改成
	# 写死的「次游玩」，卡片上的数字就会消失，而不是报错。
	for locale: String in ["en", "zh_CN"]:
		assert_string_contains(UiCopyGd.text(UiCopyGd.CARD_PLAYS_COUNT, locale), "%s")


func test_s3_fills_its_chrome_at_runtime() -> void:
	# 真正的产品判据：场景清空了，跑起来必须有字。前面那条只证明了场景是空的，
	# 只有这条能区分「接好了」和「文案丢了」。
	var packed: PackedScene = load(S3_SCENE) as PackedScene
	assert_not_null(packed, "S3 场景必须能加载")
	if packed == null:
		return
	var root: Node = packed.instantiate()
	add_child_autofree(root)

	var title: Label = root.get_node_or_null("Layout/TopBar/Row/TitleBox/Title") as Label
	assert_not_null(title, "S3 标题节点路径变了")
	if title != null:
		assert_eq(title.text, UiCopyGd.text(UiCopyGd.S3_TITLE), "标题没有从 UiCopy 填上")

	var filter_row: String = "Layout/Main/VBox/FilterRow"
	var latest: Button = root.get_node_or_null(filter_row + "/Tabs/Latest") as Button
	assert_not_null(latest, "S3 标签页节点路径变了")
	if latest != null:
		assert_eq(latest.text, UiCopyGd.text(UiCopyGd.S3_TAB_LATEST))

	var search: LineEdit = root.get_node_or_null(filter_row + "/Search") as LineEdit
	assert_not_null(search, "S3 搜索框节点路径变了")
	if search != null:
		assert_eq(search.placeholder_text, UiCopyGd.text(UiCopyGd.S3_SEARCH_PLACEHOLDER))


func test_card_fills_its_chrome_and_formats_plays() -> void:
	var packed: PackedScene = load(CARD_SCENE) as PackedScene
	assert_not_null(packed, "卡片场景必须能加载")
	if packed == null:
		return
	var card: Button = packed.instantiate() as Button
	add_child_autofree(card)
	card.set("plays", "1.2k")

	var action: Button = card.get_node_or_null("Margin/VBox/Footer/Action") as Button
	assert_not_null(action, "卡片动作按钮路径变了")
	if action != null:
		assert_eq(action.text, UiCopyGd.text(UiCopyGd.CARD_ACTION_EDIT_REUSE))

	var badge: Label = card.get_node_or_null("Margin/VBox/ThumbWrap/Badge/L") as Label
	assert_not_null(badge, "卡片徽标路径变了")
	if badge != null:
		assert_eq(badge.text, UiCopyGd.text(UiCopyGd.CARD_UNVERIFIED_BADGE))

	var plays: Label = card.get_node_or_null("Margin/VBox/Stats/Plays") as Label
	assert_not_null(plays, "卡片游玩次数路径变了")
	if plays != null:
		assert_eq(plays.text, UiCopyGd.text(UiCopyGd.CARD_PLAYS_COUNT) % "1.2k")
		assert_string_contains(plays.text, "1.2k")


func test_card_with_no_play_count_stays_empty() -> void:
	# "%s 次游玩" 套一个空串会渲染成孤零零的「次游玩」。这条钉住那个分支。
	var packed: PackedScene = load(CARD_SCENE) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var card: Button = packed.instantiate() as Button
	add_child_autofree(card)
	card.set("plays", "")

	var plays: Label = card.get_node_or_null("Margin/VBox/Stats/Plays") as Label
	assert_not_null(plays)
	if plays != null:
		assert_eq(plays.text, "", "没有次数时不应该只剩量词")


func test_demo_entries_are_not_in_the_locale_table() -> void:
	# 占位赛道名不得进本地化表：一旦进去就看起来像已定稿的产品文案，
	# 接线时还得再删一遍，而且中间任何一次「补全翻译」都会给假数据配上英文。
	var script: GDScript = load("res://src/client/ui/scripts/s3_workshop.gd") as GDScript
	assert_not_null(script, "S3 脚本必须能加载")
	if script == null:
		return
	var demo: Variant = script.get_script_constant_map().get("DEMO_ENTRIES")
	assert_eq(typeof(demo), TYPE_ARRAY, "DEMO_ENTRIES 不见了或改了名")
	if typeof(demo) != TYPE_ARRAY:
		return
	var entries: Array = demo
	assert_gt(entries.size(), 0, "占位数据为空，这条断言就没有对象了")

	var table_titles: Array[String] = []
	for key: String in UiCopyGd.ALL_KEYS:
		table_titles.append(UiCopyGd.text(key, "zh_CN"))
	for entry: Dictionary in entries:
		var title: String = str(entry["title"])
		assert_false(
			table_titles.has(title),
			"占位赛道名 %s 混进了本地化表" % title
		)
