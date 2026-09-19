extends GutTest

## 角色选择：系统目录 + 本机存档 + 大厅入口 + TRAPRUSH 本席视觉。
## 占位表现只烟测；契约侧钉住 id 解析、未知回退、默认路径与猫一致。

const MatchLobbyHomeGd := preload("res://src/client/match_lobby_home.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const StoreGd := preload("res://src/client/character_select_store.gd")
const UiCopyGd := preload("res://src/shared/ui_copy.gd")
const UiCopyCharGd := preload("res://src/shared/ui_copy_char.gd")
const ScenePath: String = "res://src/client/ui/scenes/character_select.tscn"

var _shell: MatchLobbyShellGd = null
var _store_path: String = ""


func before_each() -> void:
	UiCopyGd.reset_for_tests()
	assert_true(UiCopyGd.ensure_loaded())
	_store_path = "user://character_select_test_%s.json" % str(Time.get_ticks_usec())


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null
	if _store_path != "" and FileAccess.file_exists(_store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_store_path))


func test_default_id_is_the_already_wired_cat() -> void:
	assert_eq(SharedCharacterCatalog.DEFAULT_ID, SharedCharacterCatalog.ID_CAT)
	assert_eq(
		SharedCharacterCatalog.scene_path(SharedCharacterCatalog.DEFAULT_ID),
		SharedVisualAssetCatalog.CHARACTER_SCENE_PATH
	)
	assert_eq(SharedCharacterCatalog.all_ids().size(), 3)


func test_unknown_id_resolves_to_default() -> void:
	assert_eq(SharedCharacterCatalog.resolve(""), SharedCharacterCatalog.DEFAULT_ID)
	assert_eq(SharedCharacterCatalog.resolve("sniper"), SharedCharacterCatalog.DEFAULT_ID)
	assert_true(SharedCharacterCatalog.is_known(SharedCharacterCatalog.ID_ROBOT))
	assert_false(SharedCharacterCatalog.is_known("sniper"))


func test_name_keys_match_the_copy_table() -> void:
	assert_eq(SharedCharacterCatalog.name_key("cat"), UiCopyCharGd.NAME_CAT)
	assert_eq(SharedCharacterCatalog.name_key("runner"), UiCopyCharGd.NAME_RUNNER)
	assert_eq(SharedCharacterCatalog.name_key("robot"), UiCopyCharGd.NAME_ROBOT)
	for id: String in SharedCharacterCatalog.all_ids():
		var key: String = SharedCharacterCatalog.name_key(id)
		assert_ne(UiCopyGd.text(key, "zh_CN"), key)
		assert_ne(UiCopyGd.text(key, "en"), key)


func test_every_catalog_scene_instantiates() -> void:
	for id: String in SharedCharacterCatalog.all_ids():
		assert_true(SharedCharacterCatalog.has_scene(id), id)
		var visual: Node3D = SharedVisualAssetCatalog.try_instantiate(
			SharedCharacterCatalog.scene_path(id)
		)
		assert_not_null(visual, id)
		if visual != null:
			visual.free()


func test_store_missing_file_is_default() -> void:
	var store: StoreGd = StoreGd.new()
	store.path = _store_path
	store.load_or_default()
	assert_eq(store.selected_id, SharedCharacterCatalog.DEFAULT_ID)


func test_store_corrupt_and_unknown_id_fall_back() -> void:
	var file: FileAccess = FileAccess.open(_store_path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string("{not json")
	file.close()
	var store: StoreGd = StoreGd.new()
	store.path = _store_path
	store.load_or_default()
	assert_eq(store.selected_id, SharedCharacterCatalog.DEFAULT_ID)
	file = FileAccess.open(_store_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"id": "sniper"}))
	file.close()
	store.load_or_default()
	assert_eq(store.selected_id, SharedCharacterCatalog.DEFAULT_ID)


func test_store_roundtrip_keeps_a_known_id() -> void:
	var store: StoreGd = StoreGd.new()
	store.path = _store_path
	assert_eq(store.select(SharedCharacterCatalog.ID_ROBOT), SharedCharacterCatalog.ID_ROBOT)
	var loaded: StoreGd = StoreGd.new()
	loaded.path = _store_path
	loaded.load_or_default()
	assert_eq(loaded.selected_id, SharedCharacterCatalog.ID_ROBOT)
	assert_eq(loaded.scene_path(), SharedCharacterCatalog.scene_path(SharedCharacterCatalog.ID_ROBOT))


