class_name MatchOfflineGhost
extends RefCounted

## Parallel Solo ghost session. Live MatchOfflineSession stays under E9.

const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const TapeGd := preload("res://src/games/traprush/replay_tape.gd")


static func is_active(host: MatchOfflineSession) -> bool:
	return host.ghost != null and host.ghost.state == MatchOfflineSession.STATE_PLAYING


static func try_start(host: MatchOfflineSession) -> void:
	try_stop(host)
	if host.replay_active or host.session == null:
		return
	if not host.ghost_settings.enabled:
		return
	var course_id: String = OfficialTraprushCoursesGd.id_from_path(host.course_path)
	if course_id == "":
		return
	var tape: Dictionary = host.ghost_store.best_for(course_id)
	if tape.is_empty():
		return
	if str(tape.get("content_hash", "")) != host.session.content_hash:
		return
	var parallel: MatchOfflineSession = MatchOfflineSession.new()
	copy_play_stubs(host, parallel)
	parallel.ghost_settings.enabled = false
	parallel.persist_replay = false
	if not parallel.try_begin_replay(tape):
		return
	host.ghost = parallel


static func try_advance(host: MatchOfflineSession) -> void:
	if host.ghost == null:
		return
	host.ghost.try_advance()


static func try_stop(host: MatchOfflineSession) -> void:
	if host.ghost == null:
		return
	host.ghost.try_stop()
	host.ghost = null


static func maybe_put(host: MatchOfflineSession) -> void:
	if host.ghost_saved or host.replay_active or host.session == null:
		return
	var tape: Dictionary = TapeGd.finalize(host.tape_recorder, host.session)
	if tape.is_empty():
		return
	host.ghost_store.put_if_faster(tape)
	host.ghost_saved = true


static func after_tick(host: MatchOfflineSession) -> void:
	maybe_put(host)
	try_advance(host)


static func copy_play_stubs(from_host: MatchOfflineSession, to_host: MatchOfflineSession) -> void:
	to_host.play_jump_dy = from_host.play_jump_dy
	to_host.play_support_dy = from_host.play_support_dy
	to_host.play_fall_dy = from_host.play_fall_dy
	to_host.play_use_item_damage = from_host.play_use_item_damage
	to_host.play_use_item_reach_dx = from_host.play_use_item_reach_dx
	to_host.play_use_item_reach_dy = from_host.play_use_item_reach_dy
	to_host.play_use_item_reach_dz = from_host.play_use_item_reach_dz
	to_host.play_shove_step = from_host.play_shove_step
	to_host.play_shove_cooldown_ticks = from_host.play_shove_cooldown_ticks
	to_host.play_sprint_step = from_host.play_sprint_step
	to_host.play_item_cooldown_ticks = from_host.play_item_cooldown_ticks
	to_host.play_hazard_knockback_step = from_host.play_hazard_knockback_step
	to_host.play_conveyor_step = from_host.play_conveyor_step
	to_host.play_ice_step = from_host.play_ice_step
	to_host.play_launch_dy = from_host.play_launch_dy
	to_host.play_launch_xz = from_host.play_launch_xz
	to_host.play_respawn_stun_ticks = from_host.play_respawn_stun_ticks
	to_host.play_range_half = from_host.play_range_half
