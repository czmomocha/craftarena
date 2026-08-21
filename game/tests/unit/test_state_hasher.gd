extends GutTest

## 状态哈希必须跨调用稳定，且 Dictionary 插入顺序不得进入摘要。

const StateHasher := preload("res://src/shared/protocol/state_hasher.gd")

const SHA256_EMPTY: String = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
const SHA256_EIGHT_ZERO_BYTES: String = "af5570f5a1810b7af78caf4bc70a660f0df51e42baf91d4de5b2328de0e83dfc"
const SHA256_EIGHT_FF_BYTES: String = "12a3ae445661ce5dee78d0650d33362dec29c4f82af05e7e57fb595bbbacf0ca"


func test_empty_hasher_matches_sha256_of_empty_input() -> void:
	var hasher: StateHasher = StateHasher.new()
	assert_eq(hasher.digest_hex(), SHA256_EMPTY)


func test_little_endian_s64_encoding() -> void:
	var hasher: StateHasher = StateHasher.new()
	hasher.write_s64(0)
	assert_eq(hasher.debug_bytes_hex(), "0000000000000000")
	assert_eq(hasher.digest_hex(), SHA256_EIGHT_ZERO_BYTES)
	hasher.reset()
	hasher.write_s64(-1)
	assert_eq(hasher.debug_bytes_hex(), "ffffffffffffffff")
	assert_eq(hasher.digest_hex(), SHA256_EIGHT_FF_BYTES)
	hasher.reset()
	hasher.write_s64(1)
	assert_eq(hasher.debug_bytes_hex(), "0100000000000000")


func test_same_canonical_payload_hashes_equal_regardless_of_key_order() -> void:
	var left: StateHasher = StateHasher.new()
	var right: StateHasher = StateHasher.new()
	assert_true(left.write_canonical({"b": 2, "a": 1}))
	assert_true(right.write_canonical({"a": 1, "b": 2}))
	assert_eq(left.digest_hex(), right.digest_hex())
	assert_false(left.digest_hex().is_empty())


func test_write_order_changes_digest() -> void:
	var left: StateHasher = StateHasher.new()
	var right: StateHasher = StateHasher.new()
	left.write_s64(1)
	left.write_s64(2)
	right.write_s64(2)
	right.write_s64(1)
	assert_ne(left.digest_hex(), right.digest_hex())


func test_canonical_write_rejects_float() -> void:
	var hasher: StateHasher = StateHasher.new()
	assert_false(hasher.write_canonical(1.25))
	assert_eq(hasher.digest_hex(), SHA256_EMPTY)
