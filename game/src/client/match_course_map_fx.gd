class_name MatchCourseMapFx
extends RefCounted

## 课内动效（可玩性深化 轨 2：传送门模型与课内动效）。
##
## 存在的理由是「哪一格是活的」读不出来。此前赛道上会动的只有周期机关一件，
## 传送门、当前目标垫与开放中的终点全是静止的：玩家分不出「这是门」和「这是
## 摆在那里的装饰」，也分不出「终点开了」和「终点还锁着」。
##
## **由权威 tick 驱动，不读墙钟。** 与 `MatchSolidMap.apply_tick` 同一条约定：
## 同一个 tick 必须画出同一帧，否则两台机器看同一局会看到不同的门。表现层从不
## 写回裁决数据，动效只改 `rotation` 与 `scale`。
##
## 相位按 `entity_id` 错开。三扇门整齐划一地转会读成机械装置，而不是三个各自
## 独立的传送口——这是可读性，不是审美偏好。

## 传送门模型里旋翼节点的名字。契约，与 `portal_gate.tscn` 同改。
const SWIRL_NAME: String = "Swirl"
## 缩放脉冲的基准 transform 存这个 meta 上：贴合规则（`fit_prop_on_cell`）已经
## 给 visual 写了缩放，脉冲必须乘在它之上，不能覆盖它。
const BASE_SCALE_META: String = "fx_base_scale"


## 一帧的全部动效。返回被动到的节点数——对局壳每帧调一次，这个读数是它唯一
## 需要知道的东西。公开 `apply_tick` 仍在 `MatchCourseMap` 门面上。
static func apply_tick(map: MatchCourseMap, tick: int) -> int:
	var animated: int = 0
	for portal_id: int in map._portal_ids:
		if spin_portal(map.portal_node(portal_id), portal_id, tick):
			animated += 1
	for bag: Dictionary in map.wayfind_pads():
		var pad_id: int = bag["entity_id"]
		var order: int = bag["order"]
		var current: bool = map._accepted_count >= 0 and order == map._accepted_count
		if breathe(map.pad_node(pad_id), pad_id, tick, current):
			animated += 1
	var finish_open: bool = (
		map._accepted_count >= 0 and map._pad_count > 0
		and map._accepted_count >= map._pad_count and map._finish_tick < 0
	)
	for finish_id: int in map._finish_ids:
		if breathe(map.finish_node(finish_id), finish_id, tick, finish_open):
			animated += 1
	return animated


static func spin_radians(tick: int, entity_id: int) -> float:
	if tick < 0:
		return 0.0
	var period: int = PlaceholderSpec.FX_PORTAL_SPIN_TICKS
	if period < 1:
		return 0.0
	var phase: int = (tick + entity_id * 17) % period
	return TAU * float(phase) / float(period)


## 0.0 → 1.0 → 0.0 的三角波。用三角而不是正弦，是为了让「读数从 tick 整数推出」
## 这件事一眼可验证，不必信任浮点三角函数的实现差异。
static func pulse(tick: int, entity_id: int) -> float:
	if tick < 0:
		return 0.0
	var period: int = PlaceholderSpec.FX_PULSE_TICKS
	if period < 2:
		return 0.0
	var phase: int = (tick + entity_id * 11) % period
	var half: int = period / 2
	if phase < half:
		return float(phase) / float(half)
	return float(period - phase) / float(period - half)


static func pulse_scale(tick: int, entity_id: int) -> float:
	return 1.0 + PlaceholderSpec.FX_PULSE_AMPLITUDE * pulse(tick, entity_id)


## 让传送门旋翼转起来。没有 `Swirl` 子节点（视觉回退到占位盒）就什么也不做。
static func spin_portal(node: MeshInstance3D, entity_id: int, tick: int) -> bool:
	var swirl: Node3D = _find_swirl(node)
	if swirl == null:
		return false
	swirl.rotation.z = spin_radians(tick, entity_id)
	return true


## 给一格加/去掉呼吸缩放。`active = false` 必须能把缩放放回基准——当前目标垫
## 一路往后走，前一块要能停下来，否则整条路都在呼吸，等于没有指示。
static func breathe(node: MeshInstance3D, entity_id: int, tick: int, active: bool) -> bool:
	if node == null:
		return false
	var target: Node3D = node.get_node_or_null(MatchCourseMap.VISUAL_NAME) as Node3D
	if target == null:
		target = node
	var base: Vector3 = Vector3.ONE
	if target.has_meta(BASE_SCALE_META):
		var raw: Variant = target.get_meta(BASE_SCALE_META)
		if typeof(raw) == TYPE_VECTOR3:
			base = raw
	else:
		base = target.scale
		target.set_meta(BASE_SCALE_META, base)
	var wanted: Vector3 = base if not active else base * pulse_scale(tick, entity_id)
	if target.scale.is_equal_approx(wanted):
		return active
	target.scale = wanted
	return active


static func _find_swirl(node: MeshInstance3D) -> Node3D:
	if node == null:
		return null
	var visual: Node3D = node.get_node_or_null(MatchCourseMap.VISUAL_NAME) as Node3D
	if visual == null:
		return null
	return visual.get_node_or_null(SWIRL_NAME) as Node3D
