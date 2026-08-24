extends GutTest

## Preview play MoveIntent: while playing, apply existing MoveIntent through
## TraprushIntentStepper. WASD maps to world XZ. Caller supplies dx/dz; the
## shell step is a presentation stub, not a product speed. Shove/Interact
## stay refused. Occupancy is in test_authoring_preview_play_pads. No
## gravity, no tick Hz, no settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringPreviewShell := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const EPS: float = 0.0001

var _preview_shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _preview_shell != null and is_instance_valid(_preview_shell):
		_preview_shell.free()
	_preview_shell = null


func test_wasd_axes_map_to_world_xz() -> void:
	var right: Dictionary = AuthoringPreviewShell.move_payload_from_axes(
		false, false, false, true, CELL
	)
	var forward: Dictionary = AuthoringPreviewShell.move_payload_from_axes(
		true, false, false, false, CELL
	)
	var left_back: Dictionary = AuthoringPreviewShell.move_payload_from_axes(
		false, true, true, false, CELL
	)
	var cancelled: Dictionary = AuthoringPreviewShell.move_payload_from_axes(
		true, true, true, true, CELL
	)
	var no_step: Dictionary = AuthoringPreviewShell.move_payload_from_axes(
		false, false, false, true, 0
	)
	var right_intent: String = right.get("intent", "")
	var right_dx: int = right.get("dx", 0)
	var right_dz: int = right.get("dz", -1)
	var forward_dx: int = forward.get("dx", -1)
	var forward_dz: int = forward.get("dz", 0)
	var left_dx: int = left_back.get("dx", 0)
	var left_dz: int = left_back.get("dz", 0)
	assert_eq(right_intent, PlayerIntentNames.MOVE)
	assert_eq(right_dx, CELL)
	assert_eq(right_dz, 0)
	assert_eq(forward_dx, 0)
	assert_eq(forward_dz, -CELL)
	assert_eq(left_dx, -CELL)
	assert_eq(left_dz, CELL)
	assert_true(cancelled.is_empty())
	assert_true(no_step.is_empty())


func test_play_move_changes_xz_without_tick_or_settlement() -> void:
	var preview: AuthoringPreview = _connected_course()
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, CELL)
	assert_eq(pose_y, 0)
	assert_eq(pose_z, 0)
	assert_eq(preview.play_world.tick_index, 0)
	assert_true(preview.try_apply_play_intent(_move(0, -CELL)))
	pose = preview.play_world.get_pose(preview.player_id)
	pose_x = pose.get("x", -1)
	pose_z = pose.get("z", -1)
	assert_eq(pose_x, CELL)
	assert_eq(pose_z, -CELL)
	assert_eq(preview.play_world.tick_index, 0)
	assert_false(preview.allows_settlement())
	assert_false(preview.allows_online_writes())


func test_move_refused_unless_playing() -> void:
	var preview: AuthoringPreview = _connected_course()
	assert_false(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_stop_play())
	assert_false(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.is_safe_point())
	assert_false(preview.is_playing())


func test_shove_and_empty_payload_are_refused() -> void:
	var preview: AuthoringPreview = _connected_course()
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	var start: Dictionary = preview.play_world.get_pose(preview.player_id)
	assert_false(preview.try_apply_play_intent({
		"intent": PlayerIntentNames.SHOVE,
	}))
	assert_false(preview.try_apply_play_intent({}))
	assert_false(preview.try_apply_play_intent({"intent": PlayerIntentNames.MOVE, "dx": CELL}))
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
	assert_true(preview.is_playing())


func test_shell_sample_moves_marker() -> void:
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
	assert_almost_eq(marker.position.z, 0.0, EPS)
	assert_false(_preview_shell.try_sample_play_move(false, false, false, false))
	assert_false(_preview_shell.allows_settlement())
	_preview_shell.hide_window()
	assert_true(_preview_shell.preview.is_playing())
	assert_false(_preview_shell.try_sample_play_move(false, false, false, true))
	assert_true(_preview_shell.try_apply_play_intent(_move(0, CELL)))
	marker = _preview_shell.map.player_node()
	assert_not_null(marker)
	assert_almost_eq(marker.position.z, 1.0, EPS)


func _connected_course() -> AuthoringPreview:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	return preview


func _move(dx: int, dz: int) -> Dictionary:
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	}
