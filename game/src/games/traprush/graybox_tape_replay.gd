class_name TraprushGrayboxTapeReplay
extends RefCounted

## 把 SimReplayBuffer 里的 PLAYER 与 SYSTEM 命令回放到一张刚 assemble 的 GrayboxCourse。
## 依据 CD-43：相同种子与输入必须得到相同关键状态哈希。本夹具走 course API，不让 SimulationWorld 解码意图。
## Move / Jump / ResetToCheckpoint 走 try_step_intent；Interact 走 try_interact；UseItem 走 try_use_item。
## SYSTEM 的 place_pose / accept_checkpoint / land_portal / cross_finish 走对应 course API；land_portal 必须落地。
## 命令 target_tick 大于当前 tick 时用调用方 fall_dy 做 try_commit_tick 追上；结尾再追到 until_tick。
## jump_dy、support_dy、fall_dy、伤害与 reach 均由调用方传入，不从 payload 读取，不锁定 CD-63 数值。
## try_break_crate、出界复位、try_commit_tick 仍不入带；回放靠 target_tick / until_tick 追上 commit。
## Shove 与 BASTION 意图、EDIT / ADMIN、未知 SYSTEM op、已有磁带或非 tick 0 的 course 一律失败。磁带类型本身仍不应用意图。

const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")
const SystemOps := preload("res://src/games/traprush/graybox_system_ops.gd")


