extends GutTest

## 可玩性深化 轨 2：课内动效。
## 强断言只写在「由 tick 推出的读数」上（那是确定性契约）；模型与色板只烟测。

const FxGd := preload("res://src/client/match_course_map_fx.gd")
const MatchCourseMapGd := preload("res://src/client/match_course_map.gd")
const SharedVisualAssetCatalogGd := preload("res://src/shared/visual_asset_catalog.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"


# ---- 由 tick 推出的读数 ----

func test_spin_is_a_pure_function_of_tick_and_entity() -> void:
	assert_eq(FxGd.spin_radians(0, 0), 0.0)
	assert_eq(
		FxGd.spin_radians(7, 3),
		FxGd.spin_radians(7, 3),
		"同一 tick 必须画出同一帧，否则两台机器看同一局看到不同的门"
	)
	assert_almost_eq(
		FxGd.spin_radians(PlaceholderSpec.FX_PORTAL_SPIN_TICKS, 0), 0.0, 0.0001
	)
	assert_eq(FxGd.spin_radians(-1, 0), 0.0, "还没有快照就不转")


func test_spin_phase_differs_per_entity_so_gates_are_not_in_lockstep() -> void:
	assert_ne(FxGd.spin_radians(10, 1), FxGd.spin_radians(10, 2))


func test_pulse_is_a_triangle_between_zero_and_one() -> void:
	var period: int = PlaceholderSpec.FX_PULSE_TICKS
	assert_eq(FxGd.pulse(0, 0), 0.0)
	assert_almost_eq(FxGd.pulse(period / 2, 0), 1.0, 0.0001)
	assert_eq(FxGd.pulse(period, 0), 0.0)
	for tick: int in range(0, period * 2):
		var value: float = FxGd.pulse(tick, 0)
		assert_between(value, 0.0, 1.0, "tick %d 越界" % tick)


func test_pulse_scale_never_shrinks_below_the_base() -> void:
	assert_eq(FxGd.pulse_scale(0, 0), 1.0)
	assert_almost_eq(
		FxGd.pulse_scale(PlaceholderSpec.FX_PULSE_TICKS / 2, 0),
		1.0 + PlaceholderSpec.FX_PULSE_AMPLITUDE,
		0.0001
	)


# ---- 传送门模型 ----

func test_portal_asset_carries_the_spin_contract_node() -> void:
	var visual: Node3D = SharedVisualAssetCatalogGd.try_instantiate(
		SharedVisualAssetCatalogGd.PORTAL_SCENE_PATH
	)
	assert_not_null(visual, "传送门占位模型必须能解析出来")
	if visual == null:
		return
	autofree(visual)
	assert_not_null(
		visual.get_node_or_null(FxGd.SWIRL_NAME),
		"旋翼节点名是契约，portal_gate.tscn 与 MatchCourseMapFx 同改"
	)


# ---- 挂到课程上的烟测 ----

func test_official_course_portals_spin_and_the_current_pad_breathes() -> void:
	var map: MatchCourseMapGd = MatchCourseMapGd.new()
	add_child_autofree(map)
	assert_true(map.apply_path(COURSE_01_PATH))
	map.apply_own_progress(0)
	var animated: int = map.apply_tick(30)
	assert_gt(animated, 0, "至少当前目标垫要动起来")
	assert_eq(map.apply_tick(30), animated, "同一 tick 重复调用结果一致")


func test_pad_stops_breathing_once_it_is_behind_the_player() -> void:
	var map: MatchCourseMapGd = MatchCourseMapGd.new()
	add_child_autofree(map)
	assert_true(map.apply_path(COURSE_01_PATH))
	map.apply_own_progress(0)
	map.apply_tick(PlaceholderSpec.FX_PULSE_TICKS / 2)
	var first_pad: MeshInstance3D = _pad_with_order(map, 0)
	assert_not_null(first_pad)
	if first_pad == null:
		return
	var swollen: Vector3 = _fx_target(first_pad).scale
	map.apply_own_progress(1)
	map.apply_tick(PlaceholderSpec.FX_PULSE_TICKS / 2)
	var settled: Vector3 = _fx_target(first_pad).scale
	assert_false(
		settled.is_equal_approx(swollen),
		"整条路都在呼吸等于没有指示；走过的垫必须停下来"
	)


func test_idle_lobby_does_not_breathe_anything() -> void:
	var map: MatchCourseMapGd = MatchCourseMapGd.new()
	add_child_autofree(map)
	assert_true(map.apply_path(COURSE_01_PATH))
	map.apply_own_progress(-1)
	var first_pad: MeshInstance3D = _pad_with_order(map, 0)
	assert_not_null(first_pad)
	if first_pad == null:
		return
	var before: Vector3 = _fx_target(first_pad).scale
	map.apply_tick(PlaceholderSpec.FX_PULSE_TICKS / 2)
	assert_true(_fx_target(first_pad).scale.is_equal_approx(before))


func _fx_target(node: MeshInstance3D) -> Node3D:
	var visual: Node3D = node.get_node_or_null(MatchCourseMapGd.VISUAL_NAME) as Node3D
	return node if visual == null else visual


func _pad_with_order(map: MatchCourseMapGd, order: int) -> MeshInstance3D:
	for bag: Dictionary in map.wayfind_pads():
		var bag_order: int = bag["order"]
		if bag_order != order:
			continue
		var entity_id: int = bag["entity_id"]
		return map.pad_node(entity_id)
	return null
