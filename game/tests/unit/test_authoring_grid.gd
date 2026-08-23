extends GutTest

## AuthoringGrid：默认格边 = Fixed.SCALE；拒绝非正格边；XYZ 必须整格；楼层 = y / cell 向零。

const AuthoringGrid := preload("res://src/creator/authoring_grid.gd")
const Fixed := preload("res://src/shared/fixed/fixed.gd")


func test_default_cell_is_one_presentation_meter() -> void:
	var grid: AuthoringGrid = AuthoringGrid.with_default_cell()
	assert_not_null(grid)
	assert_eq(grid.cell, Fixed.SCALE)
	assert_true(grid.accepts_xyz(0, 0, 0))
	assert_true(grid.accepts_xyz(Fixed.SCALE, -Fixed.SCALE, 2 * Fixed.SCALE))
	assert_false(grid.accepts_xyz(1, 0, 0))
	assert_false(grid.accepts_xyz(0, 1, 0))
	assert_false(grid.accepts_xyz(0, 0, -1))


func test_create_rejects_non_positive_cell() -> void:
	assert_null(AuthoringGrid.create(0))
	assert_null(AuthoringGrid.create(-Fixed.SCALE))


func test_custom_cell_and_floor_index_toward_zero() -> void:
	var grid: AuthoringGrid = AuthoringGrid.create(2)
	assert_not_null(grid)
	assert_true(grid.accepts_xyz(2, -4, 0))
	assert_false(grid.accepts_xyz(3, 0, 0))
	assert_eq(grid.floor_index(0), 0)
	assert_eq(grid.floor_index(4), 2)
	assert_eq(grid.floor_index(-2), -1)
	assert_eq(grid.floor_index(-4), -2)
