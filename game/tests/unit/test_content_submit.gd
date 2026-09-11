extends GutTest

## M5 C3: player submit payload. Validator must be green. Never signs.
## Never invents content_id / version. HTTP is injected; GUT stays offline.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringEditorShellGd := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNamesGd := preload("res://src/creator/authoring_surface_names.gd")
const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const ContentSubmitGd := preload("res://src/ugc/content_submit.gd")
const ContentSubmitHttpGd := preload("res://src/ugc/content_submit_http.gd")
const ContentSignGd := preload("res://src/ugc/content_sign.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")

const GUEST_PATH: String = "user://content_submit_guest_test.json"
const HASH_A: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

var _shell: AuthoringEditorShellGd = null


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null
	if FileAccess.file_exists(GUEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GUEST_PATH))


func test_official_course_prepares_bundle_and_hash_without_signature() -> void:
	var world: AuthoringWorldGd = AuthoringDocumentGd.load_from_path(
		OfficialTraprushCoursesGd.document_path(OfficialTraprushCoursesGd.COURSE_01)
	)
	assert_not_null(world)
	var prepared: Dictionary = ContentSubmitGd.prepare(world)
	assert_true(_flag(prepared, ContentSubmitGd.KEY_OK))
	assert_eq(str(prepared.get(ContentSubmitGd.KEY_REASON, "")), "")
	var body: Dictionary = ContentSubmitGd.request_body(prepared)
	assert_eq(body.size(), 2)
	assert_true(body.has(ContentSubmitGd.KEY_BUNDLE))
	assert_true(body.has(ContentSubmitGd.KEY_CONTENT_HASH))
	assert_false(body.has(ContentSignGd.KEY_SIGNATURE))
	assert_false(body.has(ContentSubmitGd.KEY_ID))
	assert_false(body.has("content_id"))
	assert_false(body.has(ContentSubmitGd.KEY_VERSION))
	assert_eq(str(body.get(ContentSubmitGd.KEY_CONTENT_HASH, "")).length(), 64)


func test_empty_world_and_dangling_portal_are_refused() -> void:
	var empty: Dictionary = ContentSubmitGd.prepare(AuthoringWorldGd.new())
	assert_false(_flag(empty, ContentSubmitGd.KEY_OK))
	assert_eq(str(empty.get(ContentSubmitGd.KEY_REASON, "")), ContentSubmitGd.REASON_VALIDATOR_ISSUES)
	assert_true(ContentSubmitGd.request_body(empty).is_empty())
	_shell = _open_shell()
	assert_true(_shell.try_place_portal(10, 99, 0, 0, 0))
	assert_false(_shell.try_publish())
	assert_eq(
		str(_shell.last_publish.get(ContentSubmitGd.KEY_REASON, "")),
		ContentSubmitGd.REASON_VALIDATOR_ISSUES
	)
	assert_true(_shell.status_label_text().contains("publish=validator_issues"))


func test_publish_button_exists_and_injected_submit_echoes_id() -> void:
	_shell = _open_shell()
	var button: Button = _shell.window.get_node(
		"VBoxContainer/SharedActions/%s" % AuthoringEditorShellChrome.PUBLISH_NAME
	) as Button
	assert_not_null(button)
	assert_eq(button.text, UiCopy.text(UiCopy.PUBLISH))
	assert_true(_shell.status_label_text().contains("publish=idle"))
	assert_true(_shell.import_document(AuthoringDocumentGd.load_json(
		OfficialTraprushCoursesGd.document_path(OfficialTraprushCoursesGd.COURSE_01)
	)))
	_shell.on_submit = func(body: Dictionary) -> Dictionary:
		assert_eq(body.size(), 2)
		assert_false(body.has(ContentSignGd.KEY_SIGNATURE))
		return {
			ContentSubmitGd.KEY_ID: "ugc_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
			ContentSubmitGd.KEY_VERSION: 1,
			ContentSubmitGd.KEY_LATEST: 1,
			ContentSubmitGd.KEY_CONTENT_HASH: str(body.get(ContentSubmitGd.KEY_CONTENT_HASH, "")),
		}
	assert_true(_shell.try_publish())
	assert_true(_shell.status_label_text().contains(
		"publish=ugc_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb@1"
	))


