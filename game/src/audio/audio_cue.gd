class_name AudioCue
extends RefCounted

## One cue record. Unknown keys fail. Catalog membership is the loader's job.
## This file must not name a game mode or a play verb.

const FIELD_ID: String = "id"
const FIELD_STREAMS: String = "streams"
const FIELD_BUS: String = "bus"
const FIELD_GAIN_DB: String = "gain_db"
const FIELD_PITCH_MIN: String = "pitch_min"
const FIELD_PITCH_MAX: String = "pitch_max"
const FIELD_SPATIAL: String = "spatial"
const FIELD_LOOP: String = "loop"
const FIELD_PRIORITY: String = "priority"
const FIELD_MAX_VOICES: String = "max_voices"
const FIELD_COOLDOWN_MS: String = "cooldown_ms"
const FIELD_MAX_DISTANCE: String = "max_distance"
const BUS_MUSIC: String = "music"
const BUS_SFX: String = "sfx"
const BUS_UI: String = "ui"
const BUS_AMBIENCE: String = "ambience"
const CUE_BUSES: PackedStringArray = [
	BUS_MUSIC,
	BUS_SFX,
	BUS_UI,
	BUS_AMBIENCE,
]
const DEFAULT_GAIN_DB: float = 0.0
const DEFAULT_PITCH: float = 1.0
const DEFAULT_MAX_VOICES: int = 8
const DEFAULT_MAX_DISTANCE: float = 0.0

var id: String = ""
var streams: PackedStringArray = PackedStringArray()
var bus: String = BUS_SFX
var gain_db: float = DEFAULT_GAIN_DB
var pitch_min: float = DEFAULT_PITCH
var pitch_max: float = DEFAULT_PITCH
var spatial: bool = false
var loop: bool = false
var priority: int = 0
var max_voices: int = DEFAULT_MAX_VOICES
var cooldown_ms: int = 0
var max_distance: float = DEFAULT_MAX_DISTANCE


static func from_dictionary(body: Dictionary) -> AudioCue:
	for key: Variant in body.keys():
		if typeof(key) != TYPE_STRING:
			return null
		var name: String = key
		if not _is_field(name):
			return null
	var cue_id: String = _req_str(body, FIELD_ID)
	if cue_id == "":
		return null
	var streams: PackedStringArray = _read_streams(body.get(FIELD_STREAMS, null))
	if streams.is_empty():
		return null
	var bus: String = _req_str(body, FIELD_BUS)
	if not CUE_BUSES.has(bus):
		return null
	var gain_box: Array[float] = [DEFAULT_GAIN_DB]
	var pitch_min_box: Array[float] = [DEFAULT_PITCH]
	var pitch_max_box: Array[float] = [DEFAULT_PITCH]
	var spatial_box: Array[bool] = [false]
	var loop_box: Array[bool] = [false]
	var priority_box: Array[int] = [0]
	var voices_box: Array[int] = [DEFAULT_MAX_VOICES]
	var cooldown_box: Array[int] = [0]
	if not _read_float(body, FIELD_GAIN_DB, gain_box):
		return null
	if not _read_float(body, FIELD_PITCH_MIN, pitch_min_box):
		return null
	if not _read_float(body, FIELD_PITCH_MAX, pitch_max_box):
		return null
	var pitch_min: float = pitch_min_box[0]
	var pitch_max: float = pitch_max_box[0]
	if pitch_max < pitch_min:
		return null
	if not _read_bool(body, FIELD_SPATIAL, spatial_box):
		return null
	if not _read_bool(body, FIELD_LOOP, loop_box):
		return null
	if not _read_int(body, FIELD_PRIORITY, priority_box):
		return null
	if not _read_int(body, FIELD_MAX_VOICES, voices_box):
		return null
	var max_voices: int = voices_box[0]
	if max_voices < 1:
		return null
	if not _read_int(body, FIELD_COOLDOWN_MS, cooldown_box):
		return null
	var cooldown_ms: int = cooldown_box[0]
	if cooldown_ms < 0:
		return null
	var spatial: bool = spatial_box[0]
	var distance_box: Array[float] = [DEFAULT_MAX_DISTANCE]
	if spatial:
		if not body.has(FIELD_MAX_DISTANCE):
			return null
		if not _read_float(body, FIELD_MAX_DISTANCE, distance_box):
			return null
		if distance_box[0] <= 0.0:
			return null
	elif body.has(FIELD_MAX_DISTANCE):
		return null
	var cue := new()
	cue.id = cue_id
	cue.streams = streams
	cue.bus = bus
	cue.gain_db = gain_box[0]
	cue.pitch_min = pitch_min
	cue.pitch_max = pitch_max
	cue.spatial = spatial
	cue.loop = loop_box[0]
	cue.priority = priority_box[0]
	cue.max_voices = max_voices
	cue.cooldown_ms = cooldown_ms
	cue.max_distance = distance_box[0]
	return cue


