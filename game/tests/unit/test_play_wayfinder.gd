extends GutTest

## 可玩性深化 轨 1：「下一个目标在哪」。方向按**屏幕**给（相机 D4 斜 45°），
## 不按世界轴。目标只读服务端已验收的垫数，本文件不产生任何裁决。

const WayfinderGd := preload("res://src/shared/play_wayfinder.gd")


func _cell(count: int) -> int:
	return count * Fixed.SCALE


func _pad(entity_id: int, order: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"entity_id": entity_id,
		"order": order,
		"x": _cell(x),
		"y": _cell(y),
		"z": _cell(z),
	}


func _finish(entity_id: int, x: int, y: int, z: int) -> Dictionary:
	return {"entity_id": entity_id, "x": _cell(x), "y": _cell(y), "z": _cell(z)}


func _course_pads() -> Array:
	return [_pad(3, 1, 6, 1, 0), _pad(2, 0, 0, 0, -4), _pad(4, 2, -6, 2, 0)]


func _ok(view: Dictionary) -> bool:
	return view.get("ok", false) == true


func _int_at(view: Dictionary, key: String) -> int:
	var raw: Variant = view.get(key, -9999)
	if typeof(raw) != TYPE_INT:
		return -9999
	var value: int = raw
	return value


func _str_at(view: Dictionary, key: String) -> String:
	return str(view.get(key, ""))


# ---- 屏幕八向 ----

func test_arrow_uses_screen_axes_not_world_axes() -> void:
	# 相机在 (+X, +Y, +Z) 看向目标：屏幕右 = 世界 (+X, -Z)，屏幕上 = 世界 (-X, -Z)。
	assert_eq(WayfinderGd.arrow_of(-_cell(1), -_cell(1)), "^")
	assert_eq(WayfinderGd.arrow_of(_cell(1), -_cell(1)), ">")
	assert_eq(WayfinderGd.arrow_of(_cell(1), _cell(1)), "v")
	assert_eq(WayfinderGd.arrow_of(-_cell(1), _cell(1)), "<")
	# 纯世界 +X 在屏幕上是右下，这正是「不按世界轴」的那一半。
	assert_eq(WayfinderGd.arrow_of(_cell(1), 0), "v>")
	assert_eq(WayfinderGd.arrow_of(0, -_cell(1)), "^>")
	assert_eq(WayfinderGd.arrow_of(-_cell(1), 0), "^<")
	assert_eq(WayfinderGd.arrow_of(0, _cell(1)), "v<")


func test_arrow_of_zero_offset_is_empty() -> void:
	assert_eq(WayfinderGd.arrow_of(0, 0), "")


func test_distance_rounds_to_whole_meters() -> void:
	assert_eq(WayfinderGd.distance_m(_cell(3), _cell(4)), 5)
	assert_eq(WayfinderGd.distance_m(0, 0), 0)
	assert_eq(WayfinderGd.distance_m(Fixed.SCALE / 2, 0), 1)
	assert_eq(WayfinderGd.distance_m(Fixed.SCALE / 4, 0), 0)


# ---- 目标选择 ----

func test_target_is_the_pad_whose_order_equals_accepted_count() -> void:
	var target: Dictionary = WayfinderGd.target_of(_course_pads(), [], 1, -1)
	assert_true(_ok(target))
	assert_eq(_str_at(target, "kind"), WayfinderGd.KIND_CHECKPOINT)
	assert_eq(_int_at(target, "entity_id"), 3)
	assert_eq(_int_at(target, "order"), 1)


func test_target_falls_through_to_finish_after_the_last_pad() -> void:
	var target: Dictionary = WayfinderGd.target_of(_course_pads(), [_finish(9, 0, 2, 8)], 3, -1)
	assert_true(_ok(target))
	assert_eq(_str_at(target, "kind"), WayfinderGd.KIND_FINISH)
	assert_eq(_int_at(target, "entity_id"), 9)


func test_target_is_done_after_crossing_the_line() -> void:
	var target: Dictionary = WayfinderGd.target_of(_course_pads(), [_finish(9, 0, 2, 8)], 3, 120)
	assert_eq(_str_at(target, "kind"), WayfinderGd.KIND_DONE)


func test_target_is_not_ok_before_the_match_starts() -> void:
	assert_false(_ok(WayfinderGd.target_of(_course_pads(), [], -1, -1)))


func test_target_is_not_ok_when_the_course_has_no_finish_left() -> void:
	assert_false(_ok(WayfinderGd.target_of(_course_pads(), [], 3, -1)))


