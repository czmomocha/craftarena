class_name MatchLobbyDirectorReplay
extends RefCounted

## Read-only TRAPRUSH tape playback so MatchLobbyDirector stays under E9.


static func try_begin(host: MatchLobbyShell, tape: Dictionary) -> bool:
	host.chrome.release_focus()
	if host.offline == null:
		return false
	if host.offline_playing() and not host.director.try_stop_offline():
		return false
	host.offline.apply_play_stubs()
	host.stage.reset_interp()
	host.sampler.reset_motion()
	host.play_anim.reset()
	if not host.offline.try_begin_replay(tape):
		host.refresh_status()
		return false
	MatchLobbyRuntime.reset_match_camera(host)
	host.course_path = host.offline.course_path
	if host.course_path != "":
		host.apply_course_document(host.course_path)
	if host.window != null:
		host.window.visible = true
	if host.home_screen != null:
		host.home_screen.visible = false
	host.apply_snapshot_map()
	host.refresh_status()
	return true
