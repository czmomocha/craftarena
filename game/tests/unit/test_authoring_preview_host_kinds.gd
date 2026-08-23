extends GutTest

const AuthoringPreviewHostKinds := preload("res://src/creator/authoring_preview_host_kinds.gd")


func test_kind_whitelist() -> void:
	assert_eq(AuthoringPreviewHostKinds.ALL.size(), 2)
	assert_true(AuthoringPreviewHostKinds.contains(AuthoringPreviewHostKinds.WINDOW))
	assert_true(AuthoringPreviewHostKinds.contains(AuthoringPreviewHostKinds.TAB))
	assert_false(AuthoringPreviewHostKinds.contains("mobile"))
