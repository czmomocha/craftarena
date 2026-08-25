class_name MatchPlaySession
extends RefCounted

## After a ready join ticket, build the gateway URL and follow snapshots.
## Commands use MatchFrameCodec; the command tick is 0 because the server
## tick is authoritative (CD-43 §3). Shove/Interact stay unencoded.
## Sockets stay outside this type. No interpolation or prediction.
## After a close, a new ticket from reconnect can try_begin again.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchJoinSessionGd := preload("res://src/client/match_join_session.gd")
const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const STATE_IDLE: String = "idle"
const STATE_CONNECTING: String = "connecting"
const STATE_IN_MATCH: String = "in_match"
const STATE_CLOSED: String = "closed"
const _YAW_OMITTED: int = -1

var state: String = STATE_IDLE
var websocket_url: String = ""
var follow: MatchSnapshotFollowGd = MatchSnapshotFollowGd.new()
var last_command: PackedByteArray = PackedByteArray()


static func gateway_ws_url(gateway_base: String, ticket: String) -> String:
	var token: String = ticket.strip_edges()
	if token == "":
		return ""
	var base: String = gateway_base.strip_edges()
	while base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	if base.ends_with("/ws"):
		base = base.substr(0, base.length() - 3)
	if not base.begins_with("ws://") and not base.begins_with("wss://"):
		return ""
	if base.contains("@") or base.contains("#"):
		return ""
	return "%s/ws?ticket=%s" % [base, token.uri_encode()]


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


func try_begin(join: MatchJoinSessionGd, gateway_base: String) -> bool:
	if join == null or join.state != MatchJoinSessionGd.STATE_READY:
		return false
	if state == STATE_CONNECTING or state == STATE_IN_MATCH:
		return false
	var url: String = gateway_ws_url(gateway_base, join.ticket)
	if url == "":
		return false
	websocket_url = url
	follow = MatchSnapshotFollowGd.new()
	last_command = PackedByteArray()
	state = STATE_CONNECTING
	return true


func on_open() -> bool:
	if state != STATE_CONNECTING:
		return false
	state = STATE_IN_MATCH
	return true


func on_close() -> void:
	if state == STATE_CONNECTING or state == STATE_IN_MATCH:
		state = STATE_CLOSED


func on_binary(bytes: PackedByteArray) -> bool:
	if state != STATE_IN_MATCH:
		return false
	return follow.apply_frame(bytes)


func try_encode_intent(intent_name: String, dx: int, dz: int, yaw_bam: int) -> PackedByteArray:
	if state != STATE_IN_MATCH:
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
	last_command = bytes
	return bytes


func try_encode_move_axes(forward: bool, back: bool, left: bool, right: bool, step: int) -> PackedByteArray:
	var payload: Dictionary = move_axes(forward, back, left, right, step)
	if payload.is_empty():
		return PackedByteArray()
	var dx: int = payload.get("dx", 0)
	var dz: int = payload.get("dz", 0)
	return try_encode_intent(PlayerIntentNames.MOVE, dx, dz, _YAW_OMITTED)


func status_view() -> Dictionary:
	var follow_view: Dictionary = follow.status_view()
	return {
		"state": state,
		"websocket_url": websocket_url,
		"has_snapshot": follow_view.get("has_snapshot", false),
		"tick": follow_view.get("tick", -1),
		"player_count": follow_view.get("player_count", 0),
		"crate_count": follow_view.get("crate_count", 0),
	}


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false
