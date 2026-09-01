class_name MatchStandingMap
extends Node3D

## Live standing labels from the latest authoritative snapshot (CD-13,
## CD-21 §6.1). Each snapshot player becomes a Label3D at the Q48.16 pose.
## Authority stays in TraprushStanding + MatchSnapshotFollow; float
## conversion happens only here. Labels are not hitboxes. Course / crates
## / portal bars / checkpoint-order gizmos stay undrawn here. This
## node does not interpolate; the lobby may pass sampled poses from
## MatchSnapshotInterp. Ranking still uses finish_tick / accepted_count.
## follow_slot prefixes that seat's label with "*" so the own seat is
## readable on a cube. Not product cosmetics.
## No prediction, settlement, path-distance ranking, or online writes.

const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")
const TraprushStandingGd := preload("res://src/games/traprush/standing.gd")

const MARK_PREFIX: String = "standing_mark_"
const OWN_MARK_PREFIX: String = "*"
const STANDING_LIFT: float = 1.35

var follow_slot: int = -1
var _standing_count: int = 0
var _mvp_slot: int = -1
var _line: String = ""


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func mark_name(slot: int) -> String:
	return "%s%d" % [MARK_PREFIX, slot]


static func mark_text(row: Dictionary) -> String:
	var place: int = row.get("place", 0)
	var slot: int = row.get("slot", -1)
	var finished: bool = row.get("finished", false)
	if finished:
		return "#%d P%d" % [place, slot]
	var accepted_count: int = row.get("accepted_count", 0)
	var pad_total: int = row.get("pad_total", 0)
	if pad_total > 0:
		return "#%d P%d %d/%d" % [place, slot, accepted_count, pad_total]
	return "#%d P%d %d" % [place, slot, accepted_count]


func apply_follow(follow: MatchSnapshotFollowGd, pad_total: int = 0) -> bool:
	if follow == null or not follow.has_snapshot:
		return false
	return apply_players(follow.players, pad_total)


func apply_players(players: Array, pad_total: int = 0) -> bool:
	if not _players_are_mappable(players):
		return false
	var standing: Dictionary = TraprushStandingGd.from_players(players, pad_total)
	if not standing.get("ok", false):
		return false
	_sync_marks(players, standing)
	var mvp_raw: Variant = standing.get("mvp_slot", -1)
	if typeof(mvp_raw) == TYPE_INT:
		_mvp_slot = mvp_raw
	else:
		_mvp_slot = -1
	_line = TraprushStandingGd.format_line(standing)
	_standing_count = players.size()
	return true


func standing_count() -> int:
	return _standing_count


func mvp_slot() -> int:
	return _mvp_slot


func standing_line() -> String:
	return _line


func standing_node(slot: int) -> Label3D:
	return get_node_or_null(mark_name(slot)) as Label3D


func crate_node_count() -> int:
	return 0


func link_node_count() -> int:
	return 0


func checkpoint_node_count() -> int:
	return 0


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _players_are_mappable(players: Array) -> bool:
	for raw: Variant in players:
		if typeof(raw) != TYPE_DICTIONARY:
			return false
		var body: Dictionary = raw
		if _pose_from_player(body).is_empty():
			return false
	return true


func _pose_from_player(body: Dictionary) -> Dictionary:
	if not body.has("x") or typeof(body["x"]) != TYPE_INT:
		return {}
	if not body.has("y") or typeof(body["y"]) != TYPE_INT:
		return {}
	if not body.has("z") or typeof(body["z"]) != TYPE_INT:
		return {}
	var x: int = body["x"]
	var y: int = body["y"]
	var z: int = body["z"]
	return {
		"x": x,
		"y": y,
		"z": z,
	}


## 按 slot 复用已有 Label3D，只写文本、位姿与颜色；席位变少才删尾部。
##
## 存在的理由是每帧成本，不是代码整洁。本函数在对局壳的每渲染帧被调一次，原来
## 是「全清全建」——每帧 free 掉一个带 64 px 字体 + 12 px 描边 + billboard 的
## Label3D，再新建一个。与 `MatchSnapshotMap._sync_players`（C4 第 6 章）是同一
## 笔账、同一种修法：slot 是稳定键，「第 1 席换了人」仍复用第 1 席那个标，文本与
## 颜色每帧都会被覆盖，没有可残留的状态。
func _sync_marks(players: Array, standing: Dictionary) -> void:
	var by_slot: Dictionary = {}
	var rows_raw: Variant = standing.get("rows", [])
	if typeof(rows_raw) != TYPE_ARRAY:
		_clear_marks()
		return
	var rows: Array = rows_raw
	for raw: Variant in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		var slot: int = row.get("slot", -1)
		if typeof(slot) != TYPE_INT:
			continue
		by_slot[slot] = row
	var wanted: Dictionary = {}
	var index: int = 0
	for raw: Variant in players:
		var body: Dictionary = raw
		var pose: Dictionary = _pose_from_player(body)
		if by_slot.has(index):
			var row_raw: Variant = by_slot[index]
			if typeof(row_raw) == TYPE_DICTIONARY:
				var row: Dictionary = row_raw
				_write_mark(index, pose, row)
				wanted[index] = true
		index += 1
	_despawn_marks_except(wanted)


func _write_mark(slot: int, pose: Dictionary, row: Dictionary) -> void:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var label: Label3D = standing_node(slot)
	if label == null:
		label = Label3D.new()
		label.name = mark_name(slot)
		label.font_size = 64
		label.pixel_size = 0.02
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 12
		add_child(label)
	var text: String = mark_text(row)
	if follow_slot >= 0 and slot == follow_slot:
		text = "%s%s" % [OWN_MARK_PREFIX, text]
		label.outline_modulate = PlaceholderSpec.STANDING_OWN_OUTLINE
	else:
		label.outline_modulate = PlaceholderSpec.STANDING_REMOTE_OUTLINE
	label.text = text
	var finished: bool = row.get("finished", false)
	if finished:
		label.modulate = PlaceholderSpec.STANDING_FINISHED_ALBEDO
	else:
		label.modulate = PlaceholderSpec.STANDING_RUNNING_ALBEDO
	label.position = Vector3(
		meters_from_fixed(x),
		meters_from_fixed(y) + STANDING_LIFT,
		meters_from_fixed(z)
	)


## 这一份名单里没有的标一律撤掉——人数变少不能留幽灵标。
func _despawn_marks_except(wanted: Dictionary) -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		var child_name: String = str(child.name)
		if not child_name.begins_with(MARK_PREFIX):
			continue
		var slot: int = child_name.substr(MARK_PREFIX.length()).to_int()
		if not wanted.has(slot):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()


func _clear_marks() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		if str(child.name).begins_with(MARK_PREFIX):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_standing_count = 0
	_mvp_slot = -1
	_line = ""
