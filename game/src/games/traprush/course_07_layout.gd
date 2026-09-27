class_name TraprushCourse07Layout
extends RefCounted

## Terrace Circuit geometry. Vector2i is (x, z). Standing y {-6,-2,+2,+6}.
## SW is sealed from the y=-6 chassis; other terraces are cliffs.

const TERRACE_SW: int = 0
const TERRACE_SE: int = 1
const TERRACE_NE: int = 2
const TERRACE_NW: int = 3
const TERRACE_COUNT: int = 4
const STANDING: Array[int] = [-6, -2, 2, 6]
const MIN_TERRACE_MOVES: int = 120

const PORTAL_SW: int = 40
const PORTAL_SE_LAND: int = 41
const PORTAL_SE_EXIT: int = 42
const PORTAL_NE_LAND: int = 43
const PORTAL_NE_EXIT: int = 44
const PORTAL_NW_LAND: int = 45
const LIFT_SE: int = 50
const LIFT_NE: int = 51
const LIFT_NW: int = 52
const FINISH_ID: int = 30
const ENERGY_WALL_ID: int = 60
const BOMB_ID: int = 61
const CHECKPOINT_ID_START: int = 200
const FLOOR_ID_START: int = 400
const WALL_ID_START: int = 2000
const GADGET_ID_START: int = 70


static func floor_y(standing_y: int) -> int:
	return standing_y - 1


static func standing_y(terrace: int) -> int:
	return STANDING[terrace]


static func x_lo(terrace: int) -> int:
	if terrace == TERRACE_SE or terrace == TERRACE_NE:
		return 1
	return -6


static func x_hi(terrace: int) -> int:
	if terrace == TERRACE_SW or terrace == TERRACE_NW:
		return 0
	return 6


static func z_lo(terrace: int) -> int:
	if terrace == TERRACE_NE or terrace == TERRACE_NW:
		return -6
	return 1


static func z_hi(terrace: int) -> int:
	if terrace == TERRACE_SW or terrace == TERRACE_SE:
		return 6
	return 0


static func in_playable(terrace: int, x: int, z: int) -> bool:
	return x >= x_lo(terrace) and x <= x_hi(terrace) and z >= z_lo(terrace) and z <= z_hi(terrace)


static func lift_xz(terrace: int) -> Vector2i:
	if terrace == TERRACE_SE:
		return Vector2i(6, 6)
	if terrace == TERRACE_NE:
		return Vector2i(1, -6)
	if terrace == TERRACE_NW:
		return Vector2i(-6, -6)
	return Vector2i(99, 99)


static func snake_of(terrace: int) -> Array[Vector2i]:
	var skip: Dictionary = {}
	skip[_key(alcove_of(terrace))] = true
	var reserved: Vector2i = lift_xz(terrace)
	if reserved.x != 99:
		skip[_key(reserved)] = true
	var x0: int = x_lo(terrace)
	var x1: int = x_hi(terrace)
	var z0: int = z_lo(terrace)
	var z1: int = z_hi(terrace)
	if terrace == TERRACE_SW:
		x1 = -1
		z0 = 2
	return _comb(x0, x1, z0, z1, skip)


static func alcove_of(terrace: int) -> Vector2i:
	if terrace == TERRACE_SW:
		return Vector2i(0, 6)
	if terrace == TERRACE_SE:
		return Vector2i(6, 4)
	if terrace == TERRACE_NE:
		return Vector2i(1, 0)
	return Vector2i(-6, 0)


static func wall_cells(terrace: int) -> Array[Vector2i]:
	var used: Dictionary = {}
	for cell: Vector2i in snake_of(terrace):
		used[_key(cell)] = true
	used[_key(alcove_of(terrace))] = true
	if terrace == TERRACE_SE:
		used[_key(energy_wall_xz())] = true
	var reserved: Vector2i = lift_xz(terrace)
	if reserved.x != 99:
		used[_key(reserved)] = true
	var walls: Array[Vector2i] = []
	var z: int = z_lo(terrace)
	while z <= z_hi(terrace):
		var x: int = x_lo(terrace)
		while x <= x_hi(terrace):
			var cell: Vector2i = Vector2i(x, z)
			if not used.has(_key(cell)):
				walls.append(cell)
			x += 1
		z += 1
	return walls


static func gadget_cells(terrace: int) -> Array[Vector2i]:
	var walls: Array[Vector2i] = wall_cells(terrace)
	var picked: Array[Vector2i] = []
	var i: int = 0
	while i < walls.size() and picked.size() < 3:
		var cell: Vector2i = walls[i]
		if cell != energy_wall_xz() or terrace != TERRACE_SE:
			picked.append(cell)
		i += 1
	return picked


static func energy_wall_xz() -> Vector2i:
	return Vector2i(3, 2)


