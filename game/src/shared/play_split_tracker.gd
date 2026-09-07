class_name PlaySplitTracker
extends RefCounted

## Client-side pad splits. Observes accepted_count rising edges against
## the presentation clock tick. Does not enter hash_state, snapshots, or
## settlement ranking (CD-21 pad-arrival ranking stays deferred).

const PlayClockGd := preload("res://src/shared/play_clock.gd")

var last_accepted: int = 0
var last_tick: int = 0
var popup_text: String = ""
var splits: Array[Dictionary] = []


func reset() -> void:
	last_accepted = 0
	last_tick = 0
	popup_text = ""
	splits.clear()


func observe(accepted_count: int, clock_tick: int) -> bool:
	if accepted_count < 0:
		return false
	if accepted_count <= last_accepted:
		return false
	var delta: int = clock_tick - last_tick
	if delta < 0:
		delta = 0
	var entry: Dictionary = {
		"index": accepted_count,
		"tick": clock_tick,
		"delta": delta,
	}
	splits.append(entry)
	popup_text = "+%d  %s  +%s" % [
		accepted_count,
		PlayClockGd.format_clock(clock_tick),
		PlayClockGd.format_clock(delta),
	]
	last_accepted = accepted_count
	last_tick = clock_tick
	return true


func popup_line() -> String:
	return popup_text
