class_name TraprushAudioObserve
extends RefCounted

## Diffs a presentation sample of Solo/Preview authority into router events.
## Does not post audio, does not write SimulationWorld, does not enter hash.

const RouterGd := preload("res://src/games/traprush/traprush_audio_router.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")

const KEY_TICK: String = "tick"
const KEY_X: String = "x"
const KEY_Y: String = "y"
const KEY_Z: String = "z"
const KEY_AIR: String = "air"
const KEY_ACCEPTED: String = "accepted"
const KEY_FINISH: String = "finish"
const KEY_BOMB: String = "bomb"
const KEY_DASH: String = "dash"
const KEY_TAKEN: String = "taken"
const KEY_SETBACK: String = "setback"
const KEY_REASON: String = "reason"
const KEY_SHOVE: String = "shove"
const KEY_USE: String = "use"
const KEY_SPRINT: String = "sprint"
const KEY_LATCH: String = "latch"
const KEY_INTENT: String = "intent"
const KEY_HEALTH: String = "health"
const KEY_KINDS: String = "kinds"
const LOOP_EVENT: String = "event"
const LOOP_TAG: String = "tag"
const LOOP_X: String = "x"
const LOOP_Y: String = "y"
const LOOP_Z: String = "z"

var step_stride: int = PlaceholderSpec.MOVE_STEP
var _prev: Dictionary = {}
var _step_accum: int = 0


func reset() -> void:
	_prev = {}
	_step_accum = 0


func collect(sample: Dictionary) -> PackedStringArray:
	var events: PackedStringArray = PackedStringArray()
	if _prev.is_empty():
		_prev = sample.duplicate(true)
		return events
	var prev: Dictionary = _prev
	_append_fail(events, prev, sample)
	_append_reset(events, prev, sample)
	_append_jump_land(events, prev, sample)
	_append_step(events, prev, sample)
	_append_ticks(events, prev, sample)
	_append_progress(events, prev, sample)
	_append_breaks(events, prev, sample)
	_prev = sample.duplicate(true)
	return events


func sample_session(
	session: TraprushMatchSession,
	slot: int,
	intent: String = "",
	kinds: Dictionary = {}
) -> Dictionary:
	var pose: Dictionary = session.player_pose(slot)
	var health: Dictionary = {}
	for row: Dictionary in session.destructible_states():
		var entity_id: int = row.get("entity_id", 0)
		health[entity_id] = row.get("durability", 0)
	return {
		KEY_TICK: session.tick_index(),
		KEY_X: pose.get("x", 0),
		KEY_Y: pose.get("y", 0),
		KEY_Z: pose.get("z", 0),
		KEY_AIR: session.player_airborne(slot),
		KEY_ACCEPTED: session.player_accepted_count(slot),
		KEY_FINISH: session.player_finish_tick(slot),
		KEY_BOMB: session.player_bomb_count(slot),
		KEY_DASH: session.player_dash_count(slot),
		KEY_TAKEN: _taken_count(session, slot),
		KEY_SETBACK: session.player_setback_count(slot),
		KEY_REASON: session.player_setback_reason(slot),
		KEY_SHOVE: _player_int(session, slot, "last_shove_tick", -1),
		KEY_USE: _player_int(session, slot, "last_use_item_tick", -1),
		KEY_SPRINT: _player_int(session, slot, "last_sprint_tick", -1),
		KEY_LATCH: session.player_portal_latched(slot),
		KEY_INTENT: intent,
		KEY_HEALTH: health,
		KEY_KINDS: kinds,
	}


func loops_session(session: TraprushMatchSession) -> Array[Dictionary]:
	if session == null or session._world == null:
		return []
	return loops_from_bags(
		session._world,
		session._conveyor_cycle,
		session._mover_cycle,
		session._flame_cycle,
		session._hazard_cycle,
		session._crusher_cycle,
		session._pendulum_cycle,
		session._gate_cycle,
		session._ice_cycle,
		session._portal_ids
	)


