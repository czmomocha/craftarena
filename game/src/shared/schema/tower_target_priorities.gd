class_name SharedTowerTargetPriorities
extends RefCounted

## BASTION 炮塔目标优先级白名单。名字对应 CD-22 §5.1：最前、最近、最强、最弱。
## 本文件只锁 v1 四个标识符；不锁射程、冷却或伤害公式。

const FRONT: String = "front"
const NEAREST: String = "nearest"
const STRONGEST: String = "strongest"
const WEAKEST: String = "weakest"

const ALL: PackedStringArray = [
	FRONT,
	NEAREST,
	STRONGEST,
	WEAKEST,
]


static func contains(priority: String) -> bool:
	return ALL.has(priority)
