class_name MatchLobbyStage
extends RefCounted

## L4 presentation: eight occupancy maps under the lobby Window, plus
## snapshot sampling / own-slot overlay. Visuals never write authority.

const MatchCheckpointOrderMapGd := preload("res://src/client/match_checkpoint_order_map.gd")
const MatchCourseMapGd := preload("res://src/client/match_course_map.gd")
const MatchCrateMapGd := preload("res://src/client/match_crate_map.gd")
const MatchHazardMapGd := preload("res://src/client/match_hazard_map.gd")
const MatchPlaySessionGd := preload("res://src/client/match_play_session.gd")
const MatchPortalLinkMapGd := preload("res://src/client/match_portal_link_map.gd")
const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")
const MatchSnapshotInterpGd := preload("res://src/client/match_snapshot_interp.gd")
const MatchSnapshotMapGd := preload("res://src/client/match_snapshot_map.gd")
const MatchSolidMapGd := preload("res://src/client/match_solid_map.gd")
const MatchStandingMapGd := preload("res://src/client/match_standing_map.gd")

const MAP_NAME: String = "SnapshotMap"
const COURSE_NAME: String = "CourseMap"
const CRATE_NAME: String = "CrateMap"
const HAZARD_NAME: String = "HazardMap"
const SOLID_NAME: String = "SolidMap"
const LINK_NAME: String = "PortalLinkMap"
const ORDER_NAME: String = "CheckpointOrderMap"
const STANDING_NAME: String = "StandingMap"

var map: MatchSnapshotMapGd = null
var course: MatchCourseMapGd = null
var crates: MatchCrateMapGd = null
var hazards: MatchHazardMapGd = null
var solids: MatchSolidMapGd = null
var links: MatchPortalLinkMapGd = null
var orders: MatchCheckpointOrderMapGd = null
var standings: MatchStandingMapGd = null
var course_path: String = ""
var apply_count: int = 0
var interp_t: int = 0
var interp_tick: int = -1


func mount(window: Window) -> void:
	if window == null or map != null:
		return
	map = MatchSnapshotMapGd.new()
	map.name = MAP_NAME
	window.add_child(map)
	course = MatchCourseMapGd.new()
	course.name = COURSE_NAME
	map.add_child(course)
	crates = MatchCrateMapGd.new()
	crates.name = CRATE_NAME
	map.add_child(crates)
	hazards = MatchHazardMapGd.new()
	hazards.name = HAZARD_NAME
	map.add_child(hazards)
	solids = MatchSolidMapGd.new()
	solids.name = SOLID_NAME
	map.add_child(solids)
	links = MatchPortalLinkMapGd.new()
	links.name = LINK_NAME
	map.add_child(links)
	orders = MatchCheckpointOrderMapGd.new()
	orders.name = ORDER_NAME
	map.add_child(orders)
	standings = MatchStandingMapGd.new()
	standings.name = STANDING_NAME
	map.add_child(standings)


func bind_facade(shell: MatchLobbyShell) -> void:
	shell.map = map
	shell.course = course
	shell.crates = crates
	shell.hazards = hazards
	shell.solids = solids
	shell.links = links
	shell.orders = orders
	shell.standings = standings
	shell.frame_rate = shell.chrome.frame_rate


func ensure_rig() -> void:
	if map != null:
		map.ensure_rig()


func apply_course(path: String) -> void:
	course_path = path
	if course != null:
		course.apply_path(path)
	if crates != null:
		crates.apply_path(path)
	if hazards != null:
		hazards.apply_path(path)
	if solids != null:
		solids.apply_path(path)
	if links != null:
		links.apply_path(path)
	if orders != null:
		orders.apply_path(path)


func mapped_counts() -> Dictionary:
	var counts: Dictionary = {
		"players": 0,
		"pads": 0,
		"portals": 0,
		"finish": 0,
		"crates": 0,
		"crate_total": 0,
		"hazards": 0,
		"hazard_total": 0,
		"solids": 0,
		"solid_total": 0,
		"links": 0,
		"orders": 0,
		"sequences": 0,
		"standings": 0,
		"mvp_slot": -1,
		"standing_line": "",
	}
	if map != null:
		counts["players"] = map.player_count()
	if course != null:
		counts["pads"] = course.pad_count()
		counts["portals"] = course.portal_count()
		counts["finish"] = course.finish_count()
	if crates != null:
		counts["crates"] = crates.crate_count()
		counts["crate_total"] = crates.crate_total()
	if hazards != null:
		counts["hazards"] = hazards.hazard_count()
		counts["hazard_total"] = hazards.hazard_total()
	if solids != null:
		counts["solids"] = solids.solid_count()
		counts["solid_total"] = solids.solid_total()
	if links != null:
		counts["links"] = links.link_count()
	if orders != null:
		counts["orders"] = orders.checkpoint_count()
		counts["sequences"] = orders.sequence_count()
	if standings != null:
		counts["standings"] = standings.standing_count()
		counts["mvp_slot"] = standings.mvp_slot()
		counts["standing_line"] = standings.standing_line()
	return counts


