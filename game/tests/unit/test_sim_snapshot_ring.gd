extends GutTest

## SimSnapshotRing: CD-43 periodic key snapshots as a bounded tick/hash ring.
## Capacity is caller-supplied. This file does not lock snapshot Hz (CD-63).

const SimulationWorld := preload("res://src/simulation/simulation_world.gd")
const SimSnapshotRing := preload("res://src/simulation/snapshot_ring.gd")


func test_create_rejects_capacity_below_one() -> void:
	assert_eq(SimSnapshotRing.create(0), null)
	assert_eq(SimSnapshotRing.create(-1), null)
	assert_eq(SimSnapshotRing.create(-8), null)


func test_create_starts_empty_at_caller_capacity() -> void:
	var ring: SimSnapshotRing = SimSnapshotRing.create(4)
	assert_not_null(ring)
	assert_eq(ring.capacity(), 4)
	assert_eq(ring.size(), 0)


func test_record_stores_tick_and_hash_state_copy() -> void:
	var world: SimulationWorld = _world_with_capsule()
	var ring: SimSnapshotRing = SimSnapshotRing.create(2)
	var expected: PackedByteArray = world.hash_state()
	assert_false(expected.is_empty())
	assert_true(ring.record(world))
	assert_eq(ring.size(), 1)
	assert_eq(ring.hash_at_tick(world.tick_index).hex_encode(), expected.hex_encode())


func test_same_tick_record_overwrites_hash_without_growing() -> void:
	var world: SimulationWorld = _world_with_capsule()
	var ring: SimSnapshotRing = SimSnapshotRing.create(3)
	var first_hex: String = world.hash_state().hex_encode()
	assert_true(ring.record(world))
	assert_eq(ring.size(), 1)
	assert_true(world.set_pose(1, 7, 8, 9, 4))
	var second: PackedByteArray = world.hash_state()
	var second_hex: String = second.hex_encode()
	assert_ne(second_hex, first_hex)
	assert_eq(world.tick_index, 0)
	assert_true(ring.record(world))
	assert_eq(ring.size(), 1)
	assert_eq(ring.hash_at_tick(0).hex_encode(), second_hex)


func test_full_ring_drops_oldest_entry() -> void:
	var world: SimulationWorld = _world_with_capsule()
	var ring: SimSnapshotRing = SimSnapshotRing.create(2)
	var tick0: int = world.tick_index
	var hash0: String = world.hash_state().hex_encode()
	assert_true(ring.record(world))
	world.tick()
	assert_true(world.set_pose(1, 11, 12, 13, 5))
	var tick1: int = world.tick_index
	var hash1: String = world.hash_state().hex_encode()
	assert_true(ring.record(world))
	assert_eq(ring.size(), 2)
	world.tick()
	assert_true(world.set_pose(1, 21, 22, 23, 6))
	var tick2: int = world.tick_index
	var hash2: String = world.hash_state().hex_encode()
	assert_true(ring.record(world))
	assert_eq(ring.size(), 2)
	assert_eq(ring.capacity(), 2)
	assert_eq(ring.hash_at_tick(tick0).size(), 0)
	assert_eq(ring.hash_at_tick(tick1).hex_encode(), hash1)
	assert_eq(ring.hash_at_tick(tick2).hex_encode(), hash2)
	assert_ne(hash0, hash1)


func test_null_world_record_is_rejected() -> void:
	var ring: SimSnapshotRing = SimSnapshotRing.create(1)
	var missing: SimulationWorld = null
	assert_false(ring.record(missing))
	assert_eq(ring.size(), 0)


func test_empty_hash_state_record_is_rejected() -> void:
	var ring: SimSnapshotRing = SimSnapshotRing.create(1)
	var world: SimulationWorld = _EmptyHashWorld.new(1)
	world.spawn_capsule(1, 2, 3, 4)
	assert_eq(world.hash_state().size(), 0)
	assert_false(ring.record(world))
	assert_eq(ring.size(), 0)


func test_record_does_not_advance_tick_index() -> void:
	var world: SimulationWorld = _world_with_capsule()
	var ring: SimSnapshotRing = SimSnapshotRing.create(1)
	assert_eq(world.tick_index, 0)
	assert_true(ring.record(world))
	assert_eq(world.tick_index, 0)
	world.tick()
	assert_eq(world.tick_index, 1)
	assert_true(ring.record(world))
	assert_eq(world.tick_index, 1)
	assert_eq(ring.size(), 1)


func test_hash_at_tick_missing_tick_is_empty() -> void:
	var world: SimulationWorld = _world_with_capsule()
	var ring: SimSnapshotRing = SimSnapshotRing.create(1)
	assert_eq(ring.hash_at_tick(0).size(), 0)
	assert_true(ring.record(world))
	assert_eq(ring.hash_at_tick(99).size(), 0)
	assert_eq(ring.hash_at_tick(-1).size(), 0)


func test_stored_hash_is_not_mutated_by_later_world_ticks() -> void:
	var world: SimulationWorld = _world_with_capsule()
	var ring: SimSnapshotRing = SimSnapshotRing.create(2)
	var tick0: int = world.tick_index
	var original_hex: String = world.hash_state().hex_encode()
	assert_true(ring.record(world))
	world.tick()
	assert_true(world.set_pose(1, 31, 32, 33, 7))
	assert_ne(world.hash_state().hex_encode(), original_hex)
	assert_eq(ring.hash_at_tick(tick0).hex_encode(), original_hex)


func _world_with_capsule() -> SimulationWorld:
	var world: SimulationWorld = SimulationWorld.new(1)
	world.spawn_capsule(1, 2, 3, 4)
	return world


class _EmptyHashWorld extends SimulationWorld:
	func hash_state() -> PackedByteArray:
		return PackedByteArray()
