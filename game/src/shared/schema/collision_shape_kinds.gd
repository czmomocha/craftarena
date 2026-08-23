class_name SharedCollisionShapeKinds
extends RefCounted

## UGC 权威碰撞形状白名单。依据 CD-42 §1.1：盒、球、胶囊、平台预制复合体。
## 视觉网格不得作为 kind。

const BOX: String = "box"
const SPHERE: String = "sphere"
const CAPSULE: String = "capsule"
const PLATFORM_PREFAB: String = "platform_prefab"

const ALL: PackedStringArray = [
	BOX,
	SPHERE,
	CAPSULE,
	PLATFORM_PREFAB,
]


static func contains(kind: String) -> bool:
	return ALL.has(kind)
