extends SceneTree
## Renders a UI scene to a PNG so the layout can be reviewed without opening the
## editor.  Also used to capture hover / alternate states.
##
##   Godot_v4.7.2-stable_win64_console.exe --path godot \
##       --rendering-driver opengl3 --resolution 1920x1080 \
##       --script res://tools/screenshot.gd -- \
##       [scenePath] [hoverNodeName|-] [outPath] [prop=value ...]
##
## Examples
##   ... -- res://src/client/ui/scenes/s2_matchmaking.tscn - res://../preview/s2_waiting.png
##   ... -- res://src/client/ui/scenes/s2_matchmaking.tscn - res://../preview/s2_found.png state=1
##   ... -- res://src/client/ui/scenes/s1_lobby.tscn NavMyContent res://../preview/s1_hover.png
##
## Needs a real rendering context - do NOT pass --headless.

const DEFAULT_SCENE := "res://src/client/ui/scenes/s1_lobby.tscn"
const DEFAULT_OUT := "res://../preview/s1_lobby.png"
const WARMUP_FRAMES := 8
const SETTLE_FRAMES := 16

var _frames := 0
var _scene_path := DEFAULT_SCENE
var _hover_node_name := ""
var _out_path := DEFAULT_OUT
var _overrides: Array[String] = []
var _hover_pushed := false
var _scene_root: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "-":
		_scene_path = args[0]
	if args.size() > 1 and args[1] != "-":
		_hover_node_name = args[1]
	if args.size() > 2 and args[2] != "-":
		_out_path = args[2]
	for i in range(3, args.size()):
		_overrides.append(args[i])

	var ps: PackedScene = load(_scene_path)
	if ps == null:
		printerr("could not load ", _scene_path)
		quit(1)
		return
	_scene_root = ps.instantiate()
	root.add_child(_scene_root)

	for spec: String in _overrides:
		var parts := spec.split("=")
		if parts.size() != 2:
			printerr("ignoring malformed override: ", spec)
			continue
		var value: Variant = int(parts[1]) if parts[1].is_valid_int() else parts[1]
		_scene_root.set(parts[0], value)
		print("override ", parts[0], " = ", value)


func _push_hover() -> void:
	var node := _scene_root.find_child(_hover_node_name, true, false)
	if not (node is Control):
		printerr("hover target not found: ", _hover_node_name)
		return
	var pos: Vector2 = (node as Control).get_global_rect().get_center()
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev)
	print("simulated hover at ", pos, " over ", _hover_node_name)


func _process(_delta: float) -> bool:
	_frames += 1

	if _hover_node_name != "" and not _hover_pushed and _frames >= WARMUP_FRAMES:
		_push_hover()
		_hover_pushed = true
		return false

	var settle_from := WARMUP_FRAMES + (SETTLE_FRAMES if _hover_pushed else 0)
	if _frames < settle_from:
		return false

	var tex := root.get_texture()
	if tex == null:
		printerr("no viewport texture")
		quit(1)
		return true

	var img: Image = tex.get_image()
	var err := img.save_png(_out_path)
	if err != OK:
		printerr("save_png failed: ", err, " -> ", _out_path)
		quit(1)
		return true

	print("saved ", _out_path, " ", img.get_width(), "x", img.get_height())
	quit(0)
	return true
