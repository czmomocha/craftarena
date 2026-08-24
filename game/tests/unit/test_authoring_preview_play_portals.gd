extends GutTest

## Preview play portal occupancy: overlapping a compiled portal box lands through
## TraprushPortalLanding.try_land_exit (one hop). two_way pairs cannot use follow()
## because the dest is also a portal source. Occupancy is observed by Preview.
## After landing, dest volume is latched until the capsule leaves, so two_way
## does not bounce. Teleport does not skip checkpoints; PadAccept still refuses.
## Occupied dest waits without moving. No gravity, finish, Jump/Shove, tick Hz,
## or settlement.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringPreviewShell := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const TraprushPortalLanding := preload("res://src/games/traprush/portal_landing.gd")

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


func test_official_courses_walk_through_portal_to_last_pad() -> void:
	var first: AuthoringPreview = _connected_course(COURSE_01_PATH)
	var second: AuthoringPreview = _connected_course(COURSE_02_PATH)
	_assert_official_portal_run(first, 0)
	_assert_official_portal_run(second, 2 * CELL)


func test_two_way_dest_is_latched_until_capsule_leaves() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	_walk_onto_ground_portal(preview)
	var landed: Dictionary = preview.play_world.get_pose(preview.player_id)
	var landed_x: int = landed.get("x", -1)
	var landed_y: int = landed.get("y", -1)
	var landed_z: int = landed.get("z", -1)
	assert_eq(landed_x, 0)
	assert_eq(landed_y, CELL)
	assert_eq(landed_z, 0)
	assert_true(preview.try_advance_play())
	var still: Dictionary = preview.play_world.get_pose(preview.player_id)
	var still_x: int = still.get("x", -1)
	var still_y: int = still.get("y", -1)
	var still_z: int = still.get("z", -1)
	assert_eq(still_x, 0)
	assert_eq(still_y, CELL)
	assert_eq(still_z, 0)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(-CELL, 0)))
	var reversed: Dictionary = preview.play_world.get_pose(preview.player_id)
	var reversed_x: int = reversed.get("x", -1)
	var reversed_y: int = reversed.get("y", -1)
	var reversed_z: int = reversed.get("z", -1)
	assert_eq(reversed_x, 3 * CELL)
	assert_eq(reversed_y, 0)
	assert_eq(reversed_z, 0)


func test_portal_does_not_accept_skipped_checkpoint() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint(1, 0, 0, 0, 0)))
	assert_true(session.world.put(_checkpoint(2, 1, 2 * CELL, 0, 0)))
	assert_true(session.world.put(_checkpoint(3, 2, 0, CELL, 0)))
	assert_true(session.world.put(_portal(10, 11, CELL, 0, 0)))
	assert_true(session.world.put(_portal(11, 10, 0, CELL, 0)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 1)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 0)
	assert_eq(pose_y, CELL)
	assert_eq(pose_z, 0)
	assert_eq(preview.play_accepted_count(), 1)
	assert_false(preview.try_accept_play_checkpoint(THIRD_PAD))
	assert_eq(preview.play_last_accepted_id(), FIRST_PAD)


func test_occupied_dest_waits_then_lands_when_clear() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	var occupant_id: int = preview.play_world.spawn_capsule(0, CELL, 0, 0, 1, 1)
	assert_gt(occupant_id, 0)
	_walk_onto_ground_portal(preview)
	var waiting: Dictionary = preview.play_world.get_pose(preview.player_id)
	var waiting_x: int = waiting.get("x", -1)
	var waiting_y: int = waiting.get("y", -1)
	var waiting_z: int = waiting.get("z", -1)
	assert_eq(waiting_x, 3 * CELL)
	assert_eq(waiting_y, 0)
	assert_eq(waiting_z, 0)
	assert_eq(preview.play_floor_index(), 0)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var still_waiting: Dictionary = preview.play_world.get_pose(preview.player_id)
	var still_x: int = still_waiting.get("x", -1)
	assert_eq(still_x, 3 * CELL)
	assert_true(preview.play_world.try_set_pose(occupant_id, 20 * CELL, 0, 0, 0))
	assert_true(preview.try_advance_play())
	var landed: Dictionary = preview.play_world.get_pose(preview.player_id)
	var landed_x: int = landed.get("x", -1)
	var landed_y: int = landed.get("y", -1)
	var landed_z: int = landed.get("z", -1)
	assert_eq(landed_x, 0)
	assert_eq(landed_y, CELL)
	assert_eq(landed_z, 0)
	assert_eq(preview.play_floor_index(), 1)
	assert_eq(preview.play_world.tick_index, 1)


