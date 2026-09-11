class_name AudioBank
extends RefCounted

## Cue collection. Duplicate ids fail. Does not name a game mode.

const AudioCueGd := preload("res://src/audio/audio_cue.gd")
const AudioServiceGd := preload("res://src/audio/audio_service.gd")

const SCHEMA_VERSION: int = 1
const KEY_SCHEMA_VERSION: String = "schema_version"
const KEY_CUES: String = "cues"

var _cues: Dictionary = {}


func size() -> int:
	return _cues.size()


func has_id(cue_id: String) -> bool:
	return _cues.has(cue_id)


func get_cue(cue_id: String) -> AudioCueGd:
	if not _cues.has(cue_id):
		return null
	var cue: AudioCueGd = _cues[cue_id]
	return cue


func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for cue_id: Variant in _cues.keys():
		if typeof(cue_id) == TYPE_STRING:
			var id: String = cue_id
			out.append(id)
	out.sort()
	return out


func add(cue: AudioCueGd) -> bool:
	if cue == null or cue.id == "":
		return false
	if _cues.has(cue.id):
		return false
	_cues[cue.id] = cue
	return true


func apply_to(service: AudioServiceGd) -> bool:
	if service == null:
		return false
	for cue_id: String in ids():
		var cue: AudioCueGd = get_cue(cue_id)
		if cue == null:
			return false
		if not service.register_cue(cue.to_register_dict()):
			return false
	return true