func test_read_view_rejects_signature_and_accepts_json_floats() -> void:
	var signed: Dictionary = ContentSubmitGd.read_view({
		ContentSubmitGd.KEY_ID: "ugc_cccccccccccccccccccccccccccccccc",
		ContentSubmitGd.KEY_VERSION: 1,
		ContentSubmitGd.KEY_LATEST: 1,
		ContentSubmitGd.KEY_CONTENT_HASH: HASH_A,
		ContentSignGd.KEY_SIGNATURE: HASH_A,
	})
	assert_false(_flag(signed, ContentSubmitGd.KEY_OK))
	var floats: Dictionary = ContentSubmitGd.read_view({
		ContentSubmitGd.KEY_ID: "ugc_cccccccccccccccccccccccccccccccc",
		ContentSubmitGd.KEY_VERSION: 1.0,
		ContentSubmitGd.KEY_LATEST: 1.0,
		ContentSubmitGd.KEY_CONTENT_HASH: HASH_A,
	})
	assert_true(_flag(floats, ContentSubmitGd.KEY_OK))
	var version_raw: Variant = floats.get(ContentSubmitGd.KEY_VERSION, 0)
	var version: int = 0
	if typeof(version_raw) == TYPE_INT:
		version = version_raw
	assert_eq(version, 1)


func test_submit_http_mints_guest_and_posts_only_bundle_hash() -> void:
	var counts: Array[int] = [0, 0]
	var transport := func(method: String, path: String, headers: PackedStringArray, body: String) -> Dictionary:
		if path == ContentSubmitHttpGd.PATH_GUEST:
			counts[0] += 1
			assert_eq(method, "POST")
			return {
				"status": 201,
				"body": {
					"guest_id": "gst_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
					"recovery_key": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
				},
			}
		assert_eq(path, ContentSubmitHttpGd.PATH_SUBMIT)
		counts[1] += 1
		assert_eq(method, "POST")
		assert_true(_header_has(headers, "x-guest-id: gst_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
		var parsed: Variant = JSON.parse_string(body)
		assert_eq(typeof(parsed), TYPE_DICTIONARY)
		if typeof(parsed) != TYPE_DICTIONARY:
			return {"status": 400, "body": {"error": "bad"}}
		var payload: Dictionary = parsed
		assert_eq(payload.size(), 2)
		assert_false(payload.has(ContentSignGd.KEY_SIGNATURE))
		return {
			"status": 201,
			"body": {
				ContentSubmitGd.KEY_ID: "ugc_dddddddddddddddddddddddddddddddd",
				ContentSubmitGd.KEY_VERSION: 1,
				ContentSubmitGd.KEY_LATEST: 1,
				ContentSubmitGd.KEY_CONTENT_HASH: HASH_A,
			},
		}
	var view: Dictionary = ContentSubmitHttpGd.submit_player(
		"http://127.0.0.1:8080",
		{ContentSubmitGd.KEY_BUNDLE: {"schema_version": 2}, ContentSubmitGd.KEY_CONTENT_HASH: HASH_A},
		transport,
		GUEST_PATH
	)
	assert_eq(counts[0], 1)
	assert_eq(counts[1], 1)
	assert_eq(str(view.get(ContentSubmitGd.KEY_ID, "")), "ugc_dddddddddddddddddddddddddddddddd")
	assert_false(view.has(ContentSignGd.KEY_SIGNATURE))
	var again: Dictionary = ContentSubmitHttpGd.submit_player(
		"http://127.0.0.1:8080",
		{ContentSubmitGd.KEY_BUNDLE: {"schema_version": 2}, ContentSubmitGd.KEY_CONTENT_HASH: HASH_A},
		transport,
		GUEST_PATH
	)
	assert_eq(counts[0], 1)
	assert_eq(counts[1], 2)
	assert_eq(str(again.get(ContentSubmitGd.KEY_ID, "")), "ugc_dddddddddddddddddddddddddddddddd")


func _open_shell() -> AuthoringEditorShellGd:
	var shell: AuthoringEditorShellGd = AuthoringEditorShellGd.create(AuthoringSurfaceNamesGd.DESKTOP_FULL)
	add_child(shell)
	assert_true(shell.open())
	return shell


func _flag(result: Dictionary, key: String) -> bool:
	var raw: Variant = result.get(key, false)
	return raw == true


func _header_has(headers: PackedStringArray, line: String) -> bool:
	for item: String in headers:
		if item == line:
			return true
	return false
