extends GutTest

## 导出包自检（纠偏 C1）。
##
## 这批断言守的是「包里到底有什么」这条链路，不是表现。审视基线记录
## CD-62 把「`_mcp_game_helper` 进 Headless」标成「已缓解」，而项目从未导出过包，
## 该缓解没有任何实证。自检脚本要能在源码运行与导出包两种模式下给出可读结论，
## 并且只在真正打进包之后才把 addons / tests 当作缺陷。

const PackageCheckGd := preload("res://src/client/package_check.gd")

const ALWAYS_MANDATORY: PackedStringArray = [
	"courses_readable",
	"locale_table_loadable",
	"user_draft_roundtrip",
	"no_mcp_autoload",
	"runtime_material",
	"compatibility_renderer",
]

## 源码运行下这几条必然为假（tests 与 addons 就在磁盘上），因此它们只能在
## 导出包里成为失败项，否则每台开发机跑一次都会红。
const PACKED_ONLY: PackedStringArray = [
	"no_godot_ai_packed",
	"no_addons_packed",
	"tests_excluded",
]


func test_flag_is_read_from_user_args_only() -> void:
	assert_true(PackageCheckGd.requested(PackedStringArray(["--package-check"])))
	assert_true(PackageCheckGd.requested(PackedStringArray(["--course=x", "--package-check"])))
	assert_false(PackageCheckGd.requested(PackedStringArray([])))
	assert_false(PackageCheckGd.requested(PackedStringArray(["--package"])))
	assert_false(PackageCheckGd.requested(PackedStringArray(["package-check"])))


func test_source_run_passes_every_always_mandatory_check() -> void:
	var report: Dictionary = PackageCheckGd.report()
	var checks: Dictionary = report["checks"]
	for check_name: String in ALWAYS_MANDATORY:
		assert_true(
			checks.has(check_name),
			"自检缺少 %s，runbook 会验不到这条" % check_name
		)
		var passed: bool = checks[check_name]
		assert_true(passed, "源码运行下 %s 必须通过" % check_name)
	var ok: bool = report["ok"]
	assert_true(ok, "源码运行不应有失败项：%s" % str(report["failures"]))


func test_packed_only_checks_are_reported_but_do_not_fail_a_source_run() -> void:
	var report: Dictionary = PackageCheckGd.report()
	var checks: Dictionary = report["checks"]
	var failures: Array = report["failures"]
	var template_build: bool = report["template_build"]
	assert_false(template_build, "GUT 跑的是源码工程，不是导出包")
	for check_name: String in PACKED_ONLY:
		assert_true(checks.has(check_name), "自检缺少 %s" % check_name)
		assert_false(failures.has(check_name), "%s 不得让源码运行变红" % check_name)
	var tests_excluded: bool = checks["tests_excluded"]
	assert_false(tests_excluded, "源码工程里 res://tests 就该存在")


func test_report_names_all_three_official_courses() -> void:
	var report: Dictionary = PackageCheckGd.report()
	var paths: PackedStringArray = report["course_paths"]
	assert_eq(paths.size(), 3)
	for path: String in paths:
		assert_true(path.begins_with("res://content/official/traprush/"), path)
		assert_true(path.ends_with(".json"), path)
	assert_eq(str(report["locale_table_path"]), "res://content/locale/craft_arena.csv")
	var locale_exists: bool = report["locale_file_exists"]
	var locale_open: bool = report["locale_open_ok"]
	assert_true(locale_exists, "源码树里 CSV 必须能 exists")
	assert_true(locale_open, "源码树里 CSV 必须能 open")
	assert_eq(str(report["locale_banner_zh"]), "离线试玩，成绩不上传")


func test_probe_file_does_not_survive_the_check() -> void:
	var probe: String = ProjectSettings.globalize_path(PackageCheckGd.PROBE_PATH)
	PackageCheckGd.report()
	assert_false(
		FileAccess.file_exists(PackageCheckGd.PROBE_PATH),
		"自检探针文件必须删掉，否则会在玩家 user:// 里留垃圾：%s" % probe
	)


func test_committed_project_has_no_mcp_autoload() -> void:
	# CD-51 §7.3：`_mcp_game_helper` 只允许存在于未提交的本机 project.godot。
	var report: Dictionary = PackageCheckGd.report()
	var autoloads: PackedStringArray = report["autoloads"]
	assert_false(
		autoloads.has(PackageCheckGd.MCP_AUTOLOAD),
		"project.godot 被 MCP 弄脏了，提交前必须还原：%s" % str(autoloads)
	)
