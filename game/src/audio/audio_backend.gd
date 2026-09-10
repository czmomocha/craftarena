class_name AudioBackend
extends RefCounted

## Sole file in this module that may name AudioServer / AudioStreamPlayer.
## Headless DisplayServer and `--audio-driver Dummy` stay silent.
## CI GUT is `--headless` without a Dummy flag; DisplayServer is the gate.

const BUS_MASTER: String = "master"
const BUS_MUSIC: String = "music"
const BUS_SFX: String = "sfx"
const BUS_UI: String = "ui"
const BUS_AMBIENCE: String = "ambience"
const ENGINE_BUS: Dictionary = {
	BUS_MASTER: "Master",
	BUS_MUSIC: "Music",
	BUS_SFX: "Sfx",
	BUS_UI: "Ui",
	BUS_AMBIENCE: "Ambience",
}
const DRIVER_DUMMY: String = "Dummy"
const CONTAINER_NAME: String = "AudioVoices"
const VOICE_PREFIX: String = "v_"
const FALLBACK_ENGINE_BUS: String = "Sfx"

var host: Node = null
var emit_to_engine: bool = true
var force_live: bool = false
var force_silent: bool = false
var on_voice_ended: Callable = Callable()
var _container: Node = null


func is_silent() -> bool:
	if force_live:
		return false
	if force_silent:
		return true
	if DisplayServer.get_name() == "headless":
		return true
	return _cmdline_dummy()


func mount(next_host: Node) -> void:
	host = next_host
	if host == null or not is_instance_valid(host):
		return
	_ensure_container()


func unmount() -> void:
	stop_all()
	if _container != null and is_instance_valid(_container):
		_container.queue_free()
	_container = null
	host = null


func play_2d(
	voice_id: int,
	path: String,
	bus: String,
	gain_db: float,
	pitch: float,
	loop: bool
) -> bool:
	if voice_id < 1 or path == "":
		return false
	if not emit_to_engine:
		return true
	if is_silent():
		return false
	_ensure_container()
	if _container == null:
		return false
	if not ResourceLoader.exists(path):
		return false
	var loaded: Variant = load(path)
	if not (loaded is AudioStream):
		return false
	var stream: AudioStream = loaded
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = _engine_bus(bus)
	player.volume_db = gain_db
	player.pitch_scale = clampf(pitch, 0.01, 4.0)
	player.name = _voice_name(voice_id)
	if not loop:
		player.finished.connect(_on_player_ended.bind(voice_id))
	_container.add_child(player)
	player.play()
	return true


func stop(voice_id: int) -> void:
	if _container == null or not is_instance_valid(_container):
		return
	var node: Node = _container.get_node_or_null(_voice_name(voice_id))
	if node != null and is_instance_valid(node):
		node.queue_free()


func stop_all() -> void:
	if _container == null or not is_instance_valid(_container):
		return
	var children: Array[Node] = []
	for child: Node in _container.get_children():
		children.append(child)
	for child: Node in children:
		if is_instance_valid(child):
			child.queue_free()


func apply_bus_db(bus: String, db: float) -> void:
	if not emit_to_engine or is_silent():
		return
	var engine_name: String = _engine_bus(bus)
	if engine_name == "":
		return
	var index: int = AudioServer.get_bus_index(engine_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, db)


func apply_mute(muted: bool) -> void:
	if not emit_to_engine or is_silent():
		return
	var index: int = AudioServer.get_bus_index("Master")
	if index < 0:
		return
	AudioServer.set_bus_mute(index, muted)


func _ensure_container() -> void:
	if host == null or not is_instance_valid(host):
		return
	if _container != null and is_instance_valid(_container):
		return
	_container = Node.new()
	_container.name = CONTAINER_NAME
	host.add_child(_container)


func _on_player_ended(voice_id: int) -> void:
	stop(voice_id)
	if on_voice_ended.is_valid():
		on_voice_ended.call(voice_id)


func _voice_name(voice_id: int) -> String:
	return "%s%d" % [VOICE_PREFIX, voice_id]


func _engine_bus(bus: String) -> String:
	var raw: Variant = ENGINE_BUS.get(bus, FALLBACK_ENGINE_BUS)
	if typeof(raw) != TYPE_STRING:
		return FALLBACK_ENGINE_BUS
	var engine_name: String = raw
	return engine_name


func _cmdline_dummy() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	for i: int in range(args.size()):
		var token: String = args[i]
		if token == "--audio-driver" and i + 1 < args.size():
			return args[i + 1] == DRIVER_DUMMY
		if token.begins_with("--audio-driver="):
			return token.get_slice("=", 1) == DRIVER_DUMMY
	return false
