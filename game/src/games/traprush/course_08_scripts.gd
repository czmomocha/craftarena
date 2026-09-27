class_name TraprushCourse08Scripts
extends RefCounted

## Scripted safe-edge WR for official `course_08`.
## Probe: 1 action = 1 cell. Human tape expands moves and times hazards.
## Indices match TraprushCourseCompletionProbe._ACTION_NAMES.

const LayoutGd := preload("res://src/games/traprush/course_08_layout.gd")
const HumanPaceRunner := preload("res://src/games/traprush/human_pace_runner.gd")

const MOVE_X: int = 0
const MOVE_NEG_X: int = 1
const MOVE_Z: int = 2
const MOVE_NEG_Z: int = 3
const JUMP: int = 8
const USE_ITEM: int = 9
const WAIT: int = 10
const SETTLE_WAITS: int = 8
const LAND_WAITS: int = 16
const STEP_RISE_WAITS: int = 6
const LAUNCH_RISE_WAITS: int = 12
const LAUNCH_WAITS: int = 24


static func fast_hint() -> PackedByteArray:
	var packed: PackedByteArray = PackedByteArray()
	var tick: int = 0
	tick += _waits(packed, SETTLE_WAITS)
	tick += _walk_to(packed, 42, 36, 38, 36)
	tick += _gap_neg_x(packed)
	tick += _walk_to(packed, 36, 36, 34, 36)
	tick += _gap_neg_x(packed)
	tick += _walk_to(packed, 32, 36, 30, 36)
	tick += _gap_neg_x(packed)
	tick += _walk_to(packed, 28, 36, 21, 36)
	tick += _wait_pendulum_clear_z(packed, tick, 36, 19, 33, 39, LayoutGd.SPEED_PENDULUM_LANE)
	tick += _walk_to(packed, 21, 36, 17, 36)
	tick += _wait_pendulum_clear_z(packed, tick, 36, 15, 39, 33, LayoutGd.SPEED_PENDULUM_LANE)
	tick += _walk_to(packed, 17, 36, 13, 36)
	tick += _wait_pendulum_clear_z(packed, tick, 36, 11, 33, 39, LayoutGd.SPEED_PENDULUM_LANE)
	tick += _walk_to(packed, 13, 36, 6, 36)
	tick += _walk_to(packed, 6, 36, 3, 36)
	tick += _walk_to(packed, 3, 36, 3, 32)
	tick += _waits(packed, LAUNCH_RISE_WAITS)
	tick += _walk(packed, MOVE_NEG_Z, 2)
	tick += _waits(packed, LAUNCH_WAITS)
	tick += _walk_to(packed, 3, 29, 2, 28)
	tick += _walk_to(packed, 2, 28, 2, 17)
	tick += _walk_to(packed, 2, 17, 3, 15)
	tick += _walk_to(packed, 3, 15, 3, 12)
	tick += _walk_to(packed, 3, 12, 1, 12)
	tick += _walk_to(packed, 1, 12, 1, 3)
	tick += _walk_to(packed, 1, 3, 3, 0)
	tick += _walk_to(packed, 3, 0, 3, -4)
	tick += _walk_to(packed, 3, -4, 1, -4)
	tick += _step_neg_x(packed)
	tick += _step_neg_x(packed)
	tick += _step_neg_x(packed)
	tick += _step_neg_x(packed)
	tick += _walk_to(packed, -3, -4, -5, -4)
	tick += _h_wait_hazard_off(packed, packed.size(), LayoutGd.FLAME_COOLDOWN, 8)
	tick += _walk_to(packed, -5, -4, -8, -4)
	tick += _h_wait_hazard_off(packed, packed.size(), LayoutGd.FLAME_COOLDOWN, 8)
	tick += _walk_to(packed, -8, -4, -14, -4)
	tick += _h_wait_hazard_off(packed, packed.size(), LayoutGd.FLAME_COOLDOWN, 8)
	tick += _walk_to(packed, -14, -4, -20, -4)
	tick += _walk_to(packed, -20, -4, -24, -4)
	tick += _walk_to(packed, -24, -4, -24, -9)
	tick += _walk_to(packed, -24, -9, -34, -9)
	tick += _walk_to(packed, -34, -9, -34, -4)
	tick += _walk_to(packed, -34, -4, -35, -4)
	tick += _walk_to(packed, -35, -4, -38, -4)
	tick += _walk_to(packed, -38, -4, -38, -5)
	tick += _waits(packed, LAUNCH_RISE_WAITS)
	tick += _walk(packed, MOVE_NEG_Z, 2)
	tick += _waits(packed, LAUNCH_WAITS)
	tick += _walk_to(packed, -38, -8, -36, -12)
	tick += _walk_to(packed, -36, -12, -36, -14)
	tick += _walk_to(packed, -36, -14, -40, -14)
	tick += _walk_to(packed, -40, -14, -40, -16)
	tick += _walk_to(packed, -40, -16, -36, -16)
	tick += _walk_to(packed, -36, -16, -36, -18)
	tick += _walk_to(packed, -36, -18, -40, -18)
	tick += _walk_to(packed, -40, -18, -40, -20)
	tick += _walk_to(packed, -40, -20, -38, -22)
	tick += _walk_to(packed, -38, -22, -38, -25)
	tick += _h_wait_hazard_off(packed, packed.size(), LayoutGd.ROLLER_COOLDOWN, 8)
	tick += _walk_to(packed, -38, -25, -38, -27)
	tick += _wait_pendulum_clear_x(packed, tick, -38, -29, -41, -35, LayoutGd.SPEED_PENDULUM_END)
	tick += _walk_to(packed, -38, -27, -38, -30)
	tick += _wait_pendulum_clear_x(packed, tick, -38, -31, -35, -41, LayoutGd.SPEED_PENDULUM_END)
	tick += _walk_to(packed, -38, -30, -38, -33)
	tick += _step_neg_z(packed)
	tick += _walk_to(packed, -38, -34, -38, -36)
	tick += _step_neg_z(packed)
	tick += _walk_to(packed, -38, -37, -38, -39)
	return packed


