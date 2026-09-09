class_name PlayInput
extends RefCounted

## D7 输入抽象（纠偏方案：布尔改为方向向量 + 动作事件）。
##
## 玩法壳消费这一份快照。游戏进程读 InputMap；从 Godot 编辑器 Tools 打开时
## 编辑器进程没有 `move_left` 等动作，再调 `Input.get_axis` 会每帧报错且 WASD
## 恒为 0。缺动作时回退到与 `project.godot` 同一套物理键。触控摇杆走
## `vector_from_stick`。量化成 8 向 `dx/dz` 与 `yaw_bam` 仍是 `MatchMoveFacing`
## 的事；本文件不发明转向、不读 `play_move_step`（那条是冻结占位，由调用方注入）。
##
## 放 `shared/` 的理由与 `PlaceholderSpec` 相同：大厅与 Preview 必须读同一份，
## 否则两边会各养一套布尔。`simulation/` 不引用本文件。
##
## 动作是上升沿。按住不连发。CD-21 §3.2 写「长按 R 复位」，实现仍是上升沿桩，
## 时长未锁。模拟量绝对值**不**进入 MoveIntent：符号量化成整步，避免把未锁定
## 的模拟速度写进权威命令。
##
## 触控 UI / 虚拟摇杆不在本章。

const ACTION_MOVE_FORWARD: String = "move_forward"
const ACTION_MOVE_BACK: String = "move_back"
const ACTION_MOVE_LEFT: String = "move_left"
const ACTION_MOVE_RIGHT: String = "move_right"
const ACTION_JUMP: String = "jump"
const ACTION_USE_ITEM: String = "use_item"
const ACTION_SHOVE: String = "shove"
const ACTION_SPRINT: String = "sprint"
const ACTION_RESET: String = "reset_checkpoint"

## 判定「没推杆」。不是产品死区：Input Map 自己的 deadzone 已经滤过一次。
## 注入测试向量时用这个门槛，避免把浮点噪声当成一步。
const IDLE: float = 0.0001

var _jump_held: bool = false
var _shove_held: bool = false
var _use_item_held: bool = false
var _sprint_held: bool = false
var _reset_held: bool = false


static func vector_from_axes(forward: bool, back: bool, left: bool, right: bool) -> Vector2:
	var move_x: float = 0.0
	var move_z: float = 0.0
	if right:
		move_x += 1.0
	if left:
		move_x -= 1.0
	if back:
		move_z += 1.0
	if forward:
		move_z -= 1.0
	return Vector2(move_x, move_z)


static func vector_from_stick(stick_x: float, stick_z: float) -> Vector2:
	return Vector2(clampf(stick_x, -1.0, 1.0), clampf(stick_z, -1.0, 1.0))


static func step_from_vector(move_x: float, move_z: float, step: int) -> Vector2i:
	if step < 1:
		return Vector2i.ZERO
	var dx: int = 0
	if move_x > IDLE:
		dx = step
	elif move_x < -IDLE:
		dx = -step
	var dz: int = 0
	if move_z > IDLE:
		dz = step
	elif move_z < -IDLE:
		dz = -step
	if dx == 0 and dz == 0:
		return Vector2i.ZERO
	return Vector2i(dx, dz)


static func empty_held() -> Dictionary:
	return {
		"move_x": 0.0,
		"move_z": 0.0,
		"jump": false,
		"shove": false,
		"use_item": false,
		"sprint": false,
		"reset": false,
	}


## 游戏进程为 true。EditorPlugin 跑在编辑器 InputMap 上，这些动作不存在。
static func has_play_actions() -> bool:
	return (
		InputMap.has_action(ACTION_MOVE_LEFT)
		and InputMap.has_action(ACTION_MOVE_RIGHT)
		and InputMap.has_action(ACTION_MOVE_FORWARD)
		and InputMap.has_action(ACTION_MOVE_BACK)
		and InputMap.has_action(ACTION_JUMP)
		and InputMap.has_action(ACTION_SHOVE)
		and InputMap.has_action(ACTION_USE_ITEM)
		and InputMap.has_action(ACTION_SPRINT)
		and InputMap.has_action(ACTION_RESET)
	)


static func read_keyboard_held() -> Dictionary:
	if has_play_actions():
		return _read_action_held()
	return read_physical_held()


static func read_physical_held() -> Dictionary:
	var axes: Vector2 = vector_from_axes(
		_key_down(KEY_W) or _key_down(KEY_UP),
		_key_down(KEY_S) or _key_down(KEY_DOWN),
		_key_down(KEY_A) or _key_down(KEY_LEFT),
		_key_down(KEY_D) or _key_down(KEY_RIGHT)
	)
	return {
		"move_x": axes.x,
		"move_z": axes.y,
		"jump": _key_down(KEY_SPACE),
		"shove": _key_down(KEY_F),
		"use_item": _key_down(KEY_Q),
		"sprint": _key_down(KEY_SHIFT),
		"reset": _key_down(KEY_R),
	}


static func _read_action_held() -> Dictionary:
	return {
		"move_x": Input.get_axis(ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT),
		"move_z": Input.get_axis(ACTION_MOVE_FORWARD, ACTION_MOVE_BACK),
		"jump": Input.is_action_pressed(ACTION_JUMP),
		"shove": Input.is_action_pressed(ACTION_SHOVE),
		"use_item": Input.is_action_pressed(ACTION_USE_ITEM),
		"sprint": Input.is_action_pressed(ACTION_SPRINT),
		"reset": Input.is_action_pressed(ACTION_RESET),
	}


static func _key_down(physical: Key) -> bool:
	return Input.is_physical_key_pressed(physical)


func reset_held() -> void:
	_jump_held = false
	_shove_held = false
	_use_item_held = false
	_sprint_held = false
	_reset_held = false


func consume(held: Dictionary) -> Dictionary:
	var jump_held: bool = _bool_at(held, "jump")
	var shove_held: bool = _bool_at(held, "shove")
	var use_item_held: bool = _bool_at(held, "use_item")
	var sprint_held: bool = _bool_at(held, "sprint")
	var reset_held: bool = _bool_at(held, "reset")
	var jump: bool = jump_held and not _jump_held
	var shove: bool = shove_held and not _shove_held
	var use_item: bool = use_item_held and not _use_item_held
	var sprint: bool = sprint_held and not _sprint_held
	var reset: bool = reset_held and not _reset_held
	_jump_held = jump_held
	_shove_held = shove_held
	_use_item_held = use_item_held
	_sprint_held = sprint_held
	_reset_held = reset_held
	return {
		"move_x": _float_at(held, "move_x"),
		"move_z": _float_at(held, "move_z"),
		"jump": jump,
		"shove": shove,
		"use_item": use_item,
		"sprint": sprint,
		"reset": reset,
	}


func sample_keyboard() -> Dictionary:
	return consume(read_keyboard_held())


static func move_x_of(events: Dictionary) -> float:
	return _float_at(events, "move_x")


static func move_z_of(events: Dictionary) -> float:
	return _float_at(events, "move_z")


static func flag_of(events: Dictionary, key: String) -> bool:
	return _bool_at(events, key)


static func _bool_at(source: Dictionary, key: String) -> bool:
	if not source.has(key) or typeof(source[key]) != TYPE_BOOL:
		return false
	var flag: bool = source[key]
	return flag


static func _float_at(source: Dictionary, key: String) -> float:
	if not source.has(key):
		return 0.0
	if typeof(source[key]) == TYPE_FLOAT:
		var number: float = source[key]
		return number
	if typeof(source[key]) == TYPE_INT:
		var whole: int = source[key]
		return float(whole)
	return 0.0
