class_name AudioSettings
extends RefCounted

## Persistent bus levels. Product defaults live on CD-11 §8.3; this file is
## the runtime copy. Missing or corrupt files fall back to those defaults.
## Never writes SimulationWorld / hash_state / protocol.

const PATH: String = "user://audio_settings.json"
const BUS_MASTER: String = "master"
const BUS_MUSIC: String = "music"
const BUS_SFX: String = "sfx"
const BUS_UI: String = "ui"
const BUS_AMBIENCE: String = "ambience"
const BUSES: PackedStringArray = [
	"master",
	"music",
	"sfx",
	"ui",
	"ambience",
]
const KEY_MUTED: String = "muted"
const DB_MIN: float = -80.0
const DB_MAX: float = 6.0
const DEFAULT_MASTER_DB: float = 0.0
const DEFAULT_MUSIC_DB: float = -6.0
const DEFAULT_REST_DB: float = 0.0

var path: String = PATH
var muted: bool = false
var _db: Dictionary = {}


func _init() -> void:
	reset_defaults()


func reset_defaults() -> void:
	muted = false
	_db = {
		BUS_MASTER: DEFAULT_MASTER_DB,
		BUS_MUSIC: DEFAULT_MUSIC_DB,
		BUS_SFX: DEFAULT_REST_DB,
		BUS_UI: DEFAULT_REST_DB,
		BUS_AMBIENCE: DEFAULT_REST_DB,
	}


func is_bus(bus: String) -> bool:
	return BUSES.has(bus)


func get_bus_db(bus: String) -> float:
	if not is_bus(bus):
		return DEFAULT_REST_DB
	return clampf(_float_at(_db, bus, DEFAULT_REST_DB), DB_MIN, DB_MAX)


func set_bus_db(bus: String, db: float) -> bool:
	if not is_bus(bus):
		return false
	_db[bus] = clampf(db, DB_MIN, DB_MAX)
	return true


func load_or_default() -> void:
	reset_defaults()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		reset_defaults()
		return
	var parsed: Variant = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		reset_defaults()
		return
	var data: Dictionary = parsed
	var muted_raw: Variant = data.get(KEY_MUTED, false)
	if typeof(muted_raw) == TYPE_BOOL:
		var flag: bool = muted_raw
		muted = flag
	for bus: String in BUSES:
		var raw: Variant = data.get(bus, _db[bus])
		if typeof(raw) == TYPE_FLOAT:
			var f: float = raw
			_db[bus] = clampf(f, DB_MIN, DB_MAX)
		elif typeof(raw) == TYPE_INT:
			var n: int = raw
			_db[bus] = clampf(float(n), DB_MIN, DB_MAX)
		else:
			reset_defaults()
			return


func save() -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_to_dict()))
	return true


func _to_dict() -> Dictionary:
	var data: Dictionary = {KEY_MUTED: muted}
	for bus: String in BUSES:
		data[bus] = get_bus_db(bus)
	return data


func _float_at(body: Dictionary, key: String, fallback: float) -> float:
	var raw: Variant = body.get(key, fallback)
	if typeof(raw) == TYPE_FLOAT:
		var f: float = raw
		return f
	if typeof(raw) == TYPE_INT:
		var n: int = raw
		return float(n)
	return fallback
