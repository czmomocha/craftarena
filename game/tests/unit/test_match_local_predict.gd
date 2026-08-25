extends GutTest

## MatchLocalPredict: own-slot Move/Jump overlay on latest authority.
## Newer tick hard-snaps. Own slot is not interpolated. Overflow snaps.
## Latest live crates and latest remote capsules drop the overlay this frame.

const MatchLocalPredict := preload("res://src/client/match_local_predict.gd")
const MatchMoveFacing := preload("res://src/client/match_move_facing.gd")

const CELL: int = 65536
const HALF: int = 32768


func test_unbound_keeps_sampled_and_bind_rejects_out_of_range() -> void:
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	var sampled: Array = [_player(HALF, 0, 0, 0, 1, -1)]
	var latest: Array = [_player(CELL, 0, 0, 0, 1, -1)]
	var unbound: Dictionary = predict.try_apply(sampled, latest)
	assert_true(_ok(unbound))
	assert_eq(_int(_first(unbound), "x"), HALF)
	assert_false(predict.bind_slot(-1))
	assert_false(predict.bind_slot(8))
	assert_true(predict.bind_slot(0))
	assert_eq(predict.own_slot, 0)
	assert_true(predict.try_add_move(HALF, 0))
	predict.unbind()
	assert_eq(predict.own_slot, -1)
	assert_false(predict.try_add_move(HALF, 0))


func test_own_slot_uses_latest_plus_move_and_keeps_progress() -> void:
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(1)
	assert_true(predict.try_add_move(HALF, CELL))
	var sampled: Array = [_player(0, 0, 0, 0, 0, -1)]
	var latest: Array = [_player(HALF, CELL / 4, 0, Fixed.BAM_QUARTER, 3, 8)]
	var applied: Dictionary = predict.try_apply(sampled, latest)
	assert_true(_ok(applied))
	var body: Dictionary = _first(applied)
	assert_eq(_int(body, "x"), HALF + HALF)
	assert_eq(_int(body, "y"), CELL / 4)
	assert_eq(_int(body, "z"), CELL)
	assert_eq(_int(body, "yaw_bam"), Fixed.BAM_QUARTER)
	assert_eq(_int(body, "accepted_count"), 3)
	assert_eq(_int(body, "finish_tick"), 8)


func test_jump_offsets_y_and_newer_tick_clears_overlay() -> void:
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(4)
	assert_true(predict.try_add_jump(CELL))
	var jumped: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(0, 0, 0, 0, 0, -1)],
	)
	assert_eq(_int(_first(jumped), "y"), CELL)
	predict.on_authoritative_tick(4)
	assert_eq(predict.dy, CELL)
	predict.on_authoritative_tick(5)
	assert_eq(predict.dx, 0)
	assert_eq(predict.dy, 0)
	assert_eq(predict.dz, 0)
	assert_eq(predict.yaw_bam, MatchLocalPredict.YAW_OMITTED)
	var snapped: Dictionary = predict.try_apply(
		[_player(HALF, 0, 0, 0, 2, -1)],
		[_player(CELL, HALF, 0, 0, 2, -1)],
	)
	assert_eq(_int(_first(snapped), "x"), CELL)
	assert_eq(_int(_first(snapped), "y"), HALF)


func test_move_overlays_yaw_and_omitted_keeps_latest() -> void:
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(1)
	assert_true(predict.try_add_move(HALF, 0, MatchMoveFacing.YAW_RIGHT))
	assert_eq(predict.yaw_bam, MatchMoveFacing.YAW_RIGHT)
	var overlaid: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(HALF, 0, 0, Fixed.BAM_QUARTER, 1, -1)],
	)
	assert_eq(_int(_first(overlaid), "x"), HALF + HALF)
	assert_eq(_int(_first(overlaid), "yaw_bam"), MatchMoveFacing.YAW_RIGHT)
	assert_true(predict.try_add_move(0, HALF))
	var kept: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(HALF, 0, 0, Fixed.BAM_QUARTER, 1, -1)],
	)
	assert_eq(_int(_first(kept), "z"), HALF)
	assert_eq(_int(_first(kept), "yaw_bam"), MatchMoveFacing.YAW_RIGHT)
	predict.on_authoritative_tick(2)
	assert_eq(predict.yaw_bam, MatchLocalPredict.YAW_OMITTED)
	var snapped: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(CELL, 0, 0, Fixed.BAM_QUARTER, 1, -1)],
	)
	assert_eq(_int(_first(snapped), "yaw_bam"), Fixed.BAM_QUARTER)


func test_remote_slot_keeps_sampled_and_missing_own_slot_is_noop() -> void:
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(1)
	assert_true(predict.try_add_move(HALF, 0))
	var applied: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1), _player(CELL, 0, 0, 0, 1, -1)],
		[_player(HALF, 0, 0, 0, 0, -1), _player(4 * CELL, 0, 0, 0, 1, -1)],
	)
	var players: Array = _players(applied)
	assert_eq(players.size(), 2)
	var own_body: Dictionary = players[0]
	var remote: Dictionary = players[1]
	assert_eq(_int(own_body, "x"), HALF + HALF)
	assert_eq(_int(remote, "x"), CELL)
	assert_true(predict.bind_slot(3))
	assert_true(predict.try_add_move(HALF, 0))
	var skipped: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(0, 0, 0, 0, 0, -1)],
	)
	assert_true(_ok(skipped))
	assert_eq(_int(_first(skipped), "x"), 0)


