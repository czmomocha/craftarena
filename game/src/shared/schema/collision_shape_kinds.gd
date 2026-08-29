class_name SharedCollisionShapeKinds
extends RefCounted

## UGC 权威碰撞形状白名单。依据 CD-42 §1.1：盒、球、胶囊、平台预制复合体。
## 视觉网格不得作为 kind。
##
## `shape_is_valid` 是形状袋校验的唯一实现：`SharedComponentRecord` 的 `zone.shape`
## 与 `SharedGameplayAssetCatalog` 的权威碰撞都调它，避免同一份 kind→字段
## 对应关系抄两遍（ADR-0006 把权威碰撞从 `zone.shape` 挪到资产表时，两处必须
## 同时成立）。本文件不新增 `const ... : String`——`tools/content-validator`
## 的 GDScript↔Schema 同步检查按顺序比对本文件的字符串常量与
## `component_record.schema.json` 的 `collision_shape.oneOf`。

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


## 形状袋是否合法：kind 在白名单内，且该 kind 要求的字段恰好齐全且为整数。
static func shape_is_valid(shape: Dictionary) -> bool:
	if not shape.has("kind") or typeof(shape["kind"]) != TYPE_STRING:
		return false
	var kind: String = shape["kind"]
	if not contains(kind):
		return false
	match kind:
		BOX:
			return (
				_exactly(shape, PackedStringArray(["kind", "hx", "hy", "hz"]))
				and _is_int_field(shape, "hx")
				and _is_int_field(shape, "hy")
				and _is_int_field(shape, "hz")
			)
		SPHERE:
			return (
				_exactly(shape, PackedStringArray(["kind", "radius"]))
				and _is_int_field(shape, "radius")
			)
		CAPSULE:
			return (
				_exactly(shape, PackedStringArray(["kind", "radius", "cylinder_height"]))
				and _is_int_field(shape, "radius")
				and _is_int_field(shape, "cylinder_height")
			)
		PLATFORM_PREFAB:
			return (
				_exactly(shape, PackedStringArray(["kind", "prefab_id"]))
				and _int_at_least(shape, "prefab_id", 1)
			)
		_:
			return false


static func _exactly(source: Dictionary, keys: PackedStringArray) -> bool:
	if source.size() != keys.size():
		return false
	for key: String in keys:
		if not source.has(key):
			return false
	return true


static func _is_int_field(source: Dictionary, key: String) -> bool:
	if not source.has(key):
		return false
	return typeof(source[key]) == TYPE_INT


static func _int_at_least(source: Dictionary, key: String, minimum: int) -> bool:
	if not _is_int_field(source, key):
		return false
	var number: int = source[key]
	return number >= minimum
