class_name AuthoringGrid
extends RefCounted

## Authoring XYZ lattice. Cell edge is Q48.16. Default is Fixed.SCALE
## (1 presentation meter, ADR-0005). Floor index is y / cell toward zero.
## Does not invent a separate story height. UI snap is later; this type only accepts or rejects.

var cell: int = 0


static func create(cell: int) -> AuthoringGrid:
	if cell < 1:
		return null
	var grid: AuthoringGrid = AuthoringGrid.new()
	grid.cell = cell
	return grid


static func with_default_cell() -> AuthoringGrid:
	return create(Fixed.SCALE)


func accepts_xyz(x: int, y: int, z: int) -> bool:
	return _on_cell(x) and _on_cell(y) and _on_cell(z)


func floor_index(y: int) -> int:
	return y / cell


func _on_cell(value: int) -> bool:
	return value % cell == 0
