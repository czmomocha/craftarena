class_name TraprushDestructibleBreak
extends RefCounted

## UseItem occupancy break: damage a compiled destructible only when the
## caller reach pose overlaps its box. Payload is the existing UseItemIntent
## name. Damage and reach are caller-supplied (CD-63). Destroyed boxes
## become non-solid. No inventory, no item table, no regen. Never settlement.

const UseItemIntent := preload("res://src/games/traprush/use_item_intent.gd")


static func try_use_item(
	world: SimulationWorld,
	entity_id: int,
	payload: Dictionary,
	crate: TraprushDestructible,
	box_id: int,
	damage: int,
	reach_dx: int,
	reach_dy: int,
	reach_dz: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null:
		return failed
	if crate == null:
		return failed
	var decoded: Dictionary = UseItemIntent.decode(payload)
	var decoded_ok: bool = decoded.get("ok", false)
	if not decoded_ok:
		return failed
	if crate.is_destroyed():
		return failed
	var pose: Dictionary = world.get_pose(entity_id)
	if pose.is_empty():
		return failed
	var pose_x: int = pose.get("x", 0)
	var pose_y: int = pose.get("y", 0)
	var pose_z: int = pose.get("z", 0)
	var cand_x: FixedResult = Fixed.try_add(pose_x, reach_dx)
	if not cand_x.ok:
		return failed
	var cand_y: FixedResult = Fixed.try_add(pose_y, reach_dy)
	if not cand_y.ok:
		return failed
	var cand_z: FixedResult = Fixed.try_add(pose_z, reach_dz)
	if not cand_z.ok:
		return failed
	if not world.overlaps_static_box_at(
		entity_id, box_id, cand_x.value, cand_y.value, cand_z.value
	):
		return failed
	var result: Dictionary = crate.apply_damage(damage)
	var result_ok: bool = result.get("ok", false)
	if not result_ok:
		return result
	var destroyed: bool = result.get("destroyed", false)
	if destroyed:
		if not world.set_static_box_solid(box_id, false):
			return failed
	return result
