extends GutTest

## slow 层：依赖 world.gd，但不属于 fast 层，选择器不该把它选进来。

const World := preload("res://src/simulation/world.gd")


func test_search() -> void:
	assert_eq(World.new().cell(), 65536)
