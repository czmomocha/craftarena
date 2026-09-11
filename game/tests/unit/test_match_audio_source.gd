extends GutTest

## M5 B2: snapshot-diff audio source. v1 frames have no vy / stun / events.
## Jump is a y rising edge. Bad / older / duplicate ticks must not replay.

const MatchAudioSourceGd := preload("res://src/client/match_audio_source.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchSnapshotFollow := preload("res://src/client/match_snapshot_follow.gd")
const RouterGd := preload("res://src/games/traprush/traprush_audio_router.gd")


func test_first_snapshot_is_silent_then_jump_land_step_checkpoint_finish() -> void:
	var source: MatchAudioSourceGd = MatchAudioSourceGd.new()
	source.jump_dy = 8
	source.step_stride = 10
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(follow.apply_frame(_frame(1, [_player(0, 0, 0, 0, -1)])))
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray())
	assert_true(follow.apply_frame(_frame(3, [_player(0, 4, 0, 0, -1)])))
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray([RouterGd.EVENT_JUMP]))
	assert_true(follow.apply_frame(_frame(5, [_player(0, 2, 0, 0, -1)])))
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray([RouterGd.EVENT_LAND]))
	assert_true(follow.apply_frame(_frame(7, [_player(10, 2, 0, 0, -1)])))
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray([RouterGd.EVENT_STEP]))
	assert_true(follow.apply_frame(_frame(9, [_player(10, 2, 0, 1, -1)])))
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray([RouterGd.EVENT_CHECKPOINT]))
	assert_true(follow.apply_frame(_frame(11, [_player(10, 2, 0, 1, 11)])))
	assert_eq(
		_event_names(source.collect(follow, 0)),
		PackedStringArray([RouterGd.EVENT_FINISH, RouterGd.EVENT_SETTLED])
	)


func test_duplicate_older_and_bad_frames_do_not_replay() -> void:
	var source: MatchAudioSourceGd = MatchAudioSourceGd.new()
	source.jump_dy = 8
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(follow.apply_frame(_frame(2, [_player(0, 0)])))
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray())
	assert_true(follow.apply_frame(_frame(4, [_player(0, 8)])))
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray([RouterGd.EVENT_JUMP]))
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray())
	assert_false(follow.apply_frame(_frame(3, [_player(0, 99)])))
	assert_eq(follow.tick, 4)
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray())
	assert_false(follow.apply_frame(PackedByteArray([1, 2, 3])))
	assert_eq(follow.tick, 4)
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray())


func test_remote_jump_carries_meters_and_crate_break_is_an_edge() -> void:
	var source: MatchAudioSourceGd = MatchAudioSourceGd.new()
	source.jump_dy = 8
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	var cell: int = Fixed.SCALE
	assert_true(follow.apply_frame(_frame(
		1,
		[_player(0, 0), _player(cell, 0, cell)],
		[_crate(9, 2)]
	)))
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray())
	assert_true(follow.apply_frame(_frame(
		3,
		[_player(0, 0), _player(cell, 8, cell)],
		[_crate(9, 0)]
	)))
	var rows: Array[Dictionary] = source.collect(follow, 0)
	assert_eq(
		_event_names(rows),
		PackedStringArray([RouterGd.EVENT_JUMP, RouterGd.EVENT_BREAK_CRATE])
	)
	var jump: Dictionary = rows[0]
	var remote_raw: Variant = jump.get(MatchAudioSourceGd.KEY_REMOTE, false)
	assert_eq(typeof(remote_raw), TYPE_BOOL)
	var remote_flag: bool = remote_raw
	assert_true(remote_flag)
	var x_raw: Variant = jump.get(MatchAudioSourceGd.KEY_X, -1.0)
	var z_raw: Variant = jump.get(MatchAudioSourceGd.KEY_Z, -1.0)
	assert_eq(typeof(x_raw), TYPE_FLOAT)
	assert_eq(typeof(z_raw), TYPE_FLOAT)
	var x_m: float = x_raw
	var z_m: float = z_raw
	assert_almost_eq(x_m, 1.0, 0.001)
	assert_almost_eq(z_m, 1.0, 0.001)
	assert_true(follow.apply_frame(_frame(
		5,
		[_player(0, 0), _player(cell, 8, cell)],
		[_crate(9, 0)]
	)))
	assert_eq(_event_names(source.collect(follow, 0)), PackedStringArray())


func _event_names(rows: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		out.append(str(row.get(MatchAudioSourceGd.KEY_EVENT, "")))
	return out


func _player(x: int, y: int, z: int = 0, accepted: int = 0, finish_tick: int = -1) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"z": z,
		"yaw_bam": 0,
		"accepted_count": accepted,
		"finish_tick": finish_tick,
	}


func _crate(entity_id: int, durability: int) -> Dictionary:
	return {
		"entity_id": entity_id,
		"durability": durability,
	}


func _frame(tick: int, players: Array[Dictionary], crates: Array = []) -> PackedByteArray:
	var crate_rows: Array[Dictionary] = []
	for raw: Variant in crates:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		crate_rows.append(row)
	return MatchFrameCodec.encode_snapshot(tick, players, crate_rows)
