extends GutTest

## 可玩性深化 轨 3 / M-Export「Web 轻量 Edit」：玩家包里的创作入口。
## 写路径仍是 AuthoringSession + 三个已有 EDIT op；本文件只守 surface 分级、
## 入口开关与「打开就并排 Preview」。

const CreatorEntryGd := preload("res://src/client/creator_entry.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const AuthoringSurfaceNamesGd := preload("res://src/creator/authoring_surface_names.gd")
const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const ContentSubmitHttpGd := preload("res://src/ugc/content_submit_http.gd")
const TraprushEditorPanelGd := preload("res://src/creator/traprush_editor_panel.gd")
const AuthoringValidatorPanelGd := preload("res://src/creator/authoring_validator_panel.gd")
const WebLaunchArgsGd := preload("res://src/client/web_launch_args.gd")

var _shell: MatchLobbyShellGd = null


## 入口默认挂草稿存储，而草稿活在 `user://`，跨测试运行也在。不清就等于让
## 上一次运行的摆放决定这一次的实体 id。
func before_each() -> void:
	AuthoringDraftStore.new(CreatorEntryGd.DRAFT_PATH).wipe()


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null
	AuthoringDraftStore.new(CreatorEntryGd.DRAFT_PATH).wipe()
	if FileAccess.file_exists(ContentSubmitHttpGd.GUEST_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ContentSubmitHttpGd.GUEST_FILE))


func _open_shell(web: bool = false) -> MatchLobbyShellGd:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	shell.web_platform = web
	add_child(shell)
	assert_true(shell.open())
	return shell


# ---- surface 分级 ----

func test_exported_packages_never_hand_out_the_internal_dev_surface() -> void:
	assert_eq(CreatorEntryGd.surface_for_platform(true), AuthoringSurfaceNamesGd.WEB_LIGHT)
	assert_eq(CreatorEntryGd.surface_for_platform(false), AuthoringSurfaceNamesGd.DESKTOP_FULL)
	assert_ne(CreatorEntryGd.surface_for_platform(true), AuthoringSurfaceNamesGd.INTERNAL_DEV)
	assert_ne(CreatorEntryGd.surface_for_platform(false), AuthoringSurfaceNamesGd.INTERNAL_DEV)


func test_web_light_drops_batch_generate_and_validator_details() -> void:
	_shell = _open_shell(true)
	assert_true(_shell.try_open_creator())
	var editor: AuthoringEditorShell = _shell.creator.editor
	assert_eq(editor.surface, AuthoringSurfaceNamesGd.WEB_LIGHT)
	assert_null(editor.tools.batch, "CD-32：批量生成只给 internal_dev")
	assert_null(
		editor.validator.get_node_or_null(AuthoringValidatorPanelGd.LIST_NAME),
		"CD-32：验证器详情只给 internal_dev"
	)
	# 但**仍然求值**：轻量创作者读不懂问题码，却必须知道这张课能不能发。
	assert_ne(editor.validator.summary_text(), "")
	assert_true(_shell.status_label_text() != "")


func test_desktop_full_keeps_batch_and_details() -> void:
	_shell = _open_shell(false)
	assert_true(_shell.try_open_creator())
	var editor: AuthoringEditorShell = _shell.creator.editor
	assert_eq(editor.surface, AuthoringSurfaceNamesGd.DESKTOP_FULL)
	assert_null(editor.tools.batch, "批量生成仍只给 internal_dev")
	assert_null(editor.validator.get_node_or_null(AuthoringValidatorPanelGd.LIST_NAME))


# ---- 入口行为 ----

func test_opening_the_creator_brings_preview_along_and_hides_the_lobby() -> void:
	_shell = _open_shell(true)
	var lobby_window: Window = _shell.window
	assert_true(lobby_window.visible)
	assert_true(_shell.try_open_creator())
	assert_true(_shell.creator.is_open())
	assert_not_null(_shell.creator.editor.preview, "改完立刻试：Preview 不是可选项")
	assert_true(_shell.creator.editor.preview.is_window_visible())
	assert_false(lobby_window.visible, "并排两块面板下面不该再压一个最大化大厅窗")


func test_closing_the_editor_window_returns_to_the_lobby() -> void:
	_shell = _open_shell(true)
	assert_true(_shell.try_open_creator())
	assert_false(_shell.window.visible)
	_shell.creator.editor.window.close_requested.emit()
	assert_true(_shell.window.visible, "关编辑窗必须把大厅拉回来，否则 Web 画布是空的")
	assert_false(_shell.creator.is_open())
	assert_false(
		_shell.creator.editor.preview.is_window_visible(),
		"Preview 并排窗也要一起收"
	)


func test_web_light_shows_back_to_lobby() -> void:
	_shell = _open_shell(true)
	assert_true(_shell.try_open_creator())
	var back: Button = _shell.creator.editor.window.get_node_or_null(
		"VBoxContainer/SharedActions/%s" % AuthoringEditorShellChrome.BACK_NAME
	) as Button
	assert_not_null(back, "玩家包必须有返回大厅，不能只靠嵌入 Window 的标题栏 X")
	if back != null:
		assert_eq(back.text, UiCopy.text(UiCopy.BACK_TO_LOBBY))