func test_malformed_latest_fails_and_overflow_snaps_to_latest() -> void:
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(1)
	var bad: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[{"x": 1}],
	)
	assert_false(_ok(bad))
	assert_true(predict.try_add_move(Fixed.INT64_MAX, 0))
	assert_false(predict.try_add_move(1, 0))
	assert_eq(predict.dx, Fixed.INT64_MAX)
	var snapped: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(HALF, 0, 0, 0, 0, -1)],
	)
	assert_true(_ok(snapped))
	assert_eq(_int(_first(snapped), "x"), HALF)
	assert_eq(_int(_first(snapped), "accepted_count"), 0)


func test_open_ground_overlay_still_applies() -> void:
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(1)
	assert_true(predict.try_add_move(HALF, HALF / 2))
	var applied: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(0, 0, 0, 0, 0, -1)],
		[_solid_box(0, 0, CELL, HALF, HALF, HALF)],
	)
	assert_true(_ok(applied))
	assert_eq(_int(_first(applied), "x"), HALF)
	assert_eq(_int(_first(applied), "z"), HALF / 2)
	assert_eq(predict.dx, HALF)
	assert_eq(predict.dz, HALF / 2)


func test_predicted_capsule_stops_on_live_crate() -> void:
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(1)
	assert_true(predict.try_add_move(0, CELL))
	var blocked: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(0, 0, 0, 0, 0, -1)],
		[_solid_box(0, 0, CELL, HALF, HALF, HALF)],
	)
	assert_true(_ok(blocked))
	assert_eq(_int(_first(blocked), "z"), 0)
	assert_eq(predict.dz, CELL)
	var clear: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(0, 0, 0, 0, 0, -1)],
		[],
	)
	assert_eq(_int(_first(clear), "z"), CELL)


func test_broken_or_omitted_crate_does_not_block() -> void:
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(1)
	assert_true(predict.try_add_move(0, CELL))
	var omitted: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(0, 0, 0, 0, 0, -1)],
		[],
	)
	assert_eq(_int(_first(omitted), "z"), CELL)
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(2)
	assert_true(predict.try_add_move(0, CELL, MatchMoveFacing.YAW_BACK))
	var malformed: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1)],
		[_player(0, 0, 0, Fixed.BAM_QUARTER, 0, -1)],
		[{"x": 0, "z": CELL}],
	)
	assert_eq(_int(_first(malformed), "z"), CELL)
	assert_eq(_int(_first(malformed), "yaw_bam"), MatchMoveFacing.YAW_BACK)


func test_latest_remote_capsule_blocks_and_far_remote_does_not() -> void:
	var predict: MatchLocalPredict = MatchLocalPredict.new()
	assert_true(predict.bind_slot(0))
	predict.on_authoritative_tick(1)
	assert_true(predict.try_add_move(CELL, 0, MatchMoveFacing.YAW_RIGHT))
	var blocked: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1), _player(CELL, 0, 0, 0, 1, -1)],
		[_player(0, 0, 0, 0, 0, -1), _player(CELL, 0, 0, 0, 1, -1)],
	)
	var blocked_players: Array = _players(blocked)
	var blocked_own_raw: Variant = blocked_players[0]
	var blocked_remote_raw: Variant = blocked_players[1]
	assert_eq(typeof(blocked_own_raw), TYPE_DICTIONARY)
	assert_eq(typeof(blocked_remote_raw), TYPE_DICTIONARY)
	var blocked_own: Dictionary = blocked_own_raw
	var blocked_remote: Dictionary = blocked_remote_raw
	assert_eq(_int(blocked_own, "x"), 0)
	assert_eq(_int(blocked_own, "yaw_bam"), 0)
	assert_eq(_int(blocked_remote, "x"), CELL)
	assert_eq(predict.dx, CELL)
	assert_eq(predict.yaw_bam, MatchMoveFacing.YAW_RIGHT)
	var far: Dictionary = predict.try_apply(
		[_player(0, 0, 0, 0, 0, -1), _player(4 * CELL, 0, 0, 0, 1, -1)],
		[_player(0, 0, 0, 0, 0, -1), _player(4 * CELL, 0, 0, 0, 1, -1)],
	)
	var far_players: Array = _players(far)
	var far_own_raw: Variant = far_players[0]
	assert_eq(typeof(far_own_raw), TYPE_DICTIONARY)
	var far_own: Dictionary = far_own_raw
	assert_eq(_int(far_own, "x"), CELL)
	assert_eq(_int(far_own, "yaw_bam"), MatchMoveFacing.YAW_RIGHT)


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


func _solid_box(x: int, y: int, z: int, hx: int, hy: int, hz: int) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"z": z,
		"hx": hx,
		"hy": hy,
		"hz": hz,
	}


func _ok(applied: Dictionary) -> bool:
	var raw: Variant = applied.get("ok", false)
	return raw == true


func _players(applied: Dictionary) -> Array:
	var raw: Variant = applied.get("players", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw


func _first(applied: Dictionary) -> Dictionary:
	var players: Array = _players(applied)
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
