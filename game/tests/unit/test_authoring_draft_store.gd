extends GutTest

## Local authoring draft: latest snapshot + bounded checkpoints.
## Crash reopen restores. Corrupt / extra keys / res:// writes refuse.
## Not a new EDIT op. Never settlement. No cloud upload.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringDraftStore := preload("res://src/creator/authoring_draft_store.gd")
const AuthoringEditorPluginHost := preload("res://src/creator/authoring_editor_plugin_host.gd")
const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const DRAFT_PATH: String = "user://gut_authoring_draft_test.json"
const OFFICIAL_PATH: String = "res://content/official/traprush/course_01.json"

var _store: AuthoringDraftStore = null
var _shell: AuthoringEditorShell = null
var _host: AuthoringEditorPluginHost = null


func after_each() -> void:
	if _host != null:
		_host.detach()
	_host = null
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null
	if _store != null:
		_store.wipe()
	_store = null
	_wipe_path(DRAFT_PATH)


func test_record_then_load_restores_latest_world() -> void:
	_store = AuthoringDraftStore.new(DRAFT_PATH, 50, 30)
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_xyz(1, 0)))
	assert_true(_store.record(world))
	assert_eq(_store.command_count, 1)
	assert_eq(_store.checkpoints.size(), 1)
	var loaded: AuthoringWorld = _store.try_load_latest()
	assert_not_null(loaded)
	assert_eq(loaded.hash_state(), world.hash_state())
	assert_true(loaded.has_entity(1))


func test_failed_world_and_res_path_do_not_write() -> void:
	_store = AuthoringDraftStore.new(OFFICIAL_PATH, 1, 30)
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_xyz(1, 0)))
	assert_false(_store.record(world))
	assert_eq(_store.command_count, 0)
	assert_eq(FileAccess.file_exists(OFFICIAL_PATH), true)
	_store = AuthoringDraftStore.new(DRAFT_PATH)
	assert_false(_store.record(null))
	assert_eq(FileAccess.file_exists(DRAFT_PATH), false)


func test_corrupt_and_extra_key_files_are_refused() -> void:
	_store = AuthoringDraftStore.new(DRAFT_PATH)
	var empty_world: Dictionary = AuthoringDocument.encode(AuthoringWorld.new())
	_write_text(DRAFT_PATH, JSON.stringify({
		"schema_version": 2,
		"command_count": 1,
		"latest": empty_world,
		"checkpoints": [],
	}))
	assert_null(_store.try_load_latest())
	_write_text(DRAFT_PATH, JSON.stringify({
		"schema_version": 1,
		"command_count": 1,
		"latest": empty_world,
		"checkpoints": [],
		"surface": "internal_dev",
	}))
	assert_null(_store.try_load_latest())


func test_checkpoint_ring_keeps_thirty() -> void:
	_store = AuthoringDraftStore.new(DRAFT_PATH, 1, 30)
	var world: AuthoringWorld = AuthoringWorld.new()
	for index: int in range(31):
		var entity_id: int = index + 1
		assert_true(world.put(_xyz(entity_id, 0)))
		assert_true(_store.record(world))
	assert_eq(_store.command_count, 31)
	assert_eq(_store.checkpoints.size(), 30)
	var loaded: AuthoringWorld = _store.try_load_latest()
	assert_not_null(loaded)
	assert_true(loaded.has_entity(31))
	assert_false(loaded.has_entity(0))


func test_shell_reopen_restores_and_never_settles() -> void:
	_store = AuthoringDraftStore.new(DRAFT_PATH)
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	_shell.draft_store = _store
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_shell.session.world.has_entity(1))
	assert_false(_shell.allows_settlement())
	assert_false(_shell.allows_online_writes())
	_shell.free()
	_shell = null
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	_shell.draft_store = AuthoringDraftStore.new(DRAFT_PATH)
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.session.world.has_entity(1))
	assert_eq(_shell.session.world.revision, 1)
	assert_false(_shell.allows_settlement())


func test_failed_place_does_not_clobber_draft() -> void:
	_store = AuthoringDraftStore.new(DRAFT_PATH)
	_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	_shell.draft_store = _store
	add_child(_shell)
	assert_true(_shell.open())
	assert_true(_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	var before: PackedByteArray = _shell.session.world.hash_state()
	assert_false(_shell.try_place_checkpoint(1, 1, 1, 0, 0))
	assert_eq(_shell.session.world.hash_state(), before)
	var loaded: AuthoringWorld = AuthoringDraftStore.new(DRAFT_PATH).try_load_latest()
	assert_not_null(loaded)
	assert_eq(loaded.hash_state(), before)
	assert_false(loaded.has_entity(2))


func test_host_with_store_restores_after_detach() -> void:
	_store = AuthoringDraftStore.new(DRAFT_PATH)
	_host = AuthoringEditorPluginHost.new()
	_host.draft_store = _store
	assert_true(_host.attach_to(self))
	assert_true(_host.shell.try_place_checkpoint(4, 0, 1, 0, 0))
	_host.detach()
	_host = AuthoringEditorPluginHost.new()
	_host.draft_store = AuthoringDraftStore.new(DRAFT_PATH)
	assert_true(_host.attach_to(self))
	assert_true(_host.shell.session.world.has_entity(4))
	assert_false(_host.shell.allows_settlement())


func _xyz(entity_id: int, y: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": 0, "y": y, "z": 0, "yaw_bam": 0},
	})


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)


func _wipe_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
