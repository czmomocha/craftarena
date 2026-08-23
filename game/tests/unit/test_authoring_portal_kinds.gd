extends GutTest

## AuthoringPortalKinds：CD-21 成对 / 单向 / 编辑期悬空。发布期循环在 AuthoringReachability。

const AuthoringPortalKinds := preload("res://src/creator/authoring_portal_kinds.gd")


func test_kind_whitelist() -> void:
	assert_eq(AuthoringPortalKinds.ALL.size(), 3)
	assert_true(AuthoringPortalKinds.contains(AuthoringPortalKinds.TWO_WAY))
	assert_true(AuthoringPortalKinds.contains(AuthoringPortalKinds.ONE_WAY))
	assert_true(AuthoringPortalKinds.contains(AuthoringPortalKinds.DANGLING))
	assert_false(AuthoringPortalKinds.contains("invalid"))
	assert_false(AuthoringPortalKinds.contains("reachable"))
