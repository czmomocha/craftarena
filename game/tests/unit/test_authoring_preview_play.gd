extends GutTest

## Preview play: compile the connected Preview world, load topology, spawn on
## the lowest-order pad plus respawn offset, enter tick, and advance the sim.
## Empty pads / compile failure refuse. Patches stay refused until stop.
## MoveIntent while playing is in test_authoring_preview_play_move.
## Checkpoint occupancy is in test_authoring_preview_play_pads.
## Never settlement. Not a new EDIT op. Jump, gravity, and Rule VM wait.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringPreviewMap := preload("res://src/creator/authoring_preview_map.gd")
const AuthoringPreviewShell := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")
const Levels := preload("res://src/creator/preview_patch_levels.gd")
const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const COURSE_02_PATH: String = "res://content/official/traprush/course_02.json"
const CELL: int = 65536
const EPS: float = 0.0001

var _preview_shell: AuthoringPreviewShell = null
var _editor_shell: AuthoringEditorShell = null
var _map: AuthoringPreviewMap = null


func after_each() -> void:
	if _preview_shell != null and is_instance_valid(_preview_shell):
		_preview_shell.free()
	_preview_shell = null
	if _editor_shell != null and is_instance_valid(_editor_shell):
		_editor_shell.free()
	_editor_shell = null
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null


func test_official_courses_start_play_on_first_pad() -> void:
	var first: AuthoringPreview = _connected_course(COURSE_01_PATH)
	var second: AuthoringPreview = _connected_course(COURSE_02_PATH)
	assert_true(first.try_start_play(1, 1, 1))
	assert_true(second.try_start_play(1, 1, 1))
	assert_true(first.is_playing())
	assert_true(second.is_playing())
	assert_false(first.is_safe_point())
	assert_gt(first.player_id, 0)
	assert_gt(second.player_id, 0)
	var first_pose: Dictionary = first.play_world.get_pose(first.player_id)
	var second_pose: Dictionary = second.play_world.get_pose(second.player_id)
	var first_x: int = first_pose.get("x", -1)
	var first_y: int = first_pose.get("y", -1)
	var first_z: int = first_pose.get("z", -1)
	var second_x: int = second_pose.get("x", -1)
	assert_eq(first_x, 0)
	assert_eq(first_y, 0)
	assert_eq(first_z, 0)
	assert_eq(second_x, 0)
	var first_box: int = first.play_pad_ids[1]
	var overlapping: PackedInt32Array = first.play_world.overlapping_static_boxes(first.player_id)
	assert_true(_has_id(overlapping, first_box))
	assert_eq(first.play_world.tick_index, 0)
	assert_false(first.allows_settlement())
	assert_false(first.allows_online_writes())


func test_empty_world_and_no_pads_refuse_play() -> void:
	var empty: AuthoringPreview = _connected_empty()
	assert_false(empty.try_start_play(1))
	assert_false(empty.is_playing())
	assert_true(empty.is_safe_point())
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.try_apply(_edit(1, 0, _place_portal(8, 9, 0))))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_false(preview.try_start_play(1))
	assert_false(preview.is_playing())
	assert_true(preview.connected)


func test_checkpoint_without_transform_refuses_play() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	var record: SharedComponentRecord = SharedComponentRecord.create(1, {
		"checkpoint": {
			"order": 0,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})
	assert_not_null(record)
	assert_true(session.world.put(record))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_false(preview.try_start_play(1))
	assert_false(preview.is_playing())
	assert_true(preview.is_safe_point())


func test_spawn_uses_min_order_and_respawn_offset() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint(5, 2, 0, 0, 0, 0)))
	assert_true(session.world.put(_checkpoint(2, 0, CELL, 0, 0, CELL)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_true(preview.try_start_play(1))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 2 * CELL)
	assert_eq(pose_y, 0)
	assert_eq(pose_z, 0)


func test_play_blocks_patches_until_stop() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1))
	assert_false(preview.try_start_play(1))
	assert_false(preview.try_apply_patch(Levels.P2, _edit(1, preview.world.revision, _place_portal(20, 21, CELL))))
	assert_false(preview.world.has_entity(20))
	assert_true(preview.is_playing())
	assert_true(preview.try_stop_play())
	assert_false(preview.is_playing())
	assert_true(preview.is_safe_point())
	assert_null(preview.play_world)
	assert_eq(preview.player_id, 0)
	assert_true(preview.try_apply_patch(Levels.P2, _edit(1, preview.world.revision, _place_portal(20, 21, CELL))))
	assert_true(preview.world.has_entity(20))
	assert_false(preview.allows_settlement())


