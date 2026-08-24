extends GutTest

## Preview play checkpoint occupancy: while playing, PadAccept advances ordered
## progress only when the capsule overlaps a checkpoint pad. Occupancy is
## observed by Preview, not a client completion assertion. Spawn on the first
## pad accepts it; walking onto the next same-floor pad accepts the next id.
## Skip, no overlap, and not-playing stay refused. No gravity, portals, finish,
## Shove, tick Hz, or settlement.

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
const FIRST_PAD: int = 1
const SECOND_PAD: int = 2
const THIRD_PAD: int = 3


var _preview_shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _preview_shell != null and is_instance_valid(_preview_shell):
		_preview_shell.free()
	_preview_shell = null


func test_start_play_accepts_first_pad_on_official_courses() -> void:
	var first: AuthoringPreview = _connected_course(COURSE_01_PATH)
	var second: AuthoringPreview = _connected_course(COURSE_02_PATH)
	assert_true(first.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(second.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(first.play_accepted_count(), 1)
	assert_eq(first.play_checkpoint_count(), 3)
	assert_eq(first.play_last_accepted_id(), FIRST_PAD)
	assert_eq(second.play_accepted_count(), 1)
	assert_eq(second.play_last_accepted_id(), FIRST_PAD)
	assert_true(first.try_accept_play_checkpoint(FIRST_PAD))
	assert_eq(first.play_accepted_count(), 1)
	assert_eq(first.play_world.tick_index, 0)
	assert_false(first.allows_settlement())
	assert_false(first.allows_online_writes())


func test_move_onto_next_same_floor_pad_accepts_next_checkpoint() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 1)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 1)
	assert_false(preview.try_accept_play_checkpoint(SECOND_PAD))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 2)
	assert_eq(preview.play_last_accepted_id(), SECOND_PAD)
	assert_eq(preview.play_world.tick_index, 0)
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	assert_eq(pose_x, 2 * CELL)


func test_skip_and_unknown_ids_are_refused() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_false(preview.try_accept_play_checkpoint(SECOND_PAD))
	assert_false(preview.try_accept_play_checkpoint(THIRD_PAD))
	assert_false(preview.try_accept_play_checkpoint(99))
	assert_eq(preview.play_accepted_count(), 1)
	assert_eq(preview.play_last_accepted_id(), FIRST_PAD)


func test_offset_spawn_off_pad_does_not_accept() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint(5, 2, 0, 0, 0, 0)))
	assert_true(session.world.put(_checkpoint(2, 0, CELL, 0, 0, CELL)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_checkpoint_count(), 2)
	assert_eq(preview.play_accepted_count(), 0)
	assert_eq(preview.play_last_accepted_id(), -1)
	assert_false(preview.try_accept_play_checkpoint(2))
	assert_false(preview.try_accept_play_checkpoint(5))


func test_accept_refused_unless_playing() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_false(preview.try_accept_play_checkpoint(FIRST_PAD))
	assert_eq(preview.play_accepted_count(), 0)
	assert_eq(preview.play_checkpoint_count(), 0)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 1)
	assert_true(preview.try_stop_play())
	assert_false(preview.try_accept_play_checkpoint(FIRST_PAD))
	assert_eq(preview.play_accepted_count(), 0)
	assert_eq(preview.play_checkpoint_count(), 0)
	assert_eq(preview.play_last_accepted_id(), -1)
	assert_true(preview.is_safe_point())


func test_shell_status_and_checkpoint_mark_follow_accepts() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	_preview_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_preview_shell)
	assert_true(_preview_shell.open_from(session))
	var idle: Dictionary = _preview_shell.status_view()
	var idle_accepted: int = idle.get("accepted_count", -1)
	var idle_total: int = idle.get("checkpoint_count", -1)
	assert_eq(idle_accepted, 0)
	assert_eq(idle_total, 0)
	assert_true(_preview_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	var playing: Dictionary = _preview_shell.status_view()
	var accepted: int = playing.get("accepted_count", -1)
	var total: int = playing.get("checkpoint_count", -1)
	assert_eq(accepted, 1)
	assert_eq(total, 3)
	assert_true(_preview_shell.status_label_text().contains("pads=1/3"))
	var mark: Label3D = _preview_shell.map.checkpoint_node(FIRST_PAD)
	assert_not_null(mark)
	assert_eq(mark.text, "0*")
	_preview_shell.play_move_step = CELL
	assert_true(_preview_shell.try_sample_play_move(false, false, false, true))
	assert_true(_preview_shell.status_label_text().contains("pads=1/3"))
	assert_true(_preview_shell.try_apply_play_intent(_move(CELL, 0)))
	var walked: Dictionary = _preview_shell.status_view()
	var walked_accepted: int = walked.get("accepted_count", -1)
	assert_eq(walked_accepted, 2)
	assert_true(_preview_shell.status_label_text().contains("pads=2/3"))
	var second_mark: Label3D = _preview_shell.map.checkpoint_node(SECOND_PAD)
	assert_not_null(second_mark)
	assert_eq(second_mark.text, "1*")
	assert_false(_preview_shell.allows_settlement())
	assert_true(_preview_shell.try_stop_play())
	var stopped: Dictionary = _preview_shell.status_view()
	var stopped_accepted: int = stopped.get("accepted_count", -1)
	assert_eq(stopped_accepted, 0)
	assert_true(_preview_shell.status_label_text().contains("pads=0/0"))


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
