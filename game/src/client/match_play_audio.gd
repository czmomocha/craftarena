class_name MatchPlayAudio
extends RefCounted

## Solo / Preview presentation pump. Posts router events and keeps 3D
## loop voices near the listener. Never writes authority.

const ObserveGd := preload("res://src/games/traprush/traprush_audio_observe.gd")
const RouterGd := preload("res://src/games/traprush/traprush_audio_router.gd")
const AudioServiceGd := preload("res://src/audio/audio_service.gd")

var observe: ObserveGd = ObserveGd.new()
var _loops: Dictionary = {}


func reset(service: AudioServiceGd) -> void:
	if service != null:
		for key: Variant in _loops.keys():
			_stop_stored(service, key)
		service.set_space(null)
		service.attach_listener(null)
	_loops.clear()
	observe.reset()


func pump(
	service: AudioServiceGd,
	events: PackedStringArray,
	loops: Array[Dictionary],
	map: Node3D,
	ear: Node3D,
	origin: Vector3
) -> void:
	if service == null:
		return
	service.set_space(map)
	service.attach_listener(ear)
	for event: String in events:
		var cue_id: String = RouterGd.cue(event)
		if cue_id != "":
			service.post(cue_id)
	_sync_loops(service, loops, origin)


func _sync_loops(service: AudioServiceGd, loops: Array[Dictionary], origin: Vector3) -> void:
	var wanted: Dictionary = {}
	for item: Dictionary in loops:
		var tag: String = _str_at(item, ObserveGd.LOOP_TAG)
		var event: String = _str_at(item, ObserveGd.LOOP_EVENT)
		if tag == "" or event == "":
			continue
		var cue_id: String = RouterGd.cue(event)
		if cue_id == "":
			continue
		var pos: Vector3 = _meters(item)
		var max_d: float = service.cue_max_distance(cue_id)
		if max_d > 0.0 and origin.distance_to(pos) > max_d:
			continue
		wanted[tag] = {
			"cue": cue_id,
			"x": pos.x,
			"y": pos.y,
			"z": pos.z,
		}
	var stale: Array[String] = []
	for key: Variant in _loops.keys():
		if typeof(key) != TYPE_STRING:
			continue
		var tag: String = key
		if wanted.has(tag):
			continue
		stale.append(tag)
	for tag: String in stale:
		_stop_stored(service, tag)
		_loops.erase(tag)
	for key: Variant in wanted.keys():
		if typeof(key) != TYPE_STRING:
			continue
		var tag: String = key
		var body: Dictionary = wanted[tag]
		var cue_id: String = _str_at(body, "cue")
		var pos_x: float = _float_at(body, "x")
		var pos_y: float = _float_at(body, "y")
		var pos_z: float = _float_at(body, "z")
		var voice_id: int = _int_at(_loops, tag)
		if voice_id > 0 and service.has_voice(voice_id):
			service.move_voice(voice_id, pos_x, pos_y, pos_z)
			continue
		var ctx: Dictionary = {
			AudioServiceGd.KEY_X: pos_x,
			AudioServiceGd.KEY_Y: pos_y,
			AudioServiceGd.KEY_Z: pos_z,
		}
		voice_id = service.try_post(cue_id, ctx)
		if voice_id > 0:
			_loops[tag] = voice_id


func _stop_stored(service: AudioServiceGd, key: Variant) -> void:
	var voice_id: int = _int_at(_loops, key)
	if voice_id > 0:
		service.stop_voice(voice_id)


static func _meters(item: Dictionary) -> Vector3:
	var scale: float = float(Fixed.SCALE)
	return Vector3(
		_coord(item, ObserveGd.LOOP_X) / scale,
		_coord(item, ObserveGd.LOOP_Y) / scale,
		_coord(item, ObserveGd.LOOP_Z) / scale
	)


static func pose_meters(pose: Dictionary) -> Vector3:
	return _meters(pose)


static func _coord(item: Dictionary, key: String) -> float:
	var raw: Variant = item.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0.0
	var value: int = raw
	return float(value)


static func _str_at(body: Dictionary, key: String) -> String:
	var raw: Variant = body.get(key, "")
	if typeof(raw) != TYPE_STRING:
		return ""
	var value: String = raw
	return value


static func _float_at(body: Dictionary, key: String) -> float:
	var raw: Variant = body.get(key, 0.0)
	if typeof(raw) == TYPE_FLOAT:
		var f: float = raw
		return f
	if typeof(raw) == TYPE_INT:
		var n: int = raw
		return float(n)
	return 0.0


static func _int_at(body: Dictionary, key: Variant) -> int:
	var raw: Variant = body.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	var value: int = raw
	return value
