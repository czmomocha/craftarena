class_name MatchOfflineReplay
extends RefCounted

## Solo tape record / read-only replay helpers so MatchOfflineSession stays under E9.

const TapeGd := preload("res://src/games/traprush/replay_tape.gd")
const StoreGd := preload("res://src/client/traprush_replay_store.gd")
const ContentSignGd := preload("res://src/ugc/content_sign.gd")
const TraprushMatchSettlement := preload("res://src/games/traprush/match_settlement.gd")


static func start_recorder(host: MatchOfflineSession) -> void:
	if not host.persist_replay or host.session == null:
		host.tape_recorder = {}
		return
	host.tape_recorder = TapeGd.empty_recorder(host.course_path, host.session)


static func note_applied(host: MatchOfflineSession, payload: Dictionary) -> void:
	if host.session == null:
		return
	TapeGd.append_applied(host.tape_recorder, 0, payload, host.session.tick_index())


static func maybe_save(host: MatchOfflineSession, store: StoreGd) -> void:
	if host.replay_saved or not host.persist_replay or host.session == null:
		return
	var tape: Dictionary = TapeGd.finalize(host.tape_recorder, host.session)
	if tape.is_empty():
		return
	if store.append_tape(tape):
		host.replay_saved = true


static func load_tape(raw: Dictionary) -> Dictionary:
	return TapeGd.parse(raw)


static func hash_ok(bundle: SimulationBundle, expected: String) -> bool:
	if bundle == null or expected == "":
		return false
	return ContentSignGd.hash_hex(bundle) == expected


static func apply_tick_commands(host: MatchOfflineSession) -> void:
	if host.session == null:
		return
	var tick: int = host.session.tick_index()
	for item: Variant in host.replay_commands:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var command: Dictionary = item
		if TapeGd.as_int(command.get("tick", -1), -1) != tick:
			continue
		var payload: Dictionary = TapeGd.payload_from_command(command)
		if payload.is_empty():
			continue
		var slot: int = TapeGd.as_int(command.get("slot", 0), 0)
		host.session.apply_player_intent(slot, payload)


static func finished(host: MatchOfflineSession) -> bool:
	return TraprushMatchSettlement.all_finished(host.session)
