extends GutTest

## F-line FA: presentation clock. Tick is authoritative; this only formats.

const PlayClockGd := preload("res://src/shared/play_clock.gd")


func test_format_zero_and_one_second() -> void:
	assert_eq(PlayClockGd.format_clock(0), "0:00.00")
	assert_eq(PlayClockGd.format_clock(60), "0:01.00")
	assert_eq(PlayClockGd.format_clock(90), "0:01.50")
	assert_eq(PlayClockGd.format_clock(4), "0:00.06")
	assert_eq(PlayClockGd.format_clock(3600), "1:00.00")


func test_negative_tick_formats_as_zero() -> void:
	assert_eq(PlayClockGd.format_clock(-12), "0:00.00")


func test_clock_tick_freezes_after_finish() -> void:
	assert_eq(PlayClockGd.clock_tick(80, -1), 80)
	assert_eq(PlayClockGd.clock_tick(80, 12), 12)
	assert_eq(PlayClockGd.clock_tick(-1, -1), 0)
