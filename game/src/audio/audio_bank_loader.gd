class_name AudioBankLoader
extends RefCounted

## Loads cue banks from JSON. Unknown keys / missing files / illegal bus fail.
## Catalog membership is checked here. This file must not name a game mode.

const AudioBankGd := preload("res://src/audio/audio_bank.gd")
const AudioCueGd := preload("res://src/audio/audio_cue.gd")
const CatalogGd := preload("res://src/shared/schema/audio_cue_catalog.gd")

const BANKS_DIR: String = "res://content/audio/banks"
const JSON_SUFFIX: String = ".json"
const STREAM_PREFIX: String = "res://content/audio/"
## Executable copy of CD-11 §8.3. Change the numbers there first.
const SFX_MAX_BYTES: int = 262144
const MUSIC_MAX_BYTES: int = 3145728
const TOTAL_MAX_BYTES: int = 20971520


static func load_directory(path: String = BANKS_DIR) -> AudioBankGd:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return null
	var names: PackedStringArray = PackedStringArray()
	for file_name: String in dir.get_files():
		if file_name.ends_with(JSON_SUFFIX):
			names.append(file_name)
	names.sort()
	if names.is_empty():
		return null
	var bank: AudioBankGd = AudioBankGd.new()
	var total_bytes: int = 0
	var seen_files: Dictionary = {}
	for file_name: String in names:
		var full: String = "%s/%s" % [path.rstrip("/"), file_name]
		var parsed: AudioBankGd = load_file(full)
		if parsed == null:
			return null
		for cue_id: String in parsed.ids():
			var cue: AudioCueGd = parsed.get_cue(cue_id)
			if cue == null:
				return null
			if not CatalogGd.has_id(cue_id):
				return null
			if not bank.add(cue):
				return null
			var bytes: int = _stream_bytes(cue, seen_files)
			if bytes < 0:
				return null
			total_bytes += bytes
	if total_bytes > TOTAL_MAX_BYTES:
		return null
	if bank.size() != CatalogGd.all_ids().size():
		return null
	for cue_id: String in CatalogGd.all_ids():
		if not bank.has_id(cue_id):
			return null
	return bank


static func load_file(path: String) -> AudioBankGd:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		return null
	var parsed: Variant = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var body: Dictionary = parsed
	return from_dictionary(body)


static func from_dictionary(body: Dictionary) -> AudioBankGd:
	var version_raw: Variant = body.get(AudioBankGd.KEY_SCHEMA_VERSION, -1)
	if typeof(version_raw) == TYPE_FLOAT:
		var f: float = version_raw
		if f != floorf(f):
			return null
		version_raw = int(f)
	if typeof(version_raw) != TYPE_INT:
		return null
	var version: int = version_raw
	if version != AudioBankGd.SCHEMA_VERSION:
		return null
	if not body.has(AudioBankGd.KEY_CUES):
		return null
	for key: Variant in body.keys():
		if typeof(key) != TYPE_STRING:
			return null
		var name: String = key
		if name != AudioBankGd.KEY_SCHEMA_VERSION and name != AudioBankGd.KEY_CUES:
			return null
	var raw_cues: Variant = body[AudioBankGd.KEY_CUES]
	if typeof(raw_cues) != TYPE_ARRAY:
		return null
	var items: Array = raw_cues
	if items.is_empty():
		return null
	var bank: AudioBankGd = AudioBankGd.new()
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var cue_body: Dictionary = item
		var cue: AudioCueGd = AudioCueGd.from_dictionary(cue_body)
		if cue == null:
			return null
		if not bank.add(cue):
			return null
	return bank


static func bytes_ok(byte_count: int, bus: String) -> bool:
	if byte_count < 0:
		return false
	if bus == AudioCueGd.BUS_MUSIC:
		return byte_count <= MUSIC_MAX_BYTES
	if AudioCueGd.CUE_BUSES.has(bus):
		return byte_count <= SFX_MAX_BYTES
	return false


static func total_ok(byte_count: int) -> bool:
	return byte_count >= 0 and byte_count <= TOTAL_MAX_BYTES


static func streams_ok(cue: AudioCueGd) -> bool:
	if cue == null:
		return false
	var seen: Dictionary = {}
	return _stream_bytes(cue, seen) >= 0


static func _stream_bytes(cue: AudioCueGd, seen_files: Dictionary) -> int:
	var added: int = 0
	for path: String in cue.streams:
		if not path.begins_with(STREAM_PREFIX):
			return -1
		if not FileAccess.file_exists(path):
			return -1
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return -1
		var n: int = file.get_length()
		if not bytes_ok(n, cue.bus):
			return -1
		if seen_files.has(path):
			continue
		seen_files[path] = true
		added += n
	return added
