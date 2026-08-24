extends GutTest

## TraprushCheckpointTrack：有序强制检查点与传送不得跳点（CD-21 §4.2）。
## 锁死：重复踩最近已完成点为 no-op true；尚未完成任何点时 reset_pose_index 为 -1。

const Track := preload("res://src/games/traprush/checkpoint_track.gd")


func test_constructor_takes_caller_ids_not_product_defaults() -> void:
	var ids: PackedInt32Array = PackedInt32Array([10, 20])
	var track: Track = Track.new(ids)
	assert_eq(track.completed_count(), 0)
	assert_false(track.is_finished())
	assert_eq(track.reset_pose_index(), -1)


func test_from_int_array_preserves_order() -> void:
	var ids: Array[int] = [7, 8, 9]
	var track: Track = Track.from_int_array(ids)
	assert_true(track.try_accept(7))
	assert_false(track.try_accept(9))
	assert_true(track.try_accept(8))
	assert_true(track.try_accept(9))
	assert_true(track.is_finished())


func test_try_accept_only_allows_the_next_required_id() -> void:
	var track: Track = Track.new(PackedInt32Array([10, 20, 30]))
	assert_false(track.try_accept(20))
	assert_false(track.try_accept(30))
	assert_false(track.try_accept(99))
	assert_true(track.try_accept(10))
	assert_eq(track.completed_count(), 1)
	assert_eq(track.last_accepted_id(), 10)
	assert_false(track.try_accept(30))
	assert_true(track.try_accept(20))
	assert_eq(track.completed_count(), 2)
	assert_eq(track.last_accepted_id(), 20)


func test_restepping_last_completed_is_noop_true() -> void:
	var track: Track = Track.new(PackedInt32Array([10, 20, 30]))
	assert_true(track.try_accept(10))
	assert_true(track.try_accept(10))
	assert_eq(track.completed_count(), 1)
	assert_true(track.try_accept(20))
	assert_true(track.try_accept(20))
	assert_eq(track.completed_count(), 2)
	assert_false(track.try_accept(10))


func test_portal_cannot_skip_unfinished_mandatory_checkpoints() -> void:
	var track: Track = Track.new(PackedInt32Array([10, 20, 30]))
	assert_true(track.can_use_portal(10))
	assert_false(track.can_use_portal(20))
	assert_false(track.can_use_portal(30))
	assert_false(track.can_use_portal(99))
	assert_true(track.try_accept(10))
	assert_true(track.can_use_portal(10))
	assert_true(track.can_use_portal(20))
	assert_false(track.can_use_portal(30))
	assert_true(track.try_accept(20))
	assert_true(track.can_use_portal(30))
	assert_true(track.try_accept(30))
	assert_true(track.can_use_portal(10))
	assert_true(track.can_use_portal(30))


func test_reset_pose_index_is_last_completed_or_minus_one() -> void:
	var track: Track = Track.new(PackedInt32Array([10, 20, 30]))
	assert_eq(track.reset_pose_index(), -1)
	assert_true(track.try_accept(10))
	assert_eq(track.reset_pose_index(), 0)
	assert_true(track.try_accept(20))
	assert_eq(track.reset_pose_index(), 1)
	assert_true(track.try_accept(30))
	assert_eq(track.reset_pose_index(), 2)


func test_is_finished_only_when_every_mandatory_checkpoint_is_done() -> void:
	var track: Track = Track.new(PackedInt32Array([10, 20]))
	assert_false(track.is_finished())
	assert_true(track.try_accept(10))
	assert_false(track.is_finished())
	assert_true(track.try_accept(20))
	assert_true(track.is_finished())
	assert_true(track.try_accept(20))
	assert_true(track.is_finished())
	assert_false(track.try_accept(10))


func test_ordered_and_accepted_ids_are_copies() -> void:
	var track: Track = Track.new(PackedInt32Array([10, 20, 30]))
	var ordered: PackedInt32Array = track.ordered_ids()
	assert_eq(ordered.size(), 3)
	assert_eq(ordered[0], 10)
	assert_eq(track.accepted_ids().size(), 0)
	assert_true(track.try_accept(10))
	assert_true(track.try_accept(20))
	var accepted: PackedInt32Array = track.accepted_ids()
	assert_eq(accepted.size(), 2)
	assert_eq(accepted[0], 10)
	assert_eq(accepted[1], 20)
	accepted[0] = 99
	assert_eq(track.last_accepted_id(), 20)
	ordered[0] = 1
	assert_eq(track.ordered_ids()[0], 10)


func test_empty_track_is_already_finished() -> void:
	var track: Track = Track.new(PackedInt32Array())
	assert_true(track.is_finished())
	assert_eq(track.completed_count(), 0)
	assert_eq(track.reset_pose_index(), -1)
	assert_false(track.try_accept(1))
	assert_false(track.can_use_portal(1))
