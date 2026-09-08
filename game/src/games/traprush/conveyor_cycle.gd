class_name TraprushConveyorCycle
extends RefCounted

## 传送带：站上去就被往一个方向推（可玩性深化 轨 1「白名单移动件」）。
##
## 存在的理由是第一张课里「地面」只有一种语义：踩得到。移动平台（`mover`）已经
## 能带着人走，但它自己也在动，创作者拿它做不出「一段路自己往回推你」这种压力。
## 传送带补的正是那一格：几何不动，站在上面的人动。
##
## **不新增组件、不改 Component Schema v1。** 传送带就是一块固体，外加
## `zone.tags` 里的一个 `conveyor` 标签与 `transform.yaw_bam` 一个方向——
## `zone` 在 CD-42 §1 的原义就是「触发与查询区域」，`tags` 本来就是自由字符串表。
## 新增一个被编译器认识的标签不是 Schema 破坏性变更，旧内容照常编译。
##
## 方向量化到四向，与 `MatchMoveFacing` 同一套 BAM 约定（yaw 0 = 世界 -Z）。
## 不做八向：斜推会让「我到底会被带到哪一格」在定点网格上变得不可预读，而这块
## 东西的全部价值就是可预读。
##
## 判据是**支撑**，不是重叠：传送带是固体，胶囊永远不会和它重叠，只会站在它上面。
## 同时被多块传送带支撑时只认 `entity_id` 最小的那一块——两块方向相反的带子叠加
## 出的合力取决于遍历顺序，那是回放会分叉的东西。

const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")

const YAW_FORWARD: int = 0
const YAW_LEFT: int = Fixed.BAM_TURN / 4
const YAW_BACK: int = Fixed.BAM_TURN / 2
const YAW_RIGHT: int = Fixed.BAM_TURN * 3 / 4


## 四向量化。返回 XZ 单位方向（格），未知 yaw 归到最近的四向之一。
static func direction_of(yaw_bam: int) -> Vector2i:
	var turn: int = Fixed.BAM_TURN
	var wrapped: int = ((yaw_bam % turn) + turn) % turn
	var quadrant: int = (wrapped + turn / 8) / (turn / 4)
	match quadrant % 4:
		1:
			return Vector2i(-1, 0)
		2:
			return Vector2i(0, 1)
		3:
			return Vector2i(1, 0)
		_:
			return Vector2i(0, -1)


## bundle 的 `conveyors` 袋 + 已加载的固体箱 id → 可执行的周期表。
## 任何一条对不上固体箱就返回空表，调用方据大小不符判为加载失败。
static func entries_from(conveyors: Array, solid_ids: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var ids: Array[int] = []
	var by_id: Dictionary = {}
	for raw: Variant in conveyors:
		if typeof(raw) != TYPE_DICTIONARY:
			return []
		var bag: Dictionary = raw
		var entity_raw: Variant = bag.get("entity_id", null)
		var yaw_raw: Variant = bag.get("yaw_bam", null)
		if typeof(entity_raw) != TYPE_INT or typeof(yaw_raw) != TYPE_INT:
			return []
		var entity_id: int = entity_raw
		if by_id.has(entity_id) or not solid_ids.has(entity_id):
			return []
		var box_raw: Variant = solid_ids[entity_id]
		if typeof(box_raw) != TYPE_INT:
			return []
		by_id[entity_id] = {"box_id": box_raw, "yaw_bam": yaw_raw}
		ids.append(entity_id)
	ids.sort()
	for entity_id: int in ids:
		var body: Dictionary = by_id[entity_id]
		var box_id: int = body["box_id"]
		var yaw_bam: int = body["yaw_bam"]
		var direction: Vector2i = direction_of(yaw_bam)
		entries.append({
			"entity_id": entity_id,
			"box_id": box_id,
			"yaw_bam": yaw_bam,
			"dx": direction.x,
			"dz": direction.y,
		})
	return entries


## 支撑这个胶囊的传送带里 `entity_id` 最小的一条。没有就返回空字典。
static func supporting_entry(
	world: SimulationWorld,
	capsule_id: int,
	entries: Array[Dictionary],
	support_dy: int
) -> Dictionary:
	if world == null or entries.is_empty():
		return {}
	var supports: PackedInt32Array = world.supporting_solid_static_boxes(capsule_id, support_dy)
	if supports.is_empty():
		return {}
	for entry: Dictionary in entries:
		var box_id: int = entry["box_id"]
		if supports.has(box_id):
			return entry
	return {}


## 推一个胶囊一步。`step` 是调用方注入的占位桩，本文件不发明速度。
## 走 `try_move_xz_until_blocked`：被墙挡住就停在最后一个没被挡的样本，
## 和玩家自己走路是同一条位移路径，不会把人推进固体里。
static func try_push(
	world: SimulationWorld,
	capsule_id: int,
	entry: Dictionary,
	step: int
) -> bool:
	if world == null or entry.is_empty() or step <= 0:
		return false
	var dx: int = entry["dx"]
	var dz: int = entry["dz"]
	if dx == 0 and dz == 0:
		return false
	return world.try_move_xz_until_blocked(capsule_id, dx * step, dz * step)


## 每 tick 一次：每个胶囊最多被一条传送带推一步。
static func apply(
	world: SimulationWorld,
	entries: Array[Dictionary],
	capsule_ids: PackedInt32Array,
	support_dy: int,
	step: int
) -> int:
	if world == null or entries.is_empty() or step <= 0:
		return 0
	var pushed: int = 0
	for capsule_id: int in capsule_ids:
		var entry: Dictionary = supporting_entry(world, capsule_id, entries, support_dy)
		if entry.is_empty():
			continue
		if try_push(world, capsule_id, entry, step):
			pushed += 1
	return pushed
