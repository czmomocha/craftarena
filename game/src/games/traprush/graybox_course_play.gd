class_name TraprushGrayboxPlay
extends RefCounted

## Intent and occupancy verbs for TraprushGrayboxCourse.
## Public API stays on the course facade so this file can stay under E9.

const FinishAccept := preload("res://src/games/traprush/finish_accept.gd")
const Gravity := preload("res://src/games/traprush/gravity.gd")
const IntentStepper := preload("res://src/games/traprush/intent_stepper.gd")
const InteractIntent := preload("res://src/games/traprush/interact_intent.gd")
const LayoutGd := preload("res://src/games/traprush/graybox_course_layout.gd")
const PadAccept := preload("res://src/games/traprush/pad_accept.gd")
const PortalLanding := preload("res://src/games/traprush/portal_landing.gd")
const ShoveApply := preload("res://src/games/traprush/shove_apply.gd")
const SystemOps := preload("res://src/games/traprush/graybox_system_ops.gd")
const UseItemIntent := preload("res://src/games/traprush/use_item_intent.gd")


static func try_step_intent(course: TraprushGrayboxCourse, payload: Dictionary, jump_dy: int, support_dy: int) -> Dictionary:
	var result: Dictionary = IntentStepper.apply(
		course.world, course.entity_id, payload, jump_dy, course._spawn, course.track, support_dy
	)
	if not LayoutGd._flag(result):
		return result
	course._append_command(payload, SharedCommand.Kind.PLAYER)
	return result


static func try_shove(course: TraprushGrayboxCourse, payload: Dictionary, cooldown_ticks: int, dx: int, dz: int) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if course.world == null or course.shove_target_id < 1:
		return failed
	var result: Dictionary = ShoveApply.apply(
		course.world,
		course.entity_id,
		course.shove_target_id,
		payload,
		course.world.tick_index,
		course._last_shove_tick,
		cooldown_ticks,
		dx,
		dz
	)
	if not LayoutGd._flag(result):
		return result
	var shoved: bool = result.get("shoved", false)
	if shoved:
		course._last_shove_tick = course.world.tick_index
	course._append_command(payload, SharedCommand.Kind.PLAYER)
	return result


static func try_apply_fall(course: TraprushGrayboxCourse, fall_dy: int) -> bool:
	if not _move_y_until_blocked(course, fall_dy):
		return false
	course._append_command({"op": SystemOps.APPLY_FALL, "fall_dy": fall_dy}, SharedCommand.Kind.SYSTEM)
	return true


static func _move_y_until_blocked(course: TraprushGrayboxCourse, fall_dy: int) -> bool:
	if course.world == null:
		return false
	return course.world.try_move_y_until_blocked(course.entity_id, fall_dy)


