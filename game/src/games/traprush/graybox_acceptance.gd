class_name TraprushGrayboxAcceptance
extends RefCounted

## TRAPRUSH 单人灰盒整段可回放夹具：一张脚本跑完 CD-61 §4.1 里属于 M1 的件。
## 覆盖：3 个有序检查点、向上传送、侧向传送、周期 hazard 窗口、可破坏箱、UseItem 爆破、危险捷径开路、冲线。
## 不覆盖 2p Headless 与单局名次（M3）。不含推击（灰盒推击走独立 try_shove 夹具）。不锁定 Tick/重力/伤害/掉出次数 N（CD-63）。不改 hash_state 字段集。
## 安全路 = 调用方 commit 后 hazard 非 solid 的 +x 窗口；危险捷径 = 爆破后 crate 非 solid 的 +z 开路。
## 检查点 / 传送 / 冲线仍走占用判定：脚本用 try_place_pose 放到垫上，不发明寻路。PLAYER 与 SYSTEM（含 commit_tick）记录可由 TraprushGrayboxTapeReplay 回放整段。
## jump_dy、support_dy、fall_dy、blast_damage、reach、max_hops、位移 payload 与垫姿态均由调用方传入。

const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const FixedResultClass := preload("res://src/shared/fixed/fixed_result.gd")


static func try_run(course: TraprushGrayboxCourse, script: Dictionary) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if course == null or course.world == null:
		return failed
	var parsed: Dictionary = _parse_script(script)
	if not _flag(parsed):
		return failed
	var jump_dy: int = _int_at(parsed, "jump_dy")
	var support_dy: int = _int_at(parsed, "support_dy")
	var fall_dy: int = _int_at(parsed, "fall_dy")
	var blast_damage: int = _int_at(parsed, "blast_damage")
	var reach_dx: int = _int_at(parsed, "reach_dx")
	var reach_dy: int = _int_at(parsed, "reach_dy")
	var reach_dz: int = _int_at(parsed, "reach_dz")
	var max_hops: int = _int_at(parsed, "max_hops")
	var up_portal_id: int = _int_at(parsed, "up_portal_id")
	var side_portal_id: int = _int_at(parsed, "side_portal_id")
	var checkpoint_a: int = _int_at(parsed, "checkpoint_a")
	var checkpoint_b: int = _int_at(parsed, "checkpoint_b")
	var checkpoint_c: int = _int_at(parsed, "checkpoint_c")
	var crate_dx: int = _int_at(parsed, "crate_dx")
	var crate_dz: int = _int_at(parsed, "crate_dz")
	var hazard_dx: int = _int_at(parsed, "hazard_dx")
	var hazard_dz: int = _int_at(parsed, "hazard_dz")
	var start_pose: Dictionary = _dict_at(parsed, "start_pose")
	var finish_pose: Dictionary = _dict_at(parsed, "finish_pose")
	var wall_move: Dictionary = _dict_at(parsed, "wall_move")
	var crate_move: Dictionary = _dict_at(parsed, "crate_move")
	var hazard_move: Dictionary = _dict_at(parsed, "hazard_move")
	var use_item: Dictionary = _dict_at(parsed, "use_item")
	if not _place(course, start_pose):
		return failed
	if not _step_ok(course, wall_move, jump_dy, support_dy):
		return failed
	if not _place(course, start_pose):
		return failed
	if not _step_ok(course, crate_move, jump_dy, support_dy):
		return failed
	if not course.world.is_static_box_solid(course.crate_box_id):
		return failed
	if _at_translated(course, start_pose, crate_dx, crate_dz):
		return failed
	if not _place(course, start_pose):
		return failed
	var blasted: Dictionary = course.try_use_item(
		use_item, blast_damage, reach_dx, reach_dy, reach_dz
	)
	if not _flag(blasted):
		return failed
	var destroyed: bool = blasted.get("destroyed", false)
	if not destroyed:
		return failed
	if course.world.is_static_box_solid(course.crate_box_id):
		return failed
	if not _place(course, start_pose):
		return failed
	if not _step_ok(course, crate_move, jump_dy, support_dy):
		return failed
	if not _at_translated(course, start_pose, crate_dx, crate_dz):
		return failed
	if not _place(course, start_pose):
		return failed
	if not _step_ok(course, hazard_move, jump_dy, support_dy):
		return failed
	if not course.world.is_static_box_solid(course.hazard_box_id):
		return failed
	if _at_translated(course, start_pose, hazard_dx, hazard_dz):
		return failed
	if not _place(course, start_pose):
		return failed
	if not course.try_commit_tick(fall_dy):
		return failed
	if course.world.is_static_box_solid(course.hazard_box_id):
		return failed
	if not _place(course, start_pose):
		return failed
	if not _step_ok(course, hazard_move, jump_dy, support_dy):
		return failed
	if not _at_translated(course, start_pose, hazard_dx, hazard_dz):
		return failed
	if not _place(course, start_pose):
		return failed
	if not course.try_accept_checkpoint(checkpoint_a):
		return failed
	var up_land: Dictionary = course.try_land_portal(up_portal_id, checkpoint_b, max_hops)
	if not _flag(up_land):
		return failed
	var up_landed: bool = up_land.get("landed", false)
	if not up_landed:
		return failed
	if not course.try_accept_checkpoint(checkpoint_b):
		return failed
	var side_land: Dictionary = course.try_land_portal(
		side_portal_id, checkpoint_c, max_hops
	)
	if not _flag(side_land):
		return failed
	var side_landed: bool = side_land.get("landed", false)
	if not side_landed:
		return failed
	if not course.try_accept_checkpoint(checkpoint_c):
		return failed
	if course.track == null or not course.track.is_finished():
		return failed
	if not _place(course, finish_pose):
		return failed
	var crossed: Dictionary = course.try_cross_finish()
	if not _flag(crossed):
		return failed
	var finish_tick: int = crossed.get("finish_tick", -1)
	if finish_tick < 0:
		return failed
	return {"ok": true, "finish_tick": finish_tick}