func test_home_opens_character_select_and_back_returns() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_show_home())
	_isolate_store(_shell)
	assert_true(_shell.try_show_character_select())
	assert_true(MatchLobbyHomeGd.is_character_select_visible(_shell))
	assert_false(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_false(_shell.is_window_visible())
	assert_true(_shell.character_select.try_close())
	assert_true(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_false(MatchLobbyHomeGd.is_character_select_visible(_shell))


func test_selecting_a_card_persists_and_rebuilds_own_visual() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_show_home())
	_isolate_store(_shell)
	assert_true(_shell.try_show_character_select())
	var screen: Control = _shell.character_select.screen
	assert_not_null(screen)
	screen.emit_signal("character_selected", SharedCharacterCatalog.ID_RUNNER)
	assert_eq(_shell.character_select.store.selected_id, SharedCharacterCatalog.ID_RUNNER)
	var map: MatchSnapshotMap = MatchSnapshotMap.new()
	add_child_autofree(map)
	map.follow_slot = 0
	map.own_character_scene_path = _shell.character_select.store.scene_path()
	assert_true(map.apply_players([_player_body(), _player_body()]))
	var own: MeshInstance3D = map.player_node(0)
	var remote: MeshInstance3D = map.player_node(1)
	assert_not_null(own)
	assert_not_null(remote)
	if own != null:
		assert_eq(
			str(own.get_meta(MatchSnapshotMap.VISUAL_PATH_META)),
			SharedCharacterCatalog.scene_path(SharedCharacterCatalog.ID_RUNNER)
		)
	if remote != null:
		assert_eq(
			str(remote.get_meta(MatchSnapshotMap.VISUAL_PATH_META)),
			SharedVisualAssetCatalog.CHARACTER_SCENE_PATH
		)


func test_static_humanoids_yaw_to_godot_forward_without_moving_the_capsule() -> void:
	assert_eq(SharedCharacterCatalog.VISUAL_YAW_DEG.size(), SharedCharacterCatalog.IDS.size())
	assert_eq(SharedCharacterCatalog.visual_yaw_deg(SharedCharacterCatalog.ID_CAT), 0.0)
	assert_eq(SharedCharacterCatalog.visual_yaw_deg(SharedCharacterCatalog.ID_ROBOT), 180.0)
	var cat_map: MatchSnapshotMap = MatchSnapshotMap.new()
	add_child_autofree(cat_map)
	cat_map.follow_slot = 0
	cat_map.own_character_scene_path = SharedCharacterCatalog.scene_path(
		SharedCharacterCatalog.ID_CAT
	)
	assert_true(cat_map.apply_players([_player_body()]))
	var robot_map: MatchSnapshotMap = MatchSnapshotMap.new()
	add_child_autofree(robot_map)
	robot_map.follow_slot = 0
	robot_map.own_character_scene_path = SharedCharacterCatalog.scene_path(
		SharedCharacterCatalog.ID_ROBOT
	)
	assert_true(robot_map.apply_players([_player_body()]))
	var cat_player: MeshInstance3D = cat_map.player_node(0)
	var robot_player: MeshInstance3D = robot_map.player_node(0)
	assert_not_null(cat_player)
	assert_not_null(robot_player)
	if cat_player == null or robot_player == null:
		return
	assert_eq(cat_player.position, robot_player.position, "选机器人不得移动权威位姿")
	var cat_visual: Node3D = cat_map.visual_node(0)
	var robot_visual: Node3D = robot_map.visual_node(0)
	assert_not_null(cat_visual)
	assert_not_null(robot_visual)
	if cat_visual == null or robot_visual == null:
		return
	var cat_face: Vector3 = (cat_visual.transform.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	var robot_face: Vector3 = (robot_visual.transform.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	assert_gt(cat_face.dot(Vector3(0.0, 0.0, 1.0)), 0.99, "默认猫的朝向被改了")
	assert_gt(robot_face.dot(Vector3(0.0, 0.0, -1.0)), 0.99, "机器人没有转到对局 -Z")


func test_package_check_covers_the_catalog() -> void:
	var report: Dictionary = PackageCheck.report()
	var checks: Dictionary = report["checks"]
	assert_true(checks.has("character_catalog_loadable"), "包内自检没查 catalog")
	var loadable: bool = checks["character_catalog_loadable"]
	assert_true(loadable, "源码工程里 catalog 角色必须能实例化")
	var ids: PackedStringArray = report["character_catalog_ids"]
	assert_eq(ids, SharedCharacterCatalog.all_ids())


func _open_shell() -> MatchLobbyShellGd:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	add_child(shell)
	assert_true(shell.open())
	return shell


func _isolate_store(shell: MatchLobbyShellGd) -> void:
	MatchLobbyHomeGd.ensure_character_select(shell)
	assert_not_null(shell.character_select)
	assert_not_null(shell.character_select.store)
	shell.character_select.store.path = _store_path
	shell.character_select.store.reset_defaults()
	shell.character_select.store.save()


func _player_body() -> Dictionary:
	return {"x": 0, "y": 0, "z": 0, "yaw_bam": 0}
