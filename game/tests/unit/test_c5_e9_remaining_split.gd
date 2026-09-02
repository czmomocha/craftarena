extends GutTest

## C5 第 13 章：E9 剩余门面（视觉目录 + 快照映射）。
## 断言的是拆分性质与 E9 行数，不是玩法数值。现有
## test_visual_asset_sharing.gd / test_play_anim_state.gd 仍覆盖公开 API。

const CatalogGd := preload("res://src/shared/visual_asset_catalog.gd")
const FitGd := preload("res://src/shared/visual_asset_catalog_fit.gd")
const MatchSnapshotMapGd := preload("res://src/client/match_snapshot_map.gd")

const E9_LINE_CAP: int = 400
const CATALOG_PATHS: PackedStringArray = [
	"res://src/shared/visual_asset_catalog.gd",
	"res://src/shared/visual_asset_catalog_instantiate.gd",
	"res://src/shared/visual_asset_catalog_fit.gd",
]
const MAP_PATHS: PackedStringArray = [
	"res://src/client/match_snapshot_map.gd",
	"res://src/client/match_snapshot_map_players.gd",
]


func _line_count(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return E9_LINE_CAP
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n").size()


func test_catalog_files_stay_under_e9_line_cap() -> void:
	for path: String in CATALOG_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_snapshot_map_files_stay_under_e9_line_cap() -> void:
	for path: String in MAP_PATHS:
		assert_lt(_line_count(path), E9_LINE_CAP, "%s 必须低于 E9 400 行（含空行）" % path)


func test_catalog_facade_still_owns_public_api() -> void:
	assert_eq(CatalogGd.SEAT_TINT_ALPHA, FitGd.SEAT_TINT_ALPHA)
	CatalogGd.clear_template_cache()
	assert_null(CatalogGd.try_instantiate(""))
	assert_null(CatalogGd.try_instantiate("res://does_not_exist.glb"))


func test_snapshot_map_facade_still_applies_players() -> void:
	var map: MatchSnapshotMapGd = MatchSnapshotMapGd.new()
	var ok: bool = map.apply_players([{
		"x": 0,
		"y": 0,
		"z": 0,
		"yaw_bam": 0,
	}])
	assert_true(ok)
	assert_eq(map.player_count(), 1)
	assert_false(map.allows_settlement())
	assert_false(map.allows_online_writes())
	map.free()
