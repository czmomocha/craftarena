extends GutTest

## L0 稳定 ID：0 为空，正整数有效。CONTRACT_VERSION 随信封冻结而不是随定点尺度。

const SharedIds := preload("res://src/shared/ids/shared_ids.gd")


func test_null_and_negative_ids_are_rejected() -> void:
	assert_false(SharedIds.is_valid(SharedIds.NULL_ID), "0 必须表示空 ID")
	assert_false(SharedIds.is_valid(-1), "负数不得当作稳定 ID")
	assert_false(SharedIds.is_valid(0), "NULL_ID 必须是 0")


func test_positive_ids_are_valid() -> void:
	assert_true(SharedIds.is_valid(1))
	assert_true(SharedIds.is_valid(9223372036854775807))


func test_contract_version_is_v1() -> void:
	assert_eq(SharedIds.CONTRACT_VERSION, 1)
