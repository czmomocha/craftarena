extends GutTest

## Latest-snapshot follow: apply decoded frames, ignore older ticks, keep
## the last good snapshot when a frame is malformed. No interpolation.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchSnapshotFollow := preload("res://src/client/match_snapshot_follow.gd")


func test_applies_latest_snapshot_and_rejects_older_or_bad() -> void:
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(follow.apply_frame(_snapshot(3, 10, 1)))
	assert_true(follow.has_snapshot)
	assert_eq(follow.tick, 3)
	assert_eq(follow.players.size(), 1)
	var first_player: Dictionary = follow.players[0]
	var first_x: int = first_player.get("x", -1)
	assert_eq(first_x, 10)
	assert_eq(follow.crates.size(), 1)
	var first_crate: Dictionary = follow.crates[0]
	var first_durability: int = first_crate.get("durability", -1)
	assert_eq(first_durability, 1)
	assert_true(follow.apply_frame(_snapshot(5, 20, 0)))
	assert_eq(follow.tick, 5)
	var later_player: Dictionary = follow.players[0]
	var later_x: int = later_player.get("x", -1)
	assert_eq(later_x, 20)
	var later_crate: Dictionary = follow.crates[0]
	var later_durability: int = later_crate.get("durability", -1)
	assert_eq(later_durability, 0)
	assert_false(follow.apply_frame(_snapshot(4, 99, 0)))
	assert_eq(follow.tick, 5)
	var kept_player: Dictionary = follow.players[0]
	var kept_x: int = kept_player.get("x", -1)
	assert_eq(kept_x, 20)
	assert_false(follow.apply_frame(PackedByteArray([1, 2, 3])))
	assert_eq(follow.tick, 5)
	assert_false(follow.allows_settlement())
	assert_false(follow.allows_online_writes())


func test_equal_tick_replaces_payload() -> void:
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(follow.apply_frame(_snapshot(1, 1, 4)))
	assert_true(follow.apply_frame(_snapshot(1, 8, 2)))
	assert_eq(follow.tick, 1)
	var player: Dictionary = follow.players[0]
	var crate: Dictionary = follow.crates[0]
	var x: int = player.get("x", -1)
	var durability: int = crate.get("durability", -1)
	assert_eq(x, 8)
	assert_eq(durability, 2)


func _snapshot(tick: int, x: int, durability: int) -> PackedByteArray:
	var players: Array[Dictionary] = [{
		"x": x,
		"y": 0,
		"z": 0,
		"yaw_bam": 0,
		"accepted_count": 0,
		"finish_tick": -1,
	}]
	var crates: Array[Dictionary] = [{
		"entity_id": 9,
		"durability": durability,
	}]
	return MatchFrameCodec.encode_snapshot(tick, players, crates)
