extends Control
## S3 public workshop grid (spec 3).
##
## The grid is data-driven: it instantiates scenes/components/content_card.tscn
## once per entry, so adding content never means editing the scene tree.
##
## Data rules from the spec that this scene honours:
##   * titles come from a fixed word bank (词库A·词库B), never free text
##   * tags are whitelisted structured values
##   * unverified entries are marked and keep their edit/reuse action disabled

const CARD_SCENE := preload("res://src/client/ui/scenes/components/content_card.tscn")
const THUMB_DIR := "res://content/ui/assets/%s.png"

# Placeholder grid content, NOT product copy. These stand in for the control
# plane's listing response until this screen is wired (UI wiring batch 1,
# CD-61 section 2 M-Art), and they get deleted then — hence DEMO_, so nobody
# mistakes them for something to translate. Deliberately absent from
# content/locale/craft_arena.csv: a fake course name in the locale table looks
# like signed-off product copy and has to be removed again later.
#
# `plays` holds the number only; the unit comes from craft_arena.card.plays_count.
#
# Data rules (spec 3) that the real listing must also honour: titles come from
# the word bank, tags are whitelisted, unverified entries keep their edit/reuse
# action disabled.
const DEMO_ENTRIES: Array[Dictionary] = [
	{
		"title": "熔岩回廊·疾走段", "thumb": "card_lava_express",
		"tags": ["竞速", "短程"], "author": "Nova", "color": Color(0.85098, 0.211765, 0.419608),
		"score": 4.8, "plays": "1.2k", "verified": true,
	},
	{
		"title": "云端断梯·连跳段", "thumb": "card_cloud_ladder",
		"tags": ["跳跃", "传送"], "author": "阿凯", "color": Color(0.949019, 0.47451, 0.184314),
		"score": 4.5, "plays": "1.8k", "verified": true,
	},
	{
		"title": "齿轮迷城·回旋段", "thumb": "card_gear_maze",
		"tags": ["机关", "中阶"], "author": "Sprite", "color": Color(0.239216, 0.85098, 0.482353),
		"score": 3.9, "plays": "642", "verified": false,
	},
	{
		"title": "夜光矿道·俯冲段", "thumb": "card_glowmine_dive",
		"tags": ["竞速", "破坏"], "author": "Maker_042", "color": Color(0.207843, 0.709804, 0.658824),
		"score": 4.2, "plays": "956", "verified": true,
	},
	{
		"title": "锯齿车间·窄桥段", "thumb": "card_sawmill_bridge",
		"tags": ["高阶", "机关"], "author": "Taro", "color": Color(0.541176, 0.568627, 0.627451),
		"score": 4.0, "plays": "433", "verified": true,
	},
	{
		"title": "镜湖回环·传送段", "thumb": "card_mirror_loop",
		"tags": ["迷惑", "传送"], "author": "Luna", "color": Color(0.243137, 0.560784, 0.639216),
		"score": 4.7, "plays": "1.1k", "verified": true,
	},
	{
		"title": "熔岩回廊·逃生段", "thumb": "card_lava_escape",
		"tags": ["破坏", "短程"], "author": "Nova", "color": Color(0.85098, 0.211765, 0.419608),
		"score": 3.6, "plays": "287", "verified": true,
	},
	{
		"title": "风蚀高塔·登顶段", "thumb": "card_wind_tower",
		"tags": ["跳跃", "高阶"], "author": "Kenji", "color": Color(0.909804, 0.639216, 0.239216),
		"score": 4.4, "plays": "715", "verified": false,
	},
]

const _FILTER_ROW := "Layout/Main/VBox/FilterRow"

@onready var _grid: GridContainer = $Layout/Main/VBox/Grid


func _ready() -> void:
	_apply_copy()
	_populate()


## Chrome text lives in the locale table, not in the scene: the .tscn labels ship
## empty and are filled here (human decision 2026-09-13). A key that never gets
## assigned therefore shows up as a blank label instead of quietly keeping a
## Chinese string that no translator can reach.
func _apply_copy() -> void:
	_set_text("Layout/TopBar/Row/TitleBox/Title", UiCopy.S3_TITLE)
	_set_text(_FILTER_ROW + "/Tabs/Latest", UiCopy.S3_TAB_LATEST)
	_set_text(_FILTER_ROW + "/Tabs/Rating", UiCopy.S3_TAB_RATING)
	_set_text(_FILTER_ROW + "/Tabs/Plays", UiCopy.S3_TAB_PLAYS)
	_set_text(_FILTER_ROW + "/Tabs/Verified", UiCopy.S3_TAB_VERIFIED)
	_set_text(_FILTER_ROW + "/Sort", UiCopy.S3_SORT)
	_set_text(_FILTER_ROW + "/TagFilter", UiCopy.S3_TAG_FILTER)
	_set_text("Layout/Main/VBox/Note", UiCopy.S3_NOTE)

	var search: LineEdit = get_node_or_null(_FILTER_ROW + "/Search") as LineEdit
	if search != null:
		search.placeholder_text = UiCopy.text(UiCopy.S3_SEARCH_PLACEHOLDER)


## Label and Button share no common base that carries `text`, so the assignment
## is split rather than routed through `set()` — the project treats unsafe
## property access as an error (constitution article 23).
func _set_text(path: String, key: String) -> void:
	var node: Node = get_node_or_null(path)
	var value: String = UiCopy.text(key)
	if node is Label:
		(node as Label).text = value
	elif node is Button:
		(node as Button).text = value


func _populate() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()

	# The card component is addressed through set() rather than typed property
	# access so this file stays clean under the project's strict-GDScript
	# warnings (unsafe_property_access is treated as an error here).
	for entry: Dictionary in DEMO_ENTRIES:
		# Typed locals first: Dictionary lookups return Variant, and Craft Arena
		# treats unsafe Variant->primitive conversions as compile errors.
		var tag_values: Array = entry["tags"]
		var score_value: float = entry["score"]
		var verified_value: bool = entry["verified"]

		var card: Button = CARD_SCENE.instantiate() as Button
		_grid.add_child(card)
		card.set("thumbnail", load(THUMB_DIR % str(entry["thumb"])))
		card.set("card_title", str(entry["title"]))
		card.set("tags", PackedStringArray(tag_values))
		card.set("author", str(entry["author"]))
		card.set("author_color", entry["color"])
		card.set("score", score_value)
		card.set("plays", str(entry["plays"]))
		card.set("verified", verified_value)
