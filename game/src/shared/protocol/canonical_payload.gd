class_name CanonicalPayload
extends RefCounted

## 命令 / 事件 payload 的白名单形状：可哈希、可跨端复现、不含引擎对象。
## 递归深度上限是编码安全阀，不是 CD-63 的内容性能预算。

const MAX_DEPTH: int = 8


static func is_allowed(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_DEPTH:
		return false
	var value_type: int = typeof(value)
	match value_type:
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			return _array_is_allowed(value, depth)
		TYPE_DICTIONARY:
			return _dictionary_is_allowed(value, depth)
		_:
			return false


static func _array_is_allowed(value: Variant, depth: int) -> bool:
	if not value is Array:
		return false
	var items: Array = value
	for item: Variant in items:
		if not is_allowed(item, depth + 1):
			return false
	return true


static func _dictionary_is_allowed(value: Variant, depth: int) -> bool:
	if not value is Dictionary:
		return false
	var dict: Dictionary = value
	var keys: Array = dict.keys()
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING:
			return false
		if not is_allowed(dict[key], depth + 1):
			return false
	return true
