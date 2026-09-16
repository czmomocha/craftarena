class_name MatchLobbyStageBastion
extends RefCounted

## BASTION field mount / follow / pick, kept off MatchLobbyStage for E9.

const MAP_NAME: String = "BastionField"
const ObserveGd := preload("res://src/games/bastion/audio_observe.gd")
const RouterGd := preload("res://src/games/bastion/audio_router.gd")
const MatchGameplayGd := preload("res://src/shared/match_gameplay.gd")

static var _observe: ObserveGd = ObserveGd.new()
static var _interact: BastionInteract = BastionInteract.new()


static func mount(shell: MatchLobbyShell) -> void:
	if shell.window == null:
		return
	if shell.window.get_node_or_null(MAP_NAME) != null:
		return
	var field: BastionFieldMap = BastionFieldMap.new()
	field.name = MAP_NAME
	field.visible = false
	shell.window.add_child(field)
	field.ensure_rig()


static func field_of(shell: MatchLobbyShell) -> BastionFieldMap:
	if shell.window == null:
		return null
	return shell.window.get_node_or_null(MAP_NAME) as BastionFieldMap


static func interact_of(_shell: MatchLobbyShell) -> BastionInteract:
	return _interact


static func apply_path(shell: MatchLobbyShell, path: String) -> bool:
	var field: BastionFieldMap = field_of(shell)
	if field == null:
		return false
	_show_bastion(shell, true)
	_interact.reset()
	_observe.reset()
	return field.apply_path(path)


static func apply_follow(shell: MatchLobbyShell) -> bool:
	var field: BastionFieldMap = field_of(shell)
	if field == null or shell.play == null or shell.play.bastion == null:
		return false
	_show_bastion(shell, true)
	return field.apply_follow(shell.play.bastion)


static func try_pick(shell: MatchLobbyShell, screen: Vector2) -> bool:
	var field: BastionFieldMap = field_of(shell)
	if field == null:
		return false
	var hit: Dictionary = field.pick_at(screen)
	if not hit.get("ok", false):
		return false
	var pick_id: int = hit.get("id", 0)
	if not _interact.try_select(str(hit.get("kind", "")), pick_id):
		return false
	field.set_selection(_interact.selected_kind, _interact.selected_id)
	ClientAudio.post(RouterGd.cue(RouterGd.EVENT_SELECT))
	return true


static func try_zoom(shell: MatchLobbyShell, steps: int) -> bool:
	var field: BastionFieldMap = field_of(shell)
	return field != null and field.try_zoom(steps)


static func try_pan(shell: MatchLobbyShell, relative: Vector2) -> bool:
	var field: BastionFieldMap = field_of(shell)
	return field != null and field.try_pan(relative)


static func hud_view(shell: MatchLobbyShell) -> Dictionary:
	var field: BastionFieldMap = field_of(shell)
	if field == null or shell.play == null or shell.play.bastion == null:
		return BastionHud.view_from_follow(null, 0, 0, 0)
	var own_team: int = MatchGameplayGd.team_id_for_seat(shell.play.predict.own_slot)
	var wave_total: int = 0
	var remain: int = 0
	if field.bundle != null:
		wave_total = field.bundle.total_wave_count()
		remain = shell.play.bastion.remain_ticks(_phase_limit(field.bundle, shell.play.bastion.phase))
	return BastionHud.view_from_follow(shell.play.bastion, own_team, wave_total, remain)


static func mapped_overlay(shell: MatchLobbyShell) -> Dictionary:
	var field: BastionFieldMap = field_of(shell)
	if field == null or not field.visible:
		return {"bastion_active": false}
	return {
		"bastion_active": true,
		"mapped_cores": field.core_count(),
		"mapped_build_slots": field.build_slot_count(),
		"mapped_towers": field.tower_count(),
		"mapped_units": field.unit_count(),
		"mapped_obstacles": field.obstacle_count(),
	}


static func pump_audio(shell: MatchLobbyShell) -> void:
	if shell.play == null or shell.play.bastion == null:
		return
	var events: PackedStringArray = _observe.collect(shell.play.bastion)
	var field: BastionFieldMap = field_of(shell)
	var ear: Node3D = null if field == null else field.camera_node()
	if ClientAudio.service != null:
		ClientAudio.service.set_space(field)
		ClientAudio.service.attach_listener(ear)
	for event: String in events:
		ClientAudio.post(RouterGd.cue(event))


static func show_traprush(shell: MatchLobbyShell) -> void:
	_show_bastion(shell, false)


static func _show_bastion(shell: MatchLobbyShell, on: bool) -> void:
	var field: BastionFieldMap = field_of(shell)
	if field != null:
		field.visible = on
		field.ensure_rig()
	if shell.map != null:
		shell.map.visible = not on
		var camera: Camera3D = shell.map.camera_node()
		if camera != null:
			camera.current = not on


static func _phase_limit(bundle: BastionBlueprintBundle, phase: int) -> int:
	match phase:
		BastionMatchSession.PHASE_SETUP:
			return bundle.economy_value("setup_ticks")
		BastionMatchSession.PHASE_PREP:
			return bundle.economy_value("prep_ticks")
		BastionMatchSession.PHASE_WAVES:
			return bundle.economy_value("time_limit_ticks")
		_:
			return 0
