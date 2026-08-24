extends GutTest

## Preview play UseItemIntent: while playing, apply the existing use-item
## name through TraprushDestructibleBreak. Reach pose must overlap a
## compiled solid destructible. Damage and reach are caller stubs, not a
## product blast table. Destroyed boxes become non-solid. Interact / Shove
## stay refused. No gravity, inventory, regen, or settlement.

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
const CRATE_ID: int = 40


var _preview_shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _preview_shell != null and is_instance_valid(_preview_shell):
		_preview_shell.free()
	_preview_shell = null


func test_official_courses_break_crate_from_start_reach() -> void:
	var first: AuthoringPreview = _connected_course(COURSE_01_PATH)
	var second: AuthoringPreview = _connected_course(COURSE_02_PATH)
	_assert_break_official_crate(first)
	_assert_break_official_crate(second)


func test_zero_reach_from_start_does_not_damage() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	preview.play_use_item_damage = 1
	preview.play_use_item_reach_dx = 0
	preview.play_use_item_reach_dy = 0
	preview.play_use_item_reach_dz = 0
	assert_false(preview.try_apply_play_intent(_use_item()))
	assert_eq(preview.play_destructible_alive_count(), 1)
	assert_eq(preview.play_destructible_count(), 1)
	var box_id: int = preview.play_destructible_ids[CRATE_ID]
	assert_true(preview.play_world.is_static_box_solid(box_id))
	assert_eq(preview.play_world.tick_index, 0)
	assert_false(preview.allows_settlement())


func test_zero_damage_does_not_open_crate() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	preview.play_use_item_damage = 0
	preview.play_use_item_reach_dz = CELL
	assert_false(preview.try_apply_play_intent(_use_item()))
	assert_eq(preview.play_destructible_alive_count(), 1)
	var box_id: int = preview.play_destructible_ids[CRATE_ID]
	assert_true(preview.play_world.is_static_box_solid(box_id))


func test_client_hit_fields_are_ignored() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	preview.play_use_item_damage = 1
	preview.play_use_item_reach_dz = CELL
	assert_true(preview.try_apply_play_intent({
		"intent": PlayerIntentNames.USE_ITEM,
		"destroyed": true,
		"damage": 99,
		"x": 9 * CELL,
		"z": 9 * CELL,
	}))
	assert_eq(preview.play_destructible_alive_count(), 0)
	var box_id: int = preview.play_destructible_ids[CRATE_ID]
	assert_false(preview.play_world.is_static_box_solid(box_id))


func test_blocked_move_opens_after_break() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint(1, 0, 0, 0, 0)))
	assert_true(session.world.put(_crate(8, 0, 0, CELL, 1)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	var box_id: int = preview.play_destructible_ids[8]
	assert_true(preview.play_world.is_static_box_solid(box_id))
	assert_true(preview.try_apply_play_intent(_move(0, CELL)))
	var blocked: Dictionary = preview.play_world.get_pose(preview.player_id)
	var blocked_z: int = blocked.get("z", CELL)
	assert_lt(blocked_z, CELL)
	preview.play_use_item_damage = 1
	preview.play_use_item_reach_dz = CELL
	assert_true(preview.try_apply_play_intent(_use_item()))
	assert_false(preview.play_world.is_static_box_solid(box_id))
	assert_eq(preview.play_destructible_alive_count(), 0)
	assert_true(preview.try_apply_play_intent(_move(0, CELL)))
	var opened: Dictionary = preview.play_world.get_pose(preview.player_id)
	var opened_z: int = opened.get("z", -1)
	assert_gte(opened_z, CELL)
	assert_eq(preview.play_world.tick_index, 0)
	assert_false(preview.allows_online_writes())


func test_use_item_refused_unless_playing() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	preview.play_use_item_damage = 1
	preview.play_use_item_reach_dz = CELL
	assert_false(preview.try_apply_play_intent(_use_item()))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_use_item()))
	assert_true(preview.try_stop_play())
	assert_false(preview.try_apply_play_intent(_use_item()))
	assert_true(preview.is_safe_point())


func test_interact_and_shove_still_refused() -> void:
	var preview: AuthoringPreview = _connected_course(COURSE_01_PATH)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	var start: Dictionary = preview.play_world.get_pose(preview.player_id)
	assert_false(preview.try_apply_play_intent({
		"intent": PlayerIntentNames.INTERACT,
	}))
	assert_false(preview.try_apply_play_intent({
		"intent": PlayerIntentNames.SHOVE,
	}))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var start_x: int = start.get("x", -2)
	var start_z: int = start.get("z", -2)
	var pose_x: int = pose.get("x", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, start_x)
	assert_eq(pose_z, start_z)
	assert_eq(preview.play_destructible_alive_count(), 1)


func test_shell_use_item_opens_crate_and_hidden_window_does_not_sample() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	_preview_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_preview_shell)
	assert_true(_preview_shell.open_from(session))
	assert_true(_preview_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(_preview_shell.status_label_text().contains("crates=1/1"), true)
	assert_true(_preview_shell.try_sample_play_use_item(true))
	assert_eq(_preview_shell.preview.play_destructible_alive_count(), 0)
	assert_eq(_preview_shell.status_label_text().contains("crates=0/1"), true)
	assert_false(_preview_shell.try_sample_play_use_item(true))
	assert_false(_preview_shell.try_sample_play_use_item(false))
	assert_false(_preview_shell.allows_settlement())
	_preview_shell.hide_window()
	assert_true(_preview_shell.preview.is_playing())
	var session2: AuthoringSession = AuthoringSession.new()
	assert_true(session2.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	_preview_shell.free()
	_preview_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_preview_shell)
	assert_true(_preview_shell.open_from(session2))
	assert_true(_preview_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	_preview_shell.hide_window()
	assert_false(_preview_shell.try_sample_play_use_item(true))
	assert_eq(_preview_shell.preview.play_destructible_alive_count(), 1)
	_preview_shell.preview.play_use_item_damage = 1
	_preview_shell.preview.play_use_item_reach_dz = CELL
	assert_true(_preview_shell.try_apply_play_intent(_use_item()))
	assert_eq(_preview_shell.preview.play_destructible_alive_count(), 0)


func _assert_break_official_crate(preview: AuthoringPreview) -> void:
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_destructible_count(), 1)
	assert_eq(preview.play_destructible_alive_count(), 1)
	assert_true(preview.play_destructible_ids.has(CRATE_ID))
	var box_id: int = preview.play_destructible_ids[CRATE_ID]
	assert_true(preview.play_world.is_static_box_solid(box_id))
	preview.play_use_item_damage = 1
	preview.play_use_item_reach_dz = CELL
	assert_true(preview.try_apply_play_intent(_use_item()))
	assert_eq(preview.play_destructible_alive_count(), 0)
	assert_false(preview.play_world.is_static_box_solid(box_id))
	assert_false(preview.try_apply_play_intent(_use_item()))
	assert_eq(preview.play_world.tick_index, 0)
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


func _use_item() -> Dictionary:
	return {
		"intent": PlayerIntentNames.USE_ITEM,
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


func _crate(entity_id: int, x: int, y: int, z: int, durability: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"destructible": {
			"durability": durability,
			"regen_policy_id": 0,
		},
	})
