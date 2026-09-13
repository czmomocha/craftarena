extends Control
## S3 public workshop grid (spec 3), driven as the content plaza's view.
##
## Two modes, deliberately:
##   * standalone — `_ready()` fills the grid with DEMO_ENTRIES so the screen can
##     be rendered for review before anything is wired (tools/ui/screenshot.gd);
##   * driven — `content_plaza_entry.gd` sets `demo_content = false` and pushes
##     real listing rows through `set_listing()`.
##
## The view owns no state worth keeping: it renders what it is handed and emits
## intent. Tab membership, selection, HTTP and bundle resolution all stay in
## `ContentPlazaEntry` — this file must not start deciding what is in the list.

const CARD_SCENE := preload("res://src/client/ui/scenes/components/content_card.tscn")
const THUMB_DIR := "res://content/ui/assets/%s.png"

## Emitted when a tab button is pressed. Carries the plaza tab id, not the node
## name, so the entry never has to know about this scene's node layout.
signal tab_requested(tab: String)

## Emitted when a card is pressed. Selection state lives in the entry.
signal content_selected(content_id: String)

signal back_requested()

## Standalone preview shows placeholder content; the plaza clears this before
## the node enters the tree.
@export var demo_content: bool = true

# Placeholder grid content, NOT product copy and NOT a data contract. Stands in
# for the control plane's listing response when this screen is rendered on its
# own. Deliberately absent from content/locale/craft_arena.csv: a fake course
# name in the locale table looks like signed-off product copy.
#
# `plays` holds the number only; the unit comes from craft_arena.card.plays_count.
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
const _TABS := _FILTER_ROW + "/Tabs"

## Scene node name -> plaza tab id. The scene was drawn before the plaza
## existed, so the names do not match the contract's ids; this table is the
## only place that mismatch is allowed to live.
const TAB_NODES: Dictionary = {
	"Latest": "newest",
	"Rating": "rating",
	"Plays": "plays",
	"Verified": "verified",
}

## Copy keys, same order as TAB_NODES.
const TAB_COPY: Dictionary = {
	"Latest": UiCopy.S3_TAB_LATEST,
	"Rating": UiCopy.S3_TAB_RATING,
	"Plays": UiCopy.S3_TAB_PLAYS,
	"Verified": UiCopy.S3_TAB_VERIFIED,
}

## Shown instead of the grid when a tab has nothing in it. The scene has no
## empty-state node — the mockup never drew one — so it is built here rather
## than added to the .tscn, keeping the designed file untouched.
const EMPTY_NAME: StringName = &"PlazaEmpty"

## Filters with no backing logic. `ContentPlaza` sorts by tab and nothing else:
## there is no within-tab sort, no tag filter and no search. They stay visible
## because removing them would edit the design, but they are disabled — an
## enabled control that silently does nothing is worse than a greyed-out one.
const DEAD_CONTROLS: Array[String] = ["Sort", "TagFilter", "Search"]

## How the design marks the selected tab. Both variations are declared in
## craft_arena.tres and checked by validate_theme.gd.
const TAB_VARIATION: StringName = &"TabChip"
const TAB_ACTIVE_VARIATION: StringName = &"TabChipActive"

var _active_tab: String = ""
var _empty: Label = null
var _cards: Dictionary = {}
var _chrome_ready: bool = false

## Deliberately not `@onready`. `PackedScene.instantiate()` builds the whole node
## tree, so this resolves the moment the scene exists — whereas an `@onready`
## field stays null until `_ready`, and every public method below would silently
## do nothing when called before that.
##
## That is not hypothetical: driving this view from `SceneTree._initialize()`
## produced an empty grid with no error, while the GUT suite stayed green
## because there `add_child` happens inside an already-running tree and `_ready`
## fires immediately. A view whose API depends on tree timing is a trap.
func _grid_node() -> GridContainer:
	return get_node_or_null("Layout/Main/VBox/Grid") as GridContainer


func _ready() -> void:
	_ensure_chrome()
	if demo_content:
		_populate_demo()


