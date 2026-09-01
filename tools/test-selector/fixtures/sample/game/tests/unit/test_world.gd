extends GutTest

const World := preload("res://src/simulation/world.gd")


func test_cell() -> void:
	assert_eq(World.new().cell(), 65536)