static func try_reset_if_out_of_range(course: TraprushGrayboxCourse,
	min_y: int,
	max_y: int,
	min_x: int,
	max_x: int,
	min_z: int,
	max_z: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if course.world == null:
		return failed
	var current: Dictionary = course.world.get_pose(course.entity_id)
	if current.is_empty():
		return failed
	var below: bool = course.world.is_below_min_y(course.entity_id, min_y)
	var above: bool = course.world.is_above_max_y(course.entity_id, max_y)
	var outside_xz: bool = course.world.is_outside_xz(course.entity_id, min_x, max_x, min_z, max_z)
	if not below and not above and not outside_xz:
		return {"ok": true, "reset": false}
	if course._spawn == null:
		return failed
	var pose: Dictionary = course._spawn.pose_for(course.track)
	var pose_ok: bool = pose.get("ok", false)
	if not pose_ok:
		return failed
	var x: int = pose.get("x", 0)
	var y: int = pose.get("y", 0)
	var z: int = pose.get("z", 0)
	var yaw_bam: int = pose.get("yaw_bam", 0)
	if not course.world.set_pose(course.entity_id, x, y, z, yaw_bam):
		return failed
	course.world.set_vy(course.entity_id, 0)
	course._append_command(
		{
			"op": SystemOps.RESET_IF_OUT_OF_RANGE,
			"min_y": min_y,
			"max_y": max_y,
			"min_x": min_x,
			"max_x": max_x,
			"min_z": min_z,
			"max_z": max_z,
		},
		SharedCommand.Kind.SYSTEM
	)
	return {"ok": true, "reset": true}


static func try_interact(course: TraprushGrayboxCourse, payload: Dictionary, damage: int) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	var decoded: Dictionary = InteractIntent.decode(payload)
	if not LayoutGd._flag(decoded):
		return failed
	var overlapping: PackedInt32Array = course.world.overlapping_static_boxes(course.entity_id)
	var crate_in_reach: bool = false
	for index: int in range(overlapping.size()):
		if overlapping[index] == course.crate_box_id:
			crate_in_reach = true
			break
	if not crate_in_reach:
		return failed
	var result: Dictionary = course.crate.apply_damage(damage)
	if not LayoutGd._flag(result):
		return result
	var destroyed: bool = result.get("destroyed", false)
	if destroyed:
		course.world.set_static_box_solid(course.crate_box_id, false)
	course._append_command(payload, SharedCommand.Kind.PLAYER)
	return result


static func try_use_item(course: TraprushGrayboxCourse,
	payload: Dictionary,
	damage: int,
	reach_dx: int,
	reach_dy: int,
	reach_dz: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	var decoded: Dictionary = UseItemIntent.decode(payload)
	if not LayoutGd._flag(decoded):
		return failed
	var pose: Dictionary = course.world.get_pose(course.entity_id)
	if pose.is_empty():
		return failed
	var pose_x: int = pose.get("x", 0)
	var pose_y: int = pose.get("y", 0)
	var pose_z: int = pose.get("z", 0)
	var cand_x_res: FixedResult = Fixed.try_add(pose_x, reach_dx)
	if not cand_x_res.ok:
		return failed
	var cand_y_res: FixedResult = Fixed.try_add(pose_y, reach_dy)
	if not cand_y_res.ok:
		return failed
	var cand_z_res: FixedResult = Fixed.try_add(pose_z, reach_dz)
	if not cand_z_res.ok:
		return failed
	var overlapping: PackedInt32Array = course.world.overlapping_static_boxes_at(
		course.entity_id, cand_x_res.value, cand_y_res.value, cand_z_res.value
	)
	var crate_in_reach: bool = false
	for index: int in range(overlapping.size()):
		if overlapping[index] == course.crate_box_id:
			crate_in_reach = true
			break
	if not crate_in_reach:
		return failed
	var result: Dictionary = course.crate.apply_damage(damage)
	if not LayoutGd._flag(result):
		return result
	var destroyed: bool = result.get("destroyed", false)
	if destroyed:
		course.world.set_static_box_solid(course.crate_box_id, false)
	course._append_command(payload, SharedCommand.Kind.PLAYER)
	return result


static func try_commit_tick(course: TraprushGrayboxCourse, fall_dy: int) -> bool:
	if course.world == null or course.snapshots == null:
		return false
	if not Gravity.integrate(course.world, course.entity_id, fall_dy):
		return false
	course.world.tick()
	var solid: bool = ((course.world.tick_index / course._hazard_period_ticks) % 2) == 0
	if not course.world.set_static_box_solid(course.hazard_box_id, solid):
		return false
	if not course.snapshots.record(course.world):
		return false
	course._append_command({"op": SystemOps.COMMIT_TICK, "fall_dy": fall_dy}, SharedCommand.Kind.SYSTEM)
	return true


static func try_break_crate(course: TraprushGrayboxCourse, damage: int) -> Dictionary:
	if course.crate == null or course.world == null:
		return {"ok": false}
	var result: Dictionary = course.crate.apply_damage(damage)
	if not LayoutGd._flag(result):
		return result
	var destroyed: bool = result.get("destroyed", false)
	if destroyed:
		course.world.set_static_box_solid(course.crate_box_id, false)
	course._append_command({"op": SystemOps.BREAK_CRATE, "damage": damage}, SharedCommand.Kind.SYSTEM)
	return result


static func try_place_pose(course: TraprushGrayboxCourse, x: int, y: int, z: int, yaw_bam: int) -> bool:
	if course.world == null:
		return false
	if not course.world.set_pose(course.entity_id, x, y, z, yaw_bam):
		return false
	course.world.set_vy(course.entity_id, 0)
	course._append_command(
		{
			"op": SystemOps.PLACE_POSE,
			"x": x,
			"y": y,
			"z": z,
			"yaw_bam": yaw_bam,
		},
		SharedCommand.Kind.SYSTEM
	)
	return true


static func try_land_portal(course: TraprushGrayboxCourse, start_id: int, dest_checkpoint_id: int, max_hops: int) -> Dictionary:
	if not course.track.can_use_portal(dest_checkpoint_id):
		return {"ok": false}
	var landed: Dictionary = PortalLanding.try_land(
		course.world, course.entity_id, course._graph, start_id, max_hops
	)
	if not LayoutGd._flag(landed):
		return landed
	var did_land: bool = landed.get("landed", false)
	if did_land:
		course._append_command(
			{
				"op": SystemOps.LAND_PORTAL,
				"start_id": start_id,
				"dest_checkpoint_id": dest_checkpoint_id,
				"max_hops": max_hops,
			},
			SharedCommand.Kind.SYSTEM
		)
	return landed


static func try_accept_checkpoint(course: TraprushGrayboxCourse, checkpoint_id: int) -> bool:
	var pad_index: int = -1
	for index: int in range(course._checkpoint_ids.size()):
		if course._checkpoint_ids[index] == checkpoint_id:
			pad_index = index
			break
	if pad_index < 0 or pad_index >= course.pad_box_ids.size():
		return false
	if not PadAccept.try_accept_on_pad(
		course.world, course.entity_id, course.track, checkpoint_id, course.pad_box_ids[pad_index]
	):
		return false
	course._append_command(
		{"op": SystemOps.ACCEPT_CHECKPOINT, "checkpoint_id": checkpoint_id},
		SharedCommand.Kind.SYSTEM
	)
	return true


static func try_cross_finish(course: TraprushGrayboxCourse) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if course.finish_tick != -1:
		return {"ok": true, "finish_tick": course.finish_tick}
	var crossed: Dictionary = FinishAccept.try_cross(course.world, course.entity_id, course.track, course.finish_box_id)
	if not LayoutGd._flag(crossed):
		return failed
	course.finish_tick = course.world.tick_index
	course._append_command({"op": SystemOps.CROSS_FINISH}, SharedCommand.Kind.SYSTEM)
	return {"ok": true, "finish_tick": course.finish_tick}

