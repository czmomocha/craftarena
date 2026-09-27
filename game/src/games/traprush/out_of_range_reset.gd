class_name TraprushOutOfRangeReset
extends RefCounted

## 出界复位：胶囊 y 低于/高于调用方闭区间，或 XZ 落在调用方闭区间外时，
## 用已有 CheckpointSpawn.pose_for 写回最近检查点落点（尚无进度则回起点）。
## 依据 CD-21 §6：环境失败后无限复活到最近检查点。不计数掉出次数 N，
## 复位后 set_vy(0)。复活硬直由调用方在复位成功后写入，本函数不写硬直。
## 边界由调用方传入（产品路径用下面的 `content_bounds`），不是产品场地尺寸。
## 不 tick。查询走 SimulationWorld 已有 is_below_min_y / is_above_max_y /
## is_outside_xz。空区间（min > max）拒绝，避免「永远出界」。

const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const CheckpointTrack := preload("res://src/games/traprush/checkpoint_track.gd")

## 开发期占位半宽：±8 格。官方三张赛道沿路有立足固体后，这是真正的坑边界
## （走下路面才碰到），不是缺地板时的兜底。不是产品场地尺寸。
const STUB_HALF: int = 8 * Fixed.SCALE
## 大课余量：内容越出 ±STUB_HALF 的那一侧，边界放到该侧最远实体中心外 4 格。
## 开发期占位，不是产品场地；产品级场地仍属 CD-63 延期。
const MARGIN: int = 4 * Fixed.SCALE
const BOUND_KEYS: PackedStringArray = ["min_x", "max_x", "min_y", "max_y", "min_z", "max_z"]


## 以原点为中心、半宽 half 的立方体（含 Y）。half < 1 ⇒ 空字典，调用方据此关闭出界。
static func cube_bounds(half: int) -> Dictionary:
	if half < 1:
		return {}
	return {
		"min_x": -half, "max_x": half,
		"min_y": -half, "max_y": half,
		"min_z": -half, "max_z": half,
	}


## 六个键齐全、都是 int、每轴 min <= max。
static func bounds_ok(bounds: Dictionary) -> bool:
	for key: String in BOUND_KEYS:
		if typeof(bounds.get(key, null)) != TYPE_INT:
			return false
	var min_x: int = bounds["min_x"]
	var max_x: int = bounds["max_x"]
	var min_y: int = bounds["min_y"]
	var max_y: int = bounds["max_y"]
	var min_z: int = bounds["min_z"]
	var max_z: int = bounds["max_z"]
	return min_x <= max_x and min_y <= max_y and min_z <= max_z


## 出界六面按已编译内容推导。对局进程、BotRunner、完赛探针、Solo（含幽灵）与
## Preview 都从这里取，不各算一遍。
## 取所有带位置条目的中心求 AABB：检查点垫及其复活落点、传送门源与目的、终点、
## 可破坏物、周期机关、固体、拾取、mover 路径全部航点（压板 / 摆锤 / 电梯 / 移动
## 平台的几何也在 `solids`，行为袋只带 id，不另算）。`environment` 没有几何。
## AABB 六面都在 ±STUB_HALF 闭区间内 ⇒ 仍是 ±STUB_HALF 立方体（紧凑课逐字节不变）；
## 否则每一侧取 max(STUB_HALF, 该侧极值 + MARGIN)，负侧对称取 min。
## bundle 为 null 或没有任何条目 ⇒ 立方体。
static func content_bounds(bundle: SimulationBundle) -> Dictionary:
	var cube: Dictionary = cube_bounds(STUB_HALF)
	if bundle == null:
		return cube
	var box: Dictionary = {}
	var bags: Array[Array] = [
		bundle.pads,
		bundle.portals,
		bundle.finish,
		bundle.destructibles,
		bundle.hazards,
		bundle.solids,
		bundle.pickups,
	]
	for bag: Array in bags:
		for item: Variant in bag:
			if typeof(item) == TYPE_DICTIONARY:
				var entry: Dictionary = item
				_grow_from(box, entry, "x", "y", "z")
	for pad: Dictionary in bundle.pads:
		_grow_respawn(box, pad)
	for portal: Dictionary in bundle.portals:
		_grow_from(box, portal, "dest_x", "dest_y", "dest_z")
	for mover: Dictionary in bundle.movers:
		var path_raw: Variant = mover.get("path", [])
		if typeof(path_raw) != TYPE_ARRAY:
			continue
		var path: Array = path_raw
		for point_raw: Variant in path:
			if typeof(point_raw) == TYPE_DICTIONARY:
				var point: Dictionary = point_raw
				_grow_from(box, point, "x", "y", "z")
	if box.is_empty() or _inside_cube(box, STUB_HALF):
		return cube
	return {
		"min_x": mini(-STUB_HALF, _saturating_add(_int(box, "min_x"), -MARGIN)),
		"max_x": maxi(STUB_HALF, _saturating_add(_int(box, "max_x"), MARGIN)),
		"min_y": mini(-STUB_HALF, _saturating_add(_int(box, "min_y"), -MARGIN)),
		"max_y": maxi(STUB_HALF, _saturating_add(_int(box, "max_y"), MARGIN)),
		"min_z": mini(-STUB_HALF, _saturating_add(_int(box, "min_z"), -MARGIN)),
		"max_z": maxi(STUB_HALF, _saturating_add(_int(box, "max_z"), MARGIN)),
	}


