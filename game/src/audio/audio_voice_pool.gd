class_name AudioVoicePool
extends RefCounted

## Voice slots, per-cue caps, cooldown, and priority eviction.
## Lost events are allowed. No engine types.

const DEFAULT_MAX_VOICES: int = 16
const KEY_OK: String = "ok"
const KEY_VOICE_ID: String = "voice_id"
const KEY_EVICT_ID: String = "evict_id"
const KEY_CUE_ID: String = "cue_id"
const KEY_PRIORITY: String = "priority"
const KEY_STARTED_MS: String = "started_ms"
const KEY_ID: String = "id"

var max_voices: int = DEFAULT_MAX_VOICES
var _voices: Array[Dictionary] = []
var _last_ms: Dictionary = {}
var _next_id: int = 1


func active_count() -> int:
	return _voices.size()


func count_for(cue_id: String) -> int:
	var n: int = 0
	for voice: Dictionary in _voices:
		if _str_at(voice, KEY_CUE_ID, "") == cue_id:
			n += 1
	return n


func ids_for(cue_id: String) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for voice: Dictionary in _voices:
		if _str_at(voice, KEY_CUE_ID, "") == cue_id:
			ids.append(_int_at(voice, KEY_ID, -1))
	return ids


func release(voice_id: int) -> bool:
	for i: int in range(_voices.size()):
		if _int_at(_voices[i], KEY_ID, -1) == voice_id:
			_voices.remove_at(i)
			return true
	return false


func clear() -> void:
	_voices.clear()
	_last_ms.clear()
	_next_id = 1


func reserved_ok(reserved: Dictionary) -> bool:
	return _bool_at(reserved, KEY_OK, false)


func reserved_voice_id(reserved: Dictionary) -> int:
	return _int_at(reserved, KEY_VOICE_ID, -1)


func reserved_evict_id(reserved: Dictionary) -> int:
	return _int_at(reserved, KEY_EVICT_ID, -1)


func try_reserve(
	cue_id: String,
	priority: int,
	max_for_cue: int,
	cooldown_ms: int,
	now_ms: int
) -> Dictionary:
	var fail: Dictionary = {KEY_OK: false, KEY_VOICE_ID: -1, KEY_EVICT_ID: -1}
	if cue_id == "" or max_for_cue < 1 or max_voices < 1:
		return fail
	if cooldown_ms > 0 and _last_ms.has(cue_id):
		var elapsed: int = now_ms - _int_at(_last_ms, cue_id, now_ms)
		if elapsed >= 0 and elapsed < cooldown_ms:
			return fail
	var evict_id: int = -1
	if count_for(cue_id) >= max_for_cue:
		evict_id = _evict_of(cue_id, priority)
		if evict_id < 0:
			return fail
	elif _voices.size() >= max_voices:
		evict_id = _evict_any(priority)
		if evict_id < 0:
			return fail
	if evict_id >= 0:
		release(evict_id)
	var voice_id: int = _next_id
	_next_id += 1
	_voices.append({
		KEY_ID: voice_id,
		KEY_CUE_ID: cue_id,
		KEY_PRIORITY: priority,
		KEY_STARTED_MS: now_ms,
	})
	_last_ms[cue_id] = now_ms
	return {KEY_OK: true, KEY_VOICE_ID: voice_id, KEY_EVICT_ID: evict_id}


func _evict_of(cue_id: String, incoming: int) -> int:
	var best: Dictionary = {}
	for voice: Dictionary in _voices:
		if _str_at(voice, KEY_CUE_ID, "") != cue_id:
			continue
		if _int_at(voice, KEY_PRIORITY, 0) > incoming:
			continue
		if best.is_empty() or _older_or_weaker(voice, best):
			best = voice
	if best.is_empty():
		return -1
	return _int_at(best, KEY_ID, -1)


func _evict_any(incoming: int) -> int:
	var best: Dictionary = {}
	for voice: Dictionary in _voices:
		if _int_at(voice, KEY_PRIORITY, 0) > incoming:
			continue
		if best.is_empty() or _older_or_weaker(voice, best):
			best = voice
	if best.is_empty():
		return -1
	return _int_at(best, KEY_ID, -1)


func _older_or_weaker(candidate: Dictionary, current: Dictionary) -> bool:
	var c_pri: int = _int_at(candidate, KEY_PRIORITY, 0)
	var b_pri: int = _int_at(current, KEY_PRIORITY, 0)
	if c_pri < b_pri:
		return true
	if c_pri > b_pri:
		return false
	return _int_at(candidate, KEY_STARTED_MS, 0) <= _int_at(current, KEY_STARTED_MS, 0)


func _int_at(body: Dictionary, key: String, fallback: int) -> int:
	var raw: Variant = body.get(key, fallback)
	if typeof(raw) != TYPE_INT:
		return fallback
	var value: int = raw
	return value


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
