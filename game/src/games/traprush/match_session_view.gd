class_name TraprushMatchView
extends RefCounted

## Read model for TraprushMatchSession: poses, progress, inventory, hash.
## Does not apply intents or occupancy.

const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")
const StateHasher := preload("res://src/shared/protocol/state_hasher.gd")
const TraprushDestructible := preload("res://src/games/traprush/destructible.gd")


func player_count(session: TraprushMatchSession) -> int:
	return session._players.size()


func checkpoint_count(session: TraprushMatchSession) -> int:
	return session._ordered_ids.size()


func tick_index(session: TraprushMatchSession) -> int:
	if session._world == null:
		return 0
	return session._world.tick_index


func player_capsule_id(session: TraprushMatchSession, slot: int) -> int:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return 0
	var capsule_id: int = player["capsule_id"]
	return capsule_id


func player_pose(session: TraprushMatchSession, slot: int) -> Dictionary:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return {}
	var capsule_id: int = player["capsule_id"]
	return session._world.get_pose(capsule_id)


func player_supported_by_solid(session: TraprushMatchSession, slot: int) -> bool:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return false
	var capsule_id: int = player["capsule_id"]
	return session._world.is_supported_by_solid(capsule_id, session.support_dy)


func player_accepted_count(session: TraprushMatchSession, slot: int) -> int:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return 0
	var track: CheckpointTrack = player["track"]
	return track.completed_count()


func player_last_accepted_id(session: TraprushMatchSession, slot: int) -> int:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return -1
	var track: CheckpointTrack = player["track"]
	return track.last_accepted_id()


func player_finish_tick(session: TraprushMatchSession, slot: int) -> int:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return -1
	var finish_tick: int = player["finish_tick"]
	return finish_tick


func player_bomb_count(session: TraprushMatchSession, slot: int) -> int:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return 0
	var bomb: int = player.get("bomb", 0)
	return bomb


func player_dash_count(session: TraprushMatchSession, slot: int) -> int:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return 0
	var dash: int = player.get("dash", 0)
	return dash


func player_stun_remaining(session: TraprushMatchSession, slot: int) -> int:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return 0
	var stun_raw: Variant = player.get("stun_remaining", 0)
	if typeof(stun_raw) != TYPE_INT:
		return 0
	var stun: int = stun_raw
	return stun


func player_tick_field(session: TraprushMatchSession, slot: int, key: String) -> int:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return -1
	var raw: Variant = player.get(key, -1)
	if typeof(raw) != TYPE_INT:
		return -1
	var tick: int = raw
	return tick


func player_portal_latched(session: TraprushMatchSession, slot: int) -> bool:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return false
	var latch_raw: Variant = player.get("latch", {})
	if typeof(latch_raw) != TYPE_DICTIONARY:
		return false
	var latch: Dictionary = latch_raw
	return not latch.is_empty()


func player_vy(session: TraprushMatchSession, slot: int) -> int:
	if session._world == null:
		return 0
	var capsule_id: int = player_capsule_id(session, slot)
	if capsule_id < 1:
		return 0
	return session._world.get_vy(capsule_id)


func player_airborne(session: TraprushMatchSession, slot: int) -> bool:
	if session._world == null:
		return false
	var capsule_id: int = player_capsule_id(session, slot)
	if capsule_id < 1:
		return false
	return PlayAnimState.is_airborne(
		player_vy(session, slot),
		session._world.is_supported_by_solid(capsule_id, PlayAnimState.CONTACT_DY)
	)


func destructible_alive_count(session: TraprushMatchSession) -> int:
	var alive: int = 0
	for key: Variant in session._crate_health.keys():
		var crate_raw: Variant = session._crate_health[key]
		if not (crate_raw is TraprushDestructible):
			continue
		var crate: TraprushDestructible = crate_raw
		if not crate.is_destroyed():
			alive += 1
	return alive


func hazard_count(session: TraprushMatchSession) -> int:
	return session._hazard_ids.size()


func is_hazard_solid(session: TraprushMatchSession, entity_id: int) -> bool:
	if session._world == null or not session._hazard_ids.has(entity_id):
		return false
	var box_raw: Variant = session._hazard_ids[entity_id]
	if typeof(box_raw) != TYPE_INT:
		return false
	var box_id: int = box_raw
	return session._world.is_static_box_solid(box_id)


func destructible_states(session: TraprushMatchSession) -> Array[Dictionary]:
	var ids: Array[int] = []
	for key: Variant in session._crate_health.keys():
		if typeof(key) != TYPE_INT:
			continue
		var crate_id: int = key
		ids.append(crate_id)
	ids.sort()
	var states: Array[Dictionary] = []
	for crate_id: int in ids:
		var crate_raw: Variant = session._crate_health[crate_id]
		if not (crate_raw is TraprushDestructible):
			continue
		var crate: TraprushDestructible = crate_raw
		states.append({"entity_id": crate_id, "durability": crate.current_health()})
	return states


func hash_state(session: TraprushMatchSession) -> String:
	var hasher: StateHasher = StateHasher.new()
	if session._world != null:
		hasher.write_string(session._world.hash_state().hex_encode())
	for player: Dictionary in session._players:
		var track: CheckpointTrack = player["track"]
		hasher.write_s64(track.completed_count())
		var finish_tick: int = player["finish_tick"]
		hasher.write_s64(finish_tick)
		var latch: Dictionary = player["latch"]
		var latched: Array[int] = []
		for key: Variant in latch.keys():
			if typeof(key) != TYPE_INT:
				continue
			var entity_id: int = key
			latched.append(entity_id)
		latched.sort()
		hasher.write_s64(latched.size())
		for entity_id: int in latched:
			hasher.write_s64(entity_id)
		var last_shove_tick: int = player.get("last_shove_tick", -1)
		hasher.write_s64(last_shove_tick)
		var last_use_item_tick: int = player.get("last_use_item_tick", -1)
		hasher.write_s64(last_use_item_tick)
		var last_sprint_tick: int = player.get("last_sprint_tick", -1)
		hasher.write_s64(last_sprint_tick)
		var bomb: int = player.get("bomb", 0)
		hasher.write_s64(bomb)
		var dash: int = player.get("dash", 0)
		hasher.write_s64(dash)
		var taken: Dictionary = player.get("taken", {})
		var taken_ids: Array[int] = []
		for taken_key: Variant in taken.keys():
			if typeof(taken_key) != TYPE_INT:
				continue
			var taken_id: int = taken_key
			taken_ids.append(taken_id)
		taken_ids.sort()
		hasher.write_s64(taken_ids.size())
		for taken_id: int in taken_ids:
			hasher.write_s64(taken_id)
		var stun_raw: Variant = player.get("stun_remaining", 0)
		var stun: int = 0
		if typeof(stun_raw) == TYPE_INT:
			stun = stun_raw
		hasher.write_s64(stun)
	return hasher.digest_hex()
