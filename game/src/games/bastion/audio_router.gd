class_name BastionAudioRouter
extends RefCounted

## Unique BASTION event → cue id table. Gameplay code names events here;
## `game/src/audio/**` never sees these verbs.
##
## M6 E4 reuses already-registered UI / hit / break / settled cues.
## No new catalog ids and no new OGG files.

const CatalogGd := preload("res://src/shared/schema/audio_cue_catalog.gd")

const EVENT_SELECT: String = "select"
const EVENT_CONFIRM: String = "confirm"
const EVENT_PLACE: String = "place"
const EVENT_LOCK: String = "lock"
const EVENT_REVEAL: String = "reveal"
const EVENT_BUILD: String = "build"
const EVENT_UPGRADE: String = "upgrade"
const EVENT_SELL: String = "sell"
const EVENT_HIT: String = "hit"
const EVENT_LEAK: String = "leak"
const EVENT_KILL: String = "kill"
const EVENT_CORE: String = "core"
const EVENT_SETTLED: String = "settled"

const EVENTS: PackedStringArray = [
	EVENT_SELECT,
	EVENT_CONFIRM,
	EVENT_PLACE,
	EVENT_LOCK,
	EVENT_REVEAL,
	EVENT_BUILD,
	EVENT_UPGRADE,
	EVENT_SELL,
	EVENT_HIT,
	EVENT_LEAK,
	EVENT_KILL,
	EVENT_CORE,
	EVENT_SETTLED,
]

const _MAP: Dictionary = {
	EVENT_SELECT: CatalogGd.UI_SELECT,
	EVENT_CONFIRM: CatalogGd.UI_CONFIRM,
	EVENT_PLACE: CatalogGd.UI_CONFIRM,
	EVENT_LOCK: CatalogGd.CHECKPOINT,
	EVENT_REVEAL: CatalogGd.PORTAL,
	EVENT_BUILD: CatalogGd.USE_ITEM,
	EVENT_UPGRADE: CatalogGd.CHECKPOINT,
	EVENT_SELL: CatalogGd.RESET,
	EVENT_HIT: CatalogGd.CRATE,
	EVENT_LEAK: CatalogGd.FAIL_RANGE,
	EVENT_KILL: CatalogGd.BREAK_RUBBLE,
	EVENT_CORE: CatalogGd.BREAK_CORE,
	EVENT_SETTLED: CatalogGd.SETTLED,
}


static func cue(event: String) -> String:
	var raw: Variant = _MAP.get(event, "")
	if typeof(raw) != TYPE_STRING:
		return ""
	var cue_id: String = raw
	return cue_id


static func has_event(event: String) -> bool:
	return _MAP.has(event)
