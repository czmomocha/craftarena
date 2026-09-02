class_name AuthoringPreviewMapOverlay
extends RefCounted

const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")

## Reachability overlay for AuthoringPreviewMap. Reads evaluate(); not a write gate.

const REACH_LIFT: float = 1.7
const REACH_SEG_LIFT: float = 0.45
const LINK_THICKNESS: float = 0.08
const _MIN_LINK_LEN: float = 0.001

var ok: bool = true
var issue_count: int = 0


func reset() -> void:
	ok = true
	issue_count = 0


func spawn(map: AuthoringPreviewMap, world: AuthoringWorld) -> void:
	var result: Dictionary = AuthoringReachability.evaluate(world)
	var ok_raw: Variant = result.get("ok", false)
	if typeof(ok_raw) == TYPE_BOOL:
		ok = ok_raw
	else:
		ok = false
	var issues_raw: Variant = result.get("issues", [])
	if typeof(issues_raw) != TYPE_ARRAY:
		issue_count = 0
		return
	var issues: Array = issues_raw
	issue_count = issues.size()
	for issue_value: Variant in issues:
		if typeof(issue_value) != TYPE_DICTIONARY:
			continue
		var issue: Dictionary = issue_value
		if typeof(issue.get("code", null)) != TYPE_STRING:
			continue
		var code: String = issue["code"]
		if not AuthoringReachabilityCodes.contains(code):
			continue
		var ids_raw: Variant = issue.get("entity_ids", [])
		if typeof(ids_raw) != TYPE_ARRAY:
			continue
		var ids: Array = ids_raw
		var posed: Array[int] = []
		for id_value: Variant in ids:
			if typeof(id_value) != TYPE_INT:
				continue
			var entity_id: int = id_value
			var record: SharedComponentRecord = world.get_record(entity_id)
			var pose: Dictionary = ConvertGd.pose_from_record(record)
			if pose.is_empty():
				continue
			posed.append(entity_id)
			_spawn_reach_mark(map, entity_id, code, ConvertGd.meters_from_pose(pose))
		if code != AuthoringReachabilityCodes.UNREACHABLE_CHECKPOINT:
			continue
		if posed.size() != 2:
			continue
		var from_id: int = posed[0]
		var to_id: int = posed[1]
		var from_pose: Dictionary = ConvertGd.pose_from_record(world.get_record(from_id))
		var to_pose: Dictionary = ConvertGd.pose_from_record(world.get_record(to_id))
		if from_pose.is_empty() or to_pose.is_empty():
			continue
		_spawn_unreachable_seg(
			map,
			from_id,
			to_id,
			ConvertGd.meters_from_pose(from_pose),
			ConvertGd.meters_from_pose(to_pose)
		)


func _spawn_reach_mark(map: AuthoringPreviewMap, entity_id: int, code: String, from: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.name = ConvertGd.overlay_name(entity_id, code)
	label.text = code
	label.font_size = 28
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.modulate = PlaceholderSpec.REACH_ALBEDO
	label.position = from + Vector3(0.0, REACH_LIFT, 0.0)
	map.add_child(label)


func _spawn_unreachable_seg(
	map: AuthoringPreviewMap,
	from_id: int,
	to_id: int,
	from: Vector3,
	to: Vector3
) -> void:
	var lifted_from: Vector3 = from + Vector3(0.0, REACH_SEG_LIFT, 0.0)
	var lifted_to: Vector3 = to + Vector3(0.0, REACH_SEG_LIFT, 0.0)
	var delta: Vector3 = lifted_to - lifted_from
	var length: float = delta.length()
	if length < _MIN_LINK_LEN:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(LINK_THICKNESS, LINK_THICKNESS, length)
	mesh.material = ConvertGd.unshaded(PlaceholderSpec.REACH_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = ConvertGd.unreachable_seg_name(from_id, to_id)
	node.mesh = mesh
	node.position = (lifted_from + lifted_to) * 0.5
	map.add_child(node)
	ConvertGd.look_toward(node, lifted_to)
