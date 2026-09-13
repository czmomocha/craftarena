extends GutTest

## M4b chapter 4: public content plaza. Publish enters the list;
## four tabs; plays mark verified; rating tags reject free text;
## Solo starts from a signed SimulationBundle, not an AuthoringDocument.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const ContentCatalogGd := preload("res://src/ugc/content_catalog.gd")
const ContentPlazaGd := preload("res://src/ugc/content_plaza.gd")
const ContentPlazaEntryGd := preload("res://src/client/content_plaza_entry.gd")
const ContentSignGd := preload("res://src/ugc/content_sign.gd")
const MatchLobbyChromeGd := preload("res://src/client/match_lobby_chrome.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const MatchOfflineSessionGd := preload("res://src/client/match_offline_session.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const PIPE_ID: String = "ugc_pipe_01"
const PIPE_B: String = "ugc_pipe_02"


var _shell: MatchLobbyShellGd = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_display_name_matches_the_contract_word_bank() -> void:
	assert_eq(ContentPlazaGd.display_name(PIPE_ID), "warm_forge")
	assert_eq(ContentPlazaGd.display_name(PIPE_B), "quiet_lane")
	assert_eq(ContentPlazaGd.display_name(PIPE_ID), ContentPlazaGd.display_name(PIPE_ID))


func test_publish_enters_plaza_and_unverified_stays_off_verified_tab() -> void:
	var catalog: ContentCatalogGd = ContentCatalogGd.new()
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var published: Dictionary = _publish(catalog, PIPE_ID, bundle, 1)
	assert_true(_flag(published, ContentCatalogGd.KEY_OK, false))
	var newest: Dictionary = catalog.plaza.list_tab(ContentPlazaGd.TAB_NEWEST)
	assert_true(_flag(newest, ContentPlazaGd.KEY_OK, false))
	var items: Array = _items(newest)
	assert_eq(items.size(), 1)
	var item: Dictionary = _dict_at(items, 0)
	assert_eq(_text(item, "content_id"), PIPE_ID)
	assert_eq(_text(item, "display_name"), "warm_forge")
	assert_false(_flag(item, "verified", true))
	var tags: PackedStringArray = ContentPlazaGd.tags_from_bundle(bundle)
	assert_false(tags.is_empty())
	assert_eq(_tags(item), tags)
	var verified: Dictionary = catalog.plaza.list_tab(ContentPlazaGd.TAB_VERIFIED)
	assert_eq(_items(verified).size(), 0)


func test_record_play_marks_verified_and_free_text_tags_are_rejected() -> void:
	var catalog: ContentCatalogGd = ContentCatalogGd.new()
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	assert_true(_flag(_publish(catalog, PIPE_ID, bundle, 1), ContentCatalogGd.KEY_OK, false))
	var played: Dictionary = catalog.plaza.record_play(PIPE_ID, "match_a")
	assert_true(_flag(played, ContentPlazaGd.KEY_OK, false))
	assert_true(_flag(played, "verified", false))
	assert_eq(_int_of(played, "play_count"), 1)
	var again: Dictionary = catalog.plaza.record_play(PIPE_ID, "match_a")
	assert_false(_flag(again, ContentPlazaGd.KEY_OK, true))
	assert_eq(_text(again, ContentPlazaGd.KEY_REASON), ContentPlazaGd.REASON_PLAY_EXISTS)
	var verified: Dictionary = catalog.plaza.list_tab(ContentPlazaGd.TAB_VERIFIED)
	assert_eq(_items(verified).size(), 1)
	var rejected: Dictionary = catalog.plaza.rate(PIPE_ID, "rater_1", 5, PackedStringArray(["fun"]))
	assert_false(_flag(rejected, ContentPlazaGd.KEY_OK, true))
	assert_eq(_text(rejected, ContentPlazaGd.KEY_REASON), ContentPlazaGd.REASON_TAGS_INVALID)
	var ok_rate: Dictionary = catalog.plaza.rate(
		PIPE_ID, "rater_1", 4, PackedStringArray(["portal"])
	)
	assert_true(_flag(ok_rate, ContentPlazaGd.KEY_OK, false))
	assert_eq(_int_of(ok_rate, "rating_count"), 1)


func test_tabs_sort_plays_rating_and_newest() -> void:
	var plaza: ContentPlazaGd = ContentPlazaGd.new()
	var first: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_01)
	var second: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_02)
	plaza.index_listing(PIPE_ID, 1, "aa", first, "1")
	plaza.index_listing(PIPE_B, 1, "bb", second, "2")
	plaza.record_play(PIPE_ID, "m1")
	plaza.rate(PIPE_B, "r1", 5, PackedStringArray())
	assert_eq(_text(_dict_at(_items(plaza.list_tab(ContentPlazaGd.TAB_PLAYS)), 0), "content_id"), PIPE_ID)
	assert_eq(_text(_dict_at(_items(plaza.list_tab(ContentPlazaGd.TAB_RATING)), 0), "content_id"), PIPE_B)
	assert_eq(_text(_dict_at(_items(plaza.list_tab(ContentPlazaGd.TAB_NEWEST)), 0), "content_id"), PIPE_B)


