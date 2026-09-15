extends RefCounted

## Connection slots and command queue around BastionMatchSession.
## Same occupancy / one-command-per-tick / lease-tick contract as MatchRealtime.
## Commands are type 5; snapshots are type 6 and clipped per observer in SETUP.

const BastionFrameCodec := preload("res://src/shared/protocol/bastion_frame_codec.gd")
const BastionMatchSessionGd := preload("res://src/games/bastion/match_session.gd")
const BastionMatchSettlementGd := preload("res://src/games/bastion/match_settlement.gd")
const BastionMatchSessionWireGd := preload("res://src/games/bastion/match_session_wire.gd")
const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const MatchGameplayGd := preload("res://src/shared/match_gameplay.gd")

var session: BastionMatchSessionGd = null

var _occupied: Dictionary = {}
var _queue: Array[Dictionary] = []
var _last_valid_input_tick: int = -1


static func create(match_session: BastionMatchSessionGd) -> RefCounted:
	if match_session == null:
		return null
	var realtime := new()
	realtime.session = match_session
	return realtime


func add_player() -> int:
	if session == null:
		return -1
	for slot: int in range(session.player_count()):
		if not _occupied.has(slot):
			_occupied[slot] = true
			return slot
	return -1


func occupy_slot(slot: int) -> bool:
	if session == null:
		return false
	if slot < 0 or slot >= session.player_count():
		return false
	if _occupied.has(slot):
		return false
	_occupied[slot] = true
	return true


func remove_player(slot: int) -> bool:
	if not _occupied.has(slot):
		return false
	_occupied.erase(slot)
	_drop_queued(slot)
	return true


func occupied_count() -> int:
	return _occupied.size()


func is_occupied(slot: int) -> bool:
	return _occupied.has(slot)


func pending_count() -> int:
	return _queue.size()


func last_valid_input_tick() -> int:
	return _last_valid_input_tick


func handle_inbound(slot: int, bytes: PackedByteArray) -> PackedByteArray:
	if session == null:
		return PackedByteArray()
	if not _occupied.has(slot):
		return PackedByteArray()
	var pong: PackedByteArray = MatchFrameCodec.echo_pong(bytes)
	if not pong.is_empty():
		return pong
	accept_command(slot, bytes)
	return PackedByteArray()


func accept_command(slot: int, bytes: PackedByteArray) -> bool:
	if session == null:
		return false
	if not _occupied.has(slot):
		return false
	if _queue_has_slot(slot):
		return false
	var decoded: Dictionary = BastionFrameCodec.decode_command(bytes)
	var decoded_ok: bool = decoded.get("ok", false)
	if not decoded_ok:
		return false
	_queue.append({"slot": slot, "payload": _payload_from(decoded)})
	return true


func commit_tick() -> void:
	if session == null:
		return
	var before_mark: String = session.hash_state()
	var applied_ok: bool = false
	var pending: Array[Dictionary] = _queue
	_queue = []
	for item: Dictionary in pending:
		var slot: int = item["slot"]
		if not _occupied.has(slot):
			continue
		var payload: Dictionary = item["payload"]
		if _apply_intent(slot, payload):
			applied_ok = true
	var changed: bool = applied_ok and session.hash_state() != before_mark
	session.commit_tick()
	if changed:
		_last_valid_input_tick = session.tick_index()


func snapshot_frame() -> PackedByteArray:
	return snapshot_frame_for(0)


func snapshot_frame_for(slot: int) -> PackedByteArray:
	if session == null:
		return PackedByteArray()
	var team_id: int = MatchGameplayGd.team_id_for_seat(slot)
	if team_id == 0:
		return PackedByteArray()
	return BastionMatchSessionWireGd.encode_snapshot(session, team_id)


func allows_settlement() -> bool:
	return BastionMatchSettlementGd.all_finished(session)


func allows_online_writes() -> bool:
	return false


func _apply_intent(slot: int, payload: Dictionary) -> bool:
	var team_id: int = MatchGameplayGd.team_id_for_seat(slot)
	if team_id == 0:
		return false
	var intent_name: String = payload.get("intent", "")
	var arg0: int = payload.get("arg0", 0)
	var arg1: int = payload.get("arg1", 0)
	if intent_name == PlayerIntentNames.BUILD_TOWER:
		return session.try_build_tower(team_id, arg0, arg1)
	if intent_name == PlayerIntentNames.UPGRADE_TOWER:
		return session.try_upgrade_tower(team_id, arg0)
	if intent_name == PlayerIntentNames.SELL_TOWER:
		return session.try_sell_tower(team_id, arg0)
	if intent_name == PlayerIntentNames.SET_TOWER_PRIORITY:
		var priority: String = BastionFrameCodec.priority_name(arg1)
		if priority.is_empty():
			return false
		return session.try_set_tower_priority(team_id, arg0, priority)
	if intent_name == PlayerIntentNames.PLACE_OBSTACLE:
		return session.try_place_obstacle(team_id, arg0, arg1)
	if intent_name == PlayerIntentNames.LOCK_SETUP:
		return session.lock_setup(team_id)
	return false


func _queue_has_slot(slot: int) -> bool:
	for item: Dictionary in _queue:
		var queued_slot: int = item["slot"]
		if queued_slot == slot:
			return true
	return false


func _drop_queued(slot: int) -> void:
	var kept: Array[Dictionary] = []
	for item: Dictionary in _queue:
		var queued_slot: int = item["slot"]
		if queued_slot != slot:
			kept.append(item)
	_queue = kept


static func _payload_from(decoded: Dictionary) -> Dictionary:
	return {
		"intent": decoded.get("intent", ""),
		"arg0": decoded.get("arg0", 0),
		"arg1": decoded.get("arg1", 0),
		"arg2": decoded.get("arg2", 0),
	}
