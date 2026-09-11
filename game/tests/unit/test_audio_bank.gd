extends GutTest

## M5 A2: cue bank / catalog. Strong assertions on ids, params, and rejects.

const AudioBankGd := preload("res://src/audio/audio_bank.gd")
const AudioBankLoaderGd := preload("res://src/audio/audio_bank_loader.gd")
const AudioCueGd := preload("res://src/audio/audio_cue.gd")
const AudioServiceGd := preload("res://src/audio/audio_service.gd")
const CatalogGd := preload("res://src/shared/schema/audio_cue_catalog.gd")
const ClientAudioGd := preload("res://src/client/client_audio.gd")

const STREAM: String = "res://content/audio/f_line_temp/step.wav"

var _host: Node = null


func before_each() -> void:
	_host = Node.new()
	add_child(_host)


func after_each() -> void:
	ClientAudioGd.shutdown()
	if _host != null and is_instance_valid(_host):
		_host.free()
	_host = null


func test_catalog_lists_the_eight_platform_ids() -> void:
	assert_eq(CatalogGd.all_ids().size(), 8)
	assert_true(CatalogGd.has_id(CatalogGd.STEP))
	assert_true(CatalogGd.has_id(ClientAudioGd.CUE_HAZARD_WARN))
	assert_false(CatalogGd.has_id("nope"))


func test_cue_rejects_unknown_key_illegal_bus_and_spatial_without_distance() -> void:
	assert_null(AudioCueGd.from_dictionary({
		"id": "step",
		"streams": PackedStringArray([STREAM]),
		"bus": AudioCueGd.BUS_SFX,
		"extra": 1,
	}))
	assert_null(AudioCueGd.from_dictionary({
		"id": "step",
		"streams": PackedStringArray([STREAM]),
		"bus": "master",
	}))
	assert_null(AudioCueGd.from_dictionary({
		"id": "step",
		"streams": PackedStringArray([STREAM]),
		"bus": AudioCueGd.BUS_SFX,
		"spatial": true,
	}))
	var ok: AudioCueGd = AudioCueGd.from_dictionary({
		"id": "step",
		"streams": PackedStringArray([STREAM]),
		"bus": AudioCueGd.BUS_SFX,
		"max_voices": 1,
		"cooldown_ms": 150,
	})
	assert_not_null(ok)
	assert_eq(ok.max_voices, 1)
	assert_eq(ok.cooldown_ms, 150)


func test_bank_rejects_duplicate_ids() -> void:
	var cue: AudioCueGd = AudioCueGd.from_dictionary({
		"id": "step",
		"streams": PackedStringArray([STREAM]),
		"bus": AudioCueGd.BUS_SFX,
	})
	var bank: AudioBankGd = AudioBankGd.new()
	assert_true(bank.add(cue))
	assert_false(bank.add(cue))
	assert_eq(bank.size(), 1)


func test_loader_rejects_unknown_catalog_id_and_missing_file() -> void:
	var unknown: AudioCueGd = AudioCueGd.from_dictionary({
		"id": "nope",
		"streams": PackedStringArray([STREAM]),
		"bus": AudioCueGd.BUS_SFX,
	})
	assert_not_null(unknown)
	assert_false(CatalogGd.has_id(unknown.id))
	var missing: AudioCueGd = AudioCueGd.from_dictionary({
		"id": "step",
		"streams": PackedStringArray(["res://content/audio/f_line_temp/missing.wav"]),
		"bus": AudioCueGd.BUS_SFX,
	})
	assert_not_null(missing)
	assert_false(AudioBankLoaderGd.streams_ok(missing))
	assert_true(AudioBankLoaderGd.streams_ok(AudioCueGd.from_dictionary({
		"id": "step",
		"streams": PackedStringArray([STREAM]),
		"bus": AudioCueGd.BUS_SFX,
	})))


func test_budget_helpers_reject_oversize() -> void:
	assert_true(AudioBankLoaderGd.bytes_ok(AudioBankLoaderGd.SFX_MAX_BYTES, AudioCueGd.BUS_SFX))
	assert_false(AudioBankLoaderGd.bytes_ok(AudioBankLoaderGd.SFX_MAX_BYTES + 1, AudioCueGd.BUS_SFX))
	assert_false(AudioBankLoaderGd.total_ok(AudioBankLoaderGd.TOTAL_MAX_BYTES + 1))


func test_production_banks_match_a1_slot_params() -> void:
	var bank: AudioBankGd = AudioBankLoaderGd.load_directory()
	assert_not_null(bank)
	assert_eq(bank.size(), 8)
	for cue_id: String in CatalogGd.all_ids():
		assert_true(bank.has_id(cue_id), cue_id)
		var cue: AudioCueGd = bank.get_cue(cue_id)
		assert_eq(cue.bus, AudioCueGd.BUS_SFX)
		assert_eq(cue.streams.size(), 1)
		assert_eq(cue.streams[0], ClientAudioGd.path_for(cue_id))
		assert_false(cue.spatial)
		assert_false(cue.loop)
	assert_eq(bank.get_cue(CatalogGd.STEP).max_voices, 1)
	assert_eq(bank.get_cue(CatalogGd.STEP).cooldown_ms, 150)
	assert_eq(bank.get_cue(CatalogGd.HAZARD_WARN).max_voices, 4)
	assert_eq(bank.get_cue(CatalogGd.HAZARD_WARN).priority, 2)
	assert_eq(bank.get_cue(CatalogGd.FINISH).max_voices, 1)
	assert_eq(bank.get_cue(CatalogGd.FINISH).priority, 3)


func test_client_audio_loads_banks_on_the_host() -> void:
	var mounted: AudioServiceGd = ClientAudioGd.ensure(_host)
	assert_not_null(mounted)
	assert_eq(ClientAudioGd.all_slots().size(), 8)
	for slot: String in ClientAudioGd.all_slots():
		assert_true(mounted.has_cue(slot), slot)
		assert_true(ClientAudioGd.has_slot(slot), slot)
	assert_true(mounted.backend.is_silent())
	assert_false(ClientAudioGd.post(ClientAudioGd.CUE_STEP))
