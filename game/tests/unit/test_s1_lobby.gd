extends GutTest

## F1: S1 main lobby is the landing view. MatchLobbyShell public verbs stay.

const MatchLobbyChromeGd := preload("res://src/client/match_lobby_chrome.gd")
const MatchLobbyHomeGd := preload("res://src/client/match_lobby_home.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const MatchGameplayGd := preload("res://src/shared/match_gameplay.gd")
const OfficialBastionBlueprintsGd := preload("res://src/shared/official_bastion_blueprints.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const UiCopyGd := preload("res://src/shared/ui_copy.gd")
const UiCopyS1Gd := preload("res://src/shared/ui_copy_s1.gd")

const S1_SCENE: String = "res://src/client/ui/scenes/s1_lobby.tscn"
const _BASTION := "Layout/Main/Columns/Left/BastionCard"
const _TRAPRUSH := "Layout/Main/Columns/Left/TraprushCard"
const _NAV := "Layout/Main/Columns/NavColumn"

var _shell: MatchLobbyShellGd = null


func before_each() -> void:
	UiCopyGd.reset_for_tests()
	assert_true(UiCopyGd.ensure_loaded())


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null


func test_bastion_card_is_open_and_has_no_lock_overlay() -> void:
	var root: Control = _instantiate_s1()
	var card: Button = root.get_node_or_null(_BASTION) as Button
	assert_not_null(card)
	if card != null:
		assert_false(card.disabled, "BASTION 卡必须从即将推出改成开放态")
	var overlay: CanvasItem = root.get_node_or_null(_BASTION + "/Overlay") as CanvasItem
	assert_not_null(overlay)
	if overlay != null:
		assert_false(overlay.visible)
	var cta: Button = root.get_node_or_null(_BASTION + "/Content/VBox/CTA") as Button
	assert_not_null(cta)
	if cta != null:
		assert_false(cta.disabled)
		assert_eq(cta.text, UiCopyGd.text(UiCopyS1Gd.ENTER))
	var chip: Label = root.get_node_or_null(_BASTION + "/Content/VBox/ChipRow/ComingChip/Label") as Label
	assert_not_null(chip)
	if chip != null:
		assert_eq(chip.text, UiCopyGd.text(UiCopyS1Gd.CHIP_OPEN))
		assert_false(chip.text.contains("🔒"))


func test_character_nav_is_enabled_and_my_content_stays_disabled() -> void:
	var root: Control = _instantiate_s1()
	var character: Button = root.get_node_or_null("%s/NavCharacter" % _NAV) as Button
	assert_not_null(character)
	if character != null:
		assert_false(character.disabled, "角色选择本刀必须能点")
		assert_true(character.visible)
	var mine: Button = root.get_node_or_null("%s/NavMyContent" % _NAV) as Button
	assert_not_null(mine, "我的内容被删了；设计里的项应留下并禁用")
	if mine != null:
		assert_true(mine.disabled)
		assert_true(mine.visible)


func test_open_still_shows_the_match_window_public_api() -> void:
	_shell = _open_shell()
	assert_true(_shell.is_window_visible())
	assert_false(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_not_null(_shell.home_screen, "open() 必须挂上 S1，即使默认先显示频道窗")
	assert_not_null(
		_shell.window.get_node("VBoxContainer/MatchActions/%s" % MatchLobbyShellGd.QUICK_NAME)
	)
	assert_not_null(_shell.window.get_node_or_null("WindowSizeHud"))
	assert_true(_action_visible(MatchLobbyChromeGd.HOME_NAME))


func test_show_home_hides_the_match_window() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_show_home())
	assert_true(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_false(_shell.is_window_visible())


func test_home_after_solo_finish_resets_channel_to_preview() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_enter_channel(MatchGameplayGd.TRAPRUSH))
	assert_true(_shell.try_solo())
	_shell.offline.skip_opening_countdown()
	assert_true(_shell.offline_playing())
	var steps: int = 0
	while steps < 200:
		assert_false(_shell.try_sample_play_move(false, false, false, true).is_empty())
		if _shell.offline.session.player_finish_tick(0) >= 0:
			break
		steps += 1
	assert_gte(_shell.offline.session.player_finish_tick(0), 0)
	assert_true(_shell.try_show_home())
	assert_false(_shell.offline_playing(), "返回大厅必须结束单人局，不能还停在冲线后的会话里")
	assert_true(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_true(_shell.try_enter_channel(MatchGameplayGd.TRAPRUSH))
	assert_false(_shell.offline_playing())
	assert_false(_shell.status_label_text().contains("result="))
	assert_true(_shell.is_window_visible())


func test_enter_traprush_restores_channel_chrome_and_quick_play() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_show_home())
	assert_true(_shell.try_enter_channel(MatchGameplayGd.TRAPRUSH))
	assert_false(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_true(_shell.is_window_visible())
	assert_eq(_shell.selected_course_id(), OfficialTraprushCoursesGd.DEFAULT_ID)
	assert_true(_action_visible(MatchLobbyChromeGd.SOLO_NAME))
	assert_true(_action_visible(MatchLobbyChromeGd.CREATOR_NAME))
	var course: OptionButton = _shell.window.find_child(MatchLobbyChromeGd.COURSE_ID_NAME, true, false)
	assert_not_null(course)
	assert_eq(course.get_item_count(), OfficialTraprushCoursesGd.all_document_ids().size())
	assert_false(course.disabled)
	assert_true(_shell.try_quick())
	assert_true(_shell.join.pending_body().contains("course_01"))


func test_enter_bastion_pins_blueprint_and_hides_traprush_only_actions() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_enter_channel(MatchGameplayGd.BASTION))
	assert_true(_shell.is_window_visible())
	assert_eq(_shell.selected_course_id(), OfficialBastionBlueprintsGd.DEFAULT_ID)
	assert_eq(_shell.selected_seats(), 2)
	assert_false(_action_visible(MatchLobbyChromeGd.SOLO_NAME))
	assert_false(_action_visible(MatchLobbyChromeGd.CREATOR_NAME))
	assert_true(_action_visible(MatchLobbyChromeGd.QUICK_NAME))
	assert_true(_action_visible(MatchLobbyChromeGd.HOME_NAME))
	var course: OptionButton = _shell.window.find_child(MatchLobbyChromeGd.COURSE_ID_NAME, true, false)
	assert_not_null(course)
	assert_eq(course.get_item_count(), 1)
	assert_eq(course.get_item_text(0), OfficialBastionBlueprintsGd.DEFAULT_ID)
	assert_true(course.disabled)
	assert_true(_shell.try_quick())
	assert_true(_shell.join.pending_body().contains("blueprint_01"))


func test_channel_back_home_button_returns_to_s1() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_enter_channel(MatchGameplayGd.TRAPRUSH))
	var home: Button = _shell.window.get_node_or_null(
		"VBoxContainer/MatchActions/%s" % MatchLobbyChromeGd.HOME_NAME
	) as Button
	assert_not_null(home)
	if home == null:
		return
	assert_true(home.visible)
	assert_eq(home.text, UiCopyGd.text(UiCopyGd.BACK_TO_LOBBY))
	assert_eq(home.focus_mode, Control.FOCUS_NONE)
	home.pressed.emit()
	assert_false(_shell.is_window_visible())
	assert_true(MatchLobbyHomeGd.is_home_visible(_shell))


func test_channel_close_returns_to_home() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_enter_channel(MatchGameplayGd.TRAPRUSH))
	assert_true(_shell.is_window_visible())
	_shell.window.close_requested.emit()
	assert_false(_shell.is_window_visible())
	assert_true(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_true(_shell.show_window())
	assert_true(_shell.is_window_visible())
	assert_false(MatchLobbyHomeGd.is_home_visible(_shell), "show_window 不得把 S1 叠在频道窗上面")


func test_plaza_from_home_returns_to_home() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_show_home())
	assert_true(_shell.try_open_plaza())
	assert_true(_shell.plaza.is_open())
	assert_false(_shell.is_window_visible())
	assert_false(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_true(_shell.try_close_plaza())
	assert_false(_shell.plaza.is_open())
	assert_true(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_false(_shell.is_window_visible(), "从主大厅进广场再返回，不该弹出频道窗")


func test_unknown_gameplay_is_rejected() -> void:
	_shell = _open_shell()
	assert_false(_shell.try_enter_channel("unknown"))
	assert_true(_shell.is_window_visible())


func test_s1_built_outside_the_tree_still_fills_copy() -> void:
	var packed: PackedScene = load(S1_SCENE) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var root: Control = packed.instantiate() as Control
	assert_not_null(root)
	if root == null:
		return
	root.set("name", "DetachedS1")
	root.call("_ensure_chrome")
	var title: Label = root.get_node_or_null(_TRAPRUSH + "/Content/VBox/Title") as Label
	assert_not_null(title)
	if title != null:
		assert_eq(title.text, UiCopyGd.text(UiCopyS1Gd.TRAPRUSH_TITLE))
	root.free()


func _instantiate_s1() -> Control:
	var packed: PackedScene = load(S1_SCENE) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return null
	var root: Control = packed.instantiate() as Control
	add_child_autofree(root)
	return root


func _open_shell() -> MatchLobbyShellGd:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	add_child(shell)
	assert_true(shell.open())
	return shell


func _action_visible(node_name: String) -> bool:
	var button: Button = _shell.window.get_node_or_null(
		"VBoxContainer/MatchActions/%s" % node_name
	) as Button
	return button != null and button.visible