static func move_count(hint: PackedByteArray = PackedByteArray()) -> int:
	var packed: PackedByteArray = hint
	if packed.is_empty():
		packed = fast_hint()
	var count: int = 0
	for action: int in packed:
		if action >= 0 and action <= 3:
			count += 1
	return count


static func human_tape() -> PackedByteArray:
	var tape: PackedByteArray = PackedByteArray()
	var tick: int = 0
	tick += _h_wait(tape, SETTLE_WAITS)
	tick += _h_walk(tape, MOVE_NEG_X, 4)
	tick += _h_gap_neg_x(tape)
	tick += _h_walk(tape, MOVE_NEG_X, 2)
	tick += _h_ticks(tape, MOVE_NEG_X, 8)
	tick += _h_gap_neg_x(tape)
	tick += _h_walk(tape, MOVE_NEG_X, 2)
	tick += _h_ticks(tape, MOVE_NEG_X, 8)
	tick += _h_gap_neg_x(tape)
	tick += _h_walk(tape, MOVE_NEG_X, 25)
	tick += _h_walk(tape, MOVE_NEG_Z, 4)
	tick += _h_wait(tape, LAUNCH_RISE_WAITS)
	tick += _h_walk(tape, MOVE_NEG_Z, 3)
	tick += _h_wait(tape, LAUNCH_WAITS)
	tick += _h_step(tape, MOVE_NEG_Z)
	tick += _h_step(tape, MOVE_NEG_Z)
	tick += _h_walk(tape, MOVE_NEG_X, 1)
	tick += _h_ticks(tape, MOVE_NEG_X, 8)
	tick += _h_walk(tape, MOVE_NEG_Z, 8)
	tick += _h_walk(tape, MOVE_X, 1)
	tick += _h_walk(tape, MOVE_NEG_Z, 3)
	tick += _h_walk(tape, MOVE_NEG_Z, 3)
	tick += _h_walk(tape, MOVE_NEG_X, 2)
	tick += _h_walk(tape, MOVE_NEG_Z, 9)
	tick += _h_walk(tape, MOVE_X, 2)
	tick += _h_walk(tape, MOVE_NEG_Z, 3)
	tick += _h_walk(tape, MOVE_NEG_Z, 4)
	tick += _h_walk(tape, MOVE_NEG_X, 2)
	tick += _h_step(tape, MOVE_NEG_X)
	tick += _h_step(tape, MOVE_NEG_X)
	tick += _h_step(tape, MOVE_NEG_X)
	tick += _h_step(tape, MOVE_NEG_X)
	tick += _h_walk(tape, MOVE_NEG_X, 4)
	tick += _h_wait_hazard_off(tape, tape.size(), LayoutGd.FLAME_COOLDOWN, 48)
	tick += _h_walk(tape, MOVE_NEG_X, 14)
	tick += _h_ticks(tape, MOVE_NEG_Z, 10)
	tick += _h_walk(tape, MOVE_NEG_X, 3)
	tick += _h_wait(tape, SETTLE_WAITS)
	tick += _h_walk(tape, MOVE_NEG_X, 1)
	tick += _h_walk(tape, MOVE_NEG_Z, 5)
	tick += _h_walk(tape, MOVE_NEG_X, 10)
	tick += _h_walk(tape, MOVE_Z, 5)
	tick += _h_walk(tape, MOVE_NEG_X, 1)
	tick += _h_wait(tape, SETTLE_WAITS)
	tick += _h_walk(tape, MOVE_NEG_X, 3)
	tick += _h_walk(tape, MOVE_NEG_Z, 1)
	tick += _h_wait(tape, LAUNCH_RISE_WAITS)
	tick += _h_walk(tape, MOVE_NEG_Z, 2)
	tick += _h_wait(tape, LAUNCH_WAITS)
	tick += _h_step(tape, MOVE_NEG_Z)
	tick += _h_step(tape, MOVE_NEG_Z)
	tick += _h_walk(tape, MOVE_X, 2)
	tick += _h_walk(tape, MOVE_NEG_Z, 5)
	tick += _h_ticks(tape, MOVE_NEG_Z, 10)
	tick += _h_walk(tape, MOVE_NEG_X, 4)
	tick += _h_walk(tape, MOVE_NEG_Z, 2)
	tick += _h_walk(tape, MOVE_X, 4)
	tick += _h_walk(tape, MOVE_NEG_Z, 2)
	tick += _h_walk(tape, MOVE_NEG_X, 4)
	tick += _h_walk(tape, MOVE_NEG_Z, 2)
	tick += _h_walk(tape, MOVE_X, 2)
	tick += _h_walk(tape, MOVE_NEG_Z, 2)
	tick += _h_wait(tape, SETTLE_WAITS)
	tick += _h_wait_hazard_off(tape, tape.size(), LayoutGd.ROLLER_COOLDOWN, 40)
	tick += _h_walk(tape, MOVE_NEG_Z, 11)
	tick += _h_step(tape, MOVE_NEG_Z)
	tick += _h_walk(tape, MOVE_NEG_Z, 2)
	tick += _h_step(tape, MOVE_NEG_Z)
	tick += _h_walk(tape, MOVE_NEG_Z, 2)
	tick += _h_step(tape, MOVE_NEG_Z)
	tick += _h_walk(tape, MOVE_NEG_Z, 3)
	tick += _h_wait(tape, SETTLE_WAITS)
	return tape


