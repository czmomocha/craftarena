class_name StateHasher
extends RefCounted

## 关键状态哈希。只吃 CanonicalPayload 白名单，用 SHA-256。
## 不用 Variant.hash()：那个不保证版本间稳定，也不能进回放。

var _bytes: PackedByteArray = PackedByteArray()


func reset() -> void:
	_bytes = PackedByteArray()


func write_u8(value: int) -> void:
	_bytes.append(value & 0xFF)


func write_s64(value: int) -> void:
	for shift_index: int in range(8):
		_bytes.append((value >> (shift_index * 8)) & 0xFF)


func write_bool(value: bool) -> void:
	if value:
		write_u8(1)
	else:
		write_u8(0)


func write_string(value: String) -> void:
	var utf8: PackedByteArray = value.to_utf8_buffer()
	write_s64(utf8.size())
	_bytes.append_array(utf8)


func write_canonical(value: Variant) -> bool:
	if not CanonicalPayload.is_allowed(value):
		return false
	_feed(value)
	return true


func digest_hex() -> String:
	var ctx: HashingContext = HashingContext.new()
	var start_err: Error = ctx.start(HashingContext.HASH_SHA256)
	if start_err != OK:
		return ""
	if not _bytes.is_empty():
		var update_err: Error = ctx.update(_bytes)
		if update_err != OK:
			return ""
	var digest: PackedByteArray = ctx.finish()
	return digest.hex_encode()


func debug_bytes_hex() -> String:
	return _bytes.hex_encode()


func _feed(value: Variant) -> void:
	var value_type: int = typeof(value)
	write_u8(value_type)
	match value_type:
		TYPE_NIL:
			return
		TYPE_BOOL:
			var flag: bool = value
			write_bool(flag)
		TYPE_INT:
			var number: int = value
			write_s64(number)
		TYPE_STRING:
			var text: String = value
			write_string(text)
		TYPE_ARRAY:
			_feed_array(value)
		TYPE_DICTIONARY:
			_feed_dictionary(value)


func _feed_array(value: Variant) -> void:
	var items: Array = value
	write_s64(items.size())
	for item: Variant in items:
		_feed(item)


func _feed_dictionary(value: Variant) -> void:
	var dict: Dictionary = value
	var keys: Array = dict.keys()
	keys.sort()
	write_s64(keys.size())
	for key: Variant in keys:
		var key_text: String = key
		write_string(key_text)
		_feed(dict[key])