static func bomb_xz() -> Vector2i:
	return Vector2i(3, 1)


static func pendulum_xz() -> Vector2i:
	return Vector2i(4, 0)


static func conveyor_xz() -> Vector2i:
	return Vector2i(2, 0)


static func ice_xz() -> Vector2i:
	return Vector2i(3, 0)


static func crusher_xz() -> Vector2i:
	return Vector2i(5, 0)


static func wr_cells(terrace: int) -> Array[Vector2i]:
	var snake: Array[Vector2i] = snake_of(terrace)
	var n: int = snake.size()
	var stops: PackedInt32Array = _zigzag_stops(n)
	var cells: Array[Vector2i] = []
	var idx: int = stops[0]
	cells.append(snake[idx])
	var s: int = 1
	while s < stops.size():
		var target: int = stops[s]
		_walk_snake(cells, snake, idx, target)
		idx = target
		s += 1
	var extra: Vector2i = alcove_of(terrace)
	if extra != snake[idx]:
		cells.append(extra)
	return cells


static func wr_move_count(terrace: int) -> int:
	var cells: Array[Vector2i] = wr_cells(terrace)
	return maxi(cells.size() - 1, 0)


static func checkpoint_cells(terrace: int) -> Array[Vector2i]:
	var snake: Array[Vector2i] = snake_of(terrace)
	var stops: PackedInt32Array = _zigzag_stops(snake.size())
	var seen: Dictionary = {}
	var cells: Array[Vector2i] = []
	var s: int = 0
	while s < stops.size():
		var idx: int = stops[s]
		if not seen.has(idx):
			seen[idx] = true
			cells.append(snake[idx])
		s += 1
	return cells


static func wall_height(terrace: int) -> int:
	if terrace == TERRACE_NW:
		return 2
	return 4


static func skip_floor(x: int, y: int, z: int) -> bool:
	var cell: Vector2i = Vector2i(x, z)
	if y == floor_y(-6):
		if cell == lift_xz(TERRACE_SE) or cell == lift_xz(TERRACE_NE) or cell == lift_xz(TERRACE_NW):
			return true
		if cell == pendulum_xz() or cell == Vector2i(pendulum_xz().x + 2, pendulum_xz().y):
			return true
		if cell == conveyor_xz() or cell == ice_xz() or cell == crusher_xz():
			return true
	var terrace: int = 0
	while terrace < TERRACE_COUNT:
		if y == floor_y(standing_y(terrace)):
			if cell == lift_xz(terrace):
				return true
			var gadgets: Array[Vector2i] = gadget_cells(terrace)
			if not gadgets.is_empty() and gadgets[0] == cell:
				return true
		terrace += 1
	return false


static func _comb(x0: int, x1: int, z0: int, z1: int, skip: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var going_pos: bool = true
	var last_x: int = x0
	var z: int = z0
	while z <= z1:
		var is_path_row: bool = ((z - z0) % 2) == 0
		if is_path_row:
			if going_pos:
				var x: int = x0
				while x <= x1:
					if _try_append(path, skip, x, z):
						last_x = x
					x += 1
			else:
				var x_back: int = x1
				while x_back >= x0:
					if _try_append(path, skip, x_back, z):
						last_x = x_back
					x_back -= 1
			going_pos = not going_pos
		else:
			_try_append(path, skip, last_x, z)
		z += 1
	return path


static func _try_append(path: Array[Vector2i], skip: Dictionary, x: int, z: int) -> bool:
	var cell: Vector2i = Vector2i(x, z)
	if skip.has(_key(cell)):
		return false
	path.append(cell)
	return true


static func _zigzag_stops(n: int) -> PackedInt32Array:
	var stops: PackedInt32Array = PackedInt32Array()
	stops.append(0)
	if n < 2:
		return stops
	var moves: int = 0
	var k: int = 0
	var prev: int = 0
	while moves < MIN_TERRACE_MOVES and k < 12:
		var far: int = n - 1 - k
		if far <= prev:
			break
		stops.append(far)
		moves += far - prev
		prev = far
		if moves >= MIN_TERRACE_MOVES:
			break
		var near: int = k + 1
		if near >= far:
			break
		stops.append(near)
		moves += prev - near
		prev = near
		k += 1
	if stops[stops.size() - 1] != n - 1:
		stops.append(n - 1)
	return stops


static func _walk_snake(
	cells: Array[Vector2i], snake: Array[Vector2i], from_idx: int, to_idx: int
) -> void:
	if from_idx == to_idx:
		return
	var step: int = 1
	if to_idx < from_idx:
		step = -1
	var i: int = from_idx
	while i != to_idx:
		i += step
		cells.append(snake[i])


static func _key(cell: Vector2i) -> int:
	return cell.x * 1000 + cell.y