func test_closing_the_creator_returns_to_the_lobby() -> void:
	_shell = _open_shell(true)
	assert_true(_shell.try_open_creator())
	assert_true(_shell.try_close_creator())
	assert_false(_shell.creator.is_open())
	assert_true(_shell.window.visible)
	assert_false(_shell.try_close_creator(), "已经关上就不再重复关")


func test_reopening_reuses_the_same_authoring_session() -> void:
	_shell = _open_shell(true)
	assert_true(_shell.try_open_creator())
	var editor: AuthoringEditorShell = _shell.creator.editor
	assert_true(editor.try_place_checkpoint(1, 0, 0, 0, 0))
	var revision: int = editor.session.world.revision
	assert_true(_shell.try_close_creator())
	assert_true(_shell.try_open_creator())
	assert_same(editor, _shell.creator.editor, "重开不该丢掉刚摆的东西")
	assert_eq(editor.session.world.revision, revision)


func test_creator_draft_path_does_not_collide_with_the_internal_dev_one() -> void:
	_shell = _open_shell(true)
	assert_true(_shell.try_open_creator())
	assert_not_null(_shell.creator.editor.draft_store)
	assert_eq(_shell.creator.editor.draft_store.path, CreatorEntryGd.DRAFT_PATH)
	assert_ne(_shell.creator.editor.draft_store.path, AuthoringDraftStore.DEFAULT_PATH)


func test_lobby_shows_the_create_course_button() -> void:
	_shell = _open_shell(false)
	var button: Button = _shell.window.get_node(
		"VBoxContainer/MatchActions/%s" % MatchLobbyChrome.CREATOR_NAME
	) as Button
	assert_not_null(button)
	if button != null:
		assert_eq(button.text, UiCopy.text(UiCopy.CREATE_COURSE))


func test_creator_publish_button_posts_submit_when_live_io_is_on() -> void:
	AuthoringDraftStore.new(CreatorEntryGd.DRAFT_PATH).wipe()
	if FileAccess.file_exists(ContentSubmitHttpGd.GUEST_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ContentSubmitHttpGd.GUEST_FILE))
	_shell = _open_shell(false)
	_shell.live_io = true
	_shell.control_plane_base = "http://127.0.0.1:8080"
	assert_true(_shell.try_open_creator())
	var editor: AuthoringEditorShell = _shell.creator.editor
	assert_true(editor.import_document(AuthoringDocumentGd.load_json(
		OfficialTraprushCoursesGd.document_path(OfficialTraprushCoursesGd.COURSE_01)
	)))
	_shell.creator.http_transport = func(method: String, path: String, _headers: PackedStringArray, body: String) -> Dictionary:
		if path == "/accounts/guest":
			assert_eq(method, "POST")
			return {
				"status": 201,
				"body": {
					"guest_id": "gst_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
					"recovery_key": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
				},
			}
		assert_eq(path, "/content/submit")
		var parsed: Variant = JSON.parse_string(body)
		assert_eq(typeof(parsed), TYPE_DICTIONARY)
		if typeof(parsed) != TYPE_DICTIONARY:
			return {"status": 400, "body": {"error": "bad"}}
		var payload: Dictionary = parsed
		assert_eq(payload.size(), 2)
		assert_false(payload.has("signature"))
		return {
			"status": 201,
			"body": {
				"id": "ugc_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
				"version": 1,
				"latest": 1,
				"content_hash": str(payload.get("content_hash", "")),
			},
		}
	assert_true(editor.try_publish())
	assert_true(editor.status_label_text().contains("publish=ugc_eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee@1"))


# ---- 链接开关 ----

func test_edit_query_and_flag_open_the_creator_directly() -> void:
	var none: PackedStringArray = PackedStringArray()
	assert_true(WebLaunchArgsGd.wants_edit(none, "?edit=1"))
	assert_true(WebLaunchArgsGd.wants_edit(none, "?edit"))
	assert_true(WebLaunchArgsGd.wants_edit(none, "?server=example.test&edit=true"))
	assert_true(WebLaunchArgsGd.wants_edit(PackedStringArray(["--edit"]), ""))
	# `/play/?edit=1` 的 search 仍是 `?edit=1`，与路径无关。
	assert_true(WebLaunchArgsGd.wants_edit(none, "?edit=1&server=127.0.0.1"))


func test_edit_is_off_by_default_and_can_be_turned_off_explicitly() -> void:
	var none: PackedStringArray = PackedStringArray()
	assert_false(WebLaunchArgsGd.wants_edit(none, ""))
	assert_false(WebLaunchArgsGd.wants_edit(none, "?server=example.test"))
	assert_false(WebLaunchArgsGd.wants_edit(none, "?edit=0"))
	assert_false(WebLaunchArgsGd.wants_edit(none, "?edit=false"))
	assert_false(WebLaunchArgsGd.wants_edit(PackedStringArray(["--editor"]), ""))


func test_edit_query_does_not_disturb_server_resolution() -> void:
	var merged: PackedStringArray = WebLaunchArgsGd.merge(
		PackedStringArray(), "?edit=1&server=example.test"
	)
	assert_true(merged.has("--server=example.test"))
	assert_false(merged.has("--edit"), "查询串不该被翻译成命令行 edit 旗")