static func try_apply(
	world: SimulationWorld,
	entity_id: int,
	spawn: CheckpointSpawn,
	track: CheckpointTrack,
	min_y: int,
	max_y: int,
	min_x: int,
	max_x: int,
	min_z: int,
	max_z: int
) -> Dictionary:
	var failed: Dictionary = {"ok": false}
	if world == null or spawn == null or track == null:
		return failed
	if min_x > max_x or min_z > max_z or min_y > max_y:
		return failed
	var pose: Dictionary = world.get_pose(entity_id)
	if pose.is_empty():
		return failed
	var below: bool = world.is_below_min_y(entity_id, min_y)
	var above: bool = world.is_above_max_y(entity_id, max_y)
	var outside_xz: bool = world.is_outside_xz(entity_id, min_x, max_x, min_z, max_z)
	if not below and not above and not outside_xz:
		return {"ok": true, "reset": false}
	var respawn: Dictionary = spawn.pose_for(track)
	var pose_ok: bool = respawn.get("ok", false)
	if not pose_ok:
		return failed
	var x: int = respawn.get("x", 0)
	var y: int = respawn.get("y", 0)
	var z: int = respawn.get("z", 0)
	var yaw_bam: int = respawn.get("yaw_bam", 0)
	if not world.set_pose(entity_id, x, y, z, yaw_bam):
		return failed
	world.set_vy(entity_id, 0)
	return {"ok": true, "reset": true}


static func _grow_from(box: Dictionary, item: Dictionary, kx: String, ky: String, kz: String) -> void:
	var keys: PackedStringArray = [kx, ky, kz]
	for key: String in keys:
		if typeof(item.get(key, null)) != TYPE_INT:
			return
	_grow(box, _int(item, kx), _int(item, ky), _int(item, kz))


## 复活落点 = 垫中心 + respawn 偏移。落点若在范围外，复位后下一拍又出界。
## 加法溢出的垫在 bootstrap 就会整局拒绝，这里跳过即可。
static func _grow_respawn(box: Dictionary, pad: Dictionary) -> void:
	var keys: PackedStringArray = ["x", "y", "z", "respawn_dx", "respawn_dy", "respawn_dz"]
	for key: String in keys:
		if typeof(pad.get(key, null)) != TYPE_INT:
			return
	var x: FixedResult = Fixed.try_add(_int(pad, "x"), _int(pad, "respawn_dx"))
	var y: FixedResult = Fixed.try_add(_int(pad, "y"), _int(pad, "respawn_dy"))
	var z: FixedResult = Fixed.try_add(_int(pad, "z"), _int(pad, "respawn_dz"))
	if not x.ok or not y.ok or not z.ok:
		return
	_grow(box, x.value, y.value, z.value)


static func _grow(box: Dictionary, x: int, y: int, z: int) -> void:
	if box.is_empty():
		box.merge({"min_x": x, "max_x": x, "min_y": y, "max_y": y, "min_z": z, "max_z": z})
		return
	box["min_x"] = mini(_int(box, "min_x"), x)
	box["max_x"] = maxi(_int(box, "max_x"), x)
	box["min_y"] = mini(_int(box, "min_y"), y)
	box["max_y"] = maxi(_int(box, "max_y"), y)
	box["min_z"] = mini(_int(box, "min_z"), z)
	box["max_z"] = maxi(_int(box, "max_z"), z)


static func _inside_cube(box: Dictionary, half: int) -> bool:
	for key: String in BOUND_KEYS:
		var value: int = _int(box, key)
		if value < -half or value > half:
			return false
	return true


static func _int(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	var value: int = raw
	return value


## UGC 坐标不可信：极值加余量溢出 int64 时钉在端点，而不是回绕成反号。
static func _saturating_add(value: int, delta: int) -> int:
	var sum: FixedResult = Fixed.try_add(value, delta)
	if sum.ok:
		return sum.value
	if delta > 0:
		return Fixed.INT64_MAX
	return Fixed.INT64_MIN
