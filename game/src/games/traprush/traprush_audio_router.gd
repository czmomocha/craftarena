class_name TraprushAudioRouter
extends RefCounted

## Unique TRAPRUSH event → cue id table. Gameplay code names events here;
## `game/src/audio/**` never sees these verbs.

const CatalogGd := preload("res://src/shared/schema/audio_cue_catalog.gd")

const EVENT_STEP: String = "step"
const EVENT_JUMP: String = "jump"
const EVENT_LAND: String = "land"
const EVENT_SPRINT: String = "sprint"
const EVENT_SHOVE: String = "shove"
const EVENT_USE_ITEM: String = "use_item"
const EVENT_PICKUP: String = "pickup"
const EVENT_BREAK_CRATE: String = "break_crate"
const EVENT_BREAK_RUBBLE: String = "break_rubble"
const EVENT_BREAK_CORE: String = "break_core"
const EVENT_BREAK_WALL: String = "break_wall"
const EVENT_CHECKPOINT: String = "checkpoint"
const EVENT_RESET: String = "reset"
const EVENT_FAIL_HAZARD: String = "fail_hazard"
const EVENT_FAIL_RANGE: String = "fail_range"
const EVENT_FAIL_CRUSH: String = "fail_crush"
const EVENT_PORTAL: String = "portal"
const EVENT_FINISH: String = "finish"
const EVENT_SETTLED: String = "settled"
const EVENT_HAZARD_WARN: String = "hazard_warn"
const EVENT_LOOP_CONVEYOR: String = "loop_conveyor"
const EVENT_LOOP_MOVER: String = "loop_mover"
const EVENT_LOOP_FLAME: String = "loop_flame"
const EVENT_LOOP_ROLLER: String = "loop_roller"
const EVENT_LOOP_CRUSHER: String = "loop_crusher"
const EVENT_LOOP_PENDULUM: String = "loop_pendulum"
const EVENT_LOOP_GATE: String = "loop_gate"
const EVENT_LOOP_ICE: String = "loop_ice"
const EVENT_LOOP_PORTAL: String = "loop_portal"

const EVENTS: PackedStringArray = [
	EVENT_STEP,
	EVENT_JUMP,
	EVENT_LAND,
	EVENT_SPRINT,
	EVENT_SHOVE,
	EVENT_USE_ITEM,
	EVENT_PICKUP,
	EVENT_BREAK_CRATE,
	EVENT_BREAK_RUBBLE,
	EVENT_BREAK_CORE,
	EVENT_BREAK_WALL,
	EVENT_CHECKPOINT,
	EVENT_RESET,
	EVENT_FAIL_HAZARD,
	EVENT_FAIL_RANGE,
	EVENT_FAIL_CRUSH,
	EVENT_PORTAL,
	EVENT_FINISH,
	EVENT_SETTLED,
	EVENT_HAZARD_WARN,
	EVENT_LOOP_CONVEYOR,
	EVENT_LOOP_MOVER,
	EVENT_LOOP_FLAME,
	EVENT_LOOP_ROLLER,
	EVENT_LOOP_CRUSHER,
	EVENT_LOOP_PENDULUM,
	EVENT_LOOP_GATE,
	EVENT_LOOP_ICE,
	EVENT_LOOP_PORTAL,
]

const _MAP: Dictionary = {
	EVENT_STEP: CatalogGd.STEP,
	EVENT_JUMP: CatalogGd.JUMP,
	EVENT_LAND: CatalogGd.LAND,
	EVENT_SPRINT: CatalogGd.SPRINT,
	EVENT_SHOVE: CatalogGd.SHOVE,
	EVENT_USE_ITEM: CatalogGd.USE_ITEM,
	EVENT_PICKUP: CatalogGd.PICKUP,
	EVENT_BREAK_CRATE: CatalogGd.CRATE,
	EVENT_BREAK_RUBBLE: CatalogGd.BREAK_RUBBLE,
	EVENT_BREAK_CORE: CatalogGd.BREAK_CORE,
	EVENT_BREAK_WALL: CatalogGd.BREAK_WALL,
	EVENT_CHECKPOINT: CatalogGd.CHECKPOINT,
	EVENT_RESET: CatalogGd.RESET,
	EVENT_FAIL_HAZARD: CatalogGd.FAIL_HAZARD,
	EVENT_FAIL_RANGE: CatalogGd.FAIL_RANGE,
	EVENT_FAIL_CRUSH: CatalogGd.FAIL_CRUSH,
	EVENT_PORTAL: CatalogGd.PORTAL,
	EVENT_FINISH: CatalogGd.FINISH,
	EVENT_SETTLED: CatalogGd.SETTLED,
	EVENT_HAZARD_WARN: CatalogGd.HAZARD_WARN,
	EVENT_LOOP_CONVEYOR: CatalogGd.LOOP_CONVEYOR,
	EVENT_LOOP_MOVER: CatalogGd.LOOP_MOVER,
	EVENT_LOOP_FLAME: CatalogGd.LOOP_FLAME,
	EVENT_LOOP_ROLLER: CatalogGd.LOOP_ROLLER,
	EVENT_LOOP_CRUSHER: CatalogGd.LOOP_CRUSHER,
	EVENT_LOOP_PENDULUM: CatalogGd.LOOP_PENDULUM,
	EVENT_LOOP_GATE: CatalogGd.LOOP_GATE,
	EVENT_LOOP_ICE: CatalogGd.LOOP_ICE,
	EVENT_LOOP_PORTAL: CatalogGd.LOOP_PORTAL,
}

const KIND_RUBBLE: String = "rubble"
const KIND_CORE: String = "core"
const KIND_WALL: String = "wall"


static func cue(event: String) -> String:
	var raw: Variant = _MAP.get(event, "")
	if typeof(raw) != TYPE_STRING:
		return ""
	var cue_id: String = raw
	return cue_id


static func has_event(event: String) -> bool:
	return _MAP.has(event)


static func break_event(kind: String) -> String:
	match kind:
		KIND_RUBBLE:
			return EVENT_BREAK_RUBBLE
		KIND_CORE:
			return EVENT_BREAK_CORE
		KIND_WALL:
			return EVENT_BREAK_WALL
		_:
			return EVENT_BREAK_CRATE


static func fail_event(reason: String) -> String:
	match reason:
		PlaySetback.HAZARD:
			return EVENT_FAIL_HAZARD
		PlaySetback.OUT_OF_RANGE:
			return EVENT_FAIL_RANGE
		PlaySetback.CRUSHED:
			return EVENT_FAIL_CRUSH
		_:
			return ""
