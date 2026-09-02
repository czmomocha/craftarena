class_name SimulationWorldMove
extends RefCounted

## Constitution art.17 budget for one discrete sweep. Not a product speed.
## Production capsule (SCALE/8) may travel 32 cells in one call; a 1-unit
## radius falling one cell used to sample 65536 times (2026-08-28 CI hang).
const MAX_SWEEP_STEPS: int = 256

## Discrete sweep moves for SimulationWorld.
## Public API stays on the world facade so this file can stay under E9.
## Samples are not continuous analytic TOI. A blocked sample rejects the
## whole try_move_*; until_blocked commits the last free sample.
## radius is the step scale: ceil(|d| / radius), min 1.
## Over MAX_SWEEP_STEPS rejects the whole move (same as overflow). It does
## not coarsen samples, so in-budget landings and replay hashes stay put.
## Zero radius still destination-only and does not spend the budget.


func try_set_pose(
	world: SimulationWorld, entity_id: int, x: int, y: int, z: int, yaw: int
) -> bool:
	if world.is_pose_blocked(entity_id, x, y, z):
		return false
	return world.set_pose(entity_id, x, y, z, yaw)


## dx/dz are this-tick displacement in Q48.16 internal units, not metres per second.
func try_move_xz(world: SimulationWorld, entity_id: int, dx: int, dz: int) -> bool:
	if not world._has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	var new_x_res: FixedResult = Fixed.try_add(world._x[pose_index], dx)
	if not new_x_res.ok:
		return false
	var new_z_res: FixedResult = Fixed.try_add(world._z[pose_index], dz)
	if not new_z_res.ok:
		return false
	if not _sweep_clear_xz(
		world, entity_id, pose_index, dx, dz, new_x_res.value, new_z_res.value
	):
		return false
	world._x[pose_index] = new_x_res.value
	world._z[pose_index] = new_z_res.value
	return true


## dx/dz are this-tick displacement in Q48.16 internal units, not metres per second.
func try_move_xz_until_blocked(
	world: SimulationWorld, entity_id: int, dx: int, dz: int
) -> bool:
	if not world._has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	var new_x_res: FixedResult = Fixed.try_add(world._x[pose_index], dx)
	if not new_x_res.ok:
		return false
	var new_z_res: FixedResult = Fixed.try_add(world._z[pose_index], dz)
	if not new_z_res.ok:
		return false
	var contact_xz: Array[int] = _sweep_last_free_xz(
		world, entity_id, pose_index, dx, dz, new_x_res.value, new_z_res.value
	)
	if contact_xz.size() != 2:
		return false
	world._x[pose_index] = contact_xz[0]
	world._z[pose_index] = contact_xz[1]
	return true


## dy is this-tick displacement in Q48.16 internal units, not metres per second.
func try_move_y(world: SimulationWorld, entity_id: int, dy: int) -> bool:
	if not world._has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	var new_y_res: FixedResult = Fixed.try_add(world._y[pose_index], dy)
	if not new_y_res.ok:
		return false
	if not _sweep_clear_y(world, entity_id, pose_index, dy, new_y_res.value):
		return false
	world._y[pose_index] = new_y_res.value
	return true


## dy is this-tick displacement in Q48.16 internal units, not metres per second.
func try_move_y_until_blocked(world: SimulationWorld, entity_id: int, dy: int) -> bool:
	if not world._has_entity(entity_id):
		return false
	var pose_index: int = entity_id - 1
	var new_y_res: FixedResult = Fixed.try_add(world._y[pose_index], dy)
	if not new_y_res.ok:
		return false
	var contact_y_res: FixedResult = _sweep_last_free_y(
		world, entity_id, pose_index, dy, new_y_res.value
	)
	if not contact_y_res.ok:
		return false
	world._y[pose_index] = contact_y_res.value
	return true


func _sweep_clear_xz(
	world: SimulationWorld,
	entity_id: int,
	pose_index: int,
	dx: int,
	dz: int,
	dest_x: int,
	dest_z: int
) -> bool:
	var start_x: int = world._x[pose_index]
	var start_y: int = world._y[pose_index]
	var start_z: int = world._z[pose_index]
	var radius: int = world._radius[pose_index]
	if radius <= 0:
		return not _destination_blocked(world, entity_id, dest_x, start_y, dest_z)
	var abs_dx_res: FixedResult = _try_abs(dx)
	if not abs_dx_res.ok:
		return false
	var abs_dz_res: FixedResult = _try_abs(dz)
	if not abs_dz_res.ok:
		return false
	var chebyshev: int = abs_dx_res.value
	if abs_dz_res.value > chebyshev:
		chebyshev = abs_dz_res.value
	var step_count: int = sweep_step_count(chebyshev, radius)
	if step_count < 1:
		return false
	var sample_i: int = 1
	while true:
		var step_dx_res: FixedResult = Fixed.try_mul_div(dx, sample_i, step_count)
		if not step_dx_res.ok:
			return false
		var step_dz_res: FixedResult = Fixed.try_mul_div(dz, sample_i, step_count)
		if not step_dz_res.ok:
			return false
		var sample_x_res: FixedResult = Fixed.try_add(start_x, step_dx_res.value)
		if not sample_x_res.ok:
			return false
		var sample_z_res: FixedResult = Fixed.try_add(start_z, step_dz_res.value)
		if not sample_z_res.ok:
			return false
		if _destination_blocked(
			world, entity_id, sample_x_res.value, start_y, sample_z_res.value
		):
			return false
		if sample_i == step_count:
			break
		sample_i += 1
	return true