func test_try_begin_bundle_starts_local_authority_without_a_document_path() -> void:
	var offline: MatchOfflineSessionGd = MatchOfflineSessionGd.new()
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_02)
	assert_true(offline.try_begin_bundle(bundle))
	assert_eq(offline.state, MatchOfflineSessionGd.STATE_PLAYING)
	assert_eq(offline.course_path, "")
	assert_true(offline.follow.has_snapshot)
	assert_eq(offline.session.player_count(), 1)
	assert_false(offline.allows_settlement())
	assert_false(offline.allows_online_writes())
	assert_false(offline.try_begin_bundle(bundle))
	assert_eq(offline.last_error, "busy")
	assert_true(offline.try_stop())
	assert_false(offline.try_begin_bundle(null))
	assert_eq(offline.last_error, "missing_course")


## The four tabs now come from the product screen (`s3_workshop.tscn`), so this
## asserts against that node layout instead of the hand-built row. What is being
## checked is unchanged: four tabs exist, an empty plaza says so, and the tab
## selection round-trips back into the entry's state.
func test_lobby_plaza_window_has_four_tabs_empty_list_and_returns() -> void:
	_shell = _open_shell()
	var button: Button = _shell.window.get_node(
		"VBoxContainer/MatchActions/%s" % MatchLobbyChromeGd.PLAZA_NAME
	) as Button
	assert_not_null(button)
	assert_eq(button.text, UiCopy.text(UiCopy.PLAZA))
	assert_true(_shell.try_open_plaza())
	assert_true(_shell.plaza.is_open())
	assert_false(_shell.window.visible)
	assert_eq(_shell.plaza.tab, ContentPlazaGd.TAB_NEWEST)
	assert_eq(_card_count(), 0)
	var empty: Label = _plaza_empty()
	assert_not_null(empty, "空态提示必须存在")
	if empty != null:
		assert_true(empty.visible)
		assert_eq(empty.text, UiCopy.text(UiCopy.PLAZA_EMPTY))
	for node_name: String in ["Latest", "Rating", "Plays", "Verified"]:
		assert_not_null(
			_shell.plaza.screen.get_node_or_null(
				"Layout/Main/VBox/FilterRow/Tabs/%s" % node_name
			),
			"S3 缺标签页 %s" % node_name
		)
	# The screen reflects the active tab; the entry owns which one it is.
	assert_eq(_active_tab(), ContentPlazaGd.TAB_NEWEST)
	assert_true(_shell.plaza.try_select_tab(ContentPlazaGd.TAB_VERIFIED))
	assert_eq(_shell.plaza.tab, ContentPlazaGd.TAB_VERIFIED)
	assert_eq(_active_tab(), ContentPlazaGd.TAB_VERIFIED)
	assert_true(_shell.try_close_plaza())
	assert_false(_shell.plaza.is_open())
	assert_true(_shell.window.visible)


## The design marks the active tab by swapping the theme variation. An earlier
## draft used `toggle_mode`, which paints the Button's own pressed style and
## renders the selected tab grey instead of the accent colour — invisible to
## every assertion that only looks at state.
func test_active_tab_uses_the_designed_variation() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_open_plaza())
	assert_eq(_tab_variation("Latest"), &"TabChipActive")
	assert_eq(_tab_variation("Verified"), &"TabChip")
	assert_true(_shell.plaza.try_select_tab(ContentPlazaGd.TAB_VERIFIED))
	assert_eq(_tab_variation("Latest"), &"TabChip")
	assert_eq(_tab_variation("Verified"), &"TabChipActive")


