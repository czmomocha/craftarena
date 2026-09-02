extends GutTest

## C5 第 9 章：SimulationWorld + SimulationBundle 按层拆门面。
## 断言的是拆分性质与 E9 行数，不是玩法数值。现有
## test_simulation_world.gd / test_gameplay_asset_contract.gd 仍覆盖公开 API。

const SimulationWorldGd := preload("res://src/simulation/simulation_world.gd")
const SimulationBundleGd := preload("res://src/ugc/simulation_bundle.gd")

const E9_LINE_CAP: int = 400
const WORLD_PATHS: PackedStringArray = [
	"res://src/simulation/simulation_world.gd",
	"res://src/simulation/simulation_world_query.gd",
	"res://src/simulation/simulation_world_move.gd",
	"res://src/simulation/simulation_world_index.gd",
]
const BUNDLE_PATHS: PackedStringArray = [
	"res://src/ugc/simulation_bundle.gd",
	"res://src/ugc/simulation_bundle_decode.gd",
	"res://src/ugc/simulation_bundle_bags.gd",
]


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func test_world_files_stay_under_e9_line_cap() -> void:
	for path: String in WORLD_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_bundle_files_stay_under_e9_line_cap() -> void:
	for path: String in BUNDLE_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_new_world_owns_collaborators() -> void:
	var world: SimulationWorldGd = SimulationWorldGd.new(1)
	assert_not_null(world.query)
	assert_not_null(world.move)
	assert_not_null(world.index)
	assert_eq(world.tick_index, 0)
	assert_eq(world.spawn_capsule(0, 0, 0, 0), 1)


func test_bundle_from_dictionary_stays_on_the_facade() -> void:
	var empty_v2: Dictionary = {
		"schema_version": SimulationBundleGd.SCHEMA_VERSION,
		"cell": 65536,
		"source_revision": 0,
		"assets": [],
		"pads": [],
		"portals": [],
		"finish": [],
		"destructibles": [],
		"hazards": [],
		"solids": [],
		"pickups": [],
	}
	var decoded: SimulationBundleGd = SimulationBundleGd.from_dictionary(empty_v2)
	assert_not_null(decoded)
	assert_eq(decoded.cell, 65536)
	assert_eq(decoded.pads.size(), 0)
	var encoded: Dictionary = decoded.to_dictionary()
	var encoded_raw: Variant = encoded.get("schema_version", null)
	assert_true(typeof(encoded_raw) == TYPE_INT)
	var encoded_version: int = encoded_raw
	assert_eq(encoded_version, SimulationBundleGd.SCHEMA_VERSION)
