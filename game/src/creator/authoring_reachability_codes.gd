class_name AuthoringReachabilityCodes
extends RefCounted

## Publish-time reachability issue codes. Not EditCommand ops.
## Path / cycle rules: CD-32 §3 and CD-21 §4.2. Hop cap stays unlocked (CD-63).

const DANGLING_PORTAL: String = "dangling_portal"
const PORTAL_CYCLE: String = "portal_cycle"
const DUPLICATE_CHECKPOINT_ORDER: String = "duplicate_checkpoint_order"
const MISSING_MANDATORY_PATH: String = "missing_mandatory_path"
const UNREACHABLE_CHECKPOINT: String = "unreachable_checkpoint"

const ALL: PackedStringArray = [
	DANGLING_PORTAL,
	PORTAL_CYCLE,
	DUPLICATE_CHECKPOINT_ORDER,
	MISSING_MANDATORY_PATH,
	UNREACHABLE_CHECKPOINT,
]


static func contains(code: String) -> bool:
	return ALL.has(code)