static func _walk_to(packed: PackedByteArray, x0: int, z0: int, x1: int, z1: int) -> int:
	var added: int = 0
	var x: int = x0
	var z: int = z0
	while x != x1:
		if x1 > x:
			packed.append(MOVE_X)
			x += 1
		else:
			packed.append(MOVE_NEG_X)
			x -= 1
		added += 1
	while z != z1:
		if z1 > z:
			packed.append(MOVE_Z)
			z += 1
		else:
			packed.append(MOVE_NEG_Z)
			z -= 1
		added += 1
	return added


static func _walk(packed: PackedByteArray, action: int, cells: int) -> int:
	var i: int = 0
	while i < cells:
		packed.append(action)
		i += 1
	return cells


static func _gap_neg_x(packed: PackedByteArray) -> int:
	packed.append(JUMP)
	packed.append(MOVE_NEG_X)
	packed.append(MOVE_NEG_X)
	return 3 + _waits(packed, LAND_WAITS)


static func _step_neg_x(packed: PackedByteArray) -> int:
	packed.append(JUMP)
	var added: int = 1 + _waits(packed, STEP_RISE_WAITS)
	packed.append(MOVE_NEG_X)
	return added + 1 + _waits(packed, LAND_WAITS)


static func _step_neg_z(packed: PackedByteArray) -> int:
	packed.append(JUMP)
	var added: int = 1 + _waits(packed, STEP_RISE_WAITS)
	packed.append(MOVE_NEG_Z)
	return added + 1 + _waits(packed, LAND_WAITS)


