extends GutTest

## MatchStandingMap: latest-snapshot poses → standing Label3D.
## Finished / unfinished text follows TraprushStanding. A bad follow or
## malformed player list keeps the last labels. Never settlement.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchSnapshotFollow := preload("res://src/client/match_snapshot_follow.gd")
const MatchStandingMap := preload("res://src/client/match_standing_map.gd")

const CELL: int = 65536
const EPS: float = 0.0001

var _map: MatchStandingMap = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null


func test_rebuild_maps_places_and_skips_other_gizmos() -> void:
	_map = MatchStandingMap.new()
	add_child(_map)
	assert_true(_map.apply_players([
		_player(0, 0, 0, 1, -1),
		_player(2 * CELL, CELL, 0, 3, 4),
	], 3))
	assert_eq(_map.standing_count(), 2)
	assert_eq(_map.mvp_slot(), 1)
	assert_eq(_map.crate_node_count(), 0)
	assert_eq(_map.link_node_count(), 0)
	assert_eq(_map.checkpoint_node_count(), 0)
	var first: Label3D = _map.standing_node(0)
	var second: Label3D = _map.standing_node(1)
	assert_not_null(first)
	assert_not_null(second)
	assert_eq(first.text, "#2 P0 1/3")
	assert_eq(second.text, "#1 P1")
	assert_eq(first.modulate, Color(0.85, 0.9, 1.0))
	assert_eq(second.modulate, Color(1.0, 0.85, 0.2))
	assert_almost_eq(first.position.x, 0.0, EPS)
	assert_almost_eq(first.position.y, 1.35, EPS)
	assert_almost_eq(second.position.x, 2.0, EPS)
	assert_almost_eq(second.position.y, 2.35, EPS)
	assert_eq(_map.standing_line(), "standings=#1s1,#2s0 mvp=1")
	assert_false(_map.allows_settlement())
	assert_false(_map.allows_online_writes())


func test_later_snapshot_jumps_without_interpolation() -> void:
	_map = MatchStandingMap.new()
	add_child(_map)
	assert_true(_map.apply_players([_player(0, 0, 0, 0, -1)]))
	assert_true(_map.apply_players([_player(2 * CELL, 0, 0, 0, -1)]))
	var node: Label3D = _map.standing_node(0)
	assert_almost_eq(node.position.x, 2.0, EPS)
	assert_eq(node.text, "#1 P0 0")
	assert_eq(_map.standing_count(), 1)
	assert_eq(_map.mvp_slot(), -1)


func test_player_count_shrink_and_empty_drop_stale_nodes() -> void:
	_map = MatchStandingMap.new()
	add_child(_map)
	assert_true(_map.apply_players([
		_player(0, 0, 0, 0, -1),
		_player(CELL, 0, 0, 0, -1),
	]))
	assert_true(_map.apply_players([_player(0, 0, 0, 0, -1)]))
	assert_eq(_map.standing_count(), 1)
	assert_null(_map.standing_node(1))
	assert_true(_map.apply_players([]))
	assert_eq(_map.standing_count(), 0)
	assert_null(_map.standing_node(0))
	assert_eq(_map.standing_line(), "standings=- mvp=-")


func test_bad_follow_or_players_keep_last_labels() -> void:
	_map = MatchStandingMap.new()
	add_child(_map)
	assert_true(_map.apply_players([_player(CELL, 0, 0, 2, 8)], 3))
	assert_eq(_map.standing_node(0).text, "#1 P0")
	assert_almost_eq(_map.standing_node(0).position.x, 1.0, EPS)
	assert_false(_map.apply_follow(null))
	var empty_follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_false(_map.apply_follow(empty_follow))
	assert_false(_map.apply_players([{"x": 0, "y": 0, "z": 0}]))
	assert_false(_map.apply_players([{"accepted_count": 1, "finish_tick": -1}]))
	assert_eq(_map.standing_count(), 1)
	assert_eq(_map.standing_node(0).text, "#1 P0")
	assert_almost_eq(_map.standing_node(0).position.x, 1.0, EPS)
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(follow.apply_frame(_snapshot(3, 2 * CELL, 0, -1)))
	assert_true(_map.apply_follow(follow, 3))
	assert_eq(_map.standing_node(0).text, "#1 P0 0/3")
	assert_almost_eq(_map.standing_node(0).position.x, 2.0, EPS)


func _player(x: int, y: int, z: int, accepted_count: int, finish_tick: int) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"z": z,
		"yaw_bam": 0,
		"accepted_count": accepted_count,
		"finish_tick": finish_tick,
	}


func _snapshot(tick: int, x: int, accepted_count: int, finish_tick: int) -> PackedByteArray:
	var players: Array[Dictionary] = [_player(x, 0, 0, accepted_count, finish_tick)]
	var crates: Array[Dictionary] = []
	return MatchFrameCodec.encode_snapshot(tick, players, crates)
