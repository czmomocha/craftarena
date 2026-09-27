class_name TraprushCourse08Layout
extends RefCounted

## Benchmark parkour `course_08` geometry. Vector2i is (x, z).
## Aerial yard: no chassis fill. Floors sit at standing − 1.

const YAW_NEG_Z: int = 0
const YAW_NEG_X: int = Fixed.BAM_QUARTER

const SPEED_CRUSHER: int = Fixed.SCALE / 16
const SPEED_BASKET: int = Fixed.SCALE / 16
const SPEED_PENDULUM_LANE: int = Fixed.SCALE / 16
const SPEED_PENDULUM_END: int = Fixed.SCALE / 8
const FLAME_COOLDOWN: int = 48
const ROLLER_COOLDOWN: int = 40

const FINISH_ID: int = 30
const CHECKPOINT_ID_START: int = 200
const CHECKPOINT_COUNT: int = 8
const PORTAL_ID_START: int = 10
const FLOOR_ID_START: int = 400
const RAIL_ID_START: int = 2000
const GADGET_ID_START: int = 70

const X_MIN: int = -41
const X_MAX: int = 44
const Z_MIN: int = -40
const Z_MAX: int = 38
const Y_MIN: int = -1
const Y_MAX: int = 8

const SPAWN_XZ := Vector2i(42, 36)
const CP1_XZ := Vector2i(24, 36)
const CP2_XZ := Vector2i(6, 36)
const CP3_XZ := Vector2i(3, 15)
const CP4_XZ := Vector2i(3, 0)
const CP5_XZ := Vector2i(-22, -4)
const CP6_XZ := Vector2i(-35, -4)
const CP7_XZ := Vector2i(-38, -22)
const FINISH_XZ := Vector2i(-38, -39)

const DASH_S2 := Vector2i(21, 36)
const DASH_LAND_B := Vector2i(3, 28)
const DASH_S6 := Vector2i(-5, -4)
const DASH_LAND_D := Vector2i(-38, -9)
const BOMB_XZ := Vector2i(-23, -4)
const WALL_XZ := Vector2i(-26, -4)
const STAND_Q := Vector2i(-26, -5)

const CRUSHER_A := Vector2i(3, 24)
const CRUSHER_B := Vector2i(3, 21)
const PEND_S2_A := Vector2i(19, 36)
const PEND_S2_B := Vector2i(15, 36)
const PEND_S2_C := Vector2i(11, 36)
const PEND_S9_A := Vector2i(-38, -29)
const PEND_S9_B := Vector2i(-38, -31)


static func floor_y(standing: int) -> int:
	return standing - 1


static func checkpoint_xz(order: int) -> Vector2i:
	match order:
		0:
			return SPAWN_XZ
		1:
			return CP1_XZ
		2:
			return CP2_XZ
		3:
			return CP3_XZ
		4:
			return CP4_XZ
		5:
			return CP5_XZ
		6:
			return CP6_XZ
		7:
			return CP7_XZ
		_:
			return Vector2i(99, 99)


static func checkpoint_standing(order: int) -> int:
	if order <= 2:
		return 0
	if order <= 4:
		return 2
	if order <= 6:
		return 4
	return 6


static func finish_standing() -> int:
	return 8


## Each row: x0, x1, y, z0, z1 inclusive.
static func floor_spans() -> PackedInt32Array:
	return PackedInt32Array([
		40, 44, -1, 32, 38,
		38, 39, -1, 35, 37,
		34, 36, -1, 35, 37,
		30, 32, -1, 35, 37,
		26, 28, -1, 35, 37,
		23, 25, -1, 36, 36,
		8, 22, -1, 34, 38,
		5, 7, -1, 36, 36,
		1, 4, -1, 33, 38,
		1, 5, 1, 27, 30,
		1, 2, 1, 19, 26,
		4, 5, 1, 19, 26,
		1, 5, 1, 17, 18,
		3, 3, 1, 14, 16,
		1, 5, 1, 11, 13,
		1, 1, 1, 5, 10,
		5, 5, 1, 5, 10,
		1, 5, 1, 2, 4,
		3, 3, 1, -1, 1,
		1, 5, 1, -6, -2,
		-1, 0, 2, -5, -3,
		-3, -2, 3, -5, -3,
		-20, -4, 3, -5, -3,
		-23, -21, 3, -4, -4,
		-34, -24, 3, -4, -4,
		-25, -25, 3, -5, -5,
		-26, -26, 3, -5, -5,
		-24, -24, 3, -9, -5,
		-34, -25, 3, -9, -9,
		-34, -34, 3, -8, -5,
		-35, -35, 3, -4, -4,
		-39, -36, 3, -4, -2,
		-40, -36, 5, -11, -7,
		-40, -36, 5, -20, -12,
		-38, -38, 5, -23, -21,
		-40, -36, 5, -33, -24,
		-39, -37, 6, -36, -34,
		-40, -36, 7, -40, -37,
	])