## Setting card properties before the node enters the tree must still render.
## Both this view and the card component used `@onready` plus an
## `is_node_ready()` bail-out, so a card built outside a running tree came out
## blank with no error — and the suite missed it, because `add_child` in a test
## makes `_ready` fire before the setters run.
func test_a_card_built_outside_the_tree_still_renders() -> void:
	var card: Button = preload(
		"res://src/client/ui/scenes/components/content_card.tscn"
	).instantiate() as Button
	card.set("card_title", "warm_forge")
	card.set("plays", "7")
	var title: Label = card.get_node_or_null("Margin/VBox/Title") as Label
	assert_not_null(title)
	if title != null:
		assert_eq(title.text, "warm_forge", "入树前赋的值被静默丢弃了")
	add_child_autofree(card)


## Pressing a tab in the screen must drive the entry, not just repaint itself.
## Without this the tabs would look alive and change nothing.
func test_pressing_a_screen_tab_drives_the_entry() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_open_plaza())
	var verified: Button = _shell.plaza.screen.get_node_or_null(
		"Layout/Main/VBox/FilterRow/Tabs/Verified"
	) as Button
	assert_not_null(verified)
	if verified == null:
		return
	verified.emit_signal("pressed")
	assert_eq(_shell.plaza.tab, ContentPlazaGd.TAB_VERIFIED)


## The screen's own Back button is a second route to the same exit as the
## stopgap action row's close button.
func test_screen_back_button_returns_to_the_lobby() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_open_plaza())
	assert_false(_shell.window.visible)
	var back: Button = _shell.plaza.screen.get_node_or_null("Layout/TopBar/Row/Back") as Button
	assert_not_null(back)
	if back == null:
		return
	back.emit_signal("pressed")
	assert_false(_shell.plaza.is_open())
	assert_true(_shell.window.visible)


## Sort / tag / search are drawn but `ContentPlaza` has no such queries. They
## must stay inert rather than look clickable — see ui-wiring.md.
func test_filters_without_backing_logic_are_disabled() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_open_plaza())
	var row: String = "Layout/Main/VBox/FilterRow"
	for node_name: String in ["Sort", "TagFilter"]:
		var dead: Button = _shell.plaza.screen.get_node_or_null(
			"%s/%s" % [row, node_name]
		) as Button
		assert_not_null(dead, node_name)
		if dead != null:
			assert_true(dead.disabled, "%s 没有后端逻辑，必须禁用" % node_name)
	var search: LineEdit = _shell.plaza.screen.get_node_or_null("%s/Search" % row) as LineEdit
	assert_not_null(search)
	if search != null:
		assert_false(search.editable, "搜索没有后端逻辑，必须只读")


## A listing row carries no author and no thumbnail, and players cannot upload
## textures at all this phase (CD-11 section 5). The card must degrade instead
## of inventing an attribution.
func test_cards_render_listing_rows_without_faking_author_or_thumbnail() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_open_plaza())
	_shell.plaza.apply_list(ContentPlazaGd.TAB_NEWEST, [{
		"content_id": PIPE_ID,
		"display_name": ContentPlazaGd.display_name(PIPE_ID),
		"tags": PackedStringArray(["portal"]),
		"play_count": 7,
		"rating_sum": 9,
		"rating_count": 2,
		"verified": true,
	}])
	assert_eq(_card_count(), 1)
	var card: Button = _card_for(PIPE_ID)
	assert_not_null(card, "列表行必须渲染成一张卡")
	if card == null:
		return
	assert_eq(str(card.get("card_title")), ContentPlazaGd.display_name(PIPE_ID))
	assert_eq(str(card.get("plays")), "7", "游玩次数必须是服务端的真实计数")
	assert_almost_eq(_card_score(card), 4.5, 0.01, "评分 = rating_sum / rating_count")
	assert_eq(str(card.get("author")), "", "列表行没有作者字段，不得编造")
	var thumb_raw: Variant = card.get("thumbnail")
	assert_eq(typeof(thumb_raw), TYPE_NIL, "UGC 不可能有缩略图：玩家不能上传贴图")

	var author: Label = card.get_node_or_null("Margin/VBox/Footer/Author") as Label
	assert_not_null(author)
	if author != null:
		assert_false(author.visible, "没有作者时整行要隐藏，不能只剩一个色点")


