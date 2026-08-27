extends GutTest

## Preview play ResetToCheckpointIntent: while playing, apply the existing
## reset name through TraprushIntentStepper and the compiled pad respawn
## table. No client coordinates. Progress is kept. Shove/Interact stay
## refused.
## R rising-edge and the Reset button are presentation stubs, not a product
## hold duration or stun. No gravity, tick Hz, or settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringPreviewShell := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_02_PATH: String = "res://content/official/traprush/course_02.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const EPS: float = 0.0001
const FIRST_PAD: int = 1
const SECOND_PAD: int = 2
const THIRD_PAD: int = 3


var _preview_shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _preview_shell != null and is_instance_valid(_preview_shell):
		_preview_shell.free()
	_preview_shell = null


func test_reset_after_first_pad_returns_to_start_pad() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 1)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var mid: Dictionary = preview.play_world.get_pose(preview.player_id)
	var mid_x: int = mid.get("x", -1)
	assert_eq(mid_x, CELL)
	assert_true(preview.try_apply_play_intent(_reset()))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 0)
	assert_eq(pose_y, 0)
	assert_eq(pose_z, 0)
	assert_eq(preview.play_accepted_count(), 1)
	assert_eq(preview.play_last_accepted_id(), FIRST_PAD)
	assert_eq(preview.play_world.tick_index, 0)
	assert_false(preview.allows_settlement())
	assert_false(preview.allows_online_writes())


func test_reset_after_second_pad_returns_to_second_pad() -> void:
	var first: AuthoringPreview = _connected_course(COURSE_01_PATH)
	var second: AuthoringPreview = _connected_course(COURSE_02_PATH)
	_assert_reset_to_second_pad(first, 0, CELL)
	_assert_reset_to_second_pad(second, 0, -CELL)


func test_unaccepted_track_resets_to_offset_start() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint(2, 0, 0, 0, 0, CELL)))
	assert_true(session.world.put(_checkpoint(5, 1, 2 * CELL, 0, 0, 0)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 0)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var mid: Dictionary = preview.play_world.get_pose(preview.player_id)
	var mid_x: int = mid.get("x", -1)
	assert_eq(mid_x, 2 * CELL)
	assert_true(preview.try_apply_play_intent(_reset()))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, CELL)
	assert_eq(pose_y, 0)
	assert_eq(pose_z, 0)
	assert_eq(preview.play_accepted_count(), 0)
	assert_eq(preview.play_last_accepted_id(), -1)


func test_reset_ignores_client_coordinates() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent({
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
		"x": 9 * CELL,
		"y": 9 * CELL,
		"z": 9 * CELL,
	}))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 0)
	assert_eq(pose_y, 0)
	assert_eq(pose_z, 0)


func test_reset_after_portal_returns_to_last_pad_and_clears_latch() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_floor_index(), 1)
	assert_eq(preview.play_accepted_count(), 2)
	assert_true(preview.try_apply_play_intent(_reset()))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 2 * CELL)
	assert_eq(pose_y, 0)
	assert_eq(pose_z, 0)
	assert_eq(preview.play_floor_index(), 0)
	assert_eq(preview.play_accepted_count(), 2)
	assert_eq(preview.play_last_accepted_id(), SECOND_PAD)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_floor_index(), 1)


func test_reset_after_finish_keeps_finish_tick() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 3)
	assert_eq(preview.play_last_accepted_id(), THIRD_PAD)
	assert_eq(preview.play_finish_tick(), 0)
	assert_true(preview.try_apply_play_intent(_reset()))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, CELL)
	assert_eq(pose_y, CELL)
	assert_eq(pose_z, -3 * CELL)
	assert_eq(preview.play_finish_tick(), 0)
	assert_eq(preview.play_accepted_count(), 3)
	assert_false(preview.allows_settlement())


func test_reset_refused_unless_playing() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_false(preview.try_apply_play_intent(_reset()))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_reset()))
	assert_true(preview.try_stop_play())
	assert_false(preview.try_apply_play_intent(_reset()))
	assert_true(preview.is_safe_point())


func test_shove_still_refused() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	var start: Dictionary = preview.play_world.get_pose(preview.player_id)
	assert_false(preview.try_apply_play_intent({
		"intent": PlayerIntentNames.SHOVE,
	}))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var start_x: int = start.get("x", -2)
	var start_y: int = start.get("y", -2)
	var start_z: int = start.get("z", -2)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, start_x)
	assert_eq(pose_y, start_y)
	assert_eq(pose_z, start_z)


func test_shell_reset_moves_marker_and_hidden_window_does_not_sample() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	_preview_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_preview_shell)
	assert_true(_preview_shell.open_from(session))
	assert_true(_preview_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	_preview_shell.play_move_step = CELL
	assert_true(_preview_shell.try_sample_play_move(false, false, false, true))
	var marker: MeshInstance3D = _preview_shell.map.player_node()
	assert_not_null(marker)
	assert_almost_eq(marker.position.x, 1.0, EPS)
	assert_true(_preview_shell.try_sample_play_reset(true))
	marker = _preview_shell.map.player_node()
	assert_not_null(marker)
	assert_almost_eq(marker.position.x, 0.0, EPS)
	assert_almost_eq(marker.position.z, 0.0, EPS)
	assert_false(_preview_shell.try_sample_play_reset(true))
	assert_false(_preview_shell.try_sample_play_reset(false))
	assert_false(_preview_shell.allows_settlement())
	_preview_shell.hide_window()
	assert_true(_preview_shell.preview.is_playing())
	assert_true(_preview_shell.try_apply_play_intent(_move(CELL, 0)))
	assert_false(_preview_shell.try_sample_play_reset(true))
	marker = _preview_shell.map.player_node()
	assert_not_null(marker)
	assert_almost_eq(marker.position.x, 1.0, EPS)
	assert_true(_preview_shell.try_apply_play_intent(_reset()))
	marker = _preview_shell.map.player_node()
	assert_not_null(marker)
	assert_almost_eq(marker.position.x, 0.0, EPS)


func _assert_reset_to_second_pad(preview: AuthoringPreview, dest_z: int, away_dz: int) -> void:
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 2)
	assert_eq(preview.play_last_accepted_id(), SECOND_PAD)
	assert_true(preview.try_apply_play_intent(_move(0, away_dz)))
	var away: Dictionary = preview.play_world.get_pose(preview.player_id)
	var away_z: int = away.get("z", 1)
	assert_eq(away_z, dest_z + away_dz)
	assert_true(preview.try_apply_play_intent(_reset()))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 2 * CELL)
	assert_eq(pose_y, 0)
	assert_eq(pose_z, dest_z)
	assert_eq(preview.play_accepted_count(), 2)
	assert_eq(preview.play_last_accepted_id(), SECOND_PAD)
	assert_eq(preview.play_finish_tick(), -1)
	assert_false(preview.allows_settlement())


func _connected_course(path: String) -> AuthoringPreview:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(path)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	return preview


func _move(dx: int, dz: int) -> Dictionary:
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	}


func _reset() -> Dictionary:
	return {
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
	}


func _checkpoint(
	entity_id: int,
	order: int,
	x: int,
	y: int,
	z: int,
	respawn_dx: int
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": order,
			"respawn_dx": respawn_dx,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})
