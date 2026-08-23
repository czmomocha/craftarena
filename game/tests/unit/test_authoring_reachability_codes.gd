extends GutTest

## AuthoringReachabilityCodes：发布期通路 / 循环问题名。不含 hop 上限。

const Codes := preload("res://src/creator/authoring_reachability_codes.gd")


func test_code_whitelist() -> void:
	assert_eq(Codes.ALL.size(), 5)
	assert_true(Codes.contains(Codes.DANGLING_PORTAL))
	assert_true(Codes.contains(Codes.PORTAL_CYCLE))
	assert_true(Codes.contains(Codes.DUPLICATE_CHECKPOINT_ORDER))
	assert_true(Codes.contains(Codes.MISSING_MANDATORY_PATH))
	assert_true(Codes.contains(Codes.UNREACHABLE_CHECKPOINT))
	assert_false(Codes.contains("reachable"))
	assert_false(Codes.contains("two_way"))
