class_name TraprushGravity
extends RefCounted

## 权威竖直积分：调用方重力加速度写入胶囊 vy，再按本拍 vy 做
## try_move_y_until_blocked。完整位移则保留 vy；碰到固体（落地或顶棚）
## 则 vy 归零。Jump 只在调用方已确认接地后 apply_jump：先按冲量位移，
## 未顶棚则把 vy 设成冲量，形成后续各拍的上升/下降弧。
##
## 加速度与冲量由调用方注入，不是产品重力或跳跃高度（CD-63）。
## 默认 0 表示无加速度；vy 仍会按已有速度滑行（零 G 滑行），不要把
## 「accel=0」读成「本拍强制不动」。传送 / 复位 / 出界写回应另行
## set_vy(0)，避免把跳跃速度带进落点。
## 不 tick、不锁 Tick Hz、不发明 coyote。


static func integrate(world: SimulationWorld, entity_id: int, accel: int) -> bool:
	if world == null:
		return false
	var pose: Dictionary = world.get_pose(entity_id)
	if pose.is_empty():
		return false
	var vy: int = world.get_vy(entity_id)
	var next_res: FixedResult = Fixed.try_add(vy, accel)
	if not next_res.ok:
		return false
	var before_y: int = pose.get("y", 0)
	var next_vy: int = next_res.value
	return _move_and_store_vy(world, entity_id, before_y, next_vy)


static func apply_jump(world: SimulationWorld, entity_id: int, impulse: int) -> bool:
	if world == null:
		return false
	var pose: Dictionary = world.get_pose(entity_id)
	if pose.is_empty():
		return false
	var before_y: int = pose.get("y", 0)
	return _move_and_store_vy(world, entity_id, before_y, impulse)


static func _move_and_store_vy(
	world: SimulationWorld,
	entity_id: int,
	before_y: int,
	next_vy: int
) -> bool:
	if not world.try_move_y_until_blocked(entity_id, next_vy):
		return false
	var after: Dictionary = world.get_pose(entity_id)
	var expected: FixedResult = Fixed.try_add(before_y, next_vy)
	if not expected.ok:
		return world.set_vy(entity_id, 0)
	var after_y: int = after.get("y", 0)
	if after_y != expected.value:
		return world.set_vy(entity_id, 0)
	return world.set_vy(entity_id, next_vy)
