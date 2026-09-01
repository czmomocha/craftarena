extends GutTest

const Fixed := preload("res://src/shared/fixed.gd")


func test_scale() -> void:
	assert_eq(Fixed.SCALE, 65536)
