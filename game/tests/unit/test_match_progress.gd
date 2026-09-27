extends GutTest

## Client polyline progress. Integer percent + clamp are functions, not paint.

const ProgressGd := preload("res://src/client/match_progress.gd")


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


func _player(slot_x: int, accepted: int, finish_tick: int = -1) -> Dictionary:
	return {
		"x": _cell(slot_x),
		"y": 0,
		"z": 0,
		"accepted_count": accepted,
		"finish_tick": finish_tick,
	}


func _int_at(view: Dictionary, key: String) -> int:
	var raw: Variant = view.get(key, -9999)
	if typeof(raw) != TYPE_INT:
		return -9999
	var value: int = raw
	return value


func _str_at(view: Dictionary, key: String) -> String:
	return str(view.get(key, ""))


func _as_dict(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	return body


func test_polyline_sorts_pads_and_appends_finish() -> void:
	var points: Array = ProgressGd.polyline(
		[_pad(4, 2, 6, 0, 0), _pad(2, 0, 0, 0, 0), _pad(3, 1, 3, 0, 0)],
		[_finish(9, 9, 0, 0)]
	)
	assert_eq(points.size(), 4)
	assert_eq(_int_at(_as_dict(points[0]), "x"), _cell(0))
	assert_eq(_int_at(_as_dict(points[1]), "x"), _cell(3))
	assert_eq(_int_at(_as_dict(points[2]), "x"), _cell(6))
	assert_eq(_int_at(_as_dict(points[3]), "x"), _cell(9))


func test_progress_clamps_to_current_segment() -> void:
	var points: Array = ProgressGd.polyline(
		[_pad(2, 0, 0, 0, 0), _pad(3, 1, 2, 0, 0)],
		[_finish(9, 4, 0, 0)]
	)
	var first: float = ProgressGd.total_length(points) / 2.0
	assert_eq(ProgressGd.progress_along(points, 0, 0, 0, 0), 0.0)
	assert_almost_eq(
		ProgressGd.progress_along(points, 0, _cell(1), 0, 0),
		float(_cell(1)),
		1.0
	)
	assert_almost_eq(
		ProgressGd.progress_along(points, 0, _cell(8), 0, 0),
		float(_cell(2)),
		1.0
	)
	assert_eq(ProgressGd.progress_along(points, 0, -_cell(3), 0, 0), 0.0)
	assert_almost_eq(
		ProgressGd.progress_along(points, 1, _cell(2), 0, 0),
		float(_cell(2)),
		1.0
	)
	assert_gt(first, 0.0)


func test_percent_is_0_to_100_and_finished_is_100() -> void:
	var points: Array = ProgressGd.polyline(
		[_pad(2, 0, 0, 0, 0)],
		[_finish(9, 2, 0, 0)]
	)
	assert_eq(ProgressGd.percent(points, 0, 0, 0, 0), 0)
	assert_eq(ProgressGd.percent(points, 0, _cell(1), 0, 0), 50)
	assert_eq(ProgressGd.percent(points, 0, _cell(2), 0, 0), 100)
	assert_eq(ProgressGd.percent(points, 0, 0, 0, 0, 12), 100)
	assert_eq(ProgressGd.percent([], 0, 0, 0, 0), 0)
	assert_eq(ProgressGd.percent(points, -1, _cell(1), 0, 0), 0)


func test_markers_label_own_remote_and_ghost() -> void:
	var points: Array = ProgressGd.polyline(
		[_pad(2, 0, 0, 0, 0)],
		[_finish(9, 2, 0, 0)]
	)
	var rows: Array = ProgressGd.markers(
		points,
		[_player(0, 0), _player(1, 0)],
		0,
		_player(2, 0, 4)
	)
	assert_eq(rows.size(), 3)
	assert_eq(_str_at(_as_dict(rows[0]), "kind"), ProgressGd.KIND_OWN)
	assert_eq(_int_at(_as_dict(rows[0]), "percent"), 0)
	assert_eq(_str_at(_as_dict(rows[1]), "kind"), ProgressGd.KIND_REMOTE)
	assert_eq(_int_at(_as_dict(rows[1]), "percent"), 50)
	assert_eq(_str_at(_as_dict(rows[2]), "kind"), ProgressGd.KIND_GHOST)
	assert_eq(_int_at(_as_dict(rows[2]), "percent"), 100)
	assert_eq(_int_at(_as_dict(rows[2]), "slot"), -1)
