extends GutTest

## TraprushFinishAccept：冲线由服务端占用 + 全部强制检查点完成判定（CD-21 §6 / §8）。
## 无 FinishIntent；不从客户端 Dictionary 读冲线标志。几何只用 Fixed.SCALE 整数。
## 不调用 world.tick()，本函数不移动胶囊、不写入 finish_tick。

const FinishAccept := preload("res://src/games/traprush/finish_accept.gd")
const Track := preload("res://src/games/traprush/checkpoint_track.gd")
const FixedClass := preload("res://src/shared/fixed/fixed.gd")
const SimulationWorld := preload("res://src/simulation/simulation_world.gd")

const CHECKPOINT_A: int = 10
const CHECKPOINT_B: int = 20
const START_YAW: int = 8


func test_incomplete_checkpoints_fail_even_when_overlapping() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(
		0, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var finish_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(finish_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_true(world.overlaps_static_box(entity_id, finish_box_id))
	var result: Dictionary = FinishAccept.try_cross(
		world, entity_id, track, finish_box_id
	)
	assert_false(_ok(result))
	assert_eq(track.completed_count(), 0)
	assert_false(track.is_finished())
	_assert_pose(world, entity_id, 0, 0, 0, START_YAW)
	assert_eq(world.tick_index, 0)


func test_finished_track_outside_box_fails() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var outside_x: int = 10 * FixedClass.SCALE
	var entity_id: int = world.spawn_capsule(
		outside_x, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var finish_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(finish_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_true(track.try_accept(CHECKPOINT_A))
	assert_true(track.try_accept(CHECKPOINT_B))
	assert_true(track.is_finished())
	assert_false(world.overlaps_static_box(entity_id, finish_box_id))
	var result: Dictionary = FinishAccept.try_cross(
		world, entity_id, track, finish_box_id
	)
	assert_false(_ok(result))
	assert_true(track.is_finished())
	_assert_pose(world, entity_id, outside_x, 0, 0, START_YAW)
	assert_eq(world.tick_index, 0)


func test_finished_track_overlapping_succeeds_without_tick_or_pose() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(
		0, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var finish_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(finish_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_true(track.try_accept(CHECKPOINT_A))
	assert_true(track.try_accept(CHECKPOINT_B))
	assert_true(track.is_finished())
	assert_true(world.overlaps_static_box(entity_id, finish_box_id))
	var result: Dictionary = FinishAccept.try_cross(
		world, entity_id, track, finish_box_id
	)
	assert_true(_ok(result))
	assert_false(result.has("finish_tick"))
	assert_eq(world.tick_index, 0)
	_assert_pose(world, entity_id, 0, 0, 0, START_YAW)
	assert_true(track.is_finished())


func test_unknown_ids_return_false_when_track_is_finished() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(
		0, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var finish_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(finish_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_true(track.try_accept(CHECKPOINT_A))
	assert_true(track.try_accept(CHECKPOINT_B))
	assert_false(_ok(FinishAccept.try_cross(world, 0, track, finish_box_id)))
	assert_false(_ok(FinishAccept.try_cross(world, -1, track, finish_box_id)))
	assert_false(_ok(FinishAccept.try_cross(world, 99, track, finish_box_id)))
	assert_false(_ok(FinishAccept.try_cross(world, entity_id, track, 0)))
	assert_false(_ok(FinishAccept.try_cross(world, entity_id, track, -1)))
	assert_false(_ok(FinishAccept.try_cross(world, entity_id, track, 99)))
	assert_true(track.is_finished())
	_assert_pose(world, entity_id, 0, 0, 0, START_YAW)
	assert_eq(world.tick_index, 0)


func test_null_world_or_track_returns_false() -> void:
	var world: SimulationWorld = SimulationWorld.new(1)
	var entity_id: int = world.spawn_capsule(
		0, 0, 0, START_YAW, FixedClass.SCALE, 2 * FixedClass.SCALE
	)
	var finish_box_id: int = world.spawn_static_box(
		0, 0, 0, FixedClass.SCALE, FixedClass.SCALE, FixedClass.SCALE
	)
	assert_true(world.set_static_box_solid(finish_box_id, false))
	var track: Track = Track.new(PackedInt32Array([CHECKPOINT_A, CHECKPOINT_B]))
	assert_true(track.try_accept(CHECKPOINT_A))
	assert_true(track.try_accept(CHECKPOINT_B))
	assert_false(_ok(FinishAccept.try_cross(null, entity_id, track, finish_box_id)))
	assert_true(track.is_finished())
	assert_false(_ok(FinishAccept.try_cross(world, entity_id, null, finish_box_id)))
	assert_true(track.is_finished())
	_assert_pose(world, entity_id, 0, 0, 0, START_YAW)
	assert_eq(world.tick_index, 0)


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


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
