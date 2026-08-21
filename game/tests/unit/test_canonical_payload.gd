extends GutTest

## CanonicalPayload 拒绝浮点、引擎对象和非字符串键，保证后续哈希可复现。

const CanonicalPayload := preload("res://src/shared/protocol/canonical_payload.gd")


func test_scalars_and_nested_containers_are_allowed() -> void:
	assert_true(CanonicalPayload.is_allowed(null))
	assert_true(CanonicalPayload.is_allowed(true))
	assert_true(CanonicalPayload.is_allowed(3))
	assert_true(CanonicalPayload.is_allowed("MoveIntent"))
	assert_true(CanonicalPayload.is_allowed({"intent": "MoveIntent", "dx": 1}))
	assert_true(CanonicalPayload.is_allowed([1, "a", {"k": 2}]))


func test_float_is_rejected() -> void:
	assert_false(CanonicalPayload.is_allowed(1.5))
	assert_false(CanonicalPayload.is_allowed({"speed": 1.0}))


func test_engine_object_is_rejected() -> void:
	var node: Node = Node.new()
	autofree(node)
	assert_false(CanonicalPayload.is_allowed(node))
	assert_false(CanonicalPayload.is_allowed({"node": node}))


func test_non_string_dictionary_key_is_rejected() -> void:
	assert_false(CanonicalPayload.is_allowed({1: "x"}))


func test_depth_limit_rejects_excessive_nesting() -> void:
	var nested: Variant = 0
	for _i: int in range(CanonicalPayload.MAX_DEPTH + 2):
		nested = [nested]
	assert_false(CanonicalPayload.is_allowed(nested))
