class_name TraprushSprintApply
extends RefCounted

## 把已解码的 SprintIntent 接到 SimulationWorld：门闩通过后沿胶囊当前 yaw
## 做 8 向水平位移。步长与冷却由调用方传入，不是产品冲刺距离或冷却秒数。
## yaw 量化到 8 向（W / yaw 0 = 世界 −Z），与大厅 WASD 同一套离散 BAM。
## 位移走 try_move_xz_until_blocked：停在最后未阻挡 XZ 样本，剩余位移丢弃，非贴墙滑行。
## 门闩通过后仍 {ok: true, sprinted: true}，不因接触改为 false。
## 步长超过 Fixed.SCALE 或为负整条拒绝。不调用 world.tick()。不 preload 客户端。

const SprintIntent := preload("res://src/games/traprush/sprint_intent.gd")
const ShoveGate := preload("res://src/games/traprush/shove_gate.gd")

const _TURN_BAM: int = 65536
const _OCTANT_BAM: int = 8192
const _OCTANT_DX: Array[int] = [0, -1, -1, -1, 0, 1, 1, 1]
const _OCTANT_DZ: Array[int] = [-1, -1, 0, 1, 1, 1, 0, -1]


static func apply(
	world: SimulationWorld,
	entity_id: int,
	payload: Dictionary,
	now_tick: int,
	last_sprint_tick: int,
	cooldown_ticks: int,
	step: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null:
		return failed
	var decoded: Dictionary = SprintIntent.decode(payload)
	var decode_ok: bool = decoded.get("ok", false)
	if not decode_ok:
		return failed
	var pose: Dictionary = world.get_pose(entity_id)
	if pose.is_empty():
		return failed
	if step < 0 or step > Fixed.SCALE:
		return failed
	if cooldown_ticks < 1:
		return failed
	if not ShoveGate.can_shove(now_tick, last_sprint_tick, cooldown_ticks):
		return {"ok": true, "sprinted": false}
	var yaw_raw: Variant = pose.get("yaw", 0)
	if typeof(yaw_raw) != TYPE_INT:
		return failed
	var yaw: int = yaw_raw
	var delta: Dictionary = dx_dz_from_yaw(yaw, step)
	var dx_raw: Variant = delta.get("dx", 0)
	var dz_raw: Variant = delta.get("dz", 0)
	if typeof(dx_raw) != TYPE_INT or typeof(dz_raw) != TYPE_INT:
		return failed
	var dx: int = dx_raw
	var dz: int = dz_raw
	world.try_move_xz_until_blocked(entity_id, dx, dz)
	return {"ok": true, "sprinted": true}


static func dx_dz_from_yaw(yaw: int, step: int) -> Dictionary:
	var wrapped: int = yaw % _TURN_BAM
	if wrapped < 0:
		wrapped += _TURN_BAM
	var octant: int = (wrapped + (_OCTANT_BAM / 2)) / _OCTANT_BAM
	octant = octant % 8
	var sign_x: int = _OCTANT_DX[octant]
	var sign_z: int = _OCTANT_DZ[octant]
	return {
		"dx": sign_x * step,
		"dz": sign_z * step,
	}
