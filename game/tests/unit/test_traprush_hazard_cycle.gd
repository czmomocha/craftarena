extends GutTest

## Period hazards compile into v1 topology and toggle solid on tick.
## cooldown_ticks is the existing hazard field (half-period). Intents do
## not tick, so they do not toggle. No damage, knockback, gravity, or
## settlement. Official courses stay empty.

const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")
const AuthoringPreviewShell := preload("res://src/creator/authoring_preview_shell.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const HazardCycle := preload("res://src/games/traprush/hazard_cycle.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SharedComponentRecord := preload("res://src/shared/schema/component_record.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8
const HAZARD_ID: int = 50

var _preview_shell: AuthoringPreviewShell = null


func after_each() -> void:
	if _preview_shell != null and is_instance_valid(_preview_shell):
		_preview_shell.free()
	_preview_shell = null


func test_is_solid_matches_graybox_period_formula() -> void:
	assert_true(HazardCycle.is_solid(0, 1))
	assert_false(HazardCycle.is_solid(1, 1))
	assert_true(HazardCycle.is_solid(2, 1))
	assert_true(HazardCycle.is_solid(0, 2))
	assert_true(HazardCycle.is_solid(1, 2))
	assert_false(HazardCycle.is_solid(2, 2))
	assert_true(HazardCycle.is_solid(3, 0))
	assert_true(HazardCycle.is_solid(1, 0))


func test_match_period_one_blocks_then_opens_then_blocks() -> void:
	var session: TraprushMatchSession = _hazard_session(1)
	assert_not_null(session)
	assert_eq(session.hazard_count(), 1)
	assert_true(session.is_hazard_solid(HAZARD_ID))
	assert_eq(session.tick_index(), 0)
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var blocked: Dictionary = session.player_pose(0)
	var blocked_x: int = blocked.get("x", -1)
	assert_lt(blocked_x, CELL)
	assert_true(session.is_hazard_solid(HAZARD_ID))
	assert_eq(session.tick_index(), 0)
	session.commit_tick()
	assert_eq(session.tick_index(), 1)
	assert_false(session.is_hazard_solid(HAZARD_ID))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var opened: Dictionary = session.player_pose(0)
	var opened_x: int = opened.get("x", -1)
	assert_gte(opened_x, CELL)
	session.commit_tick()
	assert_eq(session.tick_index(), 2)
	assert_true(session.is_hazard_solid(HAZARD_ID))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var reblocked: Dictionary = session.player_pose(0)
	var reblocked_x: int = reblocked.get("x", -1)
	assert_eq(reblocked_x, opened_x)


func test_zero_cooldown_stays_solid_after_ticks() -> void:
	var session: TraprushMatchSession = _hazard_session(0)
	assert_not_null(session)
	assert_true(session.is_hazard_solid(HAZARD_ID))
	session.commit_tick()
	session.commit_tick()
	assert_eq(session.tick_index(), 2)
	assert_true(session.is_hazard_solid(HAZARD_ID))
	assert_true(session.apply_player_intent(0, _move(CELL, 0)))
	var pose: Dictionary = session.player_pose(0)
	var pose_x: int = pose.get("x", -1)
	assert_lt(pose_x, CELL)


func test_preview_period_one_toggles_on_advance_not_move() -> void:
	var preview: AuthoringPreview = _connected_hazard(1)
	assert_true(preview.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_eq(preview.play_hazard_count(), 1)
	assert_true(preview.play_is_hazard_solid(HAZARD_ID))
	assert_eq(preview.play_world.tick_index, 0)
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var blocked: Dictionary = preview.play_world.get_pose(preview.player_id)
	var blocked_x: int = blocked.get("x", -1)
	assert_lt(blocked_x, CELL)
	assert_true(preview.play_is_hazard_solid(HAZARD_ID))
	assert_eq(preview.play_world.tick_index, 0)
	assert_true(preview.try_advance_play())
	assert_eq(preview.play_world.tick_index, 1)
	assert_false(preview.play_is_hazard_solid(HAZARD_ID))
	assert_true(preview.try_apply_play_intent(_move(CELL, 0)))
	var opened: Dictionary = preview.play_world.get_pose(preview.player_id)
	var opened_x: int = opened.get("x", -1)
	assert_gte(opened_x, CELL)


func test_shell_advance_tick_button_opens_period_one_hazard() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(session.world.put(_hazard_record(HAZARD_ID, CELL, 0, 0, 1)))
	_preview_shell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(_preview_shell)
	assert_true(_preview_shell.open_from(session))
	var button: Button = _preview_shell.window.find_child(
		AuthoringPreviewShell.ADVANCE_TICK_NAME, true, false
	)
	assert_not_null(button)
	assert_true(_preview_shell.try_start_play(1, PLAY_RADIUS, PLAY_RADIUS))
	assert_true(_preview_shell.preview.play_is_hazard_solid(HAZARD_ID))
	button.pressed.emit()
	assert_eq(_preview_shell.preview.play_world.tick_index, 1)
	assert_false(_preview_shell.preview.play_is_hazard_solid(HAZARD_ID))


func _hazard_session(cooldown_ticks: int) -> TraprushMatchSession:
	var world: AuthoringWorld = AuthoringWorld.new()
	assert_true(world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(world.put(_hazard_record(HAZARD_ID, CELL, 0, 0, cooldown_ticks)))
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	return TraprushMatchSession.create(bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS)


func _connected_hazard(cooldown_ticks: int) -> AuthoringPreview:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.world.put(_checkpoint_record(1, 0, 0, 0, 0)))
	assert_true(session.world.put(_hazard_record(HAZARD_ID, CELL, 0, 0, cooldown_ticks)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	return preview


func _checkpoint_record(entity_id: int, order: int, x: int, y: int, z: int) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"checkpoint": {
			"order": order,
			"respawn_dx": 0,
			"respawn_dy": 0,
			"respawn_dz": 0,
		},
	})


func _hazard_record(
	entity_id: int,
	x: int,
	y: int,
	z: int,
	cooldown_ticks: int
) -> SharedComponentRecord:
	return SharedComponentRecord.create(entity_id, {
		"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
		"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": cooldown_ticks},
	})


func _move(dx: int, dz: int) -> Dictionary:
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	}