func test_advance_play_ticks_without_settlement() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_false(preview.try_advance_play())
	assert_true(preview.try_start_play(1))
	assert_eq(preview.play_world.tick_index, 0)
	assert_true(preview.try_advance_play())
	assert_eq(preview.play_world.tick_index, 1)
	assert_true(preview.try_advance_play())
	assert_eq(preview.play_world.tick_index, 2)
	assert_false(preview.allows_settlement())
	assert_true(preview.try_stop_play())
	assert_false(preview.try_advance_play())
	assert_false(preview.try_stop_play())


func test_negative_capsule_size_refuses_play() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_false(preview.try_start_play(1, -1, 0))
	assert_false(preview.try_start_play(1, 0, -1))
	assert_false(preview.is_playing())
	assert_true(preview.is_safe_point())


func test_reconnect_clears_play() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1))
	assert_true(preview.connect_from(AuthoringSession.new()))
	assert_false(preview.is_playing())
	assert_true(preview.is_safe_point())
	assert_eq(preview.player_id, 0)


func test_shell_play_stop_updates_marker_and_status() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	_preview_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_preview_shell)
	assert_true(_preview_shell.open_from(session))
	assert_true(_preview_shell.try_start_play(1, 1, 1))
	var playing_on: bool = _preview_shell.status_view().get("playing", false)
	assert_true(playing_on)
	assert_true(_preview_shell.status_label_text().contains("playing=true"))
	var marker: MeshInstance3D = _preview_shell.map.player_node()
	assert_not_null(marker)
	assert_almost_eq(marker.position.x, 0.0, EPS)
	assert_almost_eq(marker.position.y, 0.0, EPS)
	assert_almost_eq(marker.position.z, 0.0, EPS)
	assert_gt(_preview_shell.map.mapped_count(), 0)
	assert_false(_preview_shell.allows_settlement())
	assert_true(_preview_shell.try_advance_play())
	assert_not_null(_preview_shell.map.player_node())
	assert_true(_preview_shell.try_stop_play())
	var playing_off: bool = _preview_shell.status_view().get("playing", false)
	assert_false(playing_off)
	assert_true(_preview_shell.status_label_text().contains("playing=false"))
	assert_null(_preview_shell.map.player_node())
	assert_false(_preview_shell.allows_settlement())


func test_map_player_marker_is_a_presentation_stub() -> void:
	_map = AuthoringPreviewMap.new()
	add_child(_map)
	_map.show_player_pose({"x": CELL, "y": 0, "z": 0, "yaw": 16384})
	var marker: MeshInstance3D = _map.player_node()
	assert_not_null(marker)
	assert_almost_eq(marker.position.x, 1.0, EPS)
	assert_almost_eq(marker.rotation.y, PI / 2.0, EPS)
	var box: BoxMesh = marker.mesh as BoxMesh
	assert_not_null(box)
	assert_almost_eq(box.size.x, 1.0, EPS)
	_map.clear_player_pose()
	assert_null(_map.player_node())
	_map.show_player_pose({})
	assert_null(_map.player_node())


func test_playing_drops_editor_follow_without_rolling_back_write() -> void:
	_editor_shell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(_editor_shell)
	assert_true(_editor_shell.open())
	assert_true(_editor_shell.try_place_checkpoint(1, 0, 0, 0, 0))
	assert_true(_editor_shell.open_preview())
	assert_true(_editor_shell.preview_follows)
	assert_true(_editor_shell.preview.try_start_play(1, 1, 1))
	assert_true(_editor_shell.preview.preview.is_playing())
	assert_true(_editor_shell.try_place_checkpoint(2, 1, 1, 0, 0))
	assert_true(_editor_shell.session.world.has_entity(2))
	assert_false(_editor_shell.preview.preview.world.has_entity(2))
	assert_false(_editor_shell.preview_follows)
	assert_true(_editor_shell.preview.preview.is_playing())
	assert_false(_editor_shell.allows_settlement())


func _connected_empty() -> AuthoringPreview:
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(AuthoringSession.new()))
	return preview


func _connected_course(path: String) -> AuthoringPreview:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(path)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	return preview


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


func _place_portal(entity_id: int, target_id: int, x: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": 0, "z": 0, "yaw_bam": 0},
				"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
			},
		},
	}


func _edit(command_id: int, expected_revision: int, payload: Dictionary) -> SharedCommand:
	return SharedCommand.create(
		command_id,
		2,
		command_id,
		0,
		expected_revision,
		"content-v1",
		payload,
		"trace-preview-play",
		SharedCommand.Kind.EDIT
	)


func _has_id(ids: PackedInt32Array, box_id: int) -> bool:
	for index: int in range(ids.size()):
		if ids[index] == box_id:
			return true
	return false
