extends GutTest

## 导出预设契约（纠偏 C1）。
##
## 审视基线记录导出预设为 0，项目从未离开开发机。预设一旦存在就会决定
## 「包里有什么」，所以它和 project.godot 一样需要断言守护，而不是靠人记得。
##
## 第一次真导出暴露了两件事，这里各留一条断言：
## 1. `res://addons/godot_ai/` 的脚本会被打进 release 包（`plugin.cfg` 不是资源、
##    不进包，所以按文件探测会误判为干净）；
## 2. 官方赛道是普通 `.json`，不是引擎资源，不写 include_filter 就不会进包。

const PRESETS_PATH: String = "res://export_presets.cfg"

const EXPECTED_PRESETS: PackedStringArray = ["Windows Desktop", "Linux Headless", "Web"]
const EXPECTED_PLATFORMS: PackedStringArray = ["Windows Desktop", "Linux", "Web"]

const REQUIRED_EXCLUDES: PackedStringArray = ["addons/*", "tests/*"]
const REQUIRED_INCLUDE: String = "content/official/*.json"


func _load_presets() -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(PRESETS_PATH), OK, "读不到 %s" % PRESETS_PATH)
	return config


func _preset_sections(config: ConfigFile) -> PackedStringArray:
	var sections: PackedStringArray = []
	for section: String in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			sections.append(section)
	return sections


func test_three_presets_cover_windows_linux_headless_and_web() -> void:
	var config: ConfigFile = _load_presets()
	var found: Dictionary = {}
	for section: String in _preset_sections(config):
		var preset_name: String = config.get_value(section, "name", "")
		found[preset_name] = str(config.get_value(section, "platform", ""))
	for index: int in EXPECTED_PRESETS.size():
		var preset_name: String = EXPECTED_PRESETS[index]
		assert_true(found.has(preset_name), "缺少导出预设：%s" % preset_name)
		var platform: String = found.get(preset_name, "")
		assert_eq(
			platform,
			EXPECTED_PLATFORMS[index],
			"%s 的 platform 写错会让导出直接找不到模板" % preset_name
		)


func test_every_preset_keeps_addons_and_tests_out_of_the_package() -> void:
	var config: ConfigFile = _load_presets()
	for section: String in _preset_sections(config):
		var exclude: String = config.get_value(section, "exclude_filter", "")
		for pattern: String in REQUIRED_EXCLUDES:
			assert_true(
				exclude.contains(pattern),
				"%s 的 exclude_filter 缺少 %s，GUT 与 Godot AI 插件会被打进玩家包" % [section, pattern]
			)


func test_every_preset_ships_the_official_courses() -> void:
	var config: ConfigFile = _load_presets()
	for section: String in _preset_sections(config):
		var include: String = config.get_value(section, "include_filter", "")
		assert_true(
			include.contains(REQUIRED_INCLUDE),
			"%s 不带 %s，官方赛道 JSON 不会进包" % [section, REQUIRED_INCLUDE]
		)


func test_linux_preset_is_a_dedicated_server() -> void:
	var config: ConfigFile = _load_presets()
	for section: String in _preset_sections(config):
		if str(config.get_value(section, "name", "")) != "Linux Headless":
			continue
		var dedicated: bool = config.get_value(section, "dedicated_server", false)
		assert_true(dedicated, "香港 VPS 上跑的是 MatchServer，不是带窗口的客户端")
		return
	fail_test("找不到 Linux Headless 预设")


func test_no_preset_carries_encryption_or_signing_secrets() -> void:
	# CD-51 §3：仓库只允许假凭据。导出预设是最容易漏真密钥的地方。
	var config: ConfigFile = _load_presets()
	for section: String in config.get_sections():
		for key: String in config.get_section_keys(section):
			var lowered: String = key.to_lower()
			if not (lowered.contains("password") or lowered.contains("key")):
				continue
			var value: String = str(config.get_value(section, key, ""))
			assert_eq(value, "", "%s/%s 不得带值，密钥只能走外部配置" % [section, key])