## Unrated content scores zero. That is the truth ("nobody rated this"), not a
## missing value, and it must not crash the average.
func test_unrated_listing_scores_zero_without_dividing_by_zero() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_open_plaza())
	_shell.plaza.apply_list(ContentPlazaGd.TAB_NEWEST, [{
		"content_id": PIPE_ID,
		"display_name": ContentPlazaGd.display_name(PIPE_ID),
		"tags": PackedStringArray(),
		"play_count": 0,
		"rating_sum": 0,
		"rating_count": 0,
		"verified": false,
	}])
	var card: Button = _card_for(PIPE_ID)
	assert_not_null(card)
	if card != null:
		assert_eq(_card_score(card), 0.0)
		assert_eq(str(card.get("plays")), "0")


## `Node.call()` hands back Variant, and this project treats unsafe Variant use
## as an error, so screen queries funnel through typed helpers.
func _card_count() -> int:
	var raw: Variant = _shell.plaza.screen.call("card_count")
	if typeof(raw) != TYPE_INT:
		return -1
	var count: int = raw
	return count


func _active_tab() -> String:
	return str(_shell.plaza.screen.call("active_tab"))


func _card_for(content_id: String) -> Button:
	var raw: Variant = _shell.plaza.screen.call("card_for", content_id)
	if raw is Button:
		var card: Button = raw
		return card
	return null


func _card_score(card: Button) -> float:
	var raw: Variant = card.get("score")
	if typeof(raw) == TYPE_FLOAT:
		var value: float = raw
		return value
	if typeof(raw) == TYPE_INT:
		var whole: int = raw
		return float(whole)
	return -1.0


func _tab_variation(node_name: String) -> StringName:
	var button: Button = _shell.plaza.screen.get_node_or_null(
		"Layout/Main/VBox/FilterRow/Tabs/%s" % node_name
	) as Button
	if button == null:
		return &""
	return button.theme_type_variation


func _plaza_empty() -> Label:
	return _shell.plaza.screen.get_node_or_null("Layout/Main/VBox/PlazaEmpty") as Label


func test_plaza_solo_applies_the_bound_bundle() -> void:
	_shell = _open_shell()
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_02)
	assert_true(_shell.try_open_plaza())
	_shell.plaza.bind_bundle(PIPE_ID, bundle)
	_shell.plaza.apply_list(ContentPlazaGd.TAB_NEWEST, [{
		"content_id": PIPE_ID,
		"display_name": ContentPlazaGd.display_name(PIPE_ID),
		"tags": ContentPlazaGd.tags_from_bundle(bundle),
		"verified": false,
	}])
	assert_eq(_card_count(), 1)
	assert_true(_shell.plaza.try_select_id(PIPE_ID))
	assert_true(_shell.try_solo_plaza())
	assert_eq(_shell.offline.state, MatchOfflineSessionGd.STATE_PLAYING)
	assert_eq(_shell.offline.course_path, "")
	assert_false(_shell.plaza.is_open())
	assert_true(_shell.window.visible)
	assert_eq(_shell.map.player_count(), 1)
	assert_false(_shell.try_quick())
	assert_true(_shell.try_stop_offline())
	assert_eq(_shell.offline.state, MatchOfflineSessionGd.STATE_IDLE)


func test_plaza_http_list_and_latest_bundle_start_solo() -> void:
	_shell = _open_shell()
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_02)
	var latest: Dictionary = {
		"content_id": PIPE_ID,
		"version": 1,
		"content_hash": "aa",
		"signature": "bb",
		"bundle": bundle.to_dictionary(),
	}
	assert_true(_shell.try_open_plaza())
	_shell.plaza.on_fetch_list = func(_tab: String) -> Dictionary:
		return {
			"tab": ContentPlazaGd.TAB_NEWEST,
			"items": [{
				"content_id": PIPE_ID,
				"display_name": ContentPlazaGd.display_name(PIPE_ID),
				"tags": ContentPlazaGd.tags_from_bundle(bundle),
				"verified": false,
			}],
		}
	_shell.plaza.on_fetch_latest = func(content_id: String) -> Dictionary:
		assert_eq(content_id, PIPE_ID)
		return latest
	assert_true(_shell.plaza.try_select_tab(ContentPlazaGd.TAB_NEWEST))
	assert_eq(_card_count(), 1)
	assert_true(_shell.plaza.try_select_id(PIPE_ID))
	assert_null(_shell.plaza.bundle_of(PIPE_ID))
	assert_true(_shell.try_solo_plaza())
	assert_eq(_shell.offline.state, MatchOfflineSessionGd.STATE_PLAYING)
	assert_eq(_shell.offline.course_path, "")
	assert_false(_shell.plaza.is_open())
	assert_true(_shell.try_stop_offline())