func test_follow_cannot_land_official_two_way_but_exit_can() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	var followed: Dictionary = TraprushPortalLanding.try_land(
		preview.play_world,
		preview.player_id,
		preview.play_graph,
		10,
		1
	)
	var follow_ok: bool = followed.get("ok", true)
	assert_false(follow_ok)
	var exited: Dictionary = TraprushPortalLanding.try_land_exit(
		preview.play_world,
		preview.player_id,
		preview.play_graph,
		10
	)
	var exit_ok: bool = exited.get("ok", false)
	var exit_landed: bool = exited.get("landed", false)
	assert_true(exit_ok)
	assert_true(exit_landed)
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 0)
	assert_eq(pose_y, CELL)
	assert_eq(pose_z, 0)


func test_shell_status_floor_follows_portal_land() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	_preview_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_preview_shell)
	assert_true(_preview_shell.open_from(session))
	assert_true(_preview_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(_preview_shell.status_label_text().contains("floor=0"))
	assert_true(_preview_shell.try_apply_play_intent(_move(CELL, 0)))
	assert_true(_preview_shell.try_apply_play_intent(_move(CELL, 0)))
	assert_true(_preview_shell.try_apply_play_intent(_move(CELL, 0)))
	assert_true(_preview_shell.status_label_text().contains("floor=1"))
	assert_true(_preview_shell.status_label_text().contains("pads=2/3"))
	var floor_raw: Variant = _preview_shell.status_view().get("floor_index", -1)
	var floor_index: int = floor_raw
	assert_eq(floor_index, 1)
	assert_false(_preview_shell.allows_settlement())
	assert_true(_preview_shell.try_stop_play())
	assert_true(_preview_shell.status_label_text().contains("floor=0"))


func test_not_playing_has_no_floor_or_portal_ids() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_eq(preview.play_floor_index(), 0)
	assert_eq(preview.play_portal_ids.size(), 0)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_portal_ids.size(), 2)
	assert_true(preview.try_stop_play())
	assert_eq(preview.play_floor_index(), 0)
	assert_eq(preview.play_portal_ids.size(), 0)


func _assert_official_portal_run(preview: AuthoringPreview, dest_z: int) -> void:
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 1)
	assert_eq(preview.play_floor_index(), 0)
	_walk_onto_ground_portal(preview)
	assert_eq(preview.play_accepted_count(), 2)
	assert_eq(preview.play_last_accepted_id(), SECOND_PAD)
	assert_eq(preview.play_floor_index(), 1)
	var landed: Dictionary = preview.play_world.get_pose(preview.player_id)
	var landed_x: int = landed.get("x", -1)
	var landed_y: int = landed.get("y", -1)
	var landed_z: int = landed.get("z", -1)
	assert_eq(landed_x, 0)
	assert_eq(landed_y, CELL)
	assert_eq(landed_z, dest_z)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 3)
	assert_eq(preview.play_last_accepted_id(), THIRD_PAD)
	assert_eq(preview.play_world.tick_index, 0)
	assert_false(preview.allows_settlement())
	assert_false(preview.allows_online_writes())


func _walk_onto_ground_portal(preview: AuthoringPreview) -> void:
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	assert_eq(preview.play_accepted_count(), 2)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))


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


func _portal(entity_id: int, target_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
	})