func _sweep_last_free_xz(
	world: SimulationWorld,
	entity_id: int,
	pose_index: int,
	dx: int,
	dz: int,
	dest_x: int,
	dest_z: int
) -> Array[int]:
	var failed: Array[int] = []
	var start_x: int = world._x[pose_index]
	var start_y: int = world._y[pose_index]
	var start_z: int = world._z[pose_index]
	var radius: int = world._radius[pose_index]
	if radius <= 0:
		if _destination_blocked(world, entity_id, dest_x, start_y, dest_z):
			var start_xz: Array[int] = [start_x, start_z]
			return start_xz
		var dest_xz: Array[int] = [dest_x, dest_z]
		return dest_xz
	var abs_dx_res: FixedResult = _try_abs(dx)
	if not abs_dx_res.ok:
		return failed
	var abs_dz_res: FixedResult = _try_abs(dz)
	if not abs_dz_res.ok:
		return failed
	var chebyshev: int = abs_dx_res.value
	if abs_dz_res.value > chebyshev:
		chebyshev = abs_dz_res.value
	var step_count: int = sweep_step_count(chebyshev, radius)
	if step_count < 1:
		return failed
	var last_free_x: int = start_x
	var last_free_z: int = start_z
	var sample_i: int = 1
	while true:
		var step_dx_res: FixedResult = Fixed.try_mul_div(dx, sample_i, step_count)
		if not step_dx_res.ok:
			return failed
		var step_dz_res: FixedResult = Fixed.try_mul_div(dz, sample_i, step_count)
		if not step_dz_res.ok:
			return failed
		var sample_x_res: FixedResult = Fixed.try_add(start_x, step_dx_res.value)
		if not sample_x_res.ok:
			return failed
		var sample_z_res: FixedResult = Fixed.try_add(start_z, step_dz_res.value)
		if not sample_z_res.ok:
			return failed
		if _destination_blocked(
			world, entity_id, sample_x_res.value, start_y, sample_z_res.value
		):
			var blocked_xz: Array[int] = [last_free_x, last_free_z]
			return blocked_xz
		last_free_x = sample_x_res.value
		last_free_z = sample_z_res.value
		if sample_i == step_count:
			break
		sample_i += 1
	var clear_xz: Array[int] = [last_free_x, last_free_z]
	return clear_xz


func _sweep_clear_y(
	world: SimulationWorld, entity_id: int, pose_index: int, dy: int, dest_y: int
) -> bool:
	var start_x: int = world._x[pose_index]
	var start_y: int = world._y[pose_index]
	var start_z: int = world._z[pose_index]
	var radius: int = world._radius[pose_index]
	if radius <= 0:
		return not _destination_blocked(world, entity_id, start_x, dest_y, start_z)
	var abs_dy_res: FixedResult = _try_abs(dy)
	if not abs_dy_res.ok:
		return false
	var step_count: int = sweep_step_count(abs_dy_res.value, radius)
	if step_count < 1:
		return false
	var sample_i: int = 1
	while true:
		var step_dy_res: FixedResult = Fixed.try_mul_div(dy, sample_i, step_count)
		if not step_dy_res.ok:
			return false
		var sample_y_res: FixedResult = Fixed.try_add(start_y, step_dy_res.value)
		if not sample_y_res.ok:
			return false
		if _destination_blocked(world, entity_id, start_x, sample_y_res.value, start_z):
			return false
		if sample_i == step_count:
			break
		sample_i += 1
	return true


func _sweep_last_free_y(
	world: SimulationWorld, entity_id: int, pose_index: int, dy: int, dest_y: int
) -> FixedResult:
	var start_x: int = world._x[pose_index]
	var start_y: int = world._y[pose_index]
	var start_z: int = world._z[pose_index]
	var radius: int = world._radius[pose_index]
	if radius <= 0:
		if _destination_blocked(world, entity_id, start_x, dest_y, start_z):
			return FixedResult.success(start_y)
		return FixedResult.success(dest_y)
	var abs_dy_res: FixedResult = _try_abs(dy)
	if not abs_dy_res.ok:
		return FixedResult.fail()
	var step_count: int = sweep_step_count(abs_dy_res.value, radius)
	if step_count < 1:
		return FixedResult.fail()
	var last_free_y: int = start_y
	var sample_i: int = 1
	while true:
		var step_dy_res: FixedResult = Fixed.try_mul_div(dy, sample_i, step_count)
		if not step_dy_res.ok:
			return FixedResult.fail()
		var sample_y_res: FixedResult = Fixed.try_add(start_y, step_dy_res.value)
		if not sample_y_res.ok:
			return FixedResult.fail()
		if _destination_blocked(world, entity_id, start_x, sample_y_res.value, start_z):
			return FixedResult.success(last_free_y)
		last_free_y = sample_y_res.value
		if sample_i == step_count:
			break
		sample_i += 1
	return FixedResult.success(last_free_y)


## ceil(|length| / radius) with no budget. radius must be > 0.
## Returns 0 when the count cannot be formed.
static func uncapped_sweep_step_count(length: int, radius: int) -> int:
	if radius <= 0:
		return 0
	var step_count: int = length / radius
	if length % radius != 0:
		step_count += 1
	if step_count < 1:
		step_count = 1
	return step_count


## In-budget step count, or 0 when the uncapped count exceeds MAX_SWEEP_STEPS.
static func sweep_step_count(length: int, radius: int) -> int:
	var step_count: int = uncapped_sweep_step_count(length, radius)
	if step_count < 1:
		return 0
	if step_count > MAX_SWEEP_STEPS:
		return 0
	return step_count


func _try_abs(value: int) -> FixedResult:
	if value >= 0:
		return FixedResult.success(value)
	return Fixed.try_neg(value)


func _destination_blocked(
	world: SimulationWorld, entity_id: int, dest_x: int, dest_y: int, dest_z: int
) -> bool:
	return world.is_pose_blocked(entity_id, dest_x, dest_y, dest_z)
