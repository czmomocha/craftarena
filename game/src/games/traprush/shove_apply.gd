class_name TraprushShoveApply
extends RefCounted

## 把已解码的 ShoveIntent 接到 SimulationWorld：门闩通过后对目标施加调用方 Q48.16 dx/dz。
## 依据 CD-21 §2 / §5.3：所有玩家拥有独立于道具的基础推击；力度与冷却秒数见 CD-63，本刀不锁定。
## dx/dz 只来自参数，不从 payload 读取 impulse/dx/dz，不发明默认位移。不调用 world.tick()。

const ShoveIntent := preload("res://src/games/traprush/shove_intent.gd")
const ShoveGate := preload("res://src/games/traprush/shove_gate.gd")


static func apply(
	world: SimulationWorld,
	actor_id: int,
	target_id: int,
	payload: Dictionary,
	now_tick: int,
	last_shove_tick: int,
	cooldown_ticks: int,
	dx: int,
	dz: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null:
		return failed
	var decoded: Dictionary = ShoveIntent.decode(payload)
	var decode_ok: bool = decoded.get("ok", false)
	if not decode_ok:
		return failed
	if actor_id == target_id:
		return failed
	var actor_pose: Dictionary = world.get_pose(actor_id)
	if actor_pose.is_empty():
		return failed
	var target_pose: Dictionary = world.get_pose(target_id)
	if target_pose.is_empty():
		return failed
	if not ShoveGate.can_shove(now_tick, last_shove_tick, cooldown_ticks):
		return {"ok": true, "shoved": false}
	world.try_move_xz(target_id, dx, dz)
	return {"ok": true, "shoved": true}