func camera_follow_slot(offline_playing: bool, play: MatchPlaySessionGd) -> int:
	if offline_playing:
		return 0
	if play != null and play.state == MatchPlaySessionGd.STATE_IN_MATCH:
		return play.predict.own_slot
	return -1


func predict_solid_boxes() -> Array:
	var boxes: Array = []
	if crates != null:
		for item: Variant in crates.live_solid_boxes():
			boxes.append(item)
	if hazards != null:
		for item: Variant in hazards.live_solid_boxes():
			boxes.append(item)
	if solids != null:
		for item: Variant in solids.live_solid_boxes():
			boxes.append(item)
	return boxes


func apply_snapshot(
	follow: MatchSnapshotFollowGd,
	interp_t: int,
	play: MatchPlaySessionGd,
	offline_playing: bool,
	play_moving: bool,
	play_anim: PlayAnimState,
	offline_session: TraprushMatchSession
) -> bool:
	if follow == null or not follow.has_snapshot:
		return false
	var previous_players: Array = []
	if follow.has_previous:
		previous_players = follow.previous_players
	var sampled: Dictionary = MatchSnapshotInterpGd.try_sample(
		previous_players,
		follow.players,
		interp_t
	)
	if not sampled.get("ok", false):
		return false
	var players_raw: Variant = sampled.get("players", [])
	if typeof(players_raw) != TYPE_ARRAY:
		return false
	var players: Array = players_raw
	apply_count += 1
	if crates != null:
		crates.apply_follow(follow)
	if hazards != null:
		hazards.apply_follow(follow)
	if play != null and play.state == MatchPlaySessionGd.STATE_IN_MATCH:
		var predicted: Dictionary = play.predict.try_apply(
			players,
			follow.players,
			predict_solid_boxes()
		)
		if predicted.get("ok", false):
			var predicted_raw: Variant = predicted.get("players", [])
			if typeof(predicted_raw) == TYPE_ARRAY:
				players = predicted_raw
	var slot: int = camera_follow_slot(offline_playing, play)
	if map != null:
		map.follow_slot = slot
		map.apply_players(players, follow.crates)
	if course != null:
		course.apply_own_progress(
			MatchLobbyHud.own_player_int(follow.players, slot, "accepted_count", true),
			MatchLobbyHud.own_player_int(follow.players, slot, "finish_tick", false)
		)
	if standings != null:
		var pad_total: int = 0
		if course != null:
			pad_total = course.pad_count()
		standings.follow_slot = slot
		standings.apply_players(players, pad_total)
	_apply_solo_anim(offline_playing, play_moving, play_anim, offline_session)
	return true


func reset_interp() -> void:
	interp_t = 0
	interp_tick = -1


func sync_interp(follow: MatchSnapshotFollowGd) -> void:
	if follow == null or not follow.has_snapshot:
		return
	if follow.tick == interp_tick:
		return
	interp_tick = follow.tick
	interp_t = 0 if follow.has_previous else Fixed.SCALE


func try_advance_interp(window_visible: bool, step: int, follow: MatchSnapshotFollowGd) -> bool:
	if not window_visible or step < 1:
		return false
	if follow == null or not follow.has_previous or interp_t >= Fixed.SCALE:
		return false
	var next_t: int = interp_t + step
	if next_t < interp_t or next_t > Fixed.SCALE:
		next_t = Fixed.SCALE
	interp_t = next_t
	return true


func clear_play_overlay() -> void:
	if map != null:
		map.follow_slot = -1
		map.apply_players([])
	if standings != null:
		standings.follow_slot = -1
		standings.apply_players([])
	if crates != null:
		crates.apply_path(course_path)
	if hazards != null:
		hazards.apply_path(course_path)
	if course != null:
		course.apply_own_progress(-1)


func _apply_solo_anim(
	offline_playing: bool,
	play_moving: bool,
	play_anim: PlayAnimState,
	session: TraprushMatchSession
) -> void:
	if not offline_playing or map == null or session == null or play_anim == null:
		return
	var facts: Dictionary = PlayAnimState.facts(
		session.player_airborne(0),
		play_moving,
		session.player_stun_remaining(0) > 0,
		session.player_portal_latched(0),
		session.player_shoved_this_tick(0),
		session.player_broke_this_tick(0)
	)
	map.set_anim_state(0, play_anim.resolve(facts))
