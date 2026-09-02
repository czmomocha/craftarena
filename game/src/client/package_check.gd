class_name PackageCheck
extends RefCounted

## Exported-package self check (course correction C1).
##
## The project had never left the dev machine, so every claim about what a
## packaged build contains was untested. This turns the C1 checklist into one
## command that any machine can re-run:
##
##     CraftArena.exe --headless -- --package-check
##
## It prints a single JSON line and exits non-zero when a mandatory check
## fails, so the runbook step is "expect ok=true" instead of "look around".

const FLAG: String = "--package-check"
const EVENT: String = "package_check"
const PROBE_PATH: String = "user://__package_check_probe.json"
const MCP_AUTOLOAD: String = "_mcp_game_helper"
const ADDONS_DIR: String = "res://addons"
const GODOT_AI_ADDON: String = "godot_ai"
const TEST_SENTINEL: String = "res://tests/unit/test_project_contract.gd"
const COMPATIBILITY: String = "gl_compatibility"

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const AuthoringDraftStoreGd := preload("res://src/creator/authoring_draft_store.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")


static func requested(user_args: PackedStringArray) -> bool:
	return user_args.has(FLAG)


static func report() -> Dictionary:
	var failures: Array[String] = []
	var checks: Dictionary = _run_checks(failures)
	return _body(checks, failures)


## Single entry point for the CLI so the caller never has to pull `ok` back
## out of a Variant just to pick an exit code.
static func run_and_print() -> int:
	var failures: Array[String] = []
	var checks: Dictionary = _run_checks(failures)
	print(JSON.stringify(_body(checks, failures)))
	return 0 if failures.is_empty() else 1


static func _run_checks(failures: Array[String]) -> Dictionary:
	var checks: Dictionary = {}
	# A source run legitimately has res://tests and res://addons on disk, and
	# CD-51 §7.3 expects the locally installed Godot AI plugin to sit in the
	# working tree. Those are only defects once they reach a package.
	var packed: bool = OS.has_feature("template")
	var addons: PackedStringArray = _packed_addons()
	_record(checks, failures, "courses_readable", _courses_readable(), true)
	_record(checks, failures, "character_visual_loadable", _character_visual_loadable(), true)
	_record(checks, failures, "terrain_tile_visual_loadable", _terrain_tile_visual_loadable(), true)
	_record(checks, failures, "checkpoint_pad_visual_loadable", _fitted_tile_loadable(SharedVisualAssetCatalog.CHECKPOINT_PAD_SCENE_PATH), true)
	_record(checks, failures, "checkpoint_gate_visual_loadable", _fitted_prop_loadable(SharedVisualAssetCatalog.CHECKPOINT_GATE_SCENE_PATH), true)
	_record(checks, failures, "finish_gate_visual_loadable", _fitted_prop_loadable(SharedVisualAssetCatalog.FINISH_GATE_SCENE_PATH), true)
	_record(checks, failures, "crate_visual_loadable", _fitted_prop_loadable(SharedVisualAssetCatalog.CRATE_SCENE_PATH), true)
	_record(checks, failures, "hazard_roller_visual_loadable", _fitted_prop_loadable(SharedVisualAssetCatalog.HAZARD_ROLLER_SCENE_PATH), true)
	_record(checks, failures, "locale_table_loadable", _locale_table_loadable(), true)
	_record(checks, failures, "user_draft_roundtrip", _user_draft_roundtrip(), true)
	_record(checks, failures, "no_mcp_autoload", not _autoload_names().has(MCP_AUTOLOAD), true)
	_record(checks, failures, "runtime_material", _runtime_material_ok(), true)
	_record(checks, failures, "compatibility_renderer", _rendering_method() == COMPATIBILITY, true)
	_record(checks, failures, "no_godot_ai_packed", not addons.has(GODOT_AI_ADDON), packed)
	_record(checks, failures, "no_addons_packed", addons.is_empty(), packed)
	_record(checks, failures, "tests_excluded", not FileAccess.file_exists(TEST_SENTINEL), packed)
	return checks


static func _record(
	checks: Dictionary,
	failures: Array[String],
	check_name: String,
	passed: bool,
	mandatory: bool,
) -> void:
	checks[check_name] = passed
	if mandatory and not passed:
		failures.append(check_name)


