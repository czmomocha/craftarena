class_name AuthoringPortalKinds
extends RefCounted

## Directed portal_link classification for AuthoringWorld.
## Pairing rules: CD-21 §4.2. Dangling is legal while authoring; publish reachability is later.

const TWO_WAY: String = "two_way"
const ONE_WAY: String = "one_way"
const DANGLING: String = "dangling"

const ALL: PackedStringArray = [
	TWO_WAY,
	ONE_WAY,
	DANGLING,
]


static func contains(kind_name: String) -> bool:
	return ALL.has(kind_name)