static func try_replay(
	course: TraprushGrayboxCourse,
	tape: SimReplayBuffer,
	script: Dictionary
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if course == null or course.world == null or course.tape == null:
		return failed
	if tape == null:
		return failed
	if course.tape.size() != 0:
		return failed
	if course.world.tick_index != 0:
		return failed
	if tape.get_seed() != course.tape.get_seed():
		return failed
	var parsed: Dictionary = _parse_script(script)
	if not _flag(parsed):
		return failed
	var fall_dy: int = _int_at(parsed, "fall_dy")
	var until_tick: int = _int_at(parsed, "until_tick")
	if until_tick < 0:
		return failed
	var count: int = tape.size()
	for index: int in range(count):
		var command: SharedCommand = tape.command_at(index)
		if command == null:
			return failed
		if command.target_tick < 0 or command.target_tick > until_tick:
			return failed
		if not _catch_up(course, command.target_tick, fall_dy):
			return failed
		if not _apply_command(course, command, parsed):
			return failed
	if not _catch_up(course, until_tick, fall_dy):
		return failed
	return {"ok": true}


static func _apply_command(
	course: TraprushGrayboxCourse,
	command: SharedCommand,
	parsed: Dictionary
) -> bool:
	if command.kind == SharedCommand.Kind.PLAYER:
		return _apply_player(course, command, parsed)
	if command.kind == SharedCommand.Kind.SYSTEM:
		return _apply_system(course, command)
	return false


static func _apply_system(course: TraprushGrayboxCourse, command: SharedCommand) -> bool:
	var payload: Dictionary = command.payload
	var op_raw: Variant = payload.get("op", "")
	if typeof(op_raw) != TYPE_STRING:
		return false
	var op_name: String = op_raw
	if op_name == SystemOps.PLACE_POSE:
		var x_read: Dictionary = _require_int(payload, "x")
		var y_read: Dictionary = _require_int(payload, "y")
		var z_read: Dictionary = _require_int(payload, "z")
		var yaw_read: Dictionary = _require_int(payload, "yaw_bam")
		if (
			not _flag(x_read)
			or not _flag(y_read)
			or not _flag(z_read)
			or not _flag(yaw_read)
		):
			return false
		return course.try_place_pose(
			_value(x_read), _value(y_read), _value(z_read), _value(yaw_read)
		)
	if op_name == SystemOps.ACCEPT_CHECKPOINT:
		var id_read: Dictionary = _require_int(payload, "checkpoint_id")
		if not _flag(id_read):
			return false
		return course.try_accept_checkpoint(_value(id_read))
	if op_name == SystemOps.LAND_PORTAL:
		var start_read: Dictionary = _require_int(payload, "start_id")
		var dest_read: Dictionary = _require_int(payload, "dest_checkpoint_id")
		var hops_read: Dictionary = _require_int(payload, "max_hops")
		if not _flag(start_read) or not _flag(dest_read) or not _flag(hops_read):
			return false
		var landed: Dictionary = course.try_land_portal(
			_value(start_read), _value(dest_read), _value(hops_read)
		)
		if not _flag(landed):
			return false
		var did_land: bool = landed.get("landed", false)
		return did_land
	if op_name == SystemOps.CROSS_FINISH:
		var crossed: Dictionary = course.try_cross_finish()
		return _flag(crossed)
	return false


static func _apply_player(
	course: TraprushGrayboxCourse,
	command: SharedCommand,
	parsed: Dictionary
) -> bool:
	var payload: Dictionary = command.payload.duplicate(true)
	var intent_raw: Variant = payload.get("intent", "")
	if typeof(intent_raw) != TYPE_STRING:
		return false
	var intent_name: String = intent_raw
	if (
		intent_name == PlayerIntentNames.MOVE
		or intent_name == PlayerIntentNames.JUMP
		or intent_name == PlayerIntentNames.RESET_TO_CHECKPOINT
	):
		var stepped: Dictionary = course.try_step_intent(
			payload, _int_at(parsed, "jump_dy"), _int_at(parsed, "support_dy")
		)
		return _flag(stepped)
	if intent_name == PlayerIntentNames.INTERACT:
		var interacted: Dictionary = course.try_interact(
			payload, _int_at(parsed, "interact_damage")
		)
		return _flag(interacted)
	if intent_name == PlayerIntentNames.USE_ITEM:
		var used: Dictionary = course.try_use_item(
			payload,
			_int_at(parsed, "use_item_damage"),
			_int_at(parsed, "reach_dx"),
			_int_at(parsed, "reach_dy"),
			_int_at(parsed, "reach_dz")
		)
		return _flag(used)
	return false


static func _catch_up(course: TraprushGrayboxCourse, until_tick: int, fall_dy: int) -> bool:
	if course.world == null:
		return false
	if until_tick < course.world.tick_index:
		return false
	while course.world.tick_index < until_tick:
		if not course.try_commit_tick(fall_dy):
			return false
	return course.world.tick_index == until_tick


static func _parse_script(script: Dictionary) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	var jump_read: Dictionary = _require_int(script, "jump_dy")
	var support_read: Dictionary = _require_int(script, "support_dy")
	var fall_read: Dictionary = _require_int(script, "fall_dy")
	var interact_read: Dictionary = _require_int(script, "interact_damage")
	var use_item_read: Dictionary = _require_int(script, "use_item_damage")
	var reach_x_read: Dictionary = _require_int(script, "reach_dx")
	var reach_y_read: Dictionary = _require_int(script, "reach_dy")
	var reach_z_read: Dictionary = _require_int(script, "reach_dz")
	var until_read: Dictionary = _require_int(script, "until_tick")
	if (
		not _flag(jump_read)
		or not _flag(support_read)
		or not _flag(fall_read)
		or not _flag(interact_read)
		or not _flag(use_item_read)
		or not _flag(reach_x_read)
		or not _flag(reach_y_read)
		or not _flag(reach_z_read)
		or not _flag(until_read)
	):
		return failed
	return {
		"ok": true,
		"jump_dy": _value(jump_read),
		"support_dy": _value(support_read),
		"fall_dy": _value(fall_read),
		"interact_damage": _value(interact_read),
		"use_item_damage": _value(use_item_read),
		"reach_dx": _value(reach_x_read),
		"reach_dy": _value(reach_y_read),
		"reach_dz": _value(reach_z_read),
		"until_tick": _value(until_read),
	}


static func _require_int(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": 0}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_INT:
		return {"ok": false, "value": 0}
	var number: int = raw
	return {"ok": true, "value": number}


static func _int_at(source: Dictionary, key: String) -> int:
	var number: int = source.get(key, 0)
	return number


static func _flag(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


static func _value(result: Dictionary) -> int:
	var number: int = result.get("value", 0)
	return number
