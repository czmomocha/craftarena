class_name MatchLobbyDirectorJoin
extends RefCounted

## UGC join / plaza create-room helpers so MatchLobbyDirector stays under E9.

const MatchJoinSessionGd := preload("res://src/client/match_join_session.gd")
const MatchPlaySessionGd := preload("res://src/client/match_play_session.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const OfficialBastionBlueprintsGd := preload("res://src/shared/official_bastion_blueprints.gd")
const PlazaHttpGd := preload("res://src/client/content_plaza_http.gd")


static func after_join_http(host: MatchLobbyShell, begin_play: Callable) -> void:
	if host.join != null and host.join.content_id != "":
		_apply_joined_content(host)
	elif host.join != null and host.join.blueprint != "":
		MatchLobbyRuntime.apply_blueprint_document(host, host.join.blueprint)
	elif host.join != null and host.join.course != "":
		var path: String = OfficialTraprushCoursesGd.document_path(host.join.course)
		if path != "":
			host.apply_course_document(path)
	if host.join != null and host.join.state == MatchJoinSessionGd.STATE_READY and host.play != null:
		if host.play.state == MatchPlaySessionGd.STATE_IDLE or host.play.state == MatchPlaySessionGd.STATE_CLOSED:
			if begin_play.is_valid():
				begin_play.call()
	host.refresh_status()


static func try_matchmake(host: MatchLobbyShell, create_room: bool) -> bool:
	host.chrome.release_focus()
	if host.join == null or host.offline_playing():
		return false
	var id: String = host.selected_course_id()
	if id == "":
		host.join.fail_reason("unknown_course")
		host.refresh_status()
		return false
	var started: bool = false
	if OfficialBastionBlueprintsGd.is_id(id):
		if create_room:
			started = host.join.try_create_room_blueprint(id)
		else:
			started = host.join.try_quick_blueprint(id)
	elif OfficialTraprushCoursesGd.is_id(id):
		if host.selected_seats() == 0:
			return false
		if create_room:
			started = host.join.try_create_room(id, host.selected_seats())
		else:
			started = host.join.try_quick(id, host.selected_seats())
	else:
		host.join.fail_reason("http_official_only")
		host.refresh_status()
		return false
	if not started:
		return false
	host.dispatch_pending()
	host.refresh_status()
	return true


static func try_create_room_plaza(host: MatchLobbyShell, content_id: String, version: int) -> bool:
	host.chrome.release_focus()
	if host.join == null or host.offline_playing():
		return false
	var id: String = content_id
	var pinned: int = version
	if id == "" and host.plaza != null:
		id = host.plaza.selected_content_id()
		pinned = host.plaza.selected_version()
	if id == "" or pinned < 1:
		host.join.fail_reason("invalid_content")
		host.refresh_status()
		return false
	if not host.join.try_create_room_content(id, pinned, host.selected_seats()):
		return false
	if host.plaza != null:
		host.plaza.try_close()
	host.dispatch_pending()
	host.refresh_status()
	return true


static func _apply_joined_content(host: MatchLobbyShell) -> void:
	var bundle: SimulationBundle = null
	if host.plaza != null:
		bundle = host.plaza.bundle_of(host.join.content_id)
	if bundle == null:
		var transport: Callable = Callable()
		if host.plaza != null:
			transport = host.plaza.http_transport
		var fetched: Dictionary = PlazaHttpGd.fetch_version(
			host.control_plane_base,
			host.join.content_id,
			host.join.content_version,
			transport
		)
		bundle = PlazaHttpGd.read_latest_bundle(fetched)
	if bundle != null:
		host.stage.apply_bundle(bundle)