func test_malformed_bags_are_skipped_not_crashed() -> void:
	var bags: Array = [42, {"entity_id": 1}, {"entity_id": 2, "order": 0, "x": 0, "y": 0, "z": 0}]
	var target: Dictionary = WayfinderGd.target_of(bags, [], 0, -1)
	assert_true(_ok(target))
	assert_eq(_int_at(target, "entity_id"), 2)


# ---- 计划 ----

func test_plan_reports_arrow_floor_delta_and_distance() -> void:
	var view: Dictionary = WayfinderGd.plan(
		_course_pads(), [], 1, -1, _cell(0), _cell(0), _cell(0)
	)
	assert_true(_ok(view))
	assert_eq(_str_at(view, "kind"), WayfinderGd.KIND_CHECKPOINT)
	assert_eq(_int_at(view, "order"), 1)
	assert_eq(_str_at(view, "arrow"), "v>", "目标在世界 +X，屏幕上是右下")
	assert_eq(_int_at(view, "floor_delta"), 1)
	assert_eq(_int_at(view, "distance_m"), 6)


func test_plan_reports_a_negative_floor_delta_when_the_target_is_below() -> void:
	var view: Dictionary = WayfinderGd.plan(
		_course_pads(), [], 0, -1, _cell(0), _cell(3), _cell(0)
	)
	assert_eq(_int_at(view, "floor_delta"), -3)


func test_plan_is_not_ok_before_the_match_and_done_after_the_line() -> void:
	var idle: Dictionary = WayfinderGd.plan(_course_pads(), [], -1, -1, 0, 0, 0)
	assert_false(_ok(idle))
	assert_eq(_str_at(idle, "kind"), "")
	var done: Dictionary = WayfinderGd.plan(_course_pads(), [], 3, 90, 0, 0, 0)
	assert_false(_ok(done))
	assert_eq(_str_at(done, "kind"), WayfinderGd.KIND_DONE)


# ---- 读出 ----

func test_token_is_ascii_and_names_the_checkpoint_order() -> void:
	var view: Dictionary = WayfinderGd.plan(
		_course_pads(), [], 1, -1, _cell(0), _cell(0), _cell(0)
	)
	assert_eq(WayfinderGd.token(view), "next=cp1 v> +1F 6m")


func test_token_writes_zero_floor_without_a_sign() -> void:
	var view: Dictionary = WayfinderGd.plan(
		[_pad(2, 0, 0, 0, -4)], [], 0, -1, 0, 0, 0
	)
	assert_eq(WayfinderGd.token(view), "next=cp0 ^> 0F 4m")


func test_token_is_empty_when_idle_and_done_after_the_line() -> void:
	assert_eq(WayfinderGd.token({"ok": false, "kind": ""}), "")
	assert_eq(WayfinderGd.token({"ok": false, "kind": WayfinderGd.KIND_DONE}), "next=done")


func test_guide_text_goes_through_ui_copy() -> void:
	var view: Dictionary = WayfinderGd.plan(
		_course_pads(), [], 1, -1, _cell(0), _cell(0), _cell(0)
	)
	var line: String = WayfinderGd.guide_text(view, UiCopy.FALLBACK_LOCALE)
	assert_true(line.contains("v>"), line)
	assert_true(line.contains("Checkpoint 1"), line)
	assert_true(line.contains("up 1"), line)
	assert_true(line.contains("6m"), line)
	assert_eq(WayfinderGd.guide_text({"ok": false, "kind": ""}, UiCopy.FALLBACK_LOCALE), "")


func test_guide_text_says_same_floor_and_finished() -> void:
	var flat: Dictionary = WayfinderGd.plan([_pad(2, 0, 0, 0, -4)], [], 0, -1, 0, 0, 0)
	var flat_line: String = WayfinderGd.guide_text(flat, UiCopy.FALLBACK_LOCALE)
	assert_true(flat_line.contains("same floor"), flat_line)
	assert_eq(
		WayfinderGd.guide_text({"ok": false, "kind": WayfinderGd.KIND_DONE}, UiCopy.FALLBACK_LOCALE),
		"Finished"
	)


func test_direction_is_a_horizontal_unit_vector() -> void:
	var view: Dictionary = WayfinderGd.plan(
		_course_pads(), [], 1, -1, _cell(0), _cell(0), _cell(0)
	)
	var direction: Vector3 = WayfinderGd.direction_meters(view)
	assert_almost_eq(direction.length(), 1.0, 0.0001)
	assert_eq(direction.y, 0.0)
	assert_gt(direction.x, 0.9, "目标在 +X")
	assert_eq(WayfinderGd.direction_meters({"ok": false}), Vector3.ZERO)
