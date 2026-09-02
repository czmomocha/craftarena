extends GutTest

## C5 第 12 章：TraprushTopologyCompiler 拆成 bags / fields。
## 断言的是拆分性质与 E9 行数，不是玩法数值。现有
## test_traprush_topology_compiler.gd 仍覆盖公开 API。

const AuthoringWorldGd := preload("res://src/creator/authoring_world.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const E9_LINE_CAP: int = 400
const COMPILER_PATHS: PackedStringArray = [
	"res://src/ugc/traprush_topology_compiler.gd",
	"res://src/ugc/traprush_topology_compiler_bags.gd",
	"res://src/ugc/traprush_topology_compiler_fields.gd",
]


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func test_compiler_files_stay_under_e9_line_cap() -> void:
	for path: String in COMPILER_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_compile_stays_on_the_facade() -> void:
	var world: AuthoringWorldGd = AuthoringWorldGd.new()
	var bundle: SimulationBundle = TraprushTopologyCompilerGd.compile(world)
	assert_not_null(bundle)
	assert_eq(bundle.pads.size(), 0)
	assert_eq(bundle.portals.size(), 0)
	assert_null(TraprushTopologyCompilerGd.compile(null))
