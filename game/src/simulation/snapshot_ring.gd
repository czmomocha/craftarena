class_name SimSnapshotRing
extends RefCounted

## Bounded ring of CD-43 periodic key snapshots: (tick_index, hash_state copy).
## Capacity is caller-supplied. This type does not lock snapshot Hz (see CD-63).
## A full ring drops the oldest entry (FIFO). The same tick overwrites in place.

var _capacity: int = 0
var _ticks: Array[int] = []
var _hashes: Array[PackedByteArray] = []


static func create(capacity: int) -> SimSnapshotRing:
	if capacity < 1:
		return null
	var ring: SimSnapshotRing = SimSnapshotRing.new()
	ring._capacity = capacity
	return ring


func record(world: SimulationWorld) -> bool:
	if world == null:
		return false
	var digest: PackedByteArray = world.hash_state()
	if digest.is_empty():
		return false
	var stored: PackedByteArray = digest.duplicate()
	var tick: int = world.tick_index
	var existing_index: int = _ticks.find(tick)
	if existing_index >= 0:
		_hashes[existing_index] = stored
		return true
	if _ticks.size() >= _capacity:
		_ticks.remove_at(0)
		_hashes.remove_at(0)
	_ticks.append(tick)
	_hashes.append(stored)
	return true


func hash_at_tick(tick: int) -> PackedByteArray:
	var index: int = _ticks.find(tick)
	if index < 0:
		return PackedByteArray()
	return _hashes[index].duplicate()


func size() -> int:
	return _ticks.size()


func capacity() -> int:
	return _capacity
