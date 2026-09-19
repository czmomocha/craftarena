extends GutTest

## Solo local-best ghost: settings default on, independent store, parallel
## session, live player_count stays 1, presentation fade is smoke-only.

const ContentSignGd := preload("res://src/ugc/content_sign.gd")
const MatchCourseMapGd := preload("res://src/client/match_course_map.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const MatchOfflineSessionGd := preload("res://src/client/match_offline_session.gd")
const GhostGd := preload("res://src/client/match_offline_ghost.gd")
const GhostMapGd := preload("res://src/client/match_snapshot_map_ghost.gd")
const MatchSnapshotMapGd := preload("res://src/client/match_snapshot_map.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SettingsGd := preload("res://src/client/traprush_ghost_settings.gd")
const StoreGd := preload("res://src/client/traprush_ghost_store.gd")
const TapeGd := preload("res://src/games/traprush/replay_tape.gd")
const UiCopyGd := preload("res://src/shared/ui_copy.gd")
const UiCopyPlayGd := preload("res://src/shared/ui_copy_play.gd")

const COURSE_01: String = "res://content/official/traprush/course_01.json"
const CELL: int = Fixed.SCALE

var _store_path: String = ""
var _settings_path: String = ""
var _replay_path: String = ""
var _shell: MatchLobbyShellGd = null
var _map: MatchSnapshotMapGd = null


func before_each() -> void:
	UiCopyGd.reset_for_tests()
	assert_true(UiCopyGd.ensure_loaded())
	var stamp: String = str(Time.get_ticks_usec())
	_store_path = "user://traprush_ghost_test_%s.json" % stamp
	_settings_path = "user://traprush_ghost_settings_test_%s.json" % stamp
	_replay_path = "user://traprush_ghost_replay_test_%s.json" % stamp


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null
	_remove(_store_path)
	_remove(_settings_path)
	_remove(_replay_path)


func test_settings_default_on_when_file_missing() -> void:
	var settings: SettingsGd = SettingsGd.new()
	settings.path = _settings_path
	settings.load_or_default()
	assert_true(settings.enabled)
	assert_false(FileAccess.file_exists(_settings_path))


func test_settings_persist_and_locale_has_no_emoji() -> void:
	var settings: SettingsGd = SettingsGd.new()
	settings.path = _settings_path
	settings.enabled = false
	assert_true(settings.save())
	var loaded: SettingsGd = SettingsGd.new()
	loaded.path = _settings_path
	loaded.load_or_default()
	assert_false(loaded.enabled)
	var zh: String = UiCopyGd.text(UiCopyPlayGd.GHOST_CHASE, "zh_CN")
	var en: String = UiCopyGd.text(UiCopyPlayGd.GHOST_CHASE, "en")
	assert_eq(zh, "追赶本机最高纪录")
	assert_eq(en, "Race my best time")
	assert_false(zh.contains("🔒"))
	assert_false(en.contains("🔒"))


func test_store_replaces_only_when_strictly_faster() -> void:
	var store: StoreGd = StoreGd.new()
	store.path = _store_path
	var slow: Dictionary = _valid_tape()
	slow["finish_ticks"] = [40]
	assert_true(store.put_if_faster(slow))
	assert_eq(_finish_of(store.best_for("course_01")), 40)
	var slower: Dictionary = _valid_tape()
	slower["finish_ticks"] = [41]
	assert_false(store.put_if_faster(slower))
	assert_eq(_finish_of(store.best_for("course_01")), 40)
	var tie: Dictionary = _valid_tape()
	tie["finish_ticks"] = [40]
	assert_false(store.put_if_faster(tie))
	var faster: Dictionary = _valid_tape()
	faster["finish_ticks"] = [39]
	assert_true(store.put_if_faster(faster))
	assert_eq(_finish_of(store.best_for("course_01")), 39)


func test_begin_spawns_parallel_ghost_and_keeps_live_seat_count() -> void:
	var offline: MatchOfflineSessionGd = _wired_session()
	assert_true(offline.ghost_store.put_if_faster(_moving_tape()))
	assert_true(offline.try_begin(COURSE_01), offline.last_error)
	assert_true(GhostGd.is_active(offline))
	assert_eq(offline.session.player_count(), 1)
	var view: Dictionary = offline.status_view()
	var live_count: int = view.get("player_count", -1)
	var ghost_on: bool = view.get("ghost_active", false)
	assert_eq(live_count, 1)
	assert_true(ghost_on)
	assert_eq(offline.follow.players.size(), 1)
	var before: Dictionary = _player_at(offline.ghost, 0)
	var before_x: int = before.get("x", -1)
	assert_true(offline.try_advance())
	var after: Dictionary = _player_at(offline.ghost, 0)
	var after_x: int = after.get("x", -2)
	assert_ne(after_x, before_x)
	assert_eq(offline.session.tick_index(), offline.ghost.session.tick_index())
	offline.try_stop()
	assert_false(GhostGd.is_active(offline))


func test_disabled_or_missing_or_hash_mismatch_skips_ghost() -> void:
	var offline: MatchOfflineSessionGd = _wired_session()
	assert_true(offline.try_begin(COURSE_01))
	assert_false(GhostGd.is_active(offline))
	offline.try_stop()
	assert_true(offline.ghost_store.put_if_faster(_valid_tape()))
	offline.ghost_settings.enabled = false
	assert_true(offline.try_begin(COURSE_01))
	assert_false(GhostGd.is_active(offline))
	offline.try_stop()
	offline.ghost_settings.enabled = true
	var mutated: Dictionary = _valid_tape()
	var hash_hex: String = str(mutated.get("content_hash", ""))
	mutated["content_hash"] = "0" + hash_hex.substr(1)
	if str(mutated.get("content_hash", "")) == hash_hex:
		mutated["content_hash"] = "1" + hash_hex.substr(1)
	mutated["finish_ticks"] = [1]
	assert_true(offline.ghost_store.put_if_faster(mutated))
	assert_true(offline.try_begin(COURSE_01), offline.last_error)
	assert_false(GhostGd.is_active(offline))
	offline.try_stop()


func test_replay_active_does_not_attach_ghost() -> void:
	var offline: MatchOfflineSessionGd = _wired_session()
	assert_true(offline.ghost_store.put_if_faster(_valid_tape()))
	assert_true(offline.try_begin_replay(_valid_tape()), offline.last_error)
	assert_true(offline.replay_active)
	assert_false(GhostGd.is_active(offline))
	offline.try_stop()


func test_finish_writes_ghost_not_replay_ring_and_cancel_skips() -> void:
	var offline: MatchOfflineSessionGd = _wired_session()
	assert_true(offline.try_begin(COURSE_01))
	assert_false(offline.try_encode_intent(PlayerIntentNames.MOVE, CELL, 0, -1).is_empty())
	offline.try_stop()
	assert_eq(offline.ghost_store.best_for("course_01"), {})
	assert_eq(offline.replay_store.load_items().size(), 0)
	assert_true(offline.try_begin(COURSE_01))
	for _index: int in range(5):
		assert_false(offline.try_encode_intent(PlayerIntentNames.MOVE, CELL, 0, -1).is_empty())
	assert_eq(offline.session.player_finish_tick(0), 0)
	assert_true(offline.try_advance())
	var best: Dictionary = offline.ghost_store.best_for("course_01")
	assert_false(best.is_empty())
	assert_eq(_finish_of(best), 0)
	assert_eq(offline.replay_store.load_items().size(), 0)
	var slower: Dictionary = _valid_tape()
	slower["finish_ticks"] = [1]
	assert_false(offline.ghost_store.put_if_faster(slower))
	assert_eq(_finish_of(offline.ghost_store.best_for("course_01")), 0)
	offline.try_stop()


func test_ghost_presentation_is_half_transparent_smoke() -> void:
	var offline: MatchOfflineSessionGd = _wired_session()
	assert_true(offline.ghost_store.put_if_faster(_moving_tape()))
	assert_true(offline.try_begin(COURSE_01), offline.last_error)
	_map = MatchSnapshotMapGd.new()
	add_child(_map)
	_map.ensure_rig()
	assert_true(GhostMapGd.apply(_map, offline.ghost.follow, _map.character_scene_path))
	var node: Node3D = _map.get_node_or_null(GhostMapGd.NODE_NAME) as Node3D
	assert_not_null(node)
	assert_true(_has_fade(node))
	assert_eq(_map.follow_slot, -1)
	assert_eq(_map.player_count(), 0)
	offline.try_stop()


func test_settings_window_checkbox_defaults_on() -> void:
	_shell = MatchLobbyShellGd.create()
	add_child(_shell)
	assert_true(_shell.open())
	_shell.offline.ghost_settings.path = _settings_path
	_shell.offline.ghost_settings.load_or_default()
	assert_true(_shell.try_open_settings())
	var box: CheckBox = _shell.settings.window.get_node_or_null("VBoxContainer/GhostChase")
	assert_not_null(box)
	assert_eq(box.text, UiCopyGd.text(UiCopyPlayGd.GHOST_CHASE))
	assert_true(box.button_pressed)
	box.button_pressed = false
	assert_true(_shell.try_close_settings())
	assert_false(_shell.offline.ghost_settings.enabled)
	assert_true(FileAccess.file_exists(_settings_path))


func _wired_session() -> MatchOfflineSessionGd:
	var offline: MatchOfflineSessionGd = MatchOfflineSessionGd.new()
	offline.ghost_store.path = _store_path
	offline.ghost_settings.path = _settings_path
	offline.ghost_settings.load_or_default()
	offline.replay_store.path = _replay_path
	offline.apply_play_stubs()
	return offline


func _valid_tape() -> Dictionary:
	var bundle: SimulationBundle = MatchCourseMapGd.compile_path(COURSE_01)
	assert_not_null(bundle)
	var hash_hex: String = ContentSignGd.hash_hex(bundle)
	assert_eq(hash_hex.length(), 64)
	return {
		"schema_version": TapeGd.SCHEMA_VERSION,
		"course_id": "course_01",
		"official_path": COURSE_01,
		"content_hash": hash_hex,
		"seed": 1,
		"go_tick": 0,
		"seats": 1,
		"commands": [],
		"finish_ticks": [20],
	}


func _moving_tape() -> Dictionary:
	var tape: Dictionary = _valid_tape()
	var commands: Array = []
	var move_id: int = MatchFrameCodec.intent_id_of(PlayerIntentNames.MOVE)
	for tick: int in range(8):
		commands.append({
			"tick": tick,
			"slot": 0,
			"intent_id": move_id,
			"dx": CELL,
			"dz": 0,
			"yaw_bam": 0,
		})
	tape["commands"] = commands
	tape["finish_ticks"] = [80]
	return tape


func _has_fade(root: Node) -> bool:
	var geometry: GeometryInstance3D = root as GeometryInstance3D
	if geometry != null and is_equal_approx(geometry.transparency, GhostMapGd.FADE):
		return true
	for child: Node in root.get_children():
		if _has_fade(child):
			return true
	return false


func _finish_of(tape: Dictionary) -> int:
	var raw: Variant = tape.get("finish_ticks", [])
	if typeof(raw) != TYPE_ARRAY:
		return -1
	var ticks: Array = raw
	if ticks.is_empty():
		return -1
	return TapeGd.as_int(ticks[0], -1)


func _player_at(offline: MatchOfflineSessionGd, slot: int) -> Dictionary:
	if offline == null or offline.follow.players.size() <= slot:
		return {}
	var raw: Variant = offline.follow.players[slot]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	return body


func _remove(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
