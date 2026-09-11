class_name SharedAudioCueCatalog
extends RefCounted

## Platform built-in audio cue ids. UGC may only name ids listed here
## ([CD-31](Confirmed-docs/30-ugc/31-ugc-principles.md) §5).
## Stream files and playback params live in `res://content/audio/banks/`.
## Adding a cue: append here and a bank JSON row. Do not edit `game/src/audio/`.
##
## `tools/content-validator` compares these String constants (source order)
## with the union of production bank ids.

const STEP: String = "step"
const JUMP: String = "jump"
const LAND: String = "land"
const PICKUP: String = "pickup"
const CRATE: String = "crate"
const HAZARD_WARN: String = "hazard_warn"
const PORTAL: String = "portal"
const FINISH: String = "finish"
const THEME_IDLE: String = "theme_idle"
const THEME_RUN: String = "theme_run"
const THEME_END: String = "theme_end"
const THEME_EDIT: String = "theme_edit"
const SPRINT: String = "sprint"
const SHOVE: String = "shove"
const USE_ITEM: String = "use_item"
const BREAK_RUBBLE: String = "break_rubble"
const BREAK_CORE: String = "break_core"
const BREAK_WALL: String = "break_wall"
const CHECKPOINT: String = "checkpoint"
const RESET: String = "reset"
const FAIL_HAZARD: String = "fail_hazard"
const FAIL_RANGE: String = "fail_range"
const FAIL_CRUSH: String = "fail_crush"
const SETTLED: String = "settled"
const LOOP_CONVEYOR: String = "loop_conveyor"
const LOOP_MOVER: String = "loop_mover"
const LOOP_FLAME: String = "loop_flame"
const LOOP_ROLLER: String = "loop_roller"
const LOOP_CRUSHER: String = "loop_crusher"
const LOOP_PENDULUM: String = "loop_pendulum"
const LOOP_GATE: String = "loop_gate"
const LOOP_ICE: String = "loop_ice"
const LOOP_PORTAL: String = "loop_portal"

const ALL: PackedStringArray = [
	STEP,
	JUMP,
	LAND,
	PICKUP,
	CRATE,
	HAZARD_WARN,
	PORTAL,
	FINISH,
	THEME_IDLE,
	THEME_RUN,
	THEME_END,
	THEME_EDIT,
	SPRINT,
	SHOVE,
	USE_ITEM,
	BREAK_RUBBLE,
	BREAK_CORE,
	BREAK_WALL,
	CHECKPOINT,
	RESET,
	FAIL_HAZARD,
	FAIL_RANGE,
	FAIL_CRUSH,
	SETTLED,
	LOOP_CONVEYOR,
	LOOP_MOVER,
	LOOP_FLAME,
	LOOP_ROLLER,
	LOOP_CRUSHER,
	LOOP_PENDULUM,
	LOOP_GATE,
	LOOP_ICE,
	LOOP_PORTAL,
]


static func has_id(cue_id: String) -> bool:
	return ALL.has(cue_id)


static func all_ids() -> PackedStringArray:
	return ALL
