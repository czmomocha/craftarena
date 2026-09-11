class_name AudioBackend
extends RefCounted

## Sole file in this module that may name AudioServer / AudioStreamPlayer /
## AudioStreamPlayer3D / AudioListener3D.
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
const SPACE_NAME: String = "AudioSpace"
const LISTENER_NAME: String = "AudioEar"
const VOICE_PREFIX: String = "v_"
const FALLBACK_ENGINE_BUS: String = "Sfx"

var host: Node = null
var emit_to_engine: bool = true
var force_live: bool = false
var force_silent: bool = false
var on_voice_ended: Callable = Callable()
var _container: Node = null
var _space: Node3D = null
var _listener: AudioListener3D = null


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
	_drop_listener()
	_drop_space()
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
	if loop:
		player.finished.connect(_on_loop_restart.bind(voice_id))
	else:
		player.finished.connect(_on_player_ended.bind(voice_id))
	_container.add_child(player)
	player.play()
	return true


func play_3d(
	voice_id: int,
	path: String,
	bus: String,
	gain_db: float,
	pitch: float,
	loop: bool,
	pos_x: float,
	pos_y: float,
	pos_z: float,
	max_distance: float
) -> bool:
	if voice_id < 1 or path == "":
		return false
	if not emit_to_engine:
		return true
	if is_silent():
		return false
	if _space == null or not is_instance_valid(_space):
		return false
	if not ResourceLoader.exists(path):
		return false
	var loaded: Variant = load(path)
	if not (loaded is AudioStream):
		return false
	var stream: AudioStream = loaded
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = _engine_bus(bus)
	player.volume_db = gain_db
	player.pitch_scale = clampf(pitch, 0.01, 4.0)
	player.max_distance = maxf(max_distance, 0.01)
	player.position = Vector3(pos_x, pos_y, pos_z)
	player.name = _voice_name(voice_id)
	if loop:
		player.finished.connect(_on_loop_restart.bind(voice_id))
	else:
		player.finished.connect(_on_player_ended.bind(voice_id))
	_space.add_child(player)
	player.play()
	return true


func set_space(world: Node3D) -> void:
	if world == null or not is_instance_valid(world):
		_drop_space()
		return
	if _space != null and is_instance_valid(_space) and _space.get_parent() == world:
		return
	_drop_space()
	_space = Node3D.new()
	_space.name = SPACE_NAME
	world.add_child(_space)


func attach_listener(anchor: Node3D) -> void:
	if anchor == null or not is_instance_valid(anchor):
		_drop_listener()
		return
	var existing: Node = anchor.get_node_or_null(LISTENER_NAME)
	if existing is AudioListener3D:
		_listener = existing
		_listener.make_current()
		return
	_drop_listener()
	_listener = AudioListener3D.new()
	_listener.name = LISTENER_NAME
	anchor.add_child(_listener)
	_listener.make_current()


func set_voice_position(voice_id: int, pos_x: float, pos_y: float, pos_z: float) -> void:
	var node: Node = _voice_node(voice_id)
	if node is AudioStreamPlayer3D:
		var player: AudioStreamPlayer3D = node
		player.position = Vector3(pos_x, pos_y, pos_z)


func set_voice_gain(voice_id: int, gain_db: float) -> void:
	var node: Node = _voice_node(voice_id)
	if node is AudioStreamPlayer:
		var player: AudioStreamPlayer = node
		player.volume_db = gain_db
	elif node is AudioStreamPlayer3D:
		var spatial: AudioStreamPlayer3D = node
		spatial.volume_db = gain_db


func stop(voice_id: int) -> void:
	var node: Node = _voice_node(voice_id)
	if node != null and is_instance_valid(node):
		node.queue_free()


func stop_all() -> void:
	_free_children(_container)
	_free_children(_space)


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


func _on_loop_restart(voice_id: int) -> void:
	var node: Node = _voice_node(voice_id)
	if node is AudioStreamPlayer:
		var player: AudioStreamPlayer = node
		player.play()
	elif node is AudioStreamPlayer3D:
		var spatial: AudioStreamPlayer3D = node
		spatial.play()


func _voice_node(voice_id: int) -> Node:
	var voice_name: String = _voice_name(voice_id)
	if _container != null and is_instance_valid(_container):
		var flat: Node = _container.get_node_or_null(voice_name)
		if flat != null:
			return flat
	if _space != null and is_instance_valid(_space):
		return _space.get_node_or_null(voice_name)
	return null


func _drop_space() -> void:
	_free_children(_space)
	if _space != null and is_instance_valid(_space):
		_space.queue_free()
	_space = null


func _drop_listener() -> void:
	if _listener != null and is_instance_valid(_listener):
		_listener.queue_free()
	_listener = null


func _free_children(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	var children: Array[Node] = []
	for child: Node in root.get_children():
		children.append(child)
	for child: Node in children:
		if is_instance_valid(child):
			child.queue_free()


func _on_player_ended(voice_id: int) -> void:
	stop(voice_id)
	if on_voice_ended.is_valid():
		on_voice_ended.call(voice_id)


func _voice_name(voice_id: int) -> String:
	return "%s%d" % [VOICE_PREFIX, voice_id]


func has_voice(voice_id: int) -> bool:
	var node: Node = _voice_node(voice_id)
	return node != null and is_instance_valid(node)


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
