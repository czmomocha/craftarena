class_name TraprushReplayTape
extends RefCounted

## TRAPRUSH command-tape shape for Solo persist and online MatchHost POST.
## Aligns with CD-43 §3 and backend/contracts/src/traprush_replay.ts.
## Character meshes are not in the tape (CD-12).

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const OfficialTraprushCoursesGd := preload("res://src/shared/official_traprush_courses.gd")
const TraprushMatchSettlement := preload("res://src/games/traprush/match_settlement.gd")
const PlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")

const SCHEMA_VERSION: int = 1
const LOCAL_RING: int = 50
const SERVER_RING: int = 100
const MAX_BYTES: int = 524288
const MAX_COMMANDS: int = 24000
const _YAW_OMITTED: int = -1


static func empty_recorder(course_path: String, session: TraprushMatchSession) -> Dictionary:
	if session == null:
		return {}
	var course_id: String = OfficialTraprushCoursesGd.id_from_path(course_path)
	if course_id == "":
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"course_id": course_id,
		"official_path": OfficialTraprushCoursesGd.document_path(course_id),
		"content_hash": session.content_hash,
		"seed": session.match_seed,
		"go_tick": session.go_tick,
		"seats": session.player_count(),
		"commands": [],
	}


static func append_applied(recorder: Dictionary, slot: int, payload: Dictionary, tick: int) -> void:
	if recorder.is_empty():
		return
	var commands_raw: Variant = recorder.get("commands", [])
	if typeof(commands_raw) != TYPE_ARRAY:
		return
	var commands: Array = commands_raw
	if commands.size() >= MAX_COMMANDS:
		return
	var intent_name: String = str(payload.get("intent", ""))
	var intent_id: int = MatchFrameCodec.intent_id_of(intent_name)
	if intent_id < 1:
		return
	var dx: int = 0
	var dz: int = 0
	var yaw_bam: int = 0
	if intent_name == "MoveIntent":
		dx = as_int(payload.get("dx", 0), 0)
		dz = as_int(payload.get("dz", 0), 0)
		yaw_bam = as_int(payload.get("yaw_bam", _YAW_OMITTED), _YAW_OMITTED)
	commands.append({
		"tick": tick,
		"slot": slot,
		"intent_id": intent_id,
		"dx": dx,
		"dz": dz,
		"yaw_bam": yaw_bam,
	})


static func finalize(recorder: Dictionary, session: TraprushMatchSession) -> Dictionary:
	if recorder.is_empty() or session == null:
		return {}
	if not TraprushMatchSettlement.all_finished(session):
		return {}
	var finish_ticks: Array = []
	var go_tick: int = as_int(recorder.get("go_tick", 0), 0)
	for slot: int in range(session.player_count()):
		var world_finish: int = session.player_finish_tick(slot)
		if world_finish < 0:
			return {}
		finish_ticks.append(PlayStubsGd.racing_tick(world_finish, go_tick))
	var tape: Dictionary = recorder.duplicate(true)
	tape["finish_ticks"] = finish_ticks
	if not parse(tape).get("ok", false):
		return {}
	var encoded: String = JSON.stringify(tape)
	if encoded.to_utf8_buffer().size() > MAX_BYTES:
		return {}
	return tape


static func parse(raw: Dictionary) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if as_int(raw.get("schema_version", 0), 0) != SCHEMA_VERSION:
		return failed
	var course_id: String = str(raw.get("course_id", ""))
	var official_path: String = str(raw.get("official_path", ""))
	var content_hash: String = str(raw.get("content_hash", ""))
	if not OfficialTraprushCoursesGd.is_id(course_id):
		return failed
	if official_path != OfficialTraprushCoursesGd.document_path(course_id):
		return failed
	if content_hash.length() != 64:
		return failed
	var seed: int = as_int(raw.get("seed", 0), 0)
	var go_tick: int = as_int(raw.get("go_tick", -1), -1)
	var seats: int = as_int(raw.get("seats", 0), 0)
	if go_tick < 0 or seats < 1 or seats > 8:
		return failed
	var commands_raw: Variant = raw.get("commands", null)
	if typeof(commands_raw) != TYPE_ARRAY:
		return failed
	var commands: Array = []
	var listed: Array = commands_raw
	if listed.size() > MAX_COMMANDS:
		return failed
	for item: Variant in listed:
		if typeof(item) != TYPE_DICTIONARY:
			return failed
		var row: Dictionary = item
		var tick: int = as_int(row.get("tick", -1), -1)
		var slot: int = as_int(row.get("slot", -1), -1)
		var intent_id: int = as_int(row.get("intent_id", 0), 0)
		if tick < 0 or slot < 0 or slot >= seats:
			return failed
		if MatchFrameCodec.intent_name_of(intent_id) == "":
			return failed
		commands.append({
			"tick": tick,
			"slot": slot,
			"intent_id": intent_id,
			"dx": as_int(row.get("dx", 0), 0),
			"dz": as_int(row.get("dz", 0), 0),
			"yaw_bam": as_int(row.get("yaw_bam", 0), 0),
		})
	var finish_raw: Variant = raw.get("finish_ticks", null)
	if typeof(finish_raw) != TYPE_ARRAY:
		return failed
	var finish_ticks: Array = []
	for item: Variant in finish_raw:
		if typeof(item) != TYPE_INT and typeof(item) != TYPE_FLOAT:
			return failed
		var value: int = as_int(item, -1)
		if value < 0:
			return failed
		finish_ticks.append(value)
	if finish_ticks.size() != seats:
		return failed
	return {
		"ok": true,
		"schema_version": SCHEMA_VERSION,
		"course_id": course_id,
		"official_path": official_path,
		"content_hash": content_hash,
		"seed": seed,
		"go_tick": go_tick,
		"seats": seats,
		"commands": commands,
		"finish_ticks": finish_ticks,
	}


static func payload_from_command(command: Dictionary) -> Dictionary:
	var intent_id: int = as_int(command.get("intent_id", 0), 0)
	var intent_name: String = MatchFrameCodec.intent_name_of(intent_id)
	if intent_name == "":
		return {}
	if intent_name != "MoveIntent":
		return {"intent": intent_name}
	var payload: Dictionary = {
		"intent": intent_name,
		"dx": as_int(command.get("dx", 0), 0),
		"dz": as_int(command.get("dz", 0), 0),
	}
	var yaw_bam: int = as_int(command.get("yaw_bam", _YAW_OMITTED), _YAW_OMITTED)
	if yaw_bam != _YAW_OMITTED:
		payload["yaw_bam"] = yaw_bam
	return payload


static func as_int(raw: Variant, fallback: int) -> int:
	if typeof(raw) == TYPE_INT:
		var value: int = raw
		return value
	if typeof(raw) == TYPE_FLOAT:
		var number: float = raw
		if number != floor(number):
			return fallback
		return int(number)
	return fallback
