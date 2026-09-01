class_name FrameRateMeter
extends Label

## 运行时帧率读数（一行 `FPS 60`），挂在大厅 HUD 的状态行**上面**。
##
## 自己数帧再除，而不是读 `Engine.get_frames_per_second()`：后者取引擎内部
## 的滚动平均，单元测试喂不进固定 delta，断言只能写成「大概 60」。这里的
## `sample(delta)` 吃的是调用方传进来的 delta，所以「喂 60 次 0.01 秒」必然
## 等于 100 FPS——数法能被测试钉死，不用等真机跑一帧。
##
## 每累计到 `refresh_interval_s`（默认 0.5 秒）才写一次 `text`。每帧赋值会让
## 这个 Label 每帧重排一次（白给一个常驻开销），数字也会抖到读不出来。0.5 秒
## 是「够快能看出卡顿、够慢能读出数字」的折中，**不是产品规格**，也不锁帧率
## 目标——CD-53 §1.1 明确不建自动性能回归门禁，测试只钉「数法对不对」。
##
## 这是**观察工具，不是权威数据**：读的是客户端表现帧，不参与裁决、不进快照、
## 不写日志、不发网络。Headless 下 `_process` 照样在跑，窗口 `visible` 为 false
## 时由调用方 `reset()`，不可见期间不计入下一窗。

const REFRESH_INTERVAL_S: float = 0.5
const PREFIX: String = "FPS "
const PLACEHOLDER: String = PREFIX + "--"

## 两次刷新之间累计的秒数。可调是为了测试能少喂几帧，不是产品开关。
var refresh_interval_s: float = REFRESH_INTERVAL_S
## 最近一个完整窗口测得的帧率。首窗之前是 -1，此时显示占位而不是 0——
## 开窗口的头半秒显示 `FPS 0` 会被读成「卡死了」。
var frames_per_second: int = -1

var _frames: int = 0
var _elapsed_s: float = 0.0


func _init() -> void:
	reset()


## 丢弃当前窗口已累计的帧。窗口隐藏、开停玩这类「前后帧率不可比」的时刻由
## 调用方调用，免得把不可见或切换期间的时间算进下一窗。
func reset() -> void:
	frames_per_second = -1
	_frames = 0
	_elapsed_s = 0.0
	_apply_text()


## 每帧调用一次，返回 true 表示这一帧刚好刷出了新数字。
## delta <= 0（首帧、暂停后恢复）整帧不计入：计进去既会拖低均值，
## 也会在只有这类帧时除出 0。
func sample(delta: float) -> bool:
	if delta <= 0.0:
		return false
	_frames += 1
	_elapsed_s += delta
	if _elapsed_s < refresh_interval_s:
		return false
	frames_per_second = int(roundf(float(_frames) / _elapsed_s))
	_frames = 0
	_elapsed_s = 0.0
	_apply_text()
	return true


## 当前应该显示的整行文本。与 `text` 同源；测试读它比读 Label 属性少绕一层。
func fps_text() -> String:
	if frames_per_second < 0:
		return PLACEHOLDER
	return "%s%d" % [PREFIX, frames_per_second]


func _apply_text() -> void:
	text = fps_text()
