class_name AudioMusicDirector
extends RefCounted

## Single-instance bed player. Callers pass opaque cue ids. Same id does
## not restart. One fade at a time; a later id waits in a one-slot queue.

const AudioServiceGd := preload("res://src/audio/audio_service.gd")

const SLOT_A: int = 9001
const SLOT_B: int = 9002
const SILENCE_DB: float = -80.0
const DEFAULT_FADE_MS: int = 400

var service: AudioServiceGd = null
var fade_ms: int = DEFAULT_FADE_MS
var now_ms_override: int = -1
var start_count: int = 0
var _active_id: String = ""
var _pending_id: String = ""
var _queued_id: String = ""
var _out_slot: int = 0
var _in_slot: int = 0
var _out_from_db: float = SILENCE_DB
var _in_to_db: float = 0.0
var _fade_t0: int = -1
var _next_is_a: bool = true


func bind(next: AudioServiceGd) -> void:
	service = next


func current_id() -> String:
	if _pending_id != "":
		return _pending_id
	return _active_id


func fading() -> bool:
	return _fade_t0 >= 0


func request(cue_id: String) -> bool:
	if cue_id == "" or service == null or not service.has_cue(cue_id):
		return false
	if fading():
		if cue_id == _pending_id:
			_queued_id = ""
			return true
		_queued_id = cue_id
		return true
	if cue_id == _active_id:
		return true
	return _begin(cue_id)


func advance() -> void:
	if not fading():
		return
	var elapsed: int = _clock_ms() - _fade_t0
	var t: float = 1.0
	if fade_ms > 0:
		t = clampf(float(elapsed) / float(fade_ms), 0.0, 1.0)
	_apply_gains(t)
	if t < 1.0:
		return
	_settle_fade()


func stop() -> void:
	_halt(_out_slot)
	_halt(_in_slot)
	_active_id = ""
	_pending_id = ""
	_queued_id = ""
	_out_slot = 0
	_in_slot = 0
	_fade_t0 = -1


func _begin(cue_id: String) -> bool:
	var path: String = service.stream_path(cue_id)
	if path == "":
		return false
	var incoming: int = SLOT_A if _next_is_a else SLOT_B
	_next_is_a = not _next_is_a
	var gain: float = service.cue_gain_db(cue_id)
	if not _start_slot(incoming, cue_id, path, SILENCE_DB):
		return false
	_out_slot = _in_slot
	_in_slot = incoming
	_out_from_db = _out_from_db if _active_id != "" else SILENCE_DB
	if _active_id != "":
		_out_from_db = service.cue_gain_db(_active_id)
	_in_to_db = gain
	_pending_id = cue_id
	_fade_t0 = _clock_ms()
	start_count += 1
	_apply_gains(0.0)
	return true


func _start_slot(slot: int, cue_id: String, path: String, gain_db: float) -> bool:
	if service.backend.is_silent():
		return true
	return service.backend.play_2d(
		slot,
		path,
		service.cue_bus(cue_id),
		gain_db,
		1.0,
		service.cue_loops(cue_id)
	)


func _apply_gains(t: float) -> void:
	if _out_slot > 0:
		service.backend.set_voice_gain(_out_slot, lerpf(_out_from_db, SILENCE_DB, t))
	if _in_slot > 0:
		service.backend.set_voice_gain(_in_slot, lerpf(SILENCE_DB, _in_to_db, t))


func _settle_fade() -> void:
	_halt(_out_slot)
	_out_slot = 0
	_active_id = _pending_id
	_pending_id = ""
	_fade_t0 = -1
	_out_from_db = _in_to_db
	var next_id: String = _queued_id
	_queued_id = ""
	if next_id != "" and next_id != _active_id:
		_begin(next_id)


func _halt(slot: int) -> void:
	if slot < 1:
		return
	service.backend.stop(slot)


func _clock_ms() -> int:
	if now_ms_override >= 0:
		return now_ms_override
	return Time.get_ticks_msec()