static func loops_from_bags(
	world: SimulationWorld,
	conveyors: Array[Dictionary],
	movers: Array[Dictionary],
	flames: Array[Dictionary],
	hazards: Array[Dictionary],
	crushers: Array[Dictionary],
	pendulums: Array[Dictionary],
	gates: Array[Dictionary],
	ices: Array[Dictionary],
	portals: Dictionary
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_append_cycle(out, world, conveyors, RouterGd.EVENT_LOOP_CONVEYOR)
	_append_cycle(out, world, movers, RouterGd.EVENT_LOOP_MOVER)
	_append_cycle(out, world, flames, RouterGd.EVENT_LOOP_FLAME)
	var flame_ids: Dictionary = _entity_set(flames)
	for item: Dictionary in hazards:
		var entity_id: int = item.get("entity_id", 0)
		if flame_ids.has(entity_id):
			continue
		_append_item(out, world, item, RouterGd.EVENT_LOOP_ROLLER)
	_append_cycle(out, world, crushers, RouterGd.EVENT_LOOP_CRUSHER)
	_append_cycle(out, world, pendulums, RouterGd.EVENT_LOOP_PENDULUM)
	_append_cycle(out, world, gates, RouterGd.EVENT_LOOP_GATE)
	_append_cycle(out, world, ices, RouterGd.EVENT_LOOP_ICE)
	for key: Variant in portals.keys():
		if typeof(key) != TYPE_INT:
			continue
		var box_raw: Variant = portals[key]
		if typeof(box_raw) != TYPE_INT:
			continue
		var box_id: int = box_raw
		var pose: Dictionary = world.static_box_pose(box_id)
		if pose.is_empty():
			continue
		var entity_id: int = key
		out.append({
			LOOP_EVENT: RouterGd.EVENT_LOOP_PORTAL,
			LOOP_TAG: "%s:%d" % [RouterGd.EVENT_LOOP_PORTAL, entity_id],
			LOOP_X: pose.get("x", 0),
			LOOP_Y: pose.get("y", 0),
			LOOP_Z: pose.get("z", 0),
		})
	return out


func _append_fail(events: PackedStringArray, prev: Dictionary, sample: Dictionary) -> void:
	if not _is_failing(prev, sample):
		return
	var fail: String = RouterGd.fail_event(_str_at(sample, KEY_REASON, ""))
	if fail != "":
		events.append(fail)


func _append_reset(events: PackedStringArray, prev: Dictionary, sample: Dictionary) -> void:
	var intent: String = _str_at(sample, KEY_INTENT, "")
	if intent != PlayerIntentNamesGd.RESET_TO_CHECKPOINT:
		return
	if _str_at(prev, KEY_INTENT, "") == intent:
		return
	events.append(RouterGd.EVENT_RESET)


func _append_jump_land(events: PackedStringArray, prev: Dictionary, sample: Dictionary) -> void:
	if _is_failing(prev, sample):
		return
	var was_air: bool = _bool_at(prev, KEY_AIR, false)
	var now_air: bool = _bool_at(sample, KEY_AIR, false)
	if now_air and not was_air:
		events.append(RouterGd.EVENT_JUMP)
	elif was_air and not now_air:
		events.append(RouterGd.EVENT_LAND)


func _append_step(events: PackedStringArray, prev: Dictionary, sample: Dictionary) -> void:
	if _bool_at(sample, KEY_AIR, false):
		return
	if _is_failing(prev, sample):
		return
	var dx: int = _int_at(sample, KEY_X, 0) - _int_at(prev, KEY_X, 0)
	var dz: int = _int_at(sample, KEY_Z, 0) - _int_at(prev, KEY_Z, 0)
	if dx < 0:
		dx = -dx
	if dz < 0:
		dz = -dz
	_step_accum += dx + dz
	if step_stride < 1:
		return
	if _step_accum < step_stride:
		return
	_step_accum = 0
	events.append(RouterGd.EVENT_STEP)


func _append_ticks(events: PackedStringArray, prev: Dictionary, sample: Dictionary) -> void:
	if _int_at(sample, KEY_SHOVE, -1) > _int_at(prev, KEY_SHOVE, -1):
		events.append(RouterGd.EVENT_SHOVE)
	if _int_at(sample, KEY_USE, -1) > _int_at(prev, KEY_USE, -1):
		events.append(RouterGd.EVENT_USE_ITEM)
	if _int_at(sample, KEY_SPRINT, -1) > _int_at(prev, KEY_SPRINT, -1):
		events.append(RouterGd.EVENT_SPRINT)


func _append_progress(events: PackedStringArray, prev: Dictionary, sample: Dictionary) -> void:
	if _int_at(sample, KEY_ACCEPTED, 0) > _int_at(prev, KEY_ACCEPTED, 0):
		events.append(RouterGd.EVENT_CHECKPOINT)
	if _int_at(sample, KEY_FINISH, -1) >= 0 and _int_at(prev, KEY_FINISH, -1) < 0:
		events.append(RouterGd.EVENT_FINISH)
		events.append(RouterGd.EVENT_SETTLED)
	if _int_at(sample, KEY_TAKEN, 0) > _int_at(prev, KEY_TAKEN, 0):
		events.append(RouterGd.EVENT_PICKUP)
	elif _int_at(sample, KEY_BOMB, 0) > _int_at(prev, KEY_BOMB, 0):
		events.append(RouterGd.EVENT_PICKUP)
	elif _int_at(sample, KEY_DASH, 0) > _int_at(prev, KEY_DASH, 0):
		events.append(RouterGd.EVENT_PICKUP)
	if _bool_at(sample, KEY_LATCH, false) and not _bool_at(prev, KEY_LATCH, false):
		events.append(RouterGd.EVENT_PORTAL)


func _append_breaks(events: PackedStringArray, prev: Dictionary, sample: Dictionary) -> void:
	var before: Dictionary = _dict_at(prev, KEY_HEALTH)
	var after: Dictionary = _dict_at(sample, KEY_HEALTH)
	var kinds: Dictionary = _dict_at(sample, KEY_KINDS)
	for key: Variant in before.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		var prev_hp: int = _variant_int(before.get(entity_id, 0), 0)
		var now_hp: int = _variant_int(after.get(entity_id, 0), prev_hp)
		if prev_hp > 0 and now_hp <= 0:
			events.append(RouterGd.break_event(_variant_str(kinds.get(entity_id, ""), "")))


func _is_failing(prev: Dictionary, sample: Dictionary) -> bool:
	if _int_at(sample, KEY_SETBACK, 0) > _int_at(prev, KEY_SETBACK, 0):
		return true
	var reason: String = _str_at(sample, KEY_REASON, "")
	if reason == "":
		return false
	return reason != _str_at(prev, KEY_REASON, "")


func _taken_count(session: TraprushMatchSession, slot: int) -> int:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return 0
	var taken_raw: Variant = player.get("taken", {})
	if typeof(taken_raw) != TYPE_DICTIONARY:
		return 0
	var taken: Dictionary = taken_raw
	return taken.size()


static func kinds_from_bundle(bundle: SimulationBundle) -> Dictionary:
	var kinds: Dictionary = {}
	if bundle == null:
		return kinds
	_mark_kind(kinds, bundle.energy_walls, RouterGd.KIND_WALL)
	_mark_kind(kinds, bundle.rubbles, RouterGd.KIND_RUBBLE)
	_mark_kind(kinds, bundle.obstacle_cores, RouterGd.KIND_CORE)
	return kinds


static func _mark_kind(kinds: Dictionary, bags: Array, kind: String) -> void:
	for item: Dictionary in bags:
		var entity_id: int = item.get("entity_id", 0)
		if entity_id > 0:
			kinds[entity_id] = kind


static func _player_int(
	session: TraprushMatchSession, slot: int, key: String, fallback: int
) -> int:
	var player: Dictionary = session._player_at(slot)
	if player.is_empty():
		return fallback
	return _variant_int(player.get(key, fallback), fallback)


static func _append_cycle(
	out: Array[Dictionary],
	world: SimulationWorld,
	cycle: Array[Dictionary],
	event: String
) -> void:
	for item: Dictionary in cycle:
		_append_item(out, world, item, event)


static func _append_item(
	out: Array[Dictionary],
	world: SimulationWorld,
	item: Dictionary,
	event: String
) -> void:
	var box_raw: Variant = item.get("box_id", 0)
	if typeof(box_raw) != TYPE_INT:
		return
	var box_id: int = box_raw
	var pose: Dictionary = world.static_box_pose(box_id)
	if pose.is_empty():
		return
	var entity_id: int = item.get("entity_id", box_id)
	out.append({
		LOOP_EVENT: event,
		LOOP_TAG: "%s:%d" % [event, entity_id],
		LOOP_X: pose.get("x", 0),
		LOOP_Y: pose.get("y", 0),
		LOOP_Z: pose.get("z", 0),
	})


static func _entity_set(cycle: Array[Dictionary]) -> Dictionary:
	var ids: Dictionary = {}
	for item: Dictionary in cycle:
		var entity_id: int = item.get("entity_id", 0)
		if entity_id > 0:
			ids[entity_id] = true
	return ids


static func _int_at(body: Dictionary, key: String, fallback: int) -> int:
	return _variant_int(body.get(key, fallback), fallback)


static func _variant_int(raw: Variant, fallback: int) -> int:
	if typeof(raw) != TYPE_INT:
		return fallback
	var value: int = raw
	return value


static func _bool_at(body: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = body.get(key, fallback)
	if typeof(raw) != TYPE_BOOL:
		return fallback
	var flag: bool = raw
	return flag


static func _str_at(body: Dictionary, key: String, fallback: String) -> String:
	return _variant_str(body.get(key, fallback), fallback)


static func _variant_str(raw: Variant, fallback: String) -> String:
	if typeof(raw) != TYPE_STRING:
		return fallback
	var value: String = raw
	return value


static func _dict_at(body: Dictionary, key: String) -> Dictionary:
	var raw: Variant = body.get(key, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var value: Dictionary = raw
	return value
