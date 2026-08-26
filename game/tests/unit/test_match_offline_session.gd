extends GutTest

## MatchOfflineSession: local TraprushMatchSession, latest-snapshot follow,
## CD-13 offline banner, no HTTP / settlement / online writes.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchMoveFacing := preload("res://src/client/match_move_facing.gd")
const MatchOfflineSession := preload("res://src/client/match_offline_session.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const COURSE_01: String = "res://content/official/traprush/course_01.json"
const COURSE_02: String = "res://content/official/traprush/course_02.json"
const CELL: int = 65536


func test_begin_course_01_publishes_one_player_without_writes() -> void:
	var offline: MatchOfflineSession = MatchOfflineSession.new()
	assert_true(offline.try_begin(COURSE_01))
	assert_eq(offline.state, MatchOfflineSession.STATE_PLAYING)
	assert_eq(offline.course_path, COURSE_01)
	assert_true(offline.follow.has_snapshot)
	assert_eq(offline.follow.players.size(), 1)
	assert_eq(offline.session.player_count(), 1)
	assert_eq(offline.session.tick_index(), 0)
	var banner: String = str(offline.status_view().get("banner", ""))
	assert_eq(banner, MatchOfflineSession.BANNER)
	assert_eq(banner, "离线试玩，成绩不上传")
	assert_false(offline.allows_settlement())
	assert_false(offline.allows_online_writes())


func test_web_and_bad_course_refuse() -> void:
	var offline: MatchOfflineSession = MatchOfflineSession.new()
	assert_false(offline.try_begin(COURSE_01, true))
	assert_eq(offline.last_error, "web_locked")
	assert_eq(offline.state, MatchOfflineSession.STATE_IDLE)
	assert_false(offline.follow.has_snapshot)
	assert_false(offline.try_begin(""))
	assert_eq(offline.last_error, "missing_course")
	assert_false(offline.try_begin("res://content/official/traprush/missing.json"))
	assert_eq(offline.last_error, "missing_course")


func test_second_begin_refused_until_stop() -> void:
	var offline: MatchOfflineSession = MatchOfflineSession.new()
	assert_true(offline.try_begin(COURSE_01))
	assert_false(offline.try_begin(COURSE_02))
	assert_eq(offline.last_error, "busy")
	assert_eq(offline.course_path, COURSE_01)
	assert_true(offline.try_stop())
	assert_eq(offline.state, MatchOfflineSession.STATE_IDLE)
	assert_false(offline.follow.has_snapshot)
	assert_true(offline.try_begin(COURSE_02))
	assert_eq(offline.course_path, COURSE_02)
	assert_true(offline.follow.has_snapshot)


func test_move_updates_follow_and_advance_ticks() -> void:
	var offline: MatchOfflineSession = MatchOfflineSession.new()
	assert_true(offline.try_begin(COURSE_01))
	var before: Dictionary = offline.follow.players[0]
	var before_x: int = before.get("x", -1)
	var move: PackedByteArray = offline.try_encode_intent(PlayerIntentNames.MOVE, CELL, 0, -1)
	assert_false(move.is_empty())
	var decoded: Dictionary = MatchFrameCodec.decode_command(move)
	var decoded_tick: int = decoded.get("tick", -1)
	var decoded_intent: String = str(decoded.get("intent", ""))
	assert_eq(decoded_tick, 0)
	assert_eq(decoded_intent, PlayerIntentNames.MOVE)
	var after: Dictionary = offline.follow.players[0]
	var after_x: int = after.get("x", -2)
	assert_eq(after_x, before_x + CELL)
	assert_eq(offline.session.tick_index(), 0)
	assert_true(offline.try_advance())
	assert_eq(offline.session.tick_index(), 1)
	assert_eq(offline.follow.tick, 1)


func test_wasd_and_unwired_intents() -> void:
	var offline: MatchOfflineSession = MatchOfflineSession.new()
	assert_true(offline.try_encode_move_axes(true, false, false, false, 16).is_empty())
	assert_true(offline.try_begin(COURSE_01))
	var bytes: PackedByteArray = offline.try_encode_move_axes(true, false, false, true, 16)
	var decoded: Dictionary = MatchFrameCodec.decode_command(bytes)
	var decoded_dx: int = decoded.get("dx", 0)
	var decoded_dz: int = decoded.get("dz", 0)
	var decoded_yaw: int = decoded.get("yaw_bam", -2)
	assert_eq(decoded_dx, 16)
	assert_eq(decoded_dz, -16)
	assert_eq(decoded_yaw, MatchMoveFacing.YAW_FORWARD_RIGHT)
	var before: Dictionary = offline.follow.players[0]
	var before_yaw: int = before.get("yaw_bam", -3)
	var right: PackedByteArray = offline.try_encode_move_axes(false, false, false, true, 16)
	assert_false(right.is_empty())
	var after: Dictionary = offline.follow.players[0]
	var after_yaw: int = after.get("yaw_bam", -3)
	assert_eq(after_yaw, MatchMoveFacing.YAW_RIGHT)
	assert_ne(before_yaw, MatchMoveFacing.YAW_RIGHT)
	var forward: PackedByteArray = offline.try_encode_move_axes(true, false, false, false, 16)
	assert_false(forward.is_empty())
	var faced: Dictionary = offline.follow.players[0]
	var faced_yaw: int = faced.get("yaw_bam", -3)
	assert_eq(faced_yaw, MatchMoveFacing.YAW_FORWARD)
	assert_true(offline.try_encode_move_axes(false, false, false, false, 16).is_empty())
	# Solo is one capsule: Shove has no target, so encode/apply fails closed.
	assert_true(offline.try_encode_intent(PlayerIntentNames.SHOVE, 0, 0, 0).is_empty())
	assert_true(offline.try_encode_intent(PlayerIntentNames.INTERACT, 0, 0, 0).is_empty())
	assert_false(offline.try_encode_intent(PlayerIntentNames.JUMP, 0, 0, 0).is_empty())
	assert_false(offline.try_encode_intent(PlayerIntentNames.RESET_TO_CHECKPOINT, 0, 0, 0).is_empty())
	assert_false(offline.try_apply_command(PackedByteArray([1, 2, 3])))


func test_course_01_finish_is_local_mvp_without_online_write() -> void:
	var offline: MatchOfflineSession = MatchOfflineSession.new()
	assert_true(offline.try_begin(COURSE_01))
	for _index: int in range(5):
		assert_false(offline.try_encode_intent(PlayerIntentNames.MOVE, CELL, 0, -1).is_empty())
	assert_eq(offline.session.player_accepted_count(0), 3)
	assert_eq(offline.session.player_finish_tick(0), 0)
	var player: Dictionary = offline.follow.players[0]
	var accepted_count: int = player.get("accepted_count", -1)
	var finish_tick: int = player.get("finish_tick", -1)
	assert_eq(accepted_count, 3)
	assert_eq(finish_tick, 0)
	assert_false(offline.allows_settlement())
	assert_false(offline.allows_online_writes())
	var finish_banner: String = str(offline.status_view().get("banner", ""))
	assert_eq(finish_banner, MatchOfflineSession.BANNER)


func test_tight_play_range_resets_two_cell_move() -> void:
	var offline: MatchOfflineSession = MatchOfflineSession.new()
	offline.play_range_half = CELL
	assert_true(offline.try_begin(COURSE_01))
	assert_true(offline.session.range_enabled)
	assert_false(offline.try_encode_intent(PlayerIntentNames.MOVE, CELL, 0, -1).is_empty())
	assert_false(offline.try_encode_intent(PlayerIntentNames.MOVE, CELL, 0, -1).is_empty())
	var pose: Dictionary = offline.session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)
	assert_eq(offline.session.player_accepted_count(0), 1)