func test_plaza_create_room_sends_pinned_content() -> void:
	_shell = _open_shell()
	var bundle: SimulationBundleGd = _compile(OfficialTraprushCoursesGd.COURSE_02)
	assert_true(_shell.try_open_plaza())
	# STOPGAP_ACTIONS: the designed screen has no Create room button, so the
	# original action row is still built in code below it. Same node name,
	# so this assertion is unchanged apart from the row's parent path.
	var create: Button = _shell.plaza.window.get_node("VBoxContainer/%s/%s" % [
		ContentPlazaEntryGd.ACTION_ROW_NAME, ContentPlazaEntryGd.CREATE_ROOM_NAME
	]) as Button
	assert_not_null(create)
	assert_eq(create.text, UiCopy.text(UiCopy.PLAZA_CREATE_ROOM))
	_shell.plaza.bind_bundle(PIPE_ID, bundle)
	_shell.plaza.apply_list(ContentPlazaGd.TAB_NEWEST, [{
		"content_id": PIPE_ID,
		"version": 3,
		"display_name": ContentPlazaGd.display_name(PIPE_ID),
		"tags": ContentPlazaGd.tags_from_bundle(bundle),
		"verified": false,
	}])
	assert_true(_shell.plaza.try_select_id(PIPE_ID))
	assert_eq(_shell.plaza.selected_version(), 3)
	assert_true(_shell.plaza.try_create_room_selected())
	assert_eq(_shell.join.pending_path(), "/matchmaking/rooms")
	assert_true(_shell.join.pending_body().contains(PIPE_ID))
	assert_true(_shell.join.pending_body().contains("\"version\":3"))
	assert_false(_shell.join.pending_body().contains("course"))
	assert_false(_shell.plaza.is_open())
	assert_true(_shell.window.visible)


func _open_shell() -> MatchLobbyShellGd:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	add_child(shell)
	assert_true(shell.open())
	return shell


func _publish(
	catalog: ContentCatalogGd,
	content_id: String,
	bundle: SimulationBundleGd,
	version: int
) -> Dictionary:
	var signed: Dictionary = ContentSignGd.sign(content_id, version, bundle, ContentSignGd.dev_key())
	return catalog.publish({
		ContentSignGd.KEY_SCHEMA_VERSION: signed[ContentSignGd.KEY_SCHEMA_VERSION],
		ContentSignGd.KEY_CONTENT_ID: signed[ContentSignGd.KEY_CONTENT_ID],
		ContentSignGd.KEY_VERSION: signed[ContentSignGd.KEY_VERSION],
		ContentSignGd.KEY_CONTENT_HASH: signed[ContentSignGd.KEY_CONTENT_HASH],
		ContentSignGd.KEY_SIGNATURE: signed[ContentSignGd.KEY_SIGNATURE],
	}, bundle, ContentSignGd.dev_key())


func _compile(course_id: String) -> SimulationBundleGd:
	var path: String = OfficialTraprushCoursesGd.document_path(course_id)
	var world: AuthoringWorldGd = AuthoringDocumentGd.load_from_path(path)
	assert_not_null(world, path)
	var bundle: SimulationBundleGd = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle, path)
	return bundle


func _flag(result: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = result.get(key, fallback)
	return raw == true


func _text(result: Dictionary, key: String) -> String:
	return str(result.get(key, ""))


func _int_of(result: Dictionary, key: String) -> int:
	var raw: Variant = result.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	var value: int = raw
	return value


func _items(listed: Dictionary) -> Array:
	var raw: Variant = listed.get(ContentPlazaGd.KEY_ITEMS, [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	var items: Array = raw
	return items


func _dict_at(items: Array, index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var raw: Variant = items[index]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func _tags(item: Dictionary) -> PackedStringArray:
	var raw: Variant = item.get("tags", PackedStringArray())
	if raw is PackedStringArray:
		return raw
	var tags: PackedStringArray = PackedStringArray()
	if typeof(raw) == TYPE_ARRAY:
		for entry: Variant in raw:
			tags.append(str(entry))
	return tags
