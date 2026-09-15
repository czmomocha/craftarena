class_name OfficialBastionBlueprints
extends RefCounted

## Official BASTION blueprint ids for matchmaking JSON.
## HTTP never accepts res:// paths or UGC documents.
## Match ids live here and in `backend/contracts/src/official_blueprints.ts`.
##
## Seats and the match HTTP gameplay discriminant are E3. This file only
## names the blueprint and the on-disk AuthoringDocument.

const DEFAULT_ID: String = "blueprint_01"
const BLUEPRINT_01: String = "blueprint_01"
const MATCH_IDS: PackedStringArray = [
	BLUEPRINT_01,
]
const _DOCUMENT_DIR: String = "res://content/official/bastion"


static func is_id(value: String) -> bool:
	return MATCH_IDS.has(value)


static func all_match_ids() -> PackedStringArray:
	return MATCH_IDS


static func normalize_id(raw: String) -> String:
	var trimmed: String = raw.strip_edges()
	if is_id(trimmed):
		return trimmed
	return ""


static func document_path(blueprint_id: String) -> String:
	var id: String = normalize_id(blueprint_id)
	if id == "":
		return ""
	return "%s/%s.json" % [_DOCUMENT_DIR, id]


static func default_path() -> String:
	return document_path(DEFAULT_ID)
