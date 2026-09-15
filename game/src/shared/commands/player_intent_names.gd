class_name PlayerIntentNames
extends RefCounted

## 客户端允许提交的 Intent 名。清单分别来自 CD-21 §8 与 CD-22 §7.2 / §7.3。
## 本文件只锁名字，不锁 payload 内的数值尺度。
## PlaceObstacle / LockSetup 是 §7.2 互设障碍两步的线上名；DonateResource 仍在
## 清单里但没有线上 id（M7）。

const MOVE: String = "MoveIntent"
const JUMP: String = "JumpIntent"
const SHOVE: String = "ShoveIntent"
const USE_ITEM: String = "UseItemIntent"
const SPRINT: String = "SprintIntent"
const INTERACT: String = "InteractIntent"
const RESET_TO_CHECKPOINT: String = "ResetToCheckpointIntent"
const BUILD_TOWER: String = "BuildTowerIntent"
const UPGRADE_TOWER: String = "UpgradeTowerIntent"
const SELL_TOWER: String = "SellTowerIntent"
const SET_TOWER_PRIORITY: String = "SetTowerPriorityIntent"
const DONATE_RESOURCE: String = "DonateResourceIntent"
const PLACE_OBSTACLE: String = "PlaceObstacleIntent"
const LOCK_SETUP: String = "LockSetupIntent"

const ALL: PackedStringArray = [
	MOVE,
	JUMP,
	SHOVE,
	USE_ITEM,
	SPRINT,
	INTERACT,
	RESET_TO_CHECKPOINT,
	BUILD_TOWER,
	UPGRADE_TOWER,
	SELL_TOWER,
	SET_TOWER_PRIORITY,
	DONATE_RESOURCE,
	PLACE_OBSTACLE,
	LOCK_SETUP,
]


static func contains(intent_name: String) -> bool:
	return ALL.has(intent_name)
