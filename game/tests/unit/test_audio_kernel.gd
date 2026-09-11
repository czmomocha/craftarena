extends GutTest

## M5 A1: audio kernel (pool / cooldown / settings / silent headless).
## Presentation smoke only: construct, no crash, counts. No albedo.

const AudioServiceGd := preload("res://src/audio/audio_service.gd")
const AudioSettingsGd := preload("res://src/audio/audio_settings.gd")
const AudioVoicePoolGd := preload("res://src/audio/audio_voice_pool.gd")
const ClientAudioGd := preload("res://src/client/client_audio.gd")

const TONE: String = "tone"
const STREAM: String = "res://content/audio/f_line_temp/step.wav"
const LAYOUT: String = "res://default_bus_layout.tres"

var _host: Node = null
var _svc: AudioServiceGd = null


func before_each() -> void:
	_host = Node.new()
	add_child(_host)


func after_each() -> void:
	if _svc != null:
		_remove_settings(_svc.settings.path)
		_svc.shutdown()
	_svc = null
	ClientAudioGd.shutdown()
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
	svc.settings.path = "user://audio_settings_kernel_%s.json" % str(Time.get_ticks_usec())
	return svc


func test_pool_cooldown_rejects_the_second_post() -> void:
	var pool: AudioVoicePoolGd = AudioVoicePoolGd.new()
	var first: Dictionary = pool.try_reserve(TONE, 0, 4, 150, 1000)
	assert_true(pool.reserved_ok(first))
	var early: Dictionary = pool.try_reserve(TONE, 0, 4, 150, 1149)
	assert_false(pool.reserved_ok(early))
	var later: Dictionary = pool.try_reserve(TONE, 0, 4, 150, 1150)
	assert_true(pool.reserved_ok(later))


func test_pool_caps_per_cue_and_evicts_lower_priority() -> void:
	var pool: AudioVoicePoolGd = AudioVoicePoolGd.new()
	var a: Dictionary = pool.try_reserve("a", 0, 2, 0, 1)
	var b: Dictionary = pool.try_reserve("a", 0, 2, 0, 2)
	assert_true(pool.reserved_ok(a))
	assert_true(pool.reserved_ok(b))
	assert_eq(pool.count_for("a"), 2)
	var steal: Dictionary = pool.try_reserve("a", 1, 2, 0, 3)
	assert_true(pool.reserved_ok(steal))
	assert_eq(pool.reserved_evict_id(steal), pool.reserved_voice_id(a))
	assert_eq(pool.count_for("a"), 2)
	var blocked: Dictionary = pool.try_reserve("a", -1, 2, 0, 4)
	assert_false(pool.reserved_ok(blocked))


func test_pool_global_cap_evicts_oldest_equal_priority() -> void:
	var pool: AudioVoicePoolGd = AudioVoicePoolGd.new()
	pool.max_voices = 2
	assert_true(pool.reserved_ok(pool.try_reserve("a", 0, 8, 0, 1)))
	assert_true(pool.reserved_ok(pool.try_reserve("b", 0, 8, 0, 2)))
	var third: Dictionary = pool.try_reserve("c", 0, 8, 0, 3)
	assert_true(pool.reserved_ok(third))
	assert_eq(pool.active_count(), 2)
	assert_eq(pool.count_for("a"), 0)
	assert_eq(pool.count_for("c"), 1)


func test_settings_missing_and_corrupt_files_use_defaults() -> void:
	var settings: AudioSettingsGd = AudioSettingsGd.new()
	settings.path = "user://audio_settings_test_%s.json" % str(Time.get_ticks_usec())
	settings.load_or_default()
	assert_eq(settings.get_bus_db(AudioSettingsGd.BUS_MASTER), 0.0)
	assert_eq(settings.get_bus_db(AudioSettingsGd.BUS_MUSIC), -6.0)
	assert_eq(settings.get_bus_db(AudioSettingsGd.BUS_SFX), 0.0)
	assert_false(settings.muted)
	var abs_path: String = ProjectSettings.globalize_path(settings.path)
	var file: FileAccess = FileAccess.open(settings.path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string("{not-json")
	file = null
	settings.load_or_default()
	assert_eq(settings.get_bus_db(AudioSettingsGd.BUS_MUSIC), -6.0)
	assert_false(settings.muted)
	DirAccess.remove_absolute(abs_path)


func test_settings_clamps_and_persists() -> void:
	var settings: AudioSettingsGd = AudioSettingsGd.new()
	settings.path = "user://audio_settings_test_%s.json" % str(Time.get_ticks_usec())
	assert_true(settings.set_bus_db(AudioSettingsGd.BUS_MUSIC, -90.0))
	assert_eq(settings.get_bus_db(AudioSettingsGd.BUS_MUSIC), AudioSettingsGd.DB_MIN)
	assert_false(settings.set_bus_db("nope", 0.0))
	settings.muted = true
	assert_true(settings.save())
	var again: AudioSettingsGd = AudioSettingsGd.new()
	again.path = settings.path
	again.load_or_default()
	assert_true(again.muted)
	assert_eq(again.get_bus_db(AudioSettingsGd.BUS_MUSIC), AudioSettingsGd.DB_MIN)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.path))


