class_name ClientAudio
extends RefCounted

## Presentation host for the audio module. Registers the eight F-line temp
## WAVs and is the only remaining play() entry for those slots. Cue ids here
## may use gameplay names; game/src/audio/** must not.

const AudioServiceGd := preload("res://src/audio/audio_service.gd")
const AudioSettingsGd := preload("res://src/audio/audio_settings.gd")

const DIR: String = "res://content/audio/f_line_temp/"
const CUE_STEP: String = "step"
const CUE_JUMP: String = "jump"
const CUE_LAND: String = "land"
const CUE_PICKUP: String = "pickup"
const CUE_CRATE: String = "crate"
const CUE_HAZARD_WARN: String = "hazard_warn"
const CUE_PORTAL: String = "portal"
const CUE_FINISH: String = "finish"
const STEP_COOLDOWN_MS: int = 150

static var service: AudioServiceGd = null


static func ensure(host: Node) -> AudioServiceGd:
	if service != null:
		return service
	service = AudioServiceGd.new()
	service.mount(host)
	_register_f_line(service)
	return service


static func bind(next: AudioServiceGd) -> void:
	service = next


static func shutdown() -> void:
	if service != null:
		service.shutdown()
	service = null


static func post(cue_id: String) -> bool:
	if service == null:
		return false
	return service.post(cue_id)


static func muted() -> bool:
	if service == null:
		return DisplayServer.get_name() == "headless"
	return service.settings.muted or service.backend.is_silent()


static func has_slot(slot: String) -> bool:
	var path: String = path_for(slot)
	if path == "":
		return false
	return FileAccess.file_exists(path)


static func path_for(slot: String) -> String:
	if not _slots().has(slot):
		return ""
	return "%s%s.wav" % [DIR, slot]


static func all_slots() -> PackedStringArray:
	return PackedStringArray([
		CUE_STEP,
		CUE_JUMP,
		CUE_LAND,
		CUE_PICKUP,
		CUE_CRATE,
		CUE_HAZARD_WARN,
		CUE_PORTAL,
		CUE_FINISH,
	])


static func _register_f_line(target: AudioServiceGd) -> void:
	for slot: String in all_slots():
		var max_voices: int = 2
		var cooldown_ms: int = 0
		var priority: int = 0
		if slot == CUE_STEP:
			max_voices = 1
			cooldown_ms = STEP_COOLDOWN_MS
		elif slot == CUE_HAZARD_WARN:
			max_voices = 4
			priority = 2
		elif slot == CUE_FINISH:
			max_voices = 1
			priority = 3
		target.register_cue({
			"id": slot,
			"streams": PackedStringArray([path_for(slot)]),
			"bus": AudioSettingsGd.BUS_SFX,
			"max_voices": max_voices,
			"cooldown_ms": cooldown_ms,
			"priority": priority,
		})


static func _slots() -> Dictionary:
	var out: Dictionary = {}
	for slot: String in all_slots():
		out[slot] = true
	return out