static func _parse_script(script: Dictionary) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	var jump_read: Dictionary = _require_int(script, "jump_dy")
	var support_read: Dictionary = _require_int(script, "support_dy")
	var fall_read: Dictionary = _require_int(script, "fall_dy")
	var blast_read: Dictionary = _require_int(script, "blast_damage")
	var reach_x_read: Dictionary = _require_int(script, "reach_dx")
	var reach_y_read: Dictionary = _require_int(script, "reach_dy")
	var reach_z_read: Dictionary = _require_int(script, "reach_dz")
	var hops_read: Dictionary = _require_int(script, "max_hops")
	var up_read: Dictionary = _require_int(script, "up_portal_id")
	var side_read: Dictionary = _require_int(script, "side_portal_id")
	var a_read: Dictionary = _require_int(script, "checkpoint_a")
	var b_read: Dictionary = _require_int(script, "checkpoint_b")
	var c_read: Dictionary = _require_int(script, "checkpoint_c")
	var start_read: Dictionary = _require_pose(script, "start_pose")
	var finish_read: Dictionary = _require_pose(script, "finish_pose")
	var wall_read: Dictionary = _require_move_payload(script, "wall_move")
	var crate_read: Dictionary = _require_move_payload(script, "crate_move")
	var hazard_read: Dictionary = _require_move_payload(script, "hazard_move")
	var item_read: Dictionary = _require_nested(script, "use_item")
	if (
		not _flag(jump_read)
		or not _flag(support_read)
		or not _flag(fall_read)
		or not _flag(blast_read)
		or not _flag(reach_x_read)
		or not _flag(reach_y_read)
		or not _flag(reach_z_read)
		or not _flag(hops_read)
		or not _flag(up_read)
		or not _flag(side_read)
		or not _flag(a_read)
		or not _flag(b_read)
		or not _flag(c_read)
		or not _flag(start_read)
		or not _flag(finish_read)
		or not _flag(wall_read)
		or not _flag(crate_read)
		or not _flag(hazard_read)
		or not _flag(item_read)
	):
		return failed
	return {
		"ok": true,
		"jump_dy": _value(jump_read),
		"support_dy": _value(support_read),
		"fall_dy": _value(fall_read),
		"blast_damage": _value(blast_read),
		"reach_dx": _value(reach_x_read),
		"reach_dy": _value(reach_y_read),
		"reach_dz": _value(reach_z_read),
		"max_hops": _value(hops_read),
		"up_portal_id": _value(up_read),
		"side_portal_id": _value(side_read),
		"checkpoint_a": _value(a_read),
		"checkpoint_b": _value(b_read),
		"checkpoint_c": _value(c_read),
		"crate_dx": _int_at(crate_read, "dx"),
		"crate_dz": _int_at(crate_read, "dz"),
		"hazard_dx": _int_at(hazard_read, "dx"),
		"hazard_dz": _int_at(hazard_read, "dz"),
		"start_pose": _dict_at(start_read, "pose"),
		"finish_pose": _dict_at(finish_read, "pose"),
		"wall_move": _dict_at(wall_read, "payload"),
		"crate_move": _dict_at(crate_read, "payload"),
		"hazard_move": _dict_at(hazard_read, "payload"),
		"use_item": _dict_at(item_read, "value"),
	}


