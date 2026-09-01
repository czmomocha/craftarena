extends GutTest

## FrameRateMeter: 注入 delta 的帧率读数。钉的是「数法」——帧数 / 累计秒数、
## 到点才刷新、非正 delta 不参与、reset 丢弃半窗——**不是**真机帧率数字
## （CD-53 §1.1 不建自动性能门禁）。

const FrameRateMeter := preload("res://src/client/frame_rate_meter.gd")

var _meter: FrameRateMeter = null


func before_each() -> void:
	_meter = FrameRateMeter.new()


func after_each() -> void:
	if _meter != null and is_instance_valid(_meter):
		_meter.free()
	_meter = null


func test_first_window_is_frames_over_elapsed() -> void:
	## 首窗之前显示占位而不是 0：`FPS 0` 会被读成「卡死了」。
	assert_eq(_meter.fps_text(), FrameRateMeter.PLACEHOLDER)
	assert_eq(_meter.text, FrameRateMeter.PLACEHOLDER)
	assert_eq(_meter.frames_per_second, -1)
	## 49 帧 = 0.49 s，还没到 0.5 s 的刷新点。
	assert_eq(_feed(49, 0.01), 0)
	assert_eq(_meter.fps_text(), FrameRateMeter.PLACEHOLDER)
	## 第 50 帧满 0.5 s：50 / 0.5 = 100。
	assert_eq(_feed(11, 0.01), 1)
	assert_eq(_meter.frames_per_second, 100)
	assert_eq(_meter.fps_text(), "FPS 100")
	assert_eq(_meter.text, "FPS 100")


func test_refresh_is_throttled_not_per_frame() -> void:
	## 10 帧只刷 3 次（每满 0.5 s 一次），不是每帧一次：每帧重写 text 会让
	## 这个 Label 每帧重排，数字也会抖到读不出来。
	assert_eq(_feed(10, 0.2), 3)
	assert_eq(_meter.frames_per_second, 5)
	assert_eq(_meter.fps_text(), "FPS 5")


func test_non_positive_delta_is_ignored() -> void:
	assert_false(_meter.sample(0.0))
	assert_false(_meter.sample(-1.0))
	assert_eq(_meter.frames_per_second, -1)
	assert_eq(_meter.fps_text(), FrameRateMeter.PLACEHOLDER)
	## 被跳过的帧既没有计数也没有累计，后面的窗口不受污染。
	assert_eq(_feed(60, 0.01), 1)
	assert_eq(_meter.fps_text(), "FPS 100")


func test_refresh_interval_is_injectable() -> void:
	_meter.refresh_interval_s = 0.1
	assert_eq(_feed(10, 0.01), 0)
	assert_eq(_feed(1, 0.01), 1)
	assert_eq(_meter.frames_per_second, 100)
	assert_eq(_meter.fps_text(), "FPS 100")


func test_reset_drops_the_partial_window() -> void:
	assert_eq(_feed(60, 0.01), 1)
	assert_eq(_meter.fps_text(), "FPS 100")
	_meter.reset()
	assert_eq(_meter.frames_per_second, -1)
	assert_eq(_meter.fps_text(), FrameRateMeter.PLACEHOLDER)
	assert_eq(_meter.text, FrameRateMeter.PLACEHOLDER)
	## 半窗已被丢弃，下一窗要从零重新数满一整个间隔。
	assert_eq(_feed(49, 0.01), 0)
	assert_eq(_meter.fps_text(), FrameRateMeter.PLACEHOLDER)
	assert_eq(_feed(11, 0.01), 1)
	assert_eq(_meter.fps_text(), "FPS 100")


func _feed(count: int, delta: float) -> int:
	var refreshes: int = 0
	for _i: int in range(count):
		if _meter.sample(delta):
			refreshes += 1
	return refreshes