## Far-side rails only (−Z on −X legs, −X on −Z legs). Each: x0, x1, y, z0, z1.
static func rail_spans() -> PackedInt32Array:
	return PackedInt32Array([
		8, 22, 0, 34, 34,
		1, 1, 2, 19, 26,
		-20, -4, 4, -6, -6,
		-40, -40, 6, -33, -24,
		-40, -40, 8, -40, -37,
	])


static func launch_l1_cells() -> Array[Vector2i]:
	return [Vector2i(2, 32), Vector2i(3, 32), Vector2i(4, 32)]


static func launch_l2_cells() -> Array[Vector2i]:
	return [Vector2i(-39, -5), Vector2i(-38, -5), Vector2i(-37, -5)]


static func conveyor_zs() -> PackedInt32Array:
	return PackedInt32Array([19, 20, 21, 22, 23, 24, 25, 26])


static func spike_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x: int = -40
	while x <= -38:
		cells.append(Vector2i(x, -13))
		cells.append(Vector2i(x, -17))
		x += 1
	x = -38
	while x <= -36:
		cells.append(Vector2i(x, -15))
		cells.append(Vector2i(x, -19))
		x += 1
	return cells


static func roller_xs() -> PackedInt32Array:
	return PackedInt32Array([-40, -39, -38, -37, -36])


static func flame_xs() -> PackedInt32Array:
	return PackedInt32Array([-7, -13, -19])


static func flame_zs() -> PackedInt32Array:
	return PackedInt32Array([-5, -4, -3])


static func basket_xs() -> PackedInt32Array:
	return PackedInt32Array([2, 3, 4])


static func portal_pairs() -> Array[PackedInt32Array]:
	## Off-path two-way links so reachability can climb launch / stair floors.
	return [
		PackedInt32Array([44, 0, 39, 6, 2, 38]),
		PackedInt32Array([6, 2, -7, 0, 4, 1]),
		PackedInt32Array([-41, 4, 0, -41, 6, -5]),
	]


static func throat_xz() -> Array[Vector2i]:
	return [
		CP1_XZ, CP2_XZ, CP3_XZ, CP4_XZ, CP6_XZ, CP7_XZ,
		Vector2i(1, 8), Vector2i(5, 8), Vector2i(-30, -4),
	]


static func skip_floor(x: int, y: int, z: int) -> bool:
	if y == -1:
		if z == 32 and x >= 2 and x <= 4:
			return true
	if y == 1:
		if x == 3 and z >= 19 and z <= 26:
			return true
	if y == 3:
		if z == -5 and x >= -39 and x <= -37:
			return true
	if y == 5:
		for cell: Vector2i in spike_cells():
			if cell.x == x and cell.y == z:
				return true
	return false


static func in_editor_range(x: int, y: int, z: int) -> bool:
	return x >= X_MIN and x <= X_MAX and y >= Y_MIN and y <= Y_MAX and z >= Z_MIN and z <= Z_MAX


static func geometry_ok() -> bool:
	if not _spans_in_range(floor_spans()):
		return false
	if not _spans_in_range(rail_spans()):
		return false
	if not _no_xz_overlap():
		return false
	if throat_xz().size() < 5:
		return false
	return true


static func _spans_in_range(spans: PackedInt32Array) -> bool:
	var i: int = 0
	while i + 4 < spans.size():
		var x0: int = spans[i]
		var x1: int = spans[i + 1]
		var y: int = spans[i + 2]
		var z0: int = spans[i + 3]
		var z1: int = spans[i + 4]
		if not in_editor_range(x0, y, z0) or not in_editor_range(x1, y, z1):
			return false
		i += 5
	return true


static func _no_xz_overlap() -> bool:
	var seen: Dictionary = {}
	var spans: PackedInt32Array = floor_spans()
	var i: int = 0
	while i + 4 < spans.size():
		var y: int = spans[i + 2]
		var z: int = spans[i + 3]
		while z <= spans[i + 4]:
			var x: int = spans[i]
			while x <= spans[i + 1]:
				if not skip_floor(x, y, z):
					var key: int = x * 1000 + z
					var prev: int = seen.get(key, 99)
					if prev != 99 and prev != y:
						return false
					seen[key] = y
				x += 1
			z += 1
		i += 5
	return true
