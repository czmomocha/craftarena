extends GutTest

## MatchSnapshotInterp: sample presentation poses between two snapshots.
## t is Q48.16. Progress stays on latest. Cell-or-larger XYZ snaps.

const MatchSnapshotInterp := preload("res://src/client/match_snapshot_interp.gd")

const CELL: int = 65536
const HALF: int = 32768


func test_empty_previous_returns_latest() -> void:
	var latest: Array = [_player(CELL, 0, 0, 0, 2, 4)]
	var sampled: Dictionary = MatchSnapshotInterp.try_sample([], latest, 0)
	assert_true(_ok(sampled))
	var body: Dictionary = _first(sampled)
	assert_eq(_int(body, "x"), CELL)
	assert_eq(_int(body, "accepted_count"), 2)
	assert_eq(_int(body, "finish_tick"), 4)


func test_t_zero_keeps_previous_pose_and_latest_progress() -> void:
	var sampled: Dictionary = MatchSnapshotInterp.try_sample(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(HALF, CELL / 4, HALF, Fixed.BAM_QUARTER, 3, 8)],
		0
	)
	assert_true(_ok(sampled))
	var body: Dictionary = _first(sampled)
	assert_eq(_int(body, "x"), 0)
	assert_eq(_int(body, "y"), 0)
	assert_eq(_int(body, "z"), 0)
	assert_eq(_int(body, "yaw_bam"), 0)
	assert_eq(_int(body, "accepted_count"), 3)
	assert_eq(_int(body, "finish_tick"), 8)


func test_t_scale_and_half_lerp_xyz_and_yaw() -> void:
	var previous: Array = [_player(0, 0, 0, 0, 0, -1)]
	var latest: Array = [_player(HALF, HALF, HALF, Fixed.BAM_QUARTER, 1, -1)]
	var end_body: Dictionary = _first(MatchSnapshotInterp.try_sample(previous, latest, CELL))
	assert_eq(_int(end_body, "x"), HALF)
	assert_eq(_int(end_body, "yaw_bam"), Fixed.BAM_QUARTER)
	var mid_body: Dictionary = _first(MatchSnapshotInterp.try_sample(previous, latest, HALF))
	assert_eq(_int(mid_body, "x"), HALF / 2)
	assert_eq(_int(mid_body, "y"), HALF / 2)
	assert_eq(_int(mid_body, "z"), HALF / 2)
	assert_eq(_int(mid_body, "yaw_bam"), Fixed.BAM_QUARTER / 2)


func test_clamps_t_and_wraps_yaw_shortest_arc() -> void:
	var previous: Array = [_player(0, 0, 0, 1000, 0, -1)]
	var latest: Array = [_player(HALF, 0, 0, Fixed.BAM_TURN - 1000, 0, -1)]
	var below_body: Dictionary = _first(MatchSnapshotInterp.try_sample(previous, latest, -8))
	assert_eq(_int(below_body, "x"), 0)
	assert_eq(_int(below_body, "yaw_bam"), 1000)
	var above_body: Dictionary = _first(MatchSnapshotInterp.try_sample(previous, latest, 2 * CELL))
	assert_eq(_int(above_body, "x"), HALF)
	assert_eq(_int(above_body, "yaw_bam"), Fixed.BAM_TURN - 1000)
	var mid_body: Dictionary = _first(MatchSnapshotInterp.try_sample(previous, latest, HALF))
	assert_eq(_int(mid_body, "yaw_bam"), 0)


func test_cell_or_larger_delta_snaps_to_latest() -> void:
	var sampled: Dictionary = MatchSnapshotInterp.try_sample(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(CELL, 0, 0, Fixed.BAM_QUARTER, 2, -1)],
		HALF
	)
	assert_true(_ok(sampled))
	var body: Dictionary = _first(sampled)
	assert_eq(_int(body, "x"), CELL)
	assert_eq(_int(body, "yaw_bam"), Fixed.BAM_QUARTER)
	var y_body: Dictionary = _first(MatchSnapshotInterp.try_sample(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(HALF, CELL, 0, 0, 0, -1)],
		HALF
	))
	assert_eq(_int(y_body, "x"), HALF)
	assert_eq(_int(y_body, "y"), CELL)


func test_new_slot_snaps_and_malformed_latest_fails() -> void:
	var sampled: Dictionary = MatchSnapshotInterp.try_sample(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(HALF, 0, 0, 0, 0, -1), _player(CELL, CELL, 0, 0, 1, -1)],
		HALF
	)
	assert_true(_ok(sampled))
	var players: Array = _players(sampled)
	assert_eq(players.size(), 2)
	var first: Dictionary = players[0]
	var second: Dictionary = players[1]
	assert_eq(_int(first, "x"), HALF / 2)
	assert_eq(_int(second, "x"), CELL)
	assert_eq(_int(second, "y"), CELL)
	var bad: Dictionary = MatchSnapshotInterp.try_sample(
		[_player(0, 0, 0, 0, 0, -1)],
		[{"x": 1}],
		HALF
	)
	assert_false(_ok(bad))
	var empty: Dictionary = MatchSnapshotInterp.try_sample([], [], HALF)
	assert_true(_ok(empty))
	assert_eq(_players(empty).size(), 0)


func _player(
	x: int,
	y: int,
	z: int,
	yaw_bam: int,
	accepted_count: int,
	finish_tick: int
) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"z": z,
		"yaw_bam": yaw_bam,
		"accepted_count": accepted_count,
		"finish_tick": finish_tick,
	}


func _ok(sampled: Dictionary) -> bool:
	var raw: Variant = sampled.get("ok", false)
	return raw == true


func _players(sampled: Dictionary) -> Array:
	var raw: Variant = sampled.get("players", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw


func _first(sampled: Dictionary) -> Dictionary:
	var players: Array = _players(sampled)
	if players.is_empty():
		return {}
	var raw: Variant = players[0]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func _int(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, -1)
	if typeof(raw) != TYPE_INT:
		return -1
	return raw
