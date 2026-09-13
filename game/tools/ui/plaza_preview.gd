extends SceneTree
## Renders the plaza screen as the *entry* drives it, not in standalone preview.
##
##   "$GODOT4" --path game --rendering-driver opengl3 --resolution 1920x1080 \
##       --script res://tools/ui/plaza_preview.gd -- [outPath]
##
## Why this exists: `screenshot.gd` renders s3_workshop.tscn on its own, which
## shows DEMO_ENTRIES — eight cards with thumbnails and authors. Real listing
## rows have neither (see content_plaza_entry.gd), so the standalone preview
## says nothing about what a player will actually see. This feeds the screen the
## same shape `ContentPlaza.list_tab()` returns.
##
## Engine is located through GODOT4 (README section "命令"); no hard-coded path.
## Needs a real rendering context - do NOT pass --headless. Not in CI.

const WorkshopScene := preload("res://src/client/ui/scenes/s3_workshop.tscn")

const DEFAULT_OUT := "/tmp/uicheck/plaza_driven.png"
const SETTLE_FRAMES := 12

## Shaped exactly like `content_plaza.gd` `index_listing` rows: no author, no
## thumbnail, play_count / rating_sum / rating_count as integers.
const ROWS: Array[Dictionary] = [
	{
		"content_id": "ugc_pipe_01", "display_name": "warm_forge",
		"tags": ["portal", "hazard"], "play_count": 7,
		"rating_sum": 9, "rating_count": 2, "verified": true,
	},
	{
		"content_id": "ugc_pipe_02", "display_name": "quiet_lane",
		"tags": ["crate"], "play_count": 0,
		"rating_sum": 0, "rating_count": 0, "verified": false,
	},
	{
		"content_id": "ugc_pipe_03", "display_name": "bright_span",
		"tags": ["portal"], "play_count": 142,
		"rating_sum": 20, "rating_count": 5, "verified": true,
	},
]

var _frames := 0
var _out := DEFAULT_OUT


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "-":
		_out = args[0]

	var screen: Control = WorkshopScene.instantiate() as Control
	screen.set("demo_content", false)
	root.add_child(screen)
	screen.call("set_listing", ROWS)
	screen.call("set_active_tab", "newest")
	screen.call("set_empty_notice", "")
	print("driven with ", ROWS.size(), " listing rows")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	var image: Image = root.get_texture().get_image()
	var err: int = image.save_png(_out)
	if err != OK:
		printerr("save_png failed: ", err, " -> ", _out)
		quit(1)
		return true
	print("saved ", _out, " ", image.get_width(), "x", image.get_height())
	quit(0)
	return true
