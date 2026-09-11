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

const ALL: PackedStringArray = [
	STEP,
	JUMP,
	LAND,
	PICKUP,
	CRATE,
	HAZARD_WARN,
	PORTAL,
	FINISH,
]


static func has_id(cue_id: String) -> bool:
	return ALL.has(cue_id)


static func all_ids() -> PackedStringArray:
	return ALL
