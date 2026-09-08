class_name PlayWayfinder
extends RefCounted

## 「下一个目标在哪」的纯解算（可玩性深化，轨 1：传送与镜头）。
##
## 存在的理由与 `CameraFollowTransition` 是同一条：多层课 + 传送门之后，玩家
## 知道自己该去第几个检查点，但不知道它**在哪个方向、在上面还是下面**。此前
## HUD 只有 `pads=1/3` 与 `floor=2` 两个数，两者都不含方向。
##
## 方向按**屏幕**给，不按世界轴。相机是 D4 锁死的斜 45°（`PlaceholderSpec`
## `CAMERA_YAW_DEG` / `CAMERA_PITCH_DEG`），所以屏幕右 = 世界 (+X, -Z)、屏幕上
## = 世界 (-X, -Z)，与 `MatchSnapshotMap.try_pan` 里那两个基向量是同一组。
## 给世界方位（N/E/S/W）等于要玩家自己在脑内转 45°，那正是要消掉的负担。
##
## 箭头用 ASCII（`^` `^>` `>` …）。字体入包推迟到一期收尾，中文与 Unicode 箭头
## 在导出包里都可能缺字；`token()` 这一串同时进开发期状态行，本来就不翻译。
## 玩家可读的那一行在 `guide_text()`，走 `UiCopy`。
##
## 纯函数：不持有 Node，不读 SceneTree，输入是编译后的占用袋与一份权威位姿。
## 从不写回裁决数据——目标选择只读 `accepted_count`，那已经是服务端裁决的结果。

const KIND_CHECKPOINT: String = "checkpoint"
const KIND_FINISH: String = "finish"
const KIND_DONE: String = "done"

## 屏幕八向，索引 0 = 正上，顺时针。
const ARROWS: PackedStringArray = ["^", "^>", ">", "v>", "v", "v<", "<", "^<"]

## 屏幕右在世界 XZ 上的方向（未归一化）。与 `MatchSnapshotMap.try_pan` 同源。
const SCREEN_RIGHT_XZ: Vector2 = Vector2(1.0, -1.0)
## 屏幕上（远离相机）在世界 XZ 上的方向（未归一化）。
const SCREEN_UP_XZ: Vector2 = Vector2(-1.0, -1.0)


static func floor_index_from_y(y: int) -> int:
	return y / Fixed.SCALE


## 世界 XZ 位移 → 屏幕八向箭头。零位移返回空串（没有方向可读）。
static func arrow_of(dx: int, dz: int) -> String:
	if dx == 0 and dz == 0:
		return ""
	var delta: Vector2 = Vector2(float(dx), float(dz))
	var right: float = delta.dot(SCREEN_RIGHT_XZ)
	var up: float = delta.dot(SCREEN_UP_XZ)
	if is_zero_approx(right) and is_zero_approx(up):
		return ""
	var angle: float = atan2(right, up)
	var slot: int = int(roundf(angle / (TAU / 8.0)))
	slot = ((slot % 8) + 8) % 8
	return ARROWS[slot]


## 四舍五入到米。占位表现读数，不是裁决距离。
static func distance_m(dx: int, dz: int) -> int:
	var delta: Vector2 = Vector2(float(dx), float(dz))
	return int(roundf(delta.length() / float(Fixed.SCALE)))


## 下一个该去的占用袋。`accepted_count` 是服务端已验收的垫数，也就是下一个
## 要踩的 `order`（与 `MatchCourseMap.pad_albedo` 同一口径）。所有垫都验收完
## 之后目标是终点；已冲线返回 `done`。
static func target_of(
	pads: Array,
	finish: Array,
	accepted_count: int,
	finish_tick: int
) -> Dictionary:
	if accepted_count < 0:
		return {"ok": false}
	if finish_tick >= 0:
		return {"ok": true, "kind": KIND_DONE}
	for raw: Variant in pads:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var pad: Dictionary = raw
		var pose: Dictionary = _pose_of(pad)
		if pose.is_empty():
			continue
		var order_raw: Variant = pad.get("order", -1)
		if typeof(order_raw) != TYPE_INT:
			continue
		var order: int = order_raw
		if order != accepted_count:
			continue
		pose["ok"] = true
		pose["kind"] = KIND_CHECKPOINT
		pose["order"] = order
		return pose
	for raw: Variant in finish:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var bag: Dictionary = raw
		var pose: Dictionary = _pose_of(bag)
		if pose.is_empty():
			continue
		pose["ok"] = true
		pose["kind"] = KIND_FINISH
		pose["order"] = -1
		return pose
	return {"ok": false}


