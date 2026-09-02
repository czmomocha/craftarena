extends GutTest

## 工程契约守卫测试。
##
## 把 CD-00 宪法与 CD-51 §5 中"项目设置层面"的红线变成可执行断言，
## 防止有人在编辑器里顺手改掉渲染基线、类型严格度或输入动作而无人察觉。
## 这批断言不依赖任何玩法实现，因此从 M0 起就必须常绿。

const WARNING_LEVEL_ERROR: int = 2

## 宪法第二十三条要求核心目录静态类型且警告视为错误。4.7 的 directory_rules
## 无法让单个目录比全局更严格，因此这些警告在全局取 Error，UI 与工具层局部豁免。
const STRICT_TYPING_WARNINGS: PackedStringArray = [
	"untyped_declaration",
	"inference_on_variant",
	"unsafe_call_argument",
	"unsafe_cast",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_void_return",
]

## CD-51 §5 要求的输入动作：移动、跳跃、使用道具、推击、冲刺、复位、交互、编辑器相机、建造、升级、出售。
const REQUIRED_INPUT_ACTIONS: PackedStringArray = [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"jump",
	"use_item",
	"shove",
	"sprint",
	"reset_checkpoint",
	"interact",
	"editor_camera_forward",
	"editor_camera_back",
	"editor_camera_left",
	"editor_camera_right",
	"editor_camera_up",
	"editor_camera_down",
	"editor_camera_look",
	"build",
	"upgrade",
	"sell",
]

## 宪法第七条：禁止引入 C# 与 Godot .NET 运行时，否则 Web / 微信小游戏导出路径断掉。
const FORBIDDEN_EXTENSIONS: PackedStringArray = [".cs", ".csproj", ".sln"]


func test_project_name_matches_naming_contract() -> void:
	# CD-11 §1 锁定 config/name 的写法，中文名只能进本地化表。
	var project_name: String = ProjectSettings.get_setting("application/config/name", "")
	assert_eq(project_name, "Craft Arena", "config/name 必须是 CD-11 §1 规定的英文写法")


func test_renderer_uses_compatibility_baseline_on_every_platform() -> void:
	# 宪法第七条：Compatibility 是共同渲染基线，移动端和 Web 都不得偏离。
	var platform_settings: PackedStringArray = [
		"rendering/renderer/rendering_method",
		"rendering/renderer/rendering_method.mobile",
		"rendering/renderer/rendering_method.web",
	]
	for setting_name: String in platform_settings:
		var rendering_method: String = ProjectSettings.get_setting(setting_name, "")
		assert_eq(
			rendering_method,
			"gl_compatibility",
			"%s 必须保持 Compatibility 基线" % setting_name
		)


func test_strict_typing_warnings_are_errors() -> void:
	for warning_name: String in STRICT_TYPING_WARNINGS:
		var setting_name: String = "debug/gdscript/warnings/%s" % warning_name
		var level: int = ProjectSettings.get_setting(setting_name, -1)
		assert_eq(
			level,
			WARNING_LEVEL_ERROR,
			"%s 必须是 Error，否则宪法第二十三条失去引擎强制" % setting_name
		)


func test_gdscript_warnings_are_enabled() -> void:
	var warnings_enabled: bool = ProjectSettings.get_setting("debug/gdscript/warnings/enable", false)
	assert_true(warnings_enabled, "关闭 GDScript 警告会让上面所有 Error 级别形同虚设")


func test_required_input_actions_exist() -> void:
	for action_name: String in REQUIRED_INPUT_ACTIONS:
		assert_true(
			ProjectSettings.has_setting("input/%s" % action_name),
			"缺少 CD-51 §5 要求的输入动作：%s" % action_name
		)


func test_ui_base_resolution_is_the_d4_baseline() -> void:
	# D4：UI 分辨率基准 1920×1080。它是**设计基准**，不是窗口尺寸——
	# 下一条断言的 window_*_override 才是开发机运行窗。
	var width_raw: Variant = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	var height_raw: Variant = ProjectSettings.get_setting("display/window/size/viewport_height", 0)
	assert_eq(typeof(width_raw), TYPE_INT)
	assert_eq(typeof(height_raw), TYPE_INT)
	var width: int = width_raw
	var height: int = height_raw
	assert_eq(
		Vector2i(width, height),
		PlaceholderSpec.UI_BASE_SIZE,
		"UI 基准必须与 PlaceholderSpec.UI_BASE_SIZE 是同一个数（D4）"
	)
	# 没有 canvas_items 拉伸，1920×1080 只是个更大的视口，HUD 字号仍随屏幕缩水。
	var stretch_mode: String = ProjectSettings.get_setting("display/window/stretch/mode", "")
	var stretch_aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect", "")
	assert_eq(stretch_mode, "canvas_items", "UI 基准要生效必须按 canvas_items 缩放 2D")
	assert_eq(stretch_aspect, "expand", "expand 才不会在非 16:9 屏上加黑边")


func test_dev_run_window_override_is_not_product_fov() -> void:
	# 开发机运行窗仍是 1600×900 最大化（CD-21 §3.2 / CD-53 §4 的实现落点）。
	# 接线前它写在 viewport_* 上；UI 基准接管 viewport_* 之后，它搬到 override。
	var width_raw: Variant = ProjectSettings.get_setting("display/window/size/window_width_override", 0)
	var height_raw: Variant = ProjectSettings.get_setting("display/window/size/window_height_override", 0)
	var mode_raw: Variant = ProjectSettings.get_setting("display/window/size/mode", -1)
	assert_eq(typeof(width_raw), TYPE_INT)
	assert_eq(typeof(height_raw), TYPE_INT)
	assert_eq(typeof(mode_raw), TYPE_INT)
	var width: int = width_raw
	var height: int = height_raw
	var mode: int = mode_raw
	assert_eq(width, 1600)
	assert_eq(height, 900)
	assert_eq(mode, 2)


func test_project_contains_no_dotnet_sources() -> void:
	var offenders: PackedStringArray = _collect_forbidden_files("res://")
	assert_eq(
		offenders.size(),
		0,
		"宪法第七条禁止 C# / .NET 工程文件，发现：%s" % ", ".join(offenders)
	)


func _collect_forbidden_files(directory_path: String) -> PackedStringArray:
	var offenders: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(directory_path)
	if dir == null:
		return offenders

	for file_name: String in dir.get_files():
		var lowered: String = file_name.to_lower()
		for extension: String in FORBIDDEN_EXTENSIONS:
			if lowered.ends_with(extension):
				offenders.append(directory_path.path_join(file_name))
				break

	for sub_directory: String in dir.get_directories():
		offenders.append_array(_collect_forbidden_files(directory_path.path_join(sub_directory)))

	return offenders