func test_headless_service_stays_silent_and_live_fake_throttles() -> void:
	_svc = _make_service()
	_svc.mount(_host)
	assert_true(_svc.backend.is_silent())
	assert_true(_svc.register_cue({
		"id": TONE,
		"streams": PackedStringArray([STREAM]),
		"bus": AudioSettingsGd.BUS_SFX,
		"max_voices": 1,
		"cooldown_ms": 150,
	}))
	assert_false(_svc.post(TONE))
	_svc.backend.force_live = true
	_svc.backend.emit_to_engine = false
	_svc.now_ms_override = 1000
	assert_true(_svc.post(TONE))
	assert_eq(_svc.pool.active_count(), 1)
	_svc.now_ms_override = 1149
	assert_false(_svc.post(TONE))
	_svc.now_ms_override = 1150
	assert_true(_svc.post(TONE))
	_svc.settings.muted = true
	assert_false(_svc.post(TONE))


func test_unknown_cue_and_bad_bus_are_rejected() -> void:
	_svc = _make_service()
	_svc.backend.force_live = true
	_svc.backend.emit_to_engine = false
	_svc.mount(_host)
	assert_false(_svc.register_cue({"id": TONE, "streams": PackedStringArray([STREAM]), "bus": "nope"}))
	assert_false(_svc.register_cue({"id": "", "streams": PackedStringArray([STREAM])}))
	assert_false(_svc.post("missing"))


func test_bus_layout_has_five_named_buses() -> void:
	assert_true(ResourceLoader.exists(LAYOUT))
	assert_eq(AudioServer.get_bus_count(), 5)
	assert_eq(AudioServer.get_bus_name(0), "Master")
	assert_eq(AudioServer.get_bus_name(1), "Music")
	assert_eq(AudioServer.get_bus_name(2), "Sfx")
	assert_eq(AudioServer.get_bus_name(3), "Ui")
	assert_eq(AudioServer.get_bus_name(4), "Ambience")
	var music: int = AudioServer.get_bus_index("Music")
	assert_true(music >= 0)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), -6.0, 0.05)


func test_f_line_slots_register_on_the_host() -> void:
	var mounted: AudioServiceGd = ClientAudioGd.ensure(_host)
	assert_not_null(mounted)
	assert_eq(ClientAudioGd.all_slots().size(), 33)
	for slot: String in ClientAudioGd.all_slots():
		assert_true(mounted.has_cue(slot), slot)
		assert_true(ClientAudioGd.has_slot(slot), slot)
	assert_true(mounted.backend.is_silent())
	assert_false(ClientAudioGd.post(ClientAudioGd.CUE_STEP))


func test_spatial_post_uses_3d_player_when_live() -> void:
	var world: Node3D = Node3D.new()
	_host.add_child(world)
	_svc = _make_service()
	_svc.backend.force_live = true
	_svc.mount(_host)
	_svc.backend.set_space(world)
	assert_true(_svc.register_cue({
		"id": TONE,
		"streams": PackedStringArray([STREAM]),
		"bus": AudioSettingsGd.BUS_SFX,
		"spatial": true,
		"max_distance": 8.0,
		"max_voices": 1,
	}))
	var voice_id: int = _svc.try_post(TONE, {"x": 1.0, "y": 0.0, "z": 2.0})
	assert_gt(voice_id, 0)
	assert_true(_svc.has_voice(voice_id))

