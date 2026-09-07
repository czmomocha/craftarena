class_name PlaySfx
extends RefCounted

## F-line FB presentation bus. Streams are internally generated temp WAVs
## (no third-party license). Headless MatchServer / GUT must stay silent.

const BUS_NAME: String = "Sfx"
const DIR: String = "res://content/audio/f_line_temp/"
const SLOT_STEP: String = "step"
const SLOT_JUMP: String = "jump"
const SLOT_LAND: String = "land"
const SLOT_PICKUP: String = "pickup"
const SLOT_CRATE: String = "crate"
const SLOT_HAZARD_WARN: String = "hazard_warn"
const SLOT_PORTAL: String = "portal"
const SLOT_FINISH: String = "finish"

const FILES: Dictionary = {
	SLOT_STEP: "step.wav",
	SLOT_JUMP: "jump.wav",
	SLOT_LAND: "land.wav",
	SLOT_PICKUP: "pickup.wav",
	SLOT_CRATE: "crate.wav",
	SLOT_HAZARD_WARN: "hazard_warn.wav",
	SLOT_PORTAL: "portal.wav",
	SLOT_FINISH: "finish.wav",
}


static func muted() -> bool:
	return DisplayServer.get_name() == "headless"


static func path_for(slot: String) -> String:
	if not FILES.has(slot):
		return ""
	return "%s%s" % [DIR, str(FILES[slot])]


static func has_slot(slot: String) -> bool:
	var path: String = path_for(slot)
	if path == "":
		return false
	return FileAccess.file_exists(path)


static func play(slot: String) -> bool:
	if muted():
		return false
	var path: String = path_for(slot)
	if path == "":
		return false
	if not ResourceLoader.exists(path):
		return false
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_NAME
	tree.root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return true
