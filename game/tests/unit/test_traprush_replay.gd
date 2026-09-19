extends GutTest

## TRAPRUSH player replay library: local ring 50, save only after all finish,
## command-tape re-sim, hash mismatch, countdown, sampler off.

const ContentSignGd := preload("res://src/ugc/content_sign.gd")
const MatchCourseMapGd := preload("res://src/client/match_course_map.gd")
const MatchLobbyHomeGd := preload("res://src/client/match_lobby_home.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")
const MatchOfflineSessionGd := preload("res://src/client/match_offline_session.gd")
const OverlayGd := preload("res://src/shared/play_hud_overlay.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const PlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const StoreGd := preload("res://src/client/traprush_replay_store.gd")
const TapeGd := preload("res://src/games/traprush/replay_tape.gd")
const UiCopyGd := preload("res://src/shared/ui_copy.gd")
const UiCopyPlayGd := preload("res://src/shared/ui_copy_play.gd")

const COURSE_01: String = "res://content/official/traprush/course_01.json"
const CELL: int = Fixed.SCALE

var _store_path: String = ""
var _shell: MatchLobbyShellGd = null


func before_each() -> void:
	UiCopyGd.reset_for_tests()
	assert_true(UiCopyGd.ensure_loaded())
	_store_path = "user://traprush_replay_test_%s.json" % str(Time.get_ticks_usec())


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null
	if _store_path != "" and FileAccess.file_exists(_store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_store_path))


func test_parse_rejects_unknown_course_and_bad_hash() -> void:
	var good: Dictionary = _valid_tape()
	var good_ok: bool = TapeGd.parse(good).get("ok", false)
	assert_true(good_ok)
	var bad_course: Dictionary = good.duplicate(true)
	bad_course["course_id"] = "course_99"
	var bad_course_ok: bool = TapeGd.parse(bad_course).get("ok", false)
	assert_false(bad_course_ok)
	var bad_hash: Dictionary = good.duplicate(true)
	bad_hash["content_hash"] = "zz"
	var bad_hash_ok: bool = TapeGd.parse(bad_hash).get("ok", false)
	assert_false(bad_hash_ok)


func test_finalize_empty_when_not_all_finished() -> void:
	var offline: MatchOfflineSessionGd = MatchOfflineSessionGd.new()
	offline.persist_replay = true
	offline.replay_store.path = _store_path
	offline.apply_play_stubs()
	assert_true(offline.try_begin(COURSE_01))
	var recorder: Dictionary = TapeGd.empty_recorder(COURSE_01, offline.session)
	assert_false(recorder.is_empty())
	assert_true(TapeGd.finalize(recorder, offline.session).is_empty())
	offline.try_advance()
	assert_eq(offline.replay_store.load_items().size(), 0)
	offline.try_stop()


func test_local_ring_keeps_fifty() -> void:
	var store: StoreGd = StoreGd.new()
	store.path = _store_path
	var tape: Dictionary = _valid_tape()
	for _i: int in range(TapeGd.LOCAL_RING + 1):
		assert_true(store.append_tape(tape))
	assert_eq(store.load_items().size(), TapeGd.LOCAL_RING)
	assert_eq(TapeGd.LOCAL_RING, 50)
	assert_eq(TapeGd.SERVER_RING, 100)


func test_hash_mismatch_does_not_open() -> void:
	var offline: MatchOfflineSessionGd = MatchOfflineSessionGd.new()
	offline.apply_play_stubs()
	var tape: Dictionary = _valid_tape()
	var mutated: String = str(tape.get("content_hash", ""))
	mutated = "0" + mutated.substr(1)
	if mutated == str(tape.get("content_hash", "")):
		mutated = "1" + mutated.substr(1)
	tape["content_hash"] = mutated
	assert_false(offline.try_begin_replay(tape))
	assert_eq(offline.last_error, "hash_mismatch")
	assert_false(offline.replay_active)


func test_replay_keeps_countdown_and_ignores_intents() -> void:
	var offline: MatchOfflineSessionGd = MatchOfflineSessionGd.new()
	offline.apply_play_stubs()
	var tape: Dictionary = _valid_tape()
	tape["go_tick"] = PlayStubsGd.COUNTDOWN_TICKS
	assert_true(offline.try_begin_replay(tape), offline.last_error)
	assert_true(offline.replay_active)
	assert_eq(offline.session.go_tick, PlayStubsGd.COUNTDOWN_TICKS)
	assert_true(offline.try_encode_intent(PlayerIntentNames.MOVE, CELL, 0, 0).is_empty())
	assert_eq(
		OverlayGd.countdown_line(0, PlayStubsGd.COUNTDOWN_TICKS, 1, true),
		"3"
	)
	offline.try_stop()


func test_home_opens_replay_and_back_returns() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_show_home())
	assert_true(_shell.try_show_replay())
	assert_true(MatchLobbyHomeGd.is_replay_visible(_shell))
	assert_false(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_false(_shell.is_window_visible())
	assert_true(_shell.replay_records.try_close())
	assert_true(MatchLobbyHomeGd.is_home_visible(_shell))
	assert_false(MatchLobbyHomeGd.is_replay_visible(_shell))


func test_shell_replay_skips_sampler_and_shows_banner() -> void:
	_shell = _open_shell()
	assert_true(_shell.try_show_home())
	var tape: Dictionary = _valid_tape()
	tape["go_tick"] = PlayStubsGd.COUNTDOWN_TICKS
	assert_true(_shell.try_begin_replay(tape), _shell.offline.last_error)
	assert_true(_shell.offline.replay_active)
	assert_true(_shell.try_sample_play_move(true, false, false, false).is_empty())
	_shell.refresh_status()
	assert_eq(_shell.countdown_label_text(), "3")
	var banner: Label = _shell.chrome.play_hud.replay_banner
	assert_not_null(banner)
	if banner != null:
		assert_true(banner.visible)
		assert_eq(banner.text, UiCopyGd.text(UiCopyPlayGd.REPLAY_BANNER))
	assert_true(_shell.try_stop_offline())
	assert_true(MatchLobbyHomeGd.is_replay_visible(_shell))


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
		"go_tick": PlayStubsGd.COUNTDOWN_TICKS,
		"seats": 1,
		"commands": [],
		"finish_ticks": [0],
	}


func _open_shell() -> MatchLobbyShellGd:
	var shell: MatchLobbyShellGd = MatchLobbyShellGd.create()
	add_child(shell)
	assert_true(shell.open())
	return shell
