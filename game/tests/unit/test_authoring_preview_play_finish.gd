extends GutTest

## Preview play finish occupancy: overlapping a compiled finish box after every
## mandatory pad records finish_tick through TraprushFinishAccept.try_cross.
## Occupancy is observed by Preview. No FinishIntent. Teleport does not finish.
## Missing pads or missing overlap stay refused. No gravity, Shove, tick Hz,
## or settlement.

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
const THIRD_PAD: int = 3
const FINISH_ID: int = 30


var _preview_shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _preview_shell != null and is_instance_valid(_preview_shell):
		_preview_shell.free()
	_preview_shell = null


func test_official_courses_walk_onto_finish_after_last_pad() -> void:
	var first: AuthoringPreview = _connected_course(COURSE_01_PATH)
	var second: AuthoringPreview = _connected_course(COURSE_02_PATH)
	_assert_official_finish_run(first, -3 * CELL)
	_assert_official_finish_run(second, 2 * CELL)


func test_finish_without_all_checkpoints_is_refused() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 1)
	assert_true(preview.play_world.try_set_pose(preview.player_id, 2 * CELL, CELL, -3 * CELL, 0))
	var blocked_box: int = _finish_box_id(preview)
	assert_true(preview.play_world.overlaps_static_box(preview.player_id, blocked_box))
	assert_false(preview.try_cross_play_finish())
	assert_eq(preview.play_finish_tick(), -1)
	assert_eq(preview.play_accepted_count(), 1)


func test_all_checkpoints_without_finish_overlap_is_refused() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	_walk_to_last_pad(preview)
	assert_eq(preview.play_accepted_count(), 3)
	var clear_box: int = _finish_box_id(preview)
	assert_false(preview.play_world.overlaps_static_box(preview.player_id, clear_box))
	assert_false(preview.try_cross_play_finish())
	assert_eq(preview.play_finish_tick(), -1)


func test_empty_finish_never_crosses() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint(1, 0, 0, 0, 0)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 1)
	assert_eq(preview.play_finish_ids.size(), 0)
	assert_false(preview.try_cross_play_finish())
	assert_eq(preview.play_finish_tick(), -1)
	assert_false(preview.allows_settlement())


func test_already_crossed_finish_stays_crossed() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	_walk_to_last_pad(preview)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_finish_tick(), 0)
	assert_true(preview.try_cross_play_finish())
	assert_eq(preview.play_finish_tick(), 0)
	assert_true(preview.try_advance_play())
	assert_eq(preview.play_finish_tick(), 0)
	assert_eq(preview.play_world.tick_index, 1)
	assert_false(preview.allows_settlement())
	assert_false(preview.allows_online_writes())


func test_portal_land_does_not_cross_finish() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_floor_index(), 1)
	assert_eq(preview.play_accepted_count(), 2)
	assert_eq(preview.play_finish_tick(), -1)


func test_shell_status_finish_follows_occupancy() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	_preview_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_preview_shell)
	assert_true(_preview_shell.open_from(session))
	assert_true(_preview_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(_preview_shell.status_label_text().contains("finish=-1"))
	assert_true(_preview_shell.try_apply_play_intent(_move(CELL, 0)))
	assert_true(_preview_shell.try_apply_play_intent(_move(CELL, 0)))
	assert_true(_preview_shell.try_apply_play_intent(_move(CELL, 0)))
	assert_true(_preview_shell.try_apply_play_intent(_move(CELL, 0)))
	assert_true(_preview_shell.try_apply_play_intent(_move(CELL, 0)))
	assert_true(_preview_shell.status_label_text().contains("finish=0"))
	assert_true(_preview_shell.status_label_text().contains("pads=3/3"))
	var finish_raw: Variant = _preview_shell.status_view().get("finish_tick", 99)
	var finish_tick: int = finish_raw
	assert_eq(finish_tick, 0)
	assert_false(_preview_shell.allows_settlement())
	assert_true(_preview_shell.try_stop_play())
	assert_true(_preview_shell.status_label_text().contains("finish=-1"))


func test_not_playing_has_no_finish_tick_or_ids() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_eq(preview.play_finish_tick(), -1)
	assert_eq(preview.play_finish_ids.size(), 0)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_finish_ids.size(), 1)
	assert_true(preview.try_stop_play())
	assert_eq(preview.play_finish_tick(), -1)
	assert_eq(preview.play_finish_ids.size(), 0)


func _assert_official_finish_run(preview: AuthoringPreview, dest_z: int) -> void:
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_finish_tick(), -1)
	_walk_to_last_pad(preview)
	assert_eq(preview.play_accepted_count(), 3)
	assert_eq(preview.play_last_accepted_id(), THIRD_PAD)
	assert_eq(preview.play_finish_tick(), -1)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 2 * CELL)
	assert_eq(pose_y, CELL)
	assert_eq(pose_z, dest_z)
	assert_eq(preview.play_finish_tick(), 0)
	assert_eq(preview.play_world.tick_index, 0)
	assert_false(preview.allows_settlement())
	assert_false(preview.allows_online_writes())


func _walk_to_last_pad(preview: AuthoringPreview) -> void:
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 2)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 3)


func _finish_box_id(preview: AuthoringPreview) -> int:
	var box_raw: Variant = preview.play_finish_ids.get(FINISH_ID, 0)
	if typeof(box_raw) != TYPE_INT:
		return 0
	var box_id: int = box_raw
	return box_id


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


func _checkpoint(entity_id: int, order: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": order,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})
