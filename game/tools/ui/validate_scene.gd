extends SceneTree
## Generic headless scene check.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path godot \
##       --script res://tools/ui/validate_scene.gd -- [scenePath] [scenePath...]
##
## For each scene it verifies that:
##   1. the scene loads and instantiates
##   2. every Control.theme_type_variation actually resolves to a theme type
##   3. every node carrying press_feedback.gd is a BaseButton
##
## Written against Craft Arena's strict GDScript warnings (untyped declarations
## and unsafe Variant access are treated as errors), so everything is typed.

const DEFAULT_SCENES: Array[String] = [
	"res://src/client/ui/scenes/s1_lobby.tscn",
	"res://src/client/ui/scenes/s2_matchmaking.tscn",
	"res://src/client/ui/scenes/s3_workshop.tscn",
]

const FEEDBACK_SCRIPT := "press_feedback.gd"


func _walk(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child: Node in node.get_children():
		_walk(child, out)


func _check_scene(path: String) -> int:
	var ps: PackedScene = load(path)
	if ps == null:
		printerr("FAILED: could not load ", path)
		return 1

	var inst: Node = ps.instantiate()
	if inst == null:
		printerr("FAILED: could not instantiate ", path)
		return 1

	var nodes: Array[Node] = []
	_walk(inst, nodes)

	var theme: Theme = null
	if inst is Control:
		theme = (inst as Control).theme

	var failures := 0
	var variations_checked := 0
	var feedback_checked := 0
	var missing_variations := 0

	for node: Node in nodes:
		if not (node is Control):
			continue
		var control := node as Control

		var variation := String(control.theme_type_variation)
		if variation != "":
			variations_checked += 1
			if theme == null:
				printerr("  ", path, ": '", node.name, "' uses variation '", variation, "' but no theme on root")
				failures += 1
			elif theme.get_type_variation_base(StringName(variation)) == StringName() \
					and theme.get_type_list().find(StringName(variation)) == -1:
				missing_variations += 1
				printerr("  ", path, ": '", node.name, "' uses undeclared variation '", variation, "'")
				failures += 1

		var script: Script = node.get_script()
		if script != null and script.resource_path.ends_with(FEEDBACK_SCRIPT):
			feedback_checked += 1
			if not (node is BaseButton):
				printerr("  ", path, ": '", node.name, "' has press_feedback but is ", node.get_class())
				failures += 1

	print(path)
	print("  nodes            = ", nodes.size())
	print("  variations used  = ", variations_checked, " (", missing_variations, " undeclared)")
	print("  feedback scripts = ", feedback_checked)

	inst.free()
	return failures


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scenes: Array[String] = []
	for arg: String in args:
		scenes.append(arg)
	if scenes.is_empty():
		scenes = DEFAULT_SCENES

	var total := 0
	for path: String in scenes:
		total += _check_scene(path)
		print("")

	if total > 0:
		printerr("RESULT: FAIL (", total, " failure(s))")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
