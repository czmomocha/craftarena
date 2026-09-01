extends GutTest

## MatchStandingMap: latest-snapshot poses → standing Label3D.
## Finished / unfinished text follows TraprushStanding. follow_slot
## prefixes that seat with "*". A bad follow or malformed player list
## keeps the last labels. Never settlement.

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


func test_follow_slot_stars_own_mark_only() -> void:
	_map = MatchStandingMap.new()
	add_child(_map)
	_map.follow_slot = 0
	assert_true(_map.apply_players([
		_player(0, 0, 0, 1, -1),
		_player(2 * CELL, CELL, 0, 3, 4),
	], 3))
	var first: Label3D = _map.standing_node(0)
	var second: Label3D = _map.standing_node(1)
	assert_eq(first.text, "*#2 P0 1/3")
	assert_eq(second.text, "#1 P1")
	assert_eq(first.outline_modulate, Color(0.15, 0.85, 0.75))
	assert_eq(second.outline_modulate, Color(0.0, 0.0, 0.0))
	_map.follow_slot = 1
	assert_true(_map.apply_players([
		_player(0, 0, 0, 1, -1),
		_player(2 * CELL, CELL, 0, 3, 4),
	], 3))
	assert_eq(_map.standing_node(0).text, "#2 P0 1/3")
	assert_eq(_map.standing_node(1).text, "*#1 P1")


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


## 名次标每渲染帧被写一次。原来是全清全建——每帧 free 掉一个带 64 px 字体、
## 12 px 描边、billboard 的 Label3D 再新建一个。这里钉的是**节点身份**（确定性），
## 不是毫秒数：CD-53 §1.1 不建自动性能门禁。
func test_same_standing_reuses_the_label_nodes() -> void:
	_map = MatchStandingMap.new()
	add_child(_map)
	var players: Array = [
		_player(0, 0, 0, 1, -1),
		_player(2 * CELL, CELL, 0, 3, 4),
	]
	assert_true(_map.apply_players(players, 3))
	var first_id: int = _map.standing_node(0).get_instance_id()
	var second_id: int = _map.standing_node(1).get_instance_id()

	for _frame: int in range(5):
		assert_true(_map.apply_players(players, 3))

	assert_eq(_map.standing_node(0).get_instance_id(), first_id, "名次标每帧被重建")
	assert_eq(_map.standing_node(1).get_instance_id(), second_id, "名次标每帧被重建")
	assert_eq(_map.standing_count(), 2)


## 复用最容易走反的方向是「该更新的没更新」。位姿、名次文本、本席前缀都必须跟着变。
func test_reused_labels_still_follow_the_new_snapshot() -> void:
	_map = MatchStandingMap.new()
	add_child(_map)
	assert_true(_map.apply_players([_player(0, 0, 0, 1, -1)], 3))
	var mark_id: int = _map.standing_node(0).get_instance_id()
	assert_eq(_map.standing_node(0).text, "#1 P0 1/3")

	_map.follow_slot = 0
	assert_true(_map.apply_players([_player(2 * CELL, 0, 0, 2, -1)], 3))

	var moved: Label3D = _map.standing_node(0)
	assert_eq(moved.get_instance_id(), mark_id, "同一席位换了新节点")
	assert_eq(moved.text, "*#1 P0 2/3")
	assert_almost_eq(moved.position.x, 2.0, EPS)
	assert_eq(moved.outline_modulate, PlaceholderSpec.STANDING_OWN_OUTLINE)


## 人数变少不能留幽灵标——这正是「复用」最容易漏掉的一侧。
func test_fewer_players_drop_the_trailing_marks() -> void:
	_map = MatchStandingMap.new()
	add_child(_map)
	assert_true(_map.apply_players([
		_player(0, 0, 0, 1, -1),
		_player(2 * CELL, 0, 0, 1, -1),
	], 3))
	assert_not_null(_map.standing_node(1))

	assert_true(_map.apply_players([_player(0, 0, 0, 1, -1)], 3))

	assert_not_null(_map.standing_node(0))
	assert_null(_map.standing_node(1), "人数减少后留下了幽灵名次标")
	assert_eq(_map.standing_count(), 1)


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
