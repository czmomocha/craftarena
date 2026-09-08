class_name PlayClock
extends RefCounted

## Presentation clock for TRAPRUSH HUD (F-line FA). Tick is already
## authoritative; this file only formats it. Hz matches the locked
## 60 physics tick/s stub ([CD-43 §4], TraprushPlayStubs). Not a new
## product Tick. Splits and ranking do not live here.

const TICKS_PER_SECOND: int = 60
const CENTIS_PER_SECOND: int = 100


static func dict_int(view: Dictionary, key: String, fallback: int) -> int:
	var raw: Variant = view.get(key, fallback)
	if typeof(raw) != TYPE_INT:
		return fallback
	return raw


static func dict_bool(view: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = view.get(key, fallback)
	if typeof(raw) != TYPE_BOOL:
		return fallback
	return raw


static func clock_tick(live_tick: int, finish_tick: int) -> int:
	if finish_tick >= 0:
		return finish_tick
	if live_tick < 0:
		return 0
	return live_tick


## 一位小数的秒读数。给「还剩多久」这种短倒计时用；`format_clock` 那套
## 分:秒.厘 在 0.7 秒上读起来是噪声。
static func format_seconds(tick: int) -> String:
	var safe_tick: int = maxi(tick, 0)
	var tenths: int = (safe_tick * 10 + TICKS_PER_SECOND - 1) / TICKS_PER_SECOND
	return "%d.%d" % [tenths / 10, tenths % 10]


static func format_clock(tick: int) -> String:
	var safe_tick: int = tick
	if safe_tick < 0:
		safe_tick = 0
	var total_centis: int = (safe_tick * CENTIS_PER_SECOND) / TICKS_PER_SECOND
	var minutes: int = total_centis / (60 * CENTIS_PER_SECOND)
	var remain: int = total_centis % (60 * CENTIS_PER_SECOND)
	var seconds: int = remain / CENTIS_PER_SECOND
	var centis: int = remain % CENTIS_PER_SECOND
	return "%d:%02d.%02d" % [minutes, seconds, centis]
