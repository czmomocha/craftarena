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
	assert_true(_shell.plaza.empty.visible)
	assert_eq(_shell.plaza.empty.text, UiCopy.text(UiCopy.PLAZA_EMPTY))
	assert_eq(_shell.plaza.list.item_count, 0)
	assert_not_null(_shell.plaza.window.get_node("VBoxContainer/%s/%s" % [
		ContentPlazaEntryGd.TAB_ROW_NAME, ContentPlazaEntryGd.NEWEST_NAME
	]))
	assert_not_null(_shell.plaza.window.get_node("VBoxContainer/%s/%s" % [
		ContentPlazaEntryGd.TAB_ROW_NAME, ContentPlazaEntryGd.RATING_NAME
	]))
	assert_not_null(_shell.plaza.window.get_node("VBoxContainer/%s/%s" % [
		ContentPlazaEntryGd.TAB_ROW_NAME, ContentPlazaEntryGd.PLAYS_NAME
	]))
	assert_not_null(_shell.plaza.window.get_node("VBoxContainer/%s/%s" % [
		ContentPlazaEntryGd.TAB_ROW_NAME, ContentPlazaEntryGd.VERIFIED_NAME
	]))
	assert_true(_shell.plaza.try_select_tab(ContentPlazaGd.TAB_VERIFIED))
	assert_eq(_shell.plaza.tab, ContentPlazaGd.TAB_VERIFIED)
	assert_true(_shell.try_close_plaza())
	assert_false(_shell.plaza.is_open())
	assert_true(_shell.window.visible)


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
	assert_false(_shell.plaza.empty.visible)
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
