class_name CameraFollowTransition
extends RefCounted

## 跟随相机的「跳变滑行」纯状态机（可玩性深化，轨 1：传送与镜头）。
##
## 存在的理由是**传送迷路**。本席一进传送门，跟随相机此前在同一帧把机位换到
## 新格子：玩家看到的是一次没有过程的画面替换，读不出自己从哪去了哪，也读不出
## 新落点相对旧位置在哪个方向。出界复位与机关击退复位是同一类跳变。本状态机
## 把那一跳摊成一段短滑行，让位移本身可见。
##
## **只有跳变才触发。** 常态跟随仍是逐帧对齐，没有引入任何跟随延迟——给普通
## 移动加平滑会改掉全部操作手感，那不在本刀范围。判据是一次 `track` 里锚点位移
## 超过 `PlaceholderSpec.CAMERA_TELEPORT_SNAP_M`；一帧的走 / 冲刺都远小于它
## （最大的一步是冲刺 1 格 = 1 米）。同层 hop 走 `track_pose`：空中冻结 Y，
## 不把跳跃高度当成跟随目标。
##
## 纯逻辑：不持有 Node，不读 SceneTree，也不自己取时间。`advance(delta)` 由壳
## 每帧喂一次，`track(target)` 在采样出本席表现位姿之后调。权威位姿仍在快照里，
## 本文件只决定相机看哪一点，从不写回任何裁决数据。
##
## 每帧调用顺序固定：先 `advance` 推时间，再 `track` 认目标。反过来会让滑行的
## 第一帧多走一个 delta。

## 尚未认过任何目标。`anchor` 此时无意义。
var anchor: Vector3 = Vector3.ZERO
## 正在滑行。滑行期间 `anchor` 在 `_from` 与 `_to` 之间，不等于本席位置。
var active: bool = false
## 上次接地时的跟随高度。空中冻结，换层落地或乘电梯（仍接地）才改。
var _held_y: float = 0.0

var _has_anchor: bool = false
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0


static func snap_threshold_m() -> float:
	return PlaceholderSpec.CAMERA_TELEPORT_SNAP_M


static func glide_seconds() -> float:
	return PlaceholderSpec.CAMERA_TELEPORT_GLIDE_S


## 缓出三次方。滑行起步快、收尾慢，落点前那几帧因此看得清。
static func ease_out(t: float) -> float:
	var clamped: float = clampf(t, 0.0, 1.0)
	var inverse: float = 1.0 - clamped
	return 1.0 - inverse * inverse * inverse


func has_anchor() -> bool:
	return _has_anchor


func progress() -> float:
	var glide: float = glide_seconds()
	if glide <= 0.0:
		return 1.0
	return clampf(_elapsed / glide, 0.0, 1.0)


func reset() -> void:
	anchor = Vector3.ZERO
	active = false
	_has_anchor = false
	_held_y = 0.0
	_from = Vector3.ZERO
	_to = Vector3.ZERO
	_elapsed = 0.0


## 直接就位，不滑行。切局 / 换课 / 首次拿到本席位姿时用。
func snap_to(target: Vector3) -> void:
	anchor = target
	_has_anchor = true
	active = false
	_held_y = target.y
	_from = target
	_to = target
	_elapsed = 0.0


## 跟随本席，但空中不把镜头抬到跳跃高度。接地（含乘电梯）才更新 `_held_y`。
## XZ 仍逐帧对齐。同层 hop 因此不会整屏跟着抖。
func track_pose(target: Vector3, grounded: bool) -> bool:
	if not _has_anchor:
		return track(target)
	if grounded:
		_held_y = target.y
	return track(Vector3(target.x, _held_y, target.z))


## 认下这一帧的本席位姿。返回 true 只在**本次调用刚开启一段滑行**时——
## 壳据此把中键平移量清零：被传送之后还挂着上一处的平移，等于把人跟丢。
func track(target: Vector3) -> bool:
	if not _has_anchor:
		snap_to(target)
		return false
	if active:
		if _to.distance_to(target) > snap_threshold_m():
			_restart(target)
			return true
		_to = target
		anchor = _from.lerp(_to, ease_out(progress()))
		return false
	if anchor.distance_to(target) > snap_threshold_m():
		_restart(target)
		return true
	anchor = target
	return false


## 推进滑行时钟。返回滑行是否仍在进行。
func advance(delta: float) -> bool:
	if not active:
		return false
	if delta > 0.0:
		_elapsed += delta
	var glide: float = glide_seconds()
	if glide <= 0.0 or _elapsed >= glide:
		_elapsed = maxf(glide, 0.0)
		anchor = _to
		active = false
		return false
	anchor = _from.lerp(_to, ease_out(progress()))
	return true


func _restart(target: Vector3) -> void:
	_from = anchor
	_to = target
	_elapsed = 0.0
	active = true
