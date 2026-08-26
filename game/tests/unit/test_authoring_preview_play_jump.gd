extends GutTest

## Preview play JumpIntent: while playing, apply the existing jump name
## through TraprushIntentStepper with caller play_jump_dy / play_support_dy
## stubs. Grounded (solid support inside the probe) moves up until blocked;
## airborne keeps the pose and still reports ok. Client height fields are
## ignored. Shove / Interact stay refused. No gravity or fall, no tick, no
## settlement. Official courses have no solid footing at spawn, so jump is
## an airborne no-op there; displacement is proven on synthetic footing
## (a solid crate one cell below the spawn pad, and a compiled solids bag).

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
const PAD_ID: int = 1
const CRATE_ID: int = 8
const SOLID_ID: int = 70
const STAND_Y: int = CELL
const SUPPORT_DY: int = -CELL / 2
const JUMP_DY: int = CELL / 2


var _preview_shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _preview_shell != null and is_instance_valid(_preview_shell):
		_preview_shell.free()
	_preview_shell = null


func test_grounded_jump_moves_up_by_caller_dy() -> void:
	var preview: AuthoringPreview = _grounded_preview()
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 1)
	preview.play_jump_dy = JUMP_DY
	preview.play_support_dy = SUPPORT_DY
	assert_true(preview.try_apply_play_intent(_jump()))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 0)
	assert_eq(pose_y, STAND_Y + JUMP_DY)
	assert_eq(pose_z, 0)
	assert_eq(preview.play_world.tick_index, 0)
	assert_eq(preview.play_accepted_count(), 1)
	assert_eq(preview.play_finish_tick(), -1)
	var box_id: int = preview.play_destructible_ids[CRATE_ID]
	assert_true(preview.play_world.is_static_box_solid(box_id))
	assert_eq(preview.play_destructible_alive_count(), 1)
	assert_false(preview.allows_settlement())
	assert_false(preview.allows_online_writes())


func test_grounded_jump_on_compiled_solid_moves_up() -> void:
	var preview: AuthoringPreview = _grounded_solid_preview()
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_accepted_count(), 1)
	preview.play_jump_dy = JUMP_DY
	preview.play_support_dy = SUPPORT_DY
	assert_true(preview.try_apply_play_intent(_jump()))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	assert_eq(pose_x, 0)
	assert_eq(pose_y, STAND_Y + JUMP_DY)
	assert_eq(pose_z, 0)
	assert_eq(preview.play_solid_count(), 1)
	var box_id: int = preview.play_solid_ids[SOLID_ID]
	assert_true(preview.play_world.is_static_box_solid(box_id))
	assert_false(preview.allows_settlement())


func test_airborne_jump_on_official_courses_keeps_pose() -> void:
	var first: AuthoringPreview = _connected_course(COURSE_01_PATH)
	var second: AuthoringPreview = _connected_course(COURSE_02_PATH)
	_assert_airborne_jump_keeps_pose(first)
	_assert_airborne_jump_keeps_pose(second)


func test_zero_jump_dy_keeps_pose() -> void:
	var preview: AuthoringPreview = _grounded_preview()
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	preview.play_jump_dy = 0
	preview.play_support_dy = SUPPORT_DY
	assert_true(preview.try_apply_play_intent(_jump()))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_y: int = pose.get("y", -1)
	assert_eq(pose_y, STAND_Y)
	assert_eq(preview.play_world.tick_index, 0)


func test_client_jump_fields_are_ignored() -> void:
	var preview: AuthoringPreview = _grounded_preview()
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	preview.play_jump_dy = JUMP_DY
	preview.play_support_dy = SUPPORT_DY
	assert_true(preview.try_apply_play_intent({
		"intent": PlayerIntentNames.JUMP,
		"dy": 99 * CELL,
		"height": 64,
		"y": 888,
	}))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_y: int = pose.get("y", -1)
	assert_eq(pose_y, STAND_Y + JUMP_DY)
	assert_eq(preview.play_world.tick_index, 0)


func test_jump_refused_unless_playing() -> void:
	var preview: AuthoringPreview = _grounded_preview()
	preview.play_jump_dy = JUMP_DY
	preview.play_support_dy = SUPPORT_DY
	assert_false(preview.try_apply_play_intent(_jump()))
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(preview.try_apply_play_intent(_jump()))
	assert_true(preview.try_stop_play())
	assert_false(preview.try_apply_play_intent(_jump()))
	assert_true(preview.is_safe_point())


