extends GutTest

## M5 A3: music director (one fade, same id does not restart) and settings window.

const AudioMusicDirectorGd := preload("res://src/audio/audio_music_director.gd")
const AudioServiceGd := preload("res://src/audio/audio_service.gd")
const AudioSettingsGd := preload("res://src/audio/audio_settings.gd")
const AudioSettingsEntryGd := preload("res://src/client/audio_settings_entry.gd")
const CatalogGd := preload("res://src/shared/schema/audio_cue_catalog.gd")
const ClientAudioGd := preload("res://src/client/client_audio.gd")
const MatchLobbyChromeGd := preload("res://src/client/match_lobby_chrome.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")

const STREAM_A: String = "res://content/audio/f_line_temp/theme_idle.wav"
const STREAM_B: String = "res://content/audio/f_line_temp/theme_run.wav"
const STREAM_C: String = "res://content/audio/f_line_temp/theme_end.wav"

var _host: Node = null
var _svc: AudioServiceGd = null
var _shell: MatchLobbyShellGd = null


func before_each() -> void:
	_host = Node.new()
	add_child(_host)


func after_each() -> void:
	if _svc != null:
		_remove_settings(_svc.settings.path)
		_svc.shutdown()
	_svc = null
	ClientAudioGd.shutdown()
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null
	if _host != null and is_instance_valid(_host):
		_host.free()
	_host = null


func _remove_settings(path: String) -> void:
	if path == "" or path == AudioSettingsGd.PATH:
		return
	var abs_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func _make_service() -> AudioServiceGd:
	var svc: AudioServiceGd = AudioServiceGd.new()
	svc.settings.path = "user://audio_settings_music_%s.json" % str(Time.get_ticks_usec())
	svc.mount(_host)
	assert_true(svc.register_cue({
		"id": CatalogGd.THEME_IDLE,
		"streams": PackedStringArray([STREAM_A]),
		"bus": AudioSettingsGd.BUS_MUSIC,
		"loop": true,
	}))
	assert_true(svc.register_cue({
		"id": CatalogGd.THEME_RUN,
		"streams": PackedStringArray([STREAM_B]),
		"bus": AudioSettingsGd.BUS_MUSIC,
		"loop": true,
	}))
	assert_true(svc.register_cue({
		"id": CatalogGd.THEME_END,
		"streams": PackedStringArray([STREAM_C]),
		"bus": AudioSettingsGd.BUS_MUSIC,
		"loop": true,
	}))
	return svc


func test_same_id_does_not_restart_and_one_fade_at_a_time() -> void:
	_svc = _make_service()
	var director: AudioMusicDirectorGd = AudioMusicDirectorGd.new()
	director.bind(_svc)
	director.fade_ms = 100
	director.now_ms_override = 0
	assert_true(director.request(CatalogGd.THEME_IDLE))
	assert_eq(director.start_count, 1)
	assert_true(director.fading())
	assert_true(director.request(CatalogGd.THEME_IDLE))
	assert_eq(director.start_count, 1)
	director.now_ms_override = 100
	director.advance()
	assert_false(director.fading())
	assert_eq(director.current_id(), CatalogGd.THEME_IDLE)
	assert_true(director.request(CatalogGd.THEME_IDLE))
	assert_eq(director.start_count, 1)
	assert_true(director.request(CatalogGd.THEME_RUN))
	assert_eq(director.start_count, 2)
	assert_true(director.fading())
	assert_true(director.request(CatalogGd.THEME_END))
	assert_eq(director.start_count, 2)
	assert_eq(director.current_id(), CatalogGd.THEME_RUN)
	director.now_ms_override = 200
	director.advance()
	assert_eq(director.start_count, 3)
	assert_eq(director.current_id(), CatalogGd.THEME_END)


func test_client_audio_maps_product_states() -> void:
	assert_not_null(ClientAudioGd.ensure(_host))
	ClientAudioGd.director.stop()
	ClientAudioGd.director.fade_ms = 0
	ClientAudioGd.director.now_ms_override = 0
	assert_true(ClientAudioGd.request_state(ClientAudioGd.STATE_LOBBY))
	ClientAudioGd.director.now_ms_override = 1
	ClientAudioGd.advance_music()
	assert_eq(ClientAudioGd.director.current_id(), CatalogGd.THEME_IDLE)
	assert_true(ClientAudioGd.request_state(ClientAudioGd.STATE_PLAY))
	ClientAudioGd.director.now_ms_override = 2
	ClientAudioGd.advance_music()
	assert_eq(ClientAudioGd.director.current_id(), CatalogGd.THEME_RUN)
	assert_false(ClientAudioGd.request_state("nope"))


func test_settings_window_opens_and_persists_on_close() -> void:
	_shell = MatchLobbyShellGd.create()
	add_child(_shell)
	assert_true(_shell.open())
	ClientAudioGd.ensure(_shell)
	ClientAudioGd.service.settings.path = "user://audio_settings_window_%s.json" % str(Time.get_ticks_usec())
	var button: Button = _shell.window.get_node(
		"VBoxContainer/MatchActions/%s" % MatchLobbyChromeGd.SETTINGS_NAME
	) as Button
	assert_not_null(button)
	assert_eq(button.text, UiCopy.text(UiCopy.SETTINGS))
	assert_true(_shell.try_open_settings())
	assert_true(_shell.settings.is_open())
	assert_false(_shell.window.visible)
	var music: HSlider = _shell.settings.window.get_node(
		"VBoxContainer/%s%s" % [AudioSettingsEntryGd.SLIDER_PREFIX, AudioSettingsGd.BUS_MUSIC]
	) as HSlider
	assert_not_null(music)
	music.value = -12.0
	assert_almost_eq(ClientAudioGd.service.settings.get_bus_db(AudioSettingsGd.BUS_MUSIC), -12.0, 0.05)
	assert_true(_shell.try_close_settings())
	assert_false(_shell.settings.is_open())
	assert_true(_shell.window.visible)
	var raw: String = FileAccess.get_file_as_string(ClientAudioGd.service.settings.path)
	assert_true(raw.contains("-12"))
	_remove_settings(ClientAudioGd.service.settings.path)