static func _body(checks: Dictionary, failures: Array[String]) -> Dictionary:
	return {
		"event": EVENT,
		"ok": failures.is_empty(),
		"failures": failures,
		"checks": checks,
		"template_build": OS.has_feature("template"),
		"debug_build": OS.is_debug_build(),
		"headless": DisplayServer.get_name() == "headless",
		"web": OS.has_feature("web"),
		"engine": str(Engine.get_version_info().get("string", "")),
		"rendering_method": _rendering_method(),
		"autoloads": _autoload_names(),
		"packed_addons": _packed_addons(),
		"course_paths": _course_paths(),
		"character_visual_path": SharedVisualAssetCatalog.CHARACTER_SCENE_PATH,
		"terrain_tile_visual_path": SharedVisualAssetCatalog.TERRAIN_TILE_SCENE_PATH,
		"checkpoint_pad_visual_path": SharedVisualAssetCatalog.CHECKPOINT_PAD_SCENE_PATH,
		"checkpoint_gate_visual_path": SharedVisualAssetCatalog.CHECKPOINT_GATE_SCENE_PATH,
		"finish_gate_visual_path": SharedVisualAssetCatalog.FINISH_GATE_SCENE_PATH,
		"crate_visual_path": SharedVisualAssetCatalog.CRATE_SCENE_PATH,
		"hazard_roller_visual_path": SharedVisualAssetCatalog.HAZARD_ROLLER_SCENE_PATH,
		"locale_table_path": UiCopy.TABLE_PATH,
		"locale_file_exists": FileAccess.file_exists(UiCopy.TABLE_PATH),
		"locale_open_ok": _locale_open_ok(),
		"locale_banner_zh": UiCopy.text(UiCopy.OFFLINE_BANNER, "zh_CN"),
		"locale_parse": UiCopy.parse_stats(),
		"user_data_dir": OS.get_user_data_dir(),
		"draft_path": ProjectSettings.globalize_path(AuthoringDraftStoreGd.DEFAULT_PATH),
	}


static func _course_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	var ids: Array[String] = [
		OfficialTraprushCoursesGd.COURSE_01,
		OfficialTraprushCoursesGd.COURSE_02,
		OfficialTraprushCoursesGd.COURSE_03,
	]
	for id: String in ids:
		paths.append(OfficialTraprushCoursesGd.document_path(id))
	return paths


## Decoding, not just file_exists: an export filter can ship a file the engine
## refuses to parse and still pass an existence test.
static func _courses_readable() -> bool:
	for path: String in _course_paths():
		if AuthoringDocumentGd.load_from_path(path) == null:
			return false
	return true


static func _locale_open_ok() -> bool:
	var file: FileAccess = FileAccess.open(UiCopy.TABLE_PATH, FileAccess.READ)
	if file == null:
		return false
	file.close()
	return true


static func _locale_table_loadable() -> bool:
	UiCopy.reset_for_tests()
	if not UiCopy.ensure_loaded():
		return false
	var banner: String = UiCopy.text(UiCopy.OFFLINE_BANNER, "zh_CN")
	return banner != "" and banner != UiCopy.OFFLINE_BANNER


## Instantiating, not just ResourceLoader.exists: a `.glb` reaches the package as
## an imported `.scn`, so a wrong export filter or a missing reimport shows up
## here and nowhere else. The表现层 falls back to a placeholder box when this
## fails, which is exactly why it needs a check — a silent fallback in a
## shipped package looks identical to "the art was never added".
static func _character_visual_loadable() -> bool:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_character()
	if visual == null:
		return false
	visual.free()
	return true


## Fitting, not just instantiating: the tile is scaled from its own AABB, so a
## mesh-less or degenerate import would pass a load test and then silently fall
## back to a placeholder box on every floor in the course.
static func _terrain_tile_visual_loadable() -> bool:
	return _fitted_tile_loadable(SharedVisualAssetCatalog.TERRAIN_TILE_SCENE_PATH)


static func _fitted_tile_loadable(path: String) -> bool:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_fitted_tile_from(path)
	if visual == null:
		return false
	visual.free()
	return true


static func _fitted_prop_loadable(path: String) -> bool:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate_fitted_prop(path)
	if visual == null:
		return false
	visual.free()
	return true


static func _user_draft_roundtrip() -> bool:
	var written: FileAccess = FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	if written == null:
		return false
	written.store_string("{\"probe\":1}")
	written.close()
	var read_back: FileAccess = FileAccess.open(PROBE_PATH, FileAccess.READ)
	if read_back == null:
		return false
	var text: String = read_back.get_as_text()
	read_back.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	return JSON.parse_string(text) is Dictionary


static func _runtime_material_ok() -> bool:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.5, 0.75, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material.albedo_color.is_equal_approx(Color(0.25, 0.5, 0.75, 1.0))


static func _rendering_method() -> String:
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))


## Directory listing, not file_exists: the exporter stores plugin scripts as
## `.gdc` + `.remap`, so probing for `plugin.cfg` reports "clean" on a package
## that in fact shipped the whole addon.
static func _packed_addons() -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(ADDONS_DIR)
	if dir == null:
		return PackedStringArray()
	return dir.get_directories()


static func _autoload_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in ProjectSettings.get_property_list():
		var property: String = str(entry.get("name", ""))
		if property.begins_with("autoload/"):
			names.append(property.trim_prefix("autoload/"))
	return names
