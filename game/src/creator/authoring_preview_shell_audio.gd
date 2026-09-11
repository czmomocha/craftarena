class_name AuthoringPreviewShellAudio
extends RefCounted

## Preview play → cue pump. Builds the same sample dict Solo uses.

const ClientAudioGd := preload("res://src/client/client_audio.gd")
const MatchPlayAudioGd := preload("res://src/client/match_play_audio.gd")
const ObserveGd := preload("res://src/games/traprush/traprush_audio_observe.gd")

var last_intent: String = ""


func note_intent(payload: Dictionary) -> void:
	var raw: Variant = payload.get("intent", "")
	if typeof(raw) == TYPE_STRING:
		var intent: String = raw
		last_intent = intent


func pump(shell: AuthoringPreviewShell) -> void:
	if ClientAudioGd.play_audio == null or ClientAudioGd.service == null:
		return
	var preview: AuthoringPreview = shell.preview
	if preview == null or not preview.is_playing() or preview.play_world == null:
		ClientAudioGd.clear_play()
		last_intent = ""
		return
	var pose: Dictionary = preview.play_world.get_pose(preview.player_id)
	var sample: Dictionary = {
		ObserveGd.KEY_TICK: preview.play_world.tick_index,
		ObserveGd.KEY_X: pose.get("x", 0),
		ObserveGd.KEY_Y: pose.get("y", 0),
		ObserveGd.KEY_Z: pose.get("z", 0),
		ObserveGd.KEY_AIR: _airborne(preview),
		ObserveGd.KEY_ACCEPTED: preview.play_accepted_count(),
		ObserveGd.KEY_FINISH: preview.play_finish_tick(),
		ObserveGd.KEY_BOMB: preview.play_bomb_count(),
		ObserveGd.KEY_DASH: preview.play_dash_count(),
		ObserveGd.KEY_TAKEN: preview.play_taken.size(),
		ObserveGd.KEY_SETBACK: preview.play_setback_count,
		ObserveGd.KEY_REASON: preview.play_setback_reason,
		ObserveGd.KEY_SHOVE: -1,
		ObserveGd.KEY_USE: preview.play_last_use_item_tick,
		ObserveGd.KEY_SPRINT: preview.play_last_sprint_tick,
		ObserveGd.KEY_LATCH: not preview._portal_latch.is_empty(),
		ObserveGd.KEY_INTENT: last_intent,
		ObserveGd.KEY_HEALTH: _health(preview),
		ObserveGd.KEY_KINDS: _kinds(preview),
	}
	var events: PackedStringArray = ClientAudioGd.play_audio.observe.collect(sample)
	var loops: Array[Dictionary] = ObserveGd.loops_from_bags(
		preview.play_world,
		preview.play_conveyor_cycle,
		preview.play_mover_cycle,
		preview.play_flame_cycle,
		preview.play_hazard_cycle,
		preview.play_crusher_cycle,
		preview.play_pendulum_cycle,
		preview.play_gate_cycle,
		preview.play_ice_cycle,
		preview.play_portal_ids
	)
	var ear: Node3D = null
	if shell.map != null:
		ear = shell.map.get_node_or_null(AuthoringPreviewMap.CAMERA_NAME) as Node3D
	ClientAudioGd.play_audio.pump(
		ClientAudioGd.service,
		events,
		loops,
		shell.map,
		ear,
		MatchPlayAudioGd.pose_meters(pose)
	)


static func _airborne(preview: AuthoringPreview) -> bool:
	return PlayAnimState.is_airborne(
		preview.play_world.get_vy(preview.player_id),
		preview.play_world.is_supported_by_solid(preview.player_id, PlayAnimState.CONTACT_DY)
	)


static func _health(preview: AuthoringPreview) -> Dictionary:
	var health: Dictionary = {}
	for key: Variant in preview.play_destructible_health.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		var crate_raw: Variant = preview.play_destructible_health[entity_id]
		if not (crate_raw is TraprushDestructible):
			health[entity_id] = 0
			continue
		var crate: TraprushDestructible = crate_raw
		health[entity_id] = crate.current_health()
	return health


static func _kinds(preview: AuthoringPreview) -> Dictionary:
	return preview.play_destructible_kinds
