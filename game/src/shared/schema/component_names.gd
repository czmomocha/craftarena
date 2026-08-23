class_name SharedComponentNames
extends RefCounted

## CD-42 §1 首版共享组件名。顺序与 JSON Schema `components.properties` 对齐。
## 槽位语义、具体数值和复制策略表不在本文件，见 CD-63 与 CD-42 §1.2。

const TRANSFORM: String = "transform"
const VELOCITY: String = "velocity"
const HEALTH: String = "health"
const TEAM: String = "team"
const SCORE: String = "score"
const ZONE: String = "zone"
const SPAWNER: String = "spawner"
const HAZARD: String = "hazard"
const MOVER: String = "mover"
const INTERACTABLE: String = "interactable"
const CHECKPOINT: String = "checkpoint"
const PORTAL: String = "portal"
const DESTRUCTIBLE: String = "destructible"
const INVENTORY: String = "inventory"
const PATH_AGENT: String = "path_agent"
const BUILD_SLOT: String = "build_slot"
const TOWER: String = "tower"
const REPLICATION: String = "replication"

const ALL: PackedStringArray = [
	TRANSFORM,
	VELOCITY,
	HEALTH,
	TEAM,
	SCORE,
	ZONE,
	SPAWNER,
	HAZARD,
	MOVER,
	INTERACTABLE,
	CHECKPOINT,
	PORTAL,
	DESTRUCTIBLE,
	INVENTORY,
	PATH_AGENT,
	BUILD_SLOT,
	TOWER,
	REPLICATION,
]


static func contains(component_name: String) -> bool:
	return ALL.has(component_name)
