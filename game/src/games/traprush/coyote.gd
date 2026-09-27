class_name TraprushCoyote
extends RefCounted

## 土狼窗口：离开支撑后 N tick 内仍可起跳；支撑上重置；起跳成功后消费。
## 计数由调用方在每个世界 tick 观察支撑后写入，不进快照帧、不进 hash_state。
## N 只从 TraprushPlayStubs.COYOTE_TICKS 注入，这里不发明默认值。


static func can_jump(
	supported: bool,
	now_tick: int,
	last_supported_tick: int,
	consumed: bool,
	coyote_ticks: int
) -> bool:
	if supported:
		return true
	if consumed:
		return false
	if last_supported_tick < 0:
		return false
	if coyote_ticks < 1:
		return false
	var age: int = now_tick - last_supported_tick
	if age < 0:
		return false
	return age <= coyote_ticks


static func observe(
	supported: bool,
	now_tick: int,
	last_supported_tick: int,
	consumed: bool
) -> Dictionary:
	if supported:
		return {"last_supported_tick": now_tick, "consumed": false}
	return {"last_supported_tick": last_supported_tick, "consumed": consumed}


static func observe_world(
	world: SimulationWorld,
	entity_id: int,
	support_dy: int,
	now_tick: int,
	last_supported_tick: int,
	consumed: bool
) -> Dictionary:
	if world == null:
		return {"last_supported_tick": last_supported_tick, "consumed": consumed}
	var supported: bool = world.is_supported_by_solid(entity_id, support_dy)
	return observe(supported, now_tick, last_supported_tick, consumed)
