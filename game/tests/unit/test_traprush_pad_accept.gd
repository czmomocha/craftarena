extends GutTest

## TraprushPadAccept：检查点完成由服务端占用判定，不信客户端断言（CD-21 §8）。
## 相交后才 track.try_accept；乱序与 track 合同一致（CD-21 §4.2）。
## 几何只用 Fixed.SCALE 整数。不调用 world.tick()，本函数不移动胶囊。

const PadAccept := preload("res://src/games/traprush/pad_accept.gd")
const Track := preload("res://src/games/traprush/checkpoint_track.gd")
const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")

const CHECKPOINT_A: int = 10
const CHECKPOINT_B: int = 20
const START_YAW: int = 8


func test_outside_box_does_not_accept() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var outside_x: int = 10 * FixedClass.SCALE
	var entity_id: int = world.spawn_capsule(
		outside_x, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var pad_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(pad_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_false(world.overlaps_static_box(entity_id, pad_box_id))
	assert_false(PadAccept.try_accept_on_pad(
		world, entity_id, track, CHECKPOINT_A, pad_box_id
	))
	assert_eq(track.completed_count(), 0)
	_assert_pose(world, entity_id, outside_x, 0, 0, START_YAW)
	assert_eq(world.tick_index, 0)


func test_non_solid_pad_overlap_accepts_and_advances() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(
		0, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var pad_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(pad_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_true(world.overlaps_static_box(entity_id, pad_box_id))
	assert_true(PadAccept.try_accept_on_pad(
		world, entity_id, track, CHECKPOINT_A, pad_box_id
	))
	assert_eq(track.completed_count(), 1)
	assert_eq(track.last_accepted_id(), CHECKPOINT_A)
	_assert_pose(world, entity_id, 0, 0, 0, START_YAW)
	assert_eq(world.tick_index, 0)


func test_overlapping_wrong_order_fails_like_track() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(
		0, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var pad_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(pad_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_true(world.overlaps_static_box(entity_id, pad_box_id))
	assert_false(PadAccept.try_accept_on_pad(
		world, entity_id, track, CHECKPOINT_B, pad_box_id
	))
	assert_eq(track.completed_count(), 0)
	_assert_pose(world, entity_id, 0, 0, 0, START_YAW)
	assert_eq(world.tick_index, 0)


func test_unknown_ids_return_false_without_progress() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(
		0, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var pad_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(pad_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_false(PadAccept.try_accept_on_pad(world, 0, track, CHECKPOINT_A, pad_box_id))
	assert_false(PadAccept.try_accept_on_pad(world, -1, track, CHECKPOINT_A, pad_box_id))
	assert_false(PadAccept.try_accept_on_pad(world, 99, track, CHECKPOINT_A, pad_box_id))
	assert_false(PadAccept.try_accept_on_pad(world, entity_id, track, CHECKPOINT_A, 0))
	assert_false(PadAccept.try_accept_on_pad(world, entity_id, track, CHECKPOINT_A, -1))
	assert_false(PadAccept.try_accept_on_pad(world, entity_id, track, CHECKPOINT_A, 99))
	assert_eq(track.completed_count(), 0)
	_assert_pose(world, entity_id, 0, 0, 0, START_YAW)
	assert_eq(world.tick_index, 0)


func test_null_world_or_track_returns_false() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(
		0, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var pad_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(pad_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_false(PadAccept.try_accept_on_pad(
		null, entity_id, track, CHECKPOINT_A, pad_box_id
	))
	assert_eq(track.completed_count(), 0)
	assert_false(PadAccept.try_accept_on_pad(
		world, entity_id, null, CHECKPOINT_A, pad_box_id
	))
	assert_eq(track.completed_count(), 0)
	_assert_pose(world, entity_id, 0, 0, 0, START_YAW)
	assert_eq(world.tick_index, 0)


func test_solid_pad_keeps_outside_capsule_from_accepting() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var start_x: int = 4 * FixedClass.SCALE
	var into_box: int = -2 * FixedClass.SCALE
	var entity_id: int = world.spawn_capsule(
		start_x, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var pad_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_false(world.try_move_xz(entity_id, into_box, 0))
	assert_false(world.overlaps_static_box(entity_id, pad_box_id))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_false(PadAccept.try_accept_on_pad(
		world, entity_id, track, CHECKPOINT_A, pad_box_id
	))
	assert_eq(track.completed_count(), 0)
	_assert_pose(world, entity_id, start_x, 0, 0, START_YAW)
	assert_eq(world.tick_index, 0)


func test_does_not_tick_or_move_on_success() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(
		0, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var pad_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(pad_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_eq(world.tick_index, 0)
	assert_true(PadAccept.try_accept_on_pad(
		world, entity_id, track, CHECKPOINT_A, pad_box_id
	))
	assert_eq(world.tick_index, 0)
	_assert_pose(world, entity_id, 0, 0, 0, START_YAW)
	assert_true(PadAccept.try_accept_on_pad(
		world, entity_id, track, CHECKPOINT_A, pad_box_id
	))
	assert_eq(track.completed_count(), 1)
	assert_eq(world.tick_index, 0)
	_assert_pose(world, entity_id, 0, 0, 0, START_YAW)


func _assert_pose(world: SimulationWorld, entity_id: int, x: int, y: int, z: int, yaw: int) -> void:
	var pose: Dictionary = world.get_pose(entity_id)
	var pose_x: int = pose.get("x", -1)
	var pose_y: int = pose.get("y", -1)
	var pose_z: int = pose.get("z", -1)
	var pose_yaw: int = pose.get("yaw", -1)
	assert_eq(pose_x, x)
	assert_eq(pose_y, y)
	assert_eq(pose_z, z)
	assert_eq(pose_yaw, yaw)