func to_register_dict() -> Dictionary:
	var body: Dictionary = {
		FIELD_ID: id,
		FIELD_STREAMS: streams,
		FIELD_BUS: bus,
		FIELD_GAIN_DB: gain_db,
		FIELD_PITCH_MIN: pitch_min,
		FIELD_PITCH_MAX: pitch_max,
		FIELD_SPATIAL: spatial,
		FIELD_LOOP: loop,
		FIELD_PRIORITY: priority,
		FIELD_MAX_VOICES: max_voices,
		FIELD_COOLDOWN_MS: cooldown_ms,
	}
	if spatial:
		body[FIELD_MAX_DISTANCE] = max_distance
	return body


static func _is_field(name: String) -> bool:
	match name:
		FIELD_ID, FIELD_STREAMS, FIELD_BUS, FIELD_GAIN_DB, FIELD_PITCH_MIN, FIELD_PITCH_MAX, FIELD_SPATIAL, FIELD_LOOP, FIELD_PRIORITY, FIELD_MAX_VOICES, FIELD_COOLDOWN_MS, FIELD_MAX_DISTANCE:
			return true
		_:
			return false


static func _read_streams(raw: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if typeof(raw) == TYPE_PACKED_STRING_ARRAY:
		var packed: PackedStringArray = raw
		for path: String in packed:
			if path == "":
				return PackedStringArray()
			out.append(path)
		return out
	if typeof(raw) != TYPE_ARRAY:
		return out
	var items: Array = raw
	if items.is_empty():
		return out
	for item: Variant in items:
		if typeof(item) != TYPE_STRING:
			return PackedStringArray()
		var path: String = item
		if path == "":
			return PackedStringArray()
		out.append(path)
	return out


static func _req_str(body: Dictionary, key: String) -> String:
	var raw: Variant = body.get(key, "")
	if typeof(raw) != TYPE_STRING:
		return ""
	var value: String = raw
	return value


static func _read_int(body: Dictionary, key: String, box: Array[int]) -> bool:
	if not body.has(key):
		return true
	var raw: Variant = body[key]
	if typeof(raw) == TYPE_INT:
		var value: int = raw
		box[0] = value
		return true
	if typeof(raw) == TYPE_FLOAT:
		var f: float = raw
		if f != floorf(f):
			return false
		box[0] = int(f)
		return true
	return false


static func _read_float(body: Dictionary, key: String, box: Array[float]) -> bool:
	if not body.has(key):
		return true
	var raw: Variant = body[key]
	if typeof(raw) == TYPE_FLOAT:
		var f: float = raw
		box[0] = f
		return true
	if typeof(raw) == TYPE_INT:
		var n: int = raw
		box[0] = float(n)
		return true
	return false


static func _read_bool(body: Dictionary, key: String, box: Array[bool]) -> bool:
	if not body.has(key):
		return true
	var raw: Variant = body[key]
	if typeof(raw) != TYPE_BOOL:
		return false
	var flag: bool = raw
	box[0] = flag
	return true
