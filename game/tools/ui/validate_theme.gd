extends SceneTree
## Headless sanity check for theme/craft_arena.tres.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path godot \
##       --script res://tools/validate_theme.gd
##
## Exits non-zero when the theme fails to load or a known item is missing, so it
## can be wired into CI.

const THEME_PATH := "res://content/ui/theme/craft_arena.tres"

# [theme_type, stylebox_name] pairs that must resolve.
const STYLEBOX_CHECKS := [
	["ButtonPrimary", "normal"],
	["ButtonSecondary", "normal"],
	["ButtonGhost", "normal"],
	["ButtonDanger", "normal"],
	["CardPanel", "panel"],
	["CardHoverPanel", "panel"],
	["SunkenPanel", "panel"],
	["DevBar", "panel"],
	["OfflineBanner", "panel"],
	["NavItem", "normal"],
	["VersionRow", "panel"],
	["TabChip", "normal"],
	["TabChipActive", "normal"],
	["InputDark", "normal"],
	["InputError", "normal"],
]

# Label variations whose font size must be present.
const FONT_SIZE_CHECKS := [
	"DisplayChannelTitle",
	"DisplayTimer",
	"PageTitle",
	"CardTitle",
	"NavTitle",
	"BodyText",
	"NavSubtitle",
	"ChipLabel",
	"StatusCaption",
	"MonoCaption",
]


func _init() -> void:
	var res: Resource = ResourceLoader.load(THEME_PATH)
	if res == null:
		printerr("FAILED: could not load ", THEME_PATH)
		quit(1)
		return
	if not (res is Theme):
		printerr("FAILED: ", res.get_class(), " is not a Theme")
		quit(1)
		return

	var theme: Theme = res
	var types: PackedStringArray = theme.get_type_list()
	print("Theme loaded: ", THEME_PATH)
	print("  theme types      = ", types.size())

	var variations := 0
	for t in types:
		if theme.get_type_variation_base(t) != StringName():
			variations += 1
	print("  type variations  = ", variations)

	var failures := 0

	for check: Array in STYLEBOX_CHECKS:
		var type_name := StringName(str(check[0]))
		var item_name := StringName(str(check[1]))
		var sb: StyleBox = theme.get_stylebox(item_name, type_name)
		if sb == null:
			printerr("  MISSING stylebox '", item_name, "' on type '", type_name, "'")
			failures += 1

	for name: String in FONT_SIZE_CHECKS:
		var fs: int = theme.get_font_size(&"font_size", StringName(name))
		if fs <= 0:
			printerr("  MISSING font_size on type '", name, "'")
			failures += 1

	print("  stylebox checks  = ", STYLEBOX_CHECKS.size(), " (", failures, " failure(s))")
	print("  font size checks = ", FONT_SIZE_CHECKS.size())

	# Print the resolved variation chain for the record.
	for name: String in ["ButtonPrimary", "CardPanel", "NavItem", "TabChipActive", "InputError"]:
		print("  ", name, " -> base ", theme.get_type_variation_base(StringName(name)))

	if failures > 0:
		printerr("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