## Idempotent, and called from every public entry point rather than only from
## `_ready`, for the reason above.
func _ensure_chrome() -> void:
	if _chrome_ready:
		return
	_chrome_ready = true
	_apply_copy()
	_wire_chrome()


## Chrome text lives in the locale table, not in the scene: the .tscn labels ship
## empty and are filled here (human decision 2026-09-13). A key that never gets
## assigned therefore shows up as a blank label instead of quietly keeping a
## Chinese string that no translator can reach.
func _apply_copy() -> void:
	_set_text("Layout/TopBar/Row/TitleBox/Title", UiCopy.S3_TITLE)
	for node_name: String in TAB_COPY:
		_set_text("%s/%s" % [_TABS, node_name], str(TAB_COPY[node_name]))
	_set_text(_FILTER_ROW + "/Sort", UiCopy.S3_SORT)
	_set_text(_FILTER_ROW + "/TagFilter", UiCopy.S3_TAG_FILTER)
	_set_text("Layout/Main/VBox/Note", UiCopy.S3_NOTE)

	var search: LineEdit = get_node_or_null(_FILTER_ROW + "/Search") as LineEdit
	if search != null:
		search.placeholder_text = UiCopy.text(UiCopy.S3_SEARCH_PLACEHOLDER)


func _wire_chrome() -> void:
	for node_name: String in TAB_NODES:
		var button: Button = get_node_or_null("%s/%s" % [_TABS, node_name]) as Button
		if button == null:
			continue
		var tab_id: String = str(TAB_NODES[node_name])
		button.pressed.connect(func() -> void: tab_requested.emit(tab_id))

	var back: Button = get_node_or_null("Layout/TopBar/Row/Back") as Button
	if back != null:
		back.pressed.connect(func() -> void: back_requested.emit())

	for node_name: String in DEAD_CONTROLS:
		var dead: Control = get_node_or_null("%s/%s" % [_FILTER_ROW, node_name]) as Control
		if dead is Button:
			(dead as Button).disabled = true
		elif dead is LineEdit:
			(dead as LineEdit).editable = false

	_empty = Label.new()
	_empty.name = EMPTY_NAME
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.visible = false
	var vbox: VBoxContainer = get_node_or_null("Layout/Main/VBox") as VBoxContainer
	if vbox != null:
		vbox.add_child(_empty)


## Label and Button share no base carrying `text`, so the assignment is split
## rather than routed through `set()` — unsafe property access is an error here
## (constitution article 23).
func _set_text(path: String, key: String) -> void:
	var node: Node = get_node_or_null(path)
	var value: String = UiCopy.text(key)
	if node is Label:
		(node as Label).text = value
	elif node is Button:
		(node as Button).text = value


func active_tab() -> String:
	return _active_tab


## Swaps the theme variation, which is how the design expresses an active tab
## (`TabChipActive` vs `TabChip`, see craft_arena.tres). Not `toggle_mode`:
## a toggled Button paints its own pressed style and the tab ends up grey
## instead of the design's accent colour.
##
## Which tab is *current* stays the entry's business; this only reflects it, so
## the two can never disagree about what the list is showing.
func set_active_tab(tab: String) -> void:
	_ensure_chrome()
	_active_tab = tab
	for node_name: String in TAB_NODES:
		var button: Button = get_node_or_null("%s/%s" % [_TABS, node_name]) as Button
		if button == null:
			continue
		var active: bool = str(TAB_NODES[node_name]) == tab
		button.theme_type_variation = TAB_ACTIVE_VARIATION if active else TAB_VARIATION


func set_empty_notice(text: String) -> void:
	_ensure_chrome()
	if _empty == null:
		return
	_empty.text = text
	_empty.visible = text != ""


func card_count() -> int:
	return _cards.size()


func card_for(content_id: String) -> Button:
	var raw: Variant = _cards.get(content_id, null)
	if raw is Button:
		var card: Button = raw
		return card
	return null


