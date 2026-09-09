class_name TraprushLaunchCycle
extends RefCounted

## 弹射垫：站上去被往上弹一次，并沿 `yaw_bam` 四向送出一格（可玩性深化第二批）。
##
## 传送带每 tick 推；弹射垫是**支撑上升沿**——同一格上站着不会连弹，走开再踩
## 才再弹。竖直冲量走已有 `TraprushGravity.apply_jump`，水平送出走
## `try_move_xz_until_blocked`，和跳跃 / 走路同一条位移路径。
##
## **不新增组件。** 固体 + `zone.tags` 的 `launch` + `transform.yaw_bam`。
## 斜弹不做：斜向会让落点在定点网格上不可预读。
##
## 同时被多块垫支撑时只认 `entity_id` 最小的一块，与传送带同一条回放理由。
## 与 `mover` / `conveyor` 同实体被编译拒绝：两段位移没有可解释的先后。

const ConveyorCycleGd := preload("res://src/games/traprush/conveyor_cycle.gd")
const GravityGd := preload("res://src/games/traprush/gravity.gd")


## bundle 的 `launches` 袋 + 已加载的固体箱 id → 可执行表。
## 任何一条对不上固体箱就返回空表，调用方据大小不符判为加载失败。
static func entries_from(launches: Array, solid_ids: Dictionary) -> Array[Dictionary]:
	return ConveyorCycleGd.entries_from(launches, solid_ids)


## 每 tick 一次。`previously_supported` 是上一拍站在垫上的胶囊 id 集；
## 返回本拍仍站在垫上的集合，调用方存回去。
static func apply(
	world: SimulationWorld,
	entries: Array[Dictionary],
	capsule_ids: PackedInt32Array,
	support_dy: int,
	launch_dy: int,
	launch_xz: int,
	previously_supported: Dictionary
) -> Dictionary:
	var next_supported: Dictionary = {}
	if world == null or entries.is_empty():
		return next_supported
	if launch_dy <= 0 and launch_xz <= 0:
		return next_supported
	for capsule_id: int in capsule_ids:
		var entry: Dictionary = ConveyorCycleGd.supporting_entry(
			world, capsule_id, entries, support_dy
		)
		if entry.is_empty():
			continue
		next_supported[capsule_id] = true
		var was_supported: bool = previously_supported.get(capsule_id, false)
		if was_supported:
			continue
		_try_launch(world, capsule_id, entry, launch_dy, launch_xz)
	return next_supported


static func _try_launch(
	world: SimulationWorld,
	capsule_id: int,
	entry: Dictionary,
	launch_dy: int,
	launch_xz: int
) -> void:
	if launch_dy > 0:
		GravityGd.apply_jump(world, capsule_id, launch_dy)
	if launch_xz <= 0:
		return
	var dx: int = entry["dx"]
	var dz: int = entry["dz"]
	if dx == 0 and dz == 0:
		return
	world.try_move_xz_until_blocked(capsule_id, dx * launch_xz, dz * launch_xz)