static func _require_move_payload(source: Dictionary, key: String) -> Dictionary:
	var nested_read: Dictionary = _require_nested(source, key)
	if not _flag(nested_read):
		return {"ok": false}
	var payload: Dictionary = nested_read["value"]
	var dx_read: Dictionary = _require_int(payload, "dx")
	var dz_read: Dictionary = _require_int(payload, "dz")
	if not _flag(dx_read) or not _flag(dz_read):
		return {"ok": false}
	return {
		"ok": true,
		"dx": _value(dx_read),
		"dz": _value(dz_read),
		"payload": payload.duplicate(true),
	}


static func _require_pose(source: Dictionary, key: String) -> Dictionary:
	var nested_read: Dictionary = _require_nested(source, key)
	if not _flag(nested_read):
		return {"ok": false}
	var pose_source: Dictionary = nested_read["value"]
	var x_read: Dictionary = _require_int(pose_source, "x")
	var y_read: Dictionary = _require_int(pose_source, "y")
	var z_read: Dictionary = _require_int(pose_source, "z")
	var yaw_read: Dictionary = _require_int(pose_source, "yaw_bam")
	if not _flag(x_read) or not _flag(y_read) or not _flag(z_read) or not _flag(yaw_read):
		return {"ok": false}
	return {
		"ok": true,
		"pose": {
			"x": _value(x_read),
			"y": _value(y_read),
			"z": _value(z_read),
			"yaw_bam": _value(yaw_read),
		},
	}


static func _require_nested(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": {}}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "value": {}}
	var nested: Dictionary = raw
	return {"ok": true, "value": nested}


static func _require_int(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {"ok": false, "value": 0}
	var raw: Variant = source[key]
	if typeof(raw) != TYPE_INT:
		return {"ok": false, "value": 0}
	var number: int = raw
	return {"ok": true, "value": number}


static func _place(course: TraprushGrayboxCourse, pose: Dictionary) -> bool:
	if course.world == null:
		return false
	var x: int = _int_at(pose, "x")
	var y: int = _int_at(pose, "y")
	var z: int = _int_at(pose, "z")
	var yaw_bam: int = _int_at(pose, "yaw_bam")
	return course.try_place_pose(x, y, z, yaw_bam)


static func _step_ok(
	course: TraprushGrayboxCourse,
	payload: Dictionary,
	jump_dy: int,
	support_dy: int
) -> bool:
	var result: Dictionary = course.try_step_intent(payload, jump_dy, support_dy)
	return _flag(result)


static func _at_translated(
	course: TraprushGrayboxCourse,
	start_pose: Dictionary,
	dx: int,
	dz: int
) -> bool:
	if course.world == null:
		return false
	var x_res: FixedResultClass = FixedClass.try_add(_int_at(start_pose, "x"), dx)
	var z_res: FixedResultClass = FixedClass.try_add(_int_at(start_pose, "z"), dz)
	if not x_res.ok or not z_res.ok:
		return false
	var current: Dictionary = course.world.get_pose(course.entity_id)
	if current.is_empty():
		return false
	var cur_x: int = current.get("x", -1)
	var cur_y: int = current.get("y", -1)
	var cur_z: int = current.get("z", -1)
	var cur_yaw: int = current.get("yaw", -1)
	return (
		cur_x == x_res.value
		and cur_y == _int_at(start_pose, "y")
		and cur_z == z_res.value
		and cur_yaw == _int_at(start_pose, "yaw_bam")
	)


static func _dict_at(source: Dictionary, key: String) -> Dictionary:
	var raw: Variant = source.get(key, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var nested: Dictionary = raw
	return nested


static func _int_at(source: Dictionary, key: String) -> int:
	var number: int = source.get(key, 0)
	return number


static func _flag(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


static func _value(result: Dictionary) -> int:
	var number: int = result.get("value", 0)
	return number