static func _waits(packed: PackedByteArray, count: int) -> int:
	var i: int = 0
	while i < count:
		packed.append(WAIT)
		i += 1
	return count


static func _wait_hazard_off(
	packed: PackedByteArray, tick: int, cooldown: int, extra: int
) -> int:
	var period: int = cooldown * 2
	if period < 2:
		return _waits(packed, extra)
	var phase: int = tick % period
	var wait: int = extra
	if phase < cooldown:
		wait += cooldown - phase
	return _waits(packed, wait)


static func _wait_pendulum_clear_z(
	packed: PackedByteArray,
	tick: int,
	walk_z: int,
	_pend_x: int,
	z0: int,
	z1: int,
	speed: int
) -> int:
	var wait: int = 0
	var t: int = tick
	while wait < 160:
		var pz: int = _mover_axis(t, z0 * Fixed.SCALE, z1 * Fixed.SCALE, speed)
		if absi(pz - walk_z * Fixed.SCALE) >= Fixed.SCALE:
			break
		packed.append(WAIT)
		wait += 1
		t += 1
	return wait


static func _wait_pendulum_clear_x(
	packed: PackedByteArray,
	tick: int,
	walk_x: int,
	_pend_z: int,
	x0: int,
	x1: int,
	speed: int
) -> int:
	var wait: int = 0
	var t: int = tick
	while wait < 160:
		var px: int = _mover_axis(t, x0 * Fixed.SCALE, x1 * Fixed.SCALE, speed)
		if absi(px - walk_x * Fixed.SCALE) >= Fixed.SCALE:
			break
		packed.append(WAIT)
		wait += 1
		t += 1
	return wait


static func _mover_axis(tick: int, from_v: int, to_v: int, speed: int) -> int:
	var length: int = absi(to_v - from_v)
	if length < 1 or speed < 1:
		return from_v
	var period: int = length * 2
	var raw: int = tick * speed
	var dist: int = raw % period
	var walked: int = dist
	if walked > length:
		walked = period - walked
	if to_v >= from_v:
		return from_v + walked
	return from_v - walked


static func _h_walk(tape: PackedByteArray, action: int, cells: int) -> int:
	var piece: PackedByteArray = HumanPaceRunner.expand_cells(action, cells)
	for code: int in piece:
		tape.append(code)
	return piece.size()


static func _h_wait(tape: PackedByteArray, count: int) -> int:
	return _waits(tape, count)


static func _h_ticks(tape: PackedByteArray, action: int, ticks: int) -> int:
	var i: int = 0
	while i < ticks:
		tape.append(action)
		i += 1
	return ticks


static func _h_gap_neg_x(tape: PackedByteArray) -> int:
	var i: int = 0
	while i < 8:
		tape.append(MOVE_NEG_X)
		i += 1
	tape.append(JUMP)
	i = 0
	while i < 16:
		tape.append(MOVE_NEG_X)
		i += 1
	return 25


static func _h_step(tape: PackedByteArray, action: int) -> int:
	tape.append(JUMP)
	var added: int = 1 + _h_wait(tape, 8)
	added += _h_walk(tape, action, 1)
	added += _h_wait(tape, 16)
	return added


static func _h_wait_hazard_off(
	tape: PackedByteArray, tick: int, cooldown: int, needed: int
) -> int:
	var period: int = cooldown * 2
	if period < 2:
		return 0
	var phase: int = tick % period
	var wait: int = 0
	if phase < cooldown:
		wait += cooldown - phase
		phase = cooldown
	var remaining: int = period - phase
	if remaining < needed:
		wait += remaining + cooldown
	return _waits(tape, wait)
