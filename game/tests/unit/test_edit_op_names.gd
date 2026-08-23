extends GutTest

## EDIT op 名必须与 CD-42 白名单一致。不把玩法对象表写进命令层。

const EditOpNames := preload("res://src/shared/commands/edit_op_names.gd")


func test_locked_ops_are_present() -> void:
	assert_true(EditOpNames.contains("place"))
	assert_true(EditOpNames.contains("remove"))
	assert_true(EditOpNames.contains("set_component"))


func test_unknown_or_empty_op_is_rejected() -> void:
	assert_false(EditOpNames.contains("spawn_script"))
	assert_false(EditOpNames.contains("PlaceIntent"))
	assert_false(EditOpNames.contains(""))


func test_op_list_size_matches_locked_catalog() -> void:
	assert_eq(EditOpNames.ALL.size(), 3)
