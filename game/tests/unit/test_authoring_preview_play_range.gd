extends GutTest

## Preview out-of-range reset: caller AABB via TraprushOutOfRangeReset.
## Default off so existing one-cell Move tests stay put. Shell copies the
## 8-cell stub. No gravity, no drop-count N, no stun, no settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringPreviewShell := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8

var _preview_shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _preview_shell != null and is_instance_valid(_preview_shell):
		_preview_shell.free()
	_preview_shell = null


func test_default_off_keeps_two_cell_move() -> void:
	var preview: AuthoringPreview = _connected_course()
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_false(preview.play_range_enabled)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 2 * CELL)
	assert_eq(preview.play_accepted_count(), 2)


func test_tight_range_resets_before_next_pad() -> void:
	var preview: AuthoringPreview = _connected_course()
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	preview.enable_play_range(CELL)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 0)
	assert_eq(preview.play_accepted_count(), 1)
	assert_eq(preview.play_world.tick_index, 0)


func test_shell_play_copies_stub_half() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	_preview_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_preview_shell)
	assert_true(_preview_shell.open_from(session))
	assert_true(_preview_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(_preview_shell.preview.play_range_enabled)
	assert_eq(_preview_shell.preview.play_range_max_x, OutOfRangeReset.STUB_HALF)
	assert_eq(_preview_shell.play_range_half, OutOfRangeReset.STUB_HALF)


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
