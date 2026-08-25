class_name MatchOfflineSession
extends RefCounted

## Local embedded TRAPRUSH authority (CD-13 §3). Compiles a course into
## TraprushMatchSession — the same SimulationCore as the online match
## process. Commands use MatchFrameCodec; the command tick is 0 because
## the local session tick is authoritative. Snapshots feed
## MatchSnapshotFollow so the lobby can interpolate presentation poses.
## The banner is always "离线试玩，成绩不上传". Web is refused.
## No HTTP, sockets, settlement, ghosts, or online writes.

const MatchCourseMapGd := preload("res://src/client/match_course_map.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")

const BANNER: String = "离线试玩，成绩不上传"
const DEFAULT_COURSE: String = "res://content/official/traprush/course_01.json"
const STATE_IDLE: String = "idle"
const STATE_PLAYING: String = "playing"
const _YAW_OMITTED: int = -1
## Capsule stubs match the match-server placeholders; not product sizes.
const CAPSULE_RADIUS: int = 8192
const CAPSULE_HEIGHT: int = 8192
const MATCH_SEED: int = 1

var state: String = STATE_IDLE
var course_path: String = ""
var last_error: String = ""
var last_command: PackedByteArray = PackedByteArray()
var follow: MatchSnapshotFollowGd = MatchSnapshotFollowGd.new()
var session: TraprushMatchSessionGd = null
var play_jump_dy: int = 0
var play_support_dy: int = 0
var play_use_item_damage: int = 0
var play_use_item_reach_dx: int = 0
var play_use_item_reach_dy: int = 0
var play_use_item_reach_dz: int = 0


static func move_axes(forward: bool, back: bool, left: bool, right: bool, step: int) -> Dictionary:
	if step < 1:
		return {}
	var dx: int = 0
	var dz: int = 0
	if right:
		dx += step
	if left:
		dx -= step
	if back:
		dz += step
	if forward:
		dz -= step
	if dx == 0 and dz == 0:
		return {}
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	}


func try_begin(path: String, web_platform: bool = false) -> bool:
	if web_platform:
		last_error = "web_locked"
		return false
	if state == STATE_PLAYING:
		last_error = "busy"
		return false
	var bundle: SimulationBundle = MatchCourseMapGd.compile_path(path)
	if bundle == null:
		last_error = "missing_course"
		return false
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var created: TraprushMatchSessionGd = TraprushMatchSessionGd.create(
		bundle,
		MATCH_SEED,
		1,
		offsets,
		CAPSULE_RADIUS,
		CAPSULE_HEIGHT
	)
	if created == null:
		last_error = "compile_failed"
		return false
	created.jump_dy = play_jump_dy
	created.support_dy = play_support_dy
	created.use_item_damage = play_use_item_damage
	created.use_item_reach_dx = play_use_item_reach_dx
	created.use_item_reach_dy = play_use_item_reach_dy
	created.use_item_reach_dz = play_use_item_reach_dz
	session = created
	follow = MatchSnapshotFollowGd.new()
	last_command = PackedByteArray()
	course_path = path
	state = STATE_PLAYING
	last_error = ""
	return _publish()


func try_stop() -> bool:
	if state != STATE_PLAYING:
		return false
	session = null
	follow = MatchSnapshotFollowGd.new()
	last_command = PackedByteArray()
	course_path = ""
	state = STATE_IDLE
	last_error = ""
	return true


func try_encode_intent(intent_name: String, dx: int, dz: int, yaw_bam: int) -> PackedByteArray:
	if state != STATE_PLAYING:
		return PackedByteArray()
	if intent_name == PlayerIntentNames.SHOVE or intent_name == PlayerIntentNames.INTERACT:
		return PackedByteArray()
	var yaw: int = yaw_bam
	if intent_name != PlayerIntentNames.MOVE:
		dx = 0
		dz = 0
		yaw = 0
	elif yaw == 0:
		yaw = _YAW_OMITTED
	var bytes: PackedByteArray = MatchFrameCodec.encode_command(0, intent_name, dx, dz, yaw)
	if bytes.is_empty():
		return PackedByteArray()
	if not try_apply_command(bytes):
		return PackedByteArray()
	last_command = bytes
	return bytes


func try_encode_move_axes(forward: bool, back: bool, left: bool, right: bool, step: int) -> PackedByteArray:
	var payload: Dictionary = move_axes(forward, back, left, right, step)
	if payload.is_empty():
		return PackedByteArray()
	var dx: int = payload.get("dx", 0)
	var dz: int = payload.get("dz", 0)
	return try_encode_intent(PlayerIntentNames.MOVE, dx, dz, _YAW_OMITTED)


func try_apply_command(bytes: PackedByteArray) -> bool:
	if state != STATE_PLAYING or session == null:
		return false
	var decoded: Dictionary = MatchFrameCodec.decode_command(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	if not decoded_ok:
		return false
	var payload: Dictionary = _payload_from(decoded)
	if not session.apply_player_intent(0, payload):
		return false
	return _publish()


func try_advance() -> bool:
	if state != STATE_PLAYING or session == null:
		return false
	session.commit_tick()
	return _publish()


func status_view() -> Dictionary:
	var follow_view: Dictionary = follow.status_view()
	var tick: int = -1
	var player_count: int = 0
	if session != null:
		tick = session.tick_index()
		player_count = session.player_count()
	return {
		"state": state,
		"banner": BANNER if state == STATE_PLAYING else "",
		"course_path": course_path,
		"error": last_error,
		"has_snapshot": follow_view.get("has_snapshot", false),
		"tick": tick,
		"player_count": player_count,
		"crate_count": follow_view.get("crate_count", 0),
	}


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _publish() -> bool:
	var frame: PackedByteArray = _snapshot_frame()
	if frame.is_empty():
		return false
	return follow.apply_frame(frame)


func _snapshot_frame() -> PackedByteArray:
	if session == null:
		return PackedByteArray()
	var players: Array[Dictionary] = []
	for slot: int in range(session.player_count()):
		var pose: Dictionary = session.player_pose(slot)
		players.append({
			"x": pose.get("x", 0),
			"y": pose.get("y", 0),
			"z": pose.get("z", 0),
			"yaw_bam": pose.get("yaw", 0),
			"accepted_count": session.player_accepted_count(slot),
			"finish_tick": session.player_finish_tick(slot),
		})
	return MatchFrameCodec.encode_snapshot(
		session.tick_index(),
		players,
		session.destructible_states()
	)


static func _payload_from(decoded: Dictionary) -> Dictionary:
	var intent_name: String = decoded.get("intent", "")
	if intent_name == PlayerIntentNames.MOVE:
		var payload: Dictionary = {
			"intent": intent_name,
			"dx": decoded.get("dx", 0),
			"dz": decoded.get("dz", 0),
		}
		var yaw_bam: int = decoded.get("yaw_bam", _YAW_OMITTED)
		if yaw_bam != _YAW_OMITTED:
			payload["yaw_bam"] = yaw_bam
		return payload
	return {"intent": intent_name}
