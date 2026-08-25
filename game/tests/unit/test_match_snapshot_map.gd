extends GutTest

## MatchSnapshotMap: latest-snapshot player poses → 1 m boxes.
## No interpolation. Crates have no pose in the v1 snapshot, so they
## are not drawn. A bad follow or malformed player list keeps the last map.

const MatchFrameCodec := preload("res://src/shared/protocol/match_frame_codec.gd")
const MatchSnapshotFollow := preload("res://src/client/match_snapshot_follow.gd")
const MatchSnapshotMap := preload("res://src/client/match_snapshot_map.gd")

const CELL: int = 65536
const EPS: float = 0.0001

var _map: MatchSnapshotMap = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null


func test_meters_and_yaw_conversion() -> void:
	assert_almost_eq(MatchSnapshotMap.meters_from_fixed(CELL), 1.0, EPS)
	assert_almost_eq(MatchSnapshotMap.meters_from_fixed(0), 0.0, EPS)
	assert_almost_eq(MatchSnapshotMap.yaw_radians_from_bam(16384), PI / 2.0, EPS)
	assert_almost_eq(MatchSnapshotMap.yaw_radians_from_bam(0), 0.0, EPS)


func test_rebuild_maps_player_poses_and_skips_crates() -> void:
	_map = MatchSnapshotMap.new()
	add_child(_map)
	assert_true(_map.apply_players([
		_player(CELL, 0, 2 * CELL, 16384),
		_player(0, CELL, 0, 0),
	], [_crate(9, 1)]))
	assert_eq(_map.player_count(), 2)
	assert_eq(_map.crate_node_count(), 0)
	assert_eq(_map.checkpoint_node_count(), 0)
	assert_eq(_map.standing_node_count(), 0)
	var first: MeshInstance3D = _map.player_node(0)
	var second: MeshInstance3D = _map.player_node(1)
	assert_not_null(first)
	assert_not_null(second)
	assert_almost_eq(first.position.x, 1.0, EPS)
	assert_almost_eq(first.position.z, 2.0, EPS)
	assert_almost_eq(first.rotation.y, PI / 2.0, EPS)
	assert_almost_eq(second.position.y, 1.0, EPS)
	var box: BoxMesh = first.mesh as BoxMesh
	assert_not_null(box)
	assert_almost_eq(box.size.x, 1.0, EPS)
	var camera: Camera3D = _map.get_node_or_null(MatchSnapshotMap.CAMERA_NAME) as Camera3D
	assert_not_null(camera)
	assert_true(camera.current)
	assert_false(_map.allows_settlement())
	assert_false(_map.allows_online_writes())


func test_later_snapshot_jumps_without_interpolation() -> void:
	_map = MatchSnapshotMap.new()
	add_child(_map)
	assert_true(_map.apply_players([_player(0, 0, 0, 0)]))
	assert_true(_map.apply_players([_player(2 * CELL, 0, 0, 0)]))
	var node: MeshInstance3D = _map.player_node(0)
	assert_almost_eq(node.position.x, 2.0, EPS)
	assert_eq(_map.player_count(), 1)


func test_player_count_shrink_drops_stale_nodes() -> void:
	_map = MatchSnapshotMap.new()
	add_child(_map)
	assert_true(_map.apply_players([_player(0, 0, 0, 0), _player(CELL, 0, 0, 0)]))
	assert_true(_map.apply_players([_player(0, 0, 0, 0)]))
	assert_eq(_map.player_count(), 1)
	assert_null(_map.player_node(1))


func test_empty_player_list_clears_markers() -> void:
	_map = MatchSnapshotMap.new()
	add_child(_map)
	assert_true(_map.apply_players([_player(CELL, 0, 0, 0)]))
	assert_true(_map.apply_players([]))
	assert_eq(_map.player_count(), 0)
	assert_null(_map.player_node(0))


func test_malformed_list_keeps_previous_map() -> void:
	_map = MatchSnapshotMap.new()
	add_child(_map)
	assert_true(_map.apply_players([_player(CELL, 0, 0, 0)]))
	assert_false(_map.apply_players([{"x": 1}]))
	assert_eq(_map.player_count(), 1)
	var node: MeshInstance3D = _map.player_node(0)
	assert_almost_eq(node.position.x, 1.0, EPS)


func test_follow_without_snapshot_keeps_previous_map() -> void:
	_map = MatchSnapshotMap.new()
	add_child(_map)
	var follow: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(follow.apply_frame(_snapshot(3, CELL)))
	assert_true(_map.apply_follow(follow))
	assert_eq(_map.player_count(), 1)
	var empty: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_false(_map.apply_follow(empty))
	assert_eq(_map.player_count(), 1)
	var older: MatchSnapshotFollow = MatchSnapshotFollow.new()
	assert_true(older.apply_frame(_snapshot(5, 2 * CELL)))
	assert_false(older.apply_frame(_snapshot(4, 9 * CELL)))
	assert_true(_map.apply_follow(older))
	var node: MeshInstance3D = _map.player_node(0)
	assert_almost_eq(node.position.x, 2.0, EPS)


func _player(x: int, y: int, z: int, yaw_bam: int) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"z": z,
		"yaw_bam": yaw_bam,
		"accepted_count": 0,
		"finish_tick": -1,
	}


func _crate(entity_id: int, durability: int) -> Dictionary:
	return {
		"entity_id": entity_id,
		"durability": durability,
	}


func _snapshot(tick: int, x: int) -> PackedByteArray:
	var players: Array[Dictionary] = [_player(x, 0, 0, 0)]
	var crates: Array[Dictionary] = []
	return MatchFrameCodec.encode_snapshot(tick, players, crates)