func test_shove_and_interact_still_refused() -> void:
	var preview: AuthoringPreview = _grounded_preview()
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	preview.play_jump_dy = JUMP_DY
	preview.play_support_dy = SUPPORT_DY
	assert_false(preview.try_apply_play_intent({
		"intent": PlayerIntentNames.SHOVE,
	}))
	assert_false(preview.try_apply_play_intent({
		"intent": PlayerIntentNames.INTERACT,
	}))
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var pose_y: int = pose.get("y", -1)
	assert_eq(pose_y, STAND_Y)
	assert_eq(preview.play_destructible_alive_count(), 1)


func test_shell_jump_sampling_and_hidden_window() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint(PAD_ID, 0, 0, STAND_Y, 0)))
	assert_true(session.world.put(_crate(CRATE_ID, 0, 0, 0, 1)))
	_preview_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_preview_shell)
	_preview_shell.play_jump_dy = JUMP_DY
	_preview_shell.play_support_dy = SUPPORT_DY
	assert_true(_preview_shell.open_from(session))
	assert_true(_preview_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(_preview_shell.try_sample_play_jump(true))
	var pose: Dictionary = _preview_shell.preview.play_world.get_pose(
		_preview_shell.preview.player_id
	)
	var pose_y: int = pose.get("y", -1)
	assert_eq(pose_y, STAND_Y + JUMP_DY)
	assert_false(_preview_shell.try_sample_play_jump(true))
	assert_false(_preview_shell.try_sample_play_jump(false))
	assert_true(_preview_shell.try_sample_play_jump(true))
	var risen: Dictionary = _preview_shell.preview.play_world.get_pose(
		_preview_shell.preview.player_id
	)
	var risen_y: int = risen.get("y", -1)
	assert_eq(risen_y, STAND_Y + JUMP_DY)
	assert_eq(_preview_shell.status_label_text().contains("pads=1/1"), true)
	_preview_shell.hide_window()
	assert_false(_preview_shell.try_sample_play_jump(true))
	var hidden: Dictionary = _preview_shell.preview.play_world.get_pose(
		_preview_shell.preview.player_id
	)
	var hidden_y: int = hidden.get("y", -1)
	assert_eq(hidden_y, STAND_Y + JUMP_DY)
	assert_true(_preview_shell.preview.is_playing())
	assert_true(_preview_shell.try_apply_play_intent(_jump()))
	var direct: Dictionary = _preview_shell.preview.play_world.get_pose(
		_preview_shell.preview.player_id
	)
	var direct_y: int = direct.get("y", -1)
	assert_eq(direct_y, STAND_Y + JUMP_DY)


func _assert_airborne_jump_keeps_pose(preview: AuthoringPreview) -> void:
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	preview.play_jump_dy = JUMP_DY
	preview.play_support_dy = SUPPORT_DY
	var before: Dictionary = preview.play_world.get_pose(preview.player_id)
	var before_x: int = before.get("x", -1)
	var before_y: int = before.get("y", -1)
	var before_z: int = before.get("z", -1)
	assert_true(preview.try_apply_play_intent(_jump()))
	var after: Dictionary = preview.play_world.get_pose(preview.player_id)
	var after_x: int = after.get("x", -2)
	var after_y: int = after.get("y", -2)
	var after_z: int = after.get("z", -2)
	assert_eq(after_x, before_x)
	assert_eq(after_y, before_y)
	assert_eq(after_z, before_z)
	assert_eq(preview.play_world.tick_index, 0)
	assert_false(preview.allows_settlement())


func _grounded_preview() -> AuthoringPreview:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint(PAD_ID, 0, 0, STAND_Y, 0)))
	assert_true(session.world.put(_crate(CRATE_ID, 0, 0, 0, 1)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	return preview


func _grounded_solid_preview() -> AuthoringPreview:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint(PAD_ID, 0, 0, STAND_Y, 0)))
	assert_true(session.world.put(_solid(SOLID_ID, 0, 0, 0)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	return preview


func _connected_course(path: String) -> AuthoringPreview:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(path)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	return preview


func _jump() -> Dictionary:
	return {
		"intent": PlayerIntentNames.JUMP,
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


func _solid(entity_id: int, x: int, y: int, z: int) -> SharedComponentRecord:
	var half: int = CELL / 2
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"zone": {
			"shape": {"kind": "box", "hx": half, "hy": half, "hz": half},
			"tags": ["solid"],
		},
	})