## 目标 + 本席位姿 → 一份可读的导航计划。`ok = false` 表示这一帧没有可指的
## 方向（不在局中、拓扑里没有目标、或者已冲线）。
static func plan(
	pads: Array,
	finish: Array,
	accepted_count: int,
	finish_tick: int,
	own_x: int,
	own_y: int,
	own_z: int
) -> Dictionary:
	var target: Dictionary = target_of(pads, finish, accepted_count, finish_tick)
	if not target.get("ok", false):
		return {"ok": false, "kind": ""}
	var kind: String = str(target.get("kind", ""))
	if kind == KIND_DONE:
		return {"ok": false, "kind": KIND_DONE}
	var target_x: int = target["x"]
	var target_y: int = target["y"]
	var target_z: int = target["z"]
	var dx: int = target_x - own_x
	var dz: int = target_z - own_z
	return {
		"ok": true,
		"kind": kind,
		"entity_id": target["entity_id"],
		"order": target["order"],
		"arrow": arrow_of(dx, dz),
		"floor_delta": floor_index_from_y(target_y) - floor_index_from_y(own_y),
		"distance_m": distance_m(dx, dz),
		"dx": dx,
		"dz": dz,
		"x": target_x,
		"y": target_y,
		"z": target_z,
	}


## 开发期状态行 token。不翻译，与 `join=` / `pads=` 同一类契约读出。
static func token(view: Dictionary) -> String:
	if str(view.get("kind", "")) == KIND_DONE:
		return "next=done"
	if not view.get("ok", false):
		return ""
	var name: String = "finish"
	if str(view.get("kind", "")) == KIND_CHECKPOINT:
		name = "cp%d" % _int_of(view, "order")
	var floor_delta: int = _int_of(view, "floor_delta")
	var floor_token: String = "0F" if floor_delta == 0 else "%+dF" % floor_delta
	return "next=%s %s %s %dm" % [
		name,
		str(view.get("arrow", "")),
		floor_token,
		_int_of(view, "distance_m"),
	]


## 玩家可读的一行。走 `UiCopy`，`locale` 只给测试用来钉住语言。
static func guide_text(view: Dictionary, locale: String = "") -> String:
	if str(view.get("kind", "")) == KIND_DONE:
		return UiCopy.text(UiCopy.GUIDE_DONE, locale)
	if not view.get("ok", false):
		return ""
	var name: String = UiCopy.text(UiCopy.GUIDE_FINISH, locale)
	if str(view.get("kind", "")) == KIND_CHECKPOINT:
		name = UiCopy.text(UiCopy.GUIDE_CHECKPOINT, locale) % _int_of(view, "order")
	var floor_delta: int = _int_of(view, "floor_delta")
	var floor_text: String = UiCopy.text(UiCopy.GUIDE_FLOOR_SAME, locale)
	if floor_delta > 0:
		floor_text = UiCopy.text(UiCopy.GUIDE_FLOOR_UP, locale) % floor_delta
	elif floor_delta < 0:
		floor_text = UiCopy.text(UiCopy.GUIDE_FLOOR_DOWN, locale) % -floor_delta
	return "%s %s  %s  %dm" % [
		str(view.get("arrow", "")),
		name,
		floor_text,
		_int_of(view, "distance_m"),
	]


## 世界导航箭头的朝向（表现米，水平）。没有方向时返回零向量。
static func direction_meters(view: Dictionary) -> Vector3:
	if not view.get("ok", false):
		return Vector3.ZERO
	var dx: int = _int_of(view, "dx")
	var dz: int = _int_of(view, "dz")
	if dx == 0 and dz == 0:
		return Vector3.ZERO
	var direction: Vector3 = Vector3(float(dx), 0.0, float(dz))
	return direction.normalized()


## 读出字典里的 int 字段。`shared/` 严格类型不允许 `int(Variant)`（第二十三条），
## 而计划字典本身是 Variant 袋，所以这一层拆包必须显式。
static func _int_of(view: Dictionary, key: String) -> int:
	var raw: Variant = view.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	return raw


static func _pose_of(bag: Dictionary) -> Dictionary:
	if not bag.has("entity_id") or typeof(bag["entity_id"]) != TYPE_INT:
		return {}
	if not bag.has("x") or typeof(bag["x"]) != TYPE_INT:
		return {}
	if not bag.has("y") or typeof(bag["y"]) != TYPE_INT:
		return {}
	if not bag.has("z") or typeof(bag["z"]) != TYPE_INT:
		return {}
	return {
		"entity_id": bag["entity_id"],
		"x": bag["x"],
		"y": bag["y"],
		"z": bag["z"],
	}
