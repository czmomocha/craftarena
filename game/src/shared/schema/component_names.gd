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
## 引用平台内置 GameplayAsset 的不可变玩法版本（ADR-0006）。缺省视为
## `SharedGameplayAssetCatalog.LATTICE_CELL_ID`，即"占满一格"。
const GAMEPLAY_ASSET: String = "gameplay_asset"

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
	GAMEPLAY_ASSET,
]


static func contains(component_name: String) -> bool:
	return ALL.has(component_name)
