class_name AudioService
extends RefCounted

## Facade: register / post / stop / bus / mute / shutdown.
## Callers pass opaque cue ids. This file never names a game mode.

const AudioBackendGd := preload("res://src/audio/audio_backend.gd")
const AudioSettingsGd := preload("res://src/audio/audio_settings.gd")
const AudioVoicePoolGd := preload("res://src/audio/audio_voice_pool.gd")

const KEY_ID: String = "id"
const KEY_STREAMS: String = "streams"
const KEY_BUS: String = "bus"
const KEY_GAIN_DB: String = "gain_db"
const KEY_PITCH_MIN: String = "pitch_min"
const KEY_PITCH_MAX: String = "pitch_max"
const KEY_PRIORITY: String = "priority"
const KEY_MAX_VOICES: String = "max_voices"
const KEY_COOLDOWN_MS: String = "cooldown_ms"
const KEY_LOOP: String = "loop"
const DEFAULT_BUS: String = AudioSettingsGd.BUS_SFX
const DEFAULT_MAX_VOICES: int = 8

var backend: AudioBackendGd = AudioBackendGd.new()
var pool: AudioVoicePoolGd = AudioVoicePoolGd.new()
var settings: AudioSettingsGd = AudioSettingsGd.new()
var now_ms_override: int = -1
var _cues: Dictionary = {}


func mount(host: Node) -> void:
	settings.load_or_default()
	backend.on_voice_ended = _on_voice_ended
	backend.mount(host)
	_apply_settings()


func shutdown() -> void:
	backend.stop_all()
	pool.clear()
	backend.unmount()
	_cues.clear()


func register_cue(cue: Dictionary) -> bool:
	var cue_id: String = _str_at(cue, KEY_ID, "")
	if cue_id == "":
		return false
	var streams: PackedStringArray = _read_streams(cue.get(KEY_STREAMS, PackedStringArray()))
	if streams.is_empty():
		return false
	var bus: String = _str_at(cue, KEY_BUS, DEFAULT_BUS)
	if not settings.is_bus(bus):
		return false
	var max_voices: int = _int_at(cue, KEY_MAX_VOICES, DEFAULT_MAX_VOICES)
	if max_voices < 1:
		return false
	var cooldown_ms: int = _int_at(cue, KEY_COOLDOWN_MS, 0)
	if cooldown_ms < 0:
		return false
	_cues[cue_id] = {
		KEY_ID: cue_id,
		KEY_STREAMS: streams,
		KEY_BUS: bus,
		KEY_GAIN_DB: _float_at(cue, KEY_GAIN_DB, 0.0),
		KEY_PITCH_MIN: _float_at(cue, KEY_PITCH_MIN, 1.0),
		KEY_PITCH_MAX: _float_at(cue, KEY_PITCH_MAX, 1.0),
		KEY_PRIORITY: _int_at(cue, KEY_PRIORITY, 0),
		KEY_MAX_VOICES: max_voices,
		KEY_COOLDOWN_MS: cooldown_ms,
		KEY_LOOP: _bool_at(cue, KEY_LOOP, false),
	}
	return true


func has_cue(cue_id: String) -> bool:
	return _cues.has(cue_id)


func post(cue_id: String, _ctx: Dictionary = {}) -> bool:
	if settings.muted:
		return false
	if backend.is_silent():
		return false
	if not _cues.has(cue_id):
		return false
	var cue: Dictionary = _cues[cue_id]
	var now_ms: int = _clock_ms()
	var reserved: Dictionary = pool.try_reserve(
		cue_id,
		_int_at(cue, KEY_PRIORITY, 0),
		_int_at(cue, KEY_MAX_VOICES, DEFAULT_MAX_VOICES),
		_int_at(cue, KEY_COOLDOWN_MS, 0),
		now_ms
	)
	if not pool.reserved_ok(reserved):
		return false
	var evict_id: int = pool.reserved_evict_id(reserved)
	if evict_id >= 0:
		backend.stop(evict_id)
	var voice_id: int = pool.reserved_voice_id(reserved)
	var path: String = _pick_stream(cue)
	var pitch: float = _pick_pitch(cue)
	if not backend.play_2d(
		voice_id,
		path,
		_str_at(cue, KEY_BUS, DEFAULT_BUS),
		_float_at(cue, KEY_GAIN_DB, 0.0),
		pitch,
		_bool_at(cue, KEY_LOOP, false)
	):
		pool.release(voice_id)
		return false
	return true


func stop(cue_id: String) -> void:
	var ids: PackedInt32Array = pool.ids_for(cue_id)
	for voice_id: int in ids:
		backend.stop(voice_id)
		pool.release(voice_id)


func set_bus_db(bus: String, db: float) -> bool:
	if not settings.set_bus_db(bus, db):
		return false
	backend.apply_bus_db(bus, settings.get_bus_db(bus))
	settings.save()
	return true


func set_muted(muted: bool) -> void:
	settings.muted = muted
	backend.apply_mute(muted)
	settings.save()


func _apply_settings() -> void:
	for bus: String in AudioSettingsGd.BUSES:
		backend.apply_bus_db(bus, settings.get_bus_db(bus))
	backend.apply_mute(settings.muted)


func _on_voice_ended(voice_id: int) -> void:
	pool.release(voice_id)


func _clock_ms() -> int:
	if now_ms_override >= 0:
		return now_ms_override
	return Time.get_ticks_msec()


func _pick_stream(cue: Dictionary) -> String:
	var streams: PackedStringArray = _read_streams(cue.get(KEY_STREAMS, PackedStringArray()))
	if streams.is_empty():
		return ""
	if streams.size() == 1:
		return streams[0]
	return streams[randi() % streams.size()]


func _pick_pitch(cue: Dictionary) -> float:
	var lo: float = _float_at(cue, KEY_PITCH_MIN, 1.0)
	var hi: float = _float_at(cue, KEY_PITCH_MAX, 1.0)
	if hi < lo:
		var tmp: float = lo
		lo = hi
		hi = tmp
	if is_equal_approx(lo, hi):
		return lo
	return randf_range(lo, hi)


func _read_streams(raw: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if typeof(raw) == TYPE_PACKED_STRING_ARRAY:
		var packed: PackedStringArray = raw
		for path: String in packed:
			if path != "":
				out.append(path)
		return out
	if typeof(raw) != TYPE_ARRAY:
		return out
	var items: Array = raw
	for item: Variant in items:
		if typeof(item) != TYPE_STRING:
			continue
		var path: String = item
		if path != "":
			out.append(path)
	return out


func _int_at(body: Dictionary, key: String, fallback: int) -> int:
	var raw: Variant = body.get(key, fallback)
	if typeof(raw) != TYPE_INT:
		return fallback
	var value: int = raw
	return value


func _float_at(body: Dictionary, key: String, fallback: float) -> float:
	var raw: Variant = body.get(key, fallback)
	if typeof(raw) == TYPE_FLOAT:
		var f: float = raw
		return f
	if typeof(raw) == TYPE_INT:
		var n: int = raw
		return float(n)
	return fallback


func _str_at(body: Dictionary, key: String, fallback: String) -> String:
	var raw: Variant = body.get(key, fallback)
	if typeof(raw) != TYPE_STRING:
		return fallback
	var value: String = raw
	return value


func _bool_at(body: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = body.get(key, fallback)
	if typeof(raw) != TYPE_BOOL:
		return fallback
	var flag: bool = raw
	return flag
