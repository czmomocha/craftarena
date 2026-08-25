class_name MatchStandingMap
extends Node3D

## Live standing labels from the latest authoritative snapshot (CD-13,
## CD-21 §6.1). Each snapshot player becomes a Label3D at the Q48.16 pose.
## Authority stays in TraprushStanding + MatchSnapshotFollow; float
## conversion happens only here. Labels are not hitboxes. Course / crates
## / portal bars / checkpoint-order gizmos stay undrawn here. No
## interpolation, prediction, settlement, path-distance ranking, or
## online writes.

const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")
const TraprushStandingGd := preload("res://src/games/traprush/standing.gd")

const MARK_PREFIX: String = "standing_mark_"
const STANDING_LIFT: float = 1.35
const _FINISHED_ALBEDO: Color = Color(1.0, 0.85, 0.2)
const _RUNNING_ALBEDO: Color = Color(0.85, 0.9, 1.0)

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
	_clear_marks()
	_spawn_marks(players, standing)
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


func _spawn_marks(players: Array, standing: Dictionary) -> void:
	var by_slot: Dictionary = {}
	var rows_raw: Variant = standing.get("rows", [])
	if typeof(rows_raw) != TYPE_ARRAY:
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
	var index: int = 0
	for raw: Variant in players:
		var body: Dictionary = raw
		var pose: Dictionary = _pose_from_player(body)
		if not by_slot.has(index):
			index += 1
			continue
		var row_raw: Variant = by_slot[index]
		if typeof(row_raw) != TYPE_DICTIONARY:
			index += 1
			continue
		var row: Dictionary = row_raw
		_spawn_mark(index, pose, row)
		index += 1


func _spawn_mark(slot: int, pose: Dictionary, row: Dictionary) -> void:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var label: Label3D = Label3D.new()
	label.name = mark_name(slot)
	label.text = mark_text(row)
	label.font_size = 64
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	var finished: bool = row.get("finished", false)
	if finished:
		label.modulate = _FINISHED_ALBEDO
	else:
		label.modulate = _RUNNING_ALBEDO
	label.position = Vector3(
		meters_from_fixed(x),
		meters_from_fixed(y) + STANDING_LIFT,
		meters_from_fixed(z)
	)
	add_child(label)


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
