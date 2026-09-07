extends GutTest

## F-line FA: client-side pad splits. Not hashed, not ranked.

const PlayClockGd := preload("res://src/shared/play_clock.gd")
const PlaySplitTrackerGd := preload("res://src/shared/play_split_tracker.gd")


func test_rising_edge_records_delta_and_popup() -> void:
	var tracker: PlaySplitTrackerGd = PlaySplitTrackerGd.new()
	assert_false(tracker.observe(0, 0))
	assert_true(tracker.observe(1, 60))
	assert_eq(tracker.splits.size(), 1)
	var first: Dictionary = tracker.splits[0]
	var first_delta: int = PlayClockGd.dict_int(first, "delta", -1)
	assert_eq(first_delta, 60)
	assert_true(tracker.popup_line().contains("0:01.00"))
	assert_true(tracker.observe(2, 90))
	var second: Dictionary = tracker.splits[1]
	var second_delta: int = PlayClockGd.dict_int(second, "delta", -1)
	assert_eq(second_delta, 30)
	assert_false(tracker.observe(2, 120))
	assert_eq(tracker.splits.size(), 2)


func test_reset_clears_popup() -> void:
	var tracker: PlaySplitTrackerGd = PlaySplitTrackerGd.new()
	tracker.observe(1, 30)
	tracker.reset()
	assert_eq(tracker.popup_line(), "")
	assert_eq(tracker.splits.size(), 0)
