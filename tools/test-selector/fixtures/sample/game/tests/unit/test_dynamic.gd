extends GutTest

## 依赖一个「动态加载」的源文件，所以本脚本永远受影响。

const DynamicOnly := preload("res://src/client/dynamic_only.gd")


func test_fetch_missing() -> void:
	assert_null(DynamicOnly.new().fetch("res://nope.tres"))