## Renders plaza listing rows (`content_plaza.gd` `index_listing` shape).
##
## Three fields the card was drawn for do not exist in that contract and are NOT
## invented here:
##   * thumbnail — players cannot upload textures at all (CD-11 section 5), so
##     UGC can never carry a preview image this phase. The slot stays empty.
##   * author — listing rows have no author field. The name and its colour dot
##     are hidden rather than filled with the content id, which would read as an
##     attribution the server never made.
##   * score — derived from rating_sum / rating_count, 0 when unrated. Zero
##     stars is the truth for "nobody has rated this", not a missing value.
func set_listing(rows: Array) -> void:
	_ensure_chrome()
	demo_content = false
	_clear_cards()
	var grid: GridContainer = _grid_node()
	if grid == null:
		return
	for raw: Variant in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		var content_id: String = str(row.get("content_id", ""))
		if content_id == "":
			continue
		var card: Button = CARD_SCENE.instantiate() as Button
		grid.add_child(card)
		card.set("card_title", str(row.get("display_name", content_id)))
		card.set("tags", _tags_of(row))
		card.set("author", "")
		card.set("score", _score_of(row))
		card.set("plays", _plays_of(row))
		card.set("verified", row.get("verified", false) == true)
		card.pressed.connect(func() -> void: content_selected.emit(content_id))
		_cards[content_id] = card


func _populate_demo() -> void:
	_clear_cards()
	var grid: GridContainer = _grid_node()
	if grid == null:
		return
	for entry: Dictionary in DEMO_ENTRIES:
		# Typed locals first: Dictionary lookups return Variant, and Craft Arena
		# treats unsafe Variant->primitive conversions as compile errors.
		var tag_values: Array = entry["tags"]
		var score_value: float = entry["score"]
		var verified_value: bool = entry["verified"]

		var card: Button = CARD_SCENE.instantiate() as Button
		grid.add_child(card)
		card.set("thumbnail", load(THUMB_DIR % str(entry["thumb"])))
		card.set("card_title", str(entry["title"]))
		card.set("tags", PackedStringArray(tag_values))
		card.set("author", str(entry["author"]))
		card.set("author_color", entry["color"])
		card.set("score", score_value)
		card.set("plays", str(entry["plays"]))
		card.set("verified", verified_value)


## Synchronous free, not `queue_free`. The rebuild has to be done by the time
## this returns — the entry calls `card_for()` immediately afterwards — and a
## detached node waiting on a deferred free never gets collected in a headless
## run, which showed up as 90 orphans the first time this was written.
##
## Safe here because nothing in the grid can be mid-signal: cards only emit
## `content_selected`, which sets an id and never rebuilds. Tab buttons do
## trigger a rebuild, but they live in the filter row, not the grid.
func _clear_cards() -> void:
	var grid: GridContainer = _grid_node()
	if grid == null:
		return
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.free()
	_cards.clear()


func _tags_of(row: Dictionary) -> PackedStringArray:
	var raw: Variant = row.get("tags", PackedStringArray())
	if raw is PackedStringArray:
		var packed: PackedStringArray = raw
		return packed
	var tags: PackedStringArray = PackedStringArray()
	if typeof(raw) == TYPE_ARRAY:
		var values: Array = raw
		for value: Variant in values:
			tags.append(str(value))
	return tags


func _score_of(row: Dictionary) -> float:
	var count: int = _int_of(row, "rating_count")
	if count <= 0:
		return 0.0
	return float(_int_of(row, "rating_sum")) / float(count)


## Plain integer, no "1.2k" abbreviation: rounding a real play count to make it
## look like the mockup would be inventing precision the server did not send.
func _plays_of(row: Dictionary) -> String:
	return str(_int_of(row, "play_count"))


func _int_of(row: Dictionary, key: String) -> int:
	var raw: Variant = row.get(key, 0)
	if typeof(raw) == TYPE_INT:
		var value: int = raw
		return value
	if typeof(raw) == TYPE_FLOAT:
		var number: float = raw
		return int(number)
	return 0
