class_name MatchCheckpointOrderMap
extends Node3D

## Presentation mapping for compiled TRAPRUSH checkpoint order (CD-43).
## Pad bags supply Q48.16 poses and order. Unique orders get a label and
## an ascending sequence bar (same colors / lifts as Preview). Duplicate
## orders are labeled only and stay out of the chain. Authority stays on
## SimulationBundle; float conversion happens only here. Gizmos are not
## hitboxes. Portal bars stay undrawn here; MatchPortalLinkMap draws them.
## Standing labels stay undrawn here; MatchStandingMap draws them.
## No interpolation, prediction, or course-selection API.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const CHECKPOINT_PREFIX: String = "checkpoint_mark_"
const SEQUENCE_PREFIX: String = "checkpoint_seq_"
const LINK_THICKNESS: float = 0.08
const CHECKPOINT_LIFT: float = 1.15
const SEQUENCE_LIFT: float = 0.25
const _MIN_LINK_LEN: float = 0.001
const _CHECKPOINT_ALBEDO: Color = Color(0.35, 0.9, 0.4)
const _CHECKPOINT_DUP_ALBEDO: Color = Color(0.95, 0.3, 0.85)

var _checkpoint_count: int = 0
var _sequence_count: int = 0


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func checkpoint_name(entity_id: int) -> String:
	return "%s%d" % [CHECKPOINT_PREFIX, entity_id]


static func sequence_name(from_id: int, to_id: int) -> String:
	return "%s%d_%d" % [SEQUENCE_PREFIX, from_id, to_id]


static func compile_path(path: String) -> SimulationBundle:
	if path.is_empty():
		return null
	var world: AuthoringWorld = AuthoringDocumentGd.load_from_path(path)
	if world == null:
		return null
	return TraprushTopologyCompilerGd.compile(world)


func apply_path(path: String) -> bool:
	return apply_bundle(compile_path(path))


func apply_bundle(bundle: SimulationBundle) -> bool:
	if bundle == null:
		return false
	if not _pads_are_mappable(bundle.pads):
		return false
	_clear_orders()
	_spawn_orders(bundle.pads)
	return true


func checkpoint_count() -> int:
	return _checkpoint_count


func sequence_count() -> int:
	return _sequence_count


func checkpoint_node(entity_id: int) -> Label3D:
	return get_node_or_null(checkpoint_name(entity_id)) as Label3D


func sequence_node(from_id: int, to_id: int) -> MeshInstance3D:
	return get_node_or_null(sequence_name(from_id, to_id)) as MeshInstance3D


func crate_node_count() -> int:
	return 0


func link_node_count() -> int:
	return 0


func standing_node_count() -> int:
	return 0


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _pads_are_mappable(bags: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for bag: Dictionary in bags:
		var pose: Dictionary = _pose_from_pad(bag)
		if pose.is_empty():
			return false
		var entity_id: int = pose["entity_id"]
		if seen.has(entity_id):
			return false
		seen[entity_id] = true
	return true


func _pose_from_pad(bag: Dictionary) -> Dictionary:
	if not bag.has("entity_id") or typeof(bag["entity_id"]) != TYPE_INT:
		return {}
	var entity_id: int = bag["entity_id"]
	if entity_id < 1:
		return {}
	if not bag.has("order") or typeof(bag["order"]) != TYPE_INT:
		return {}
	var order: int = bag["order"]
	if order < 0:
		return {}
	if not bag.has("x") or typeof(bag["x"]) != TYPE_INT:
		return {}
	if not bag.has("y") or typeof(bag["y"]) != TYPE_INT:
		return {}
	if not bag.has("z") or typeof(bag["z"]) != TYPE_INT:
		return {}
	var x: int = bag["x"]
	var y: int = bag["y"]
	var z: int = bag["z"]
	return {
		"entity_id": entity_id,
		"order": order,
		"x": x,
		"y": y,
		"z": z,
	}


func _spawn_orders(bags: Array[Dictionary]) -> void:
	var by_order: Dictionary = {}
	var poses: Dictionary = {}
	for bag: Dictionary in bags:
		var pose: Dictionary = _pose_from_pad(bag)
		var entity_id: int = pose["entity_id"]
		var order: int = pose["order"]
		if not by_order.has(order):
			var grouped: Array[int] = []
			by_order[order] = grouped
		var group: Array = by_order[order]
		group.append(entity_id)
		var x: int = pose["x"]
		var y: int = pose["y"]
		var z: int = pose["z"]
		poses[entity_id] = Vector3(
			meters_from_fixed(x),
			meters_from_fixed(y),
			meters_from_fixed(z)
		)
	var order_keys: Array = by_order.keys()
	order_keys.sort()
	var unique_entity_ids: Array[int] = []
	for order_value: Variant in order_keys:
		var order: int = order_value
		var group: Array = by_order[order]
		var grouped_ids: Array[int] = []
		for grouped_id_value: Variant in group:
			var grouped_id: int = grouped_id_value
			grouped_ids.append(grouped_id)
		grouped_ids.sort()
		var duplicated: bool = grouped_ids.size() != 1
		for grouped_id: int in grouped_ids:
			if not poses.has(grouped_id):
				continue
			var from_raw: Variant = poses[grouped_id]
			if typeof(from_raw) != TYPE_VECTOR3:
				continue
			var from: Vector3 = from_raw
			_spawn_checkpoint_mark(grouped_id, order, from, duplicated)
		if duplicated:
			continue
		var only_id: int = grouped_ids[0]
		if not poses.has(only_id):
			continue
		unique_entity_ids.append(only_id)
	var index: int = 0
	while index + 1 < unique_entity_ids.size():
		var from_id: int = unique_entity_ids[index]
		var to_id: int = unique_entity_ids[index + 1]
		var from_raw: Variant = poses[from_id]
		var to_raw: Variant = poses[to_id]
		if typeof(from_raw) != TYPE_VECTOR3 or typeof(to_raw) != TYPE_VECTOR3:
			index += 1
			continue
		var from: Vector3 = from_raw
		var to: Vector3 = to_raw
		_spawn_checkpoint_seq(from_id, to_id, from, to)
		index += 1


func _spawn_checkpoint_mark(entity_id: int, order: int, from: Vector3, duplicated: bool) -> void:
	var label: Label3D = Label3D.new()
	label.name = checkpoint_name(entity_id)
	label.text = str(order)
	label.font_size = 64
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	if duplicated:
		label.modulate = _CHECKPOINT_DUP_ALBEDO
	else:
		label.modulate = _CHECKPOINT_ALBEDO
	label.position = from + Vector3(0.0, CHECKPOINT_LIFT, 0.0)
	add_child(label)
	_checkpoint_count += 1


func _spawn_checkpoint_seq(from_id: int, to_id: int, from: Vector3, to: Vector3) -> void:
	var lifted_from: Vector3 = from + Vector3(0.0, SEQUENCE_LIFT, 0.0)
	var lifted_to: Vector3 = to + Vector3(0.0, SEQUENCE_LIFT, 0.0)
	var delta: Vector3 = lifted_to - lifted_from
	var length: float = delta.length()
	if length < _MIN_LINK_LEN:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(LINK_THICKNESS, LINK_THICKNESS, length)
	mesh.material = _unshaded(_CHECKPOINT_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = sequence_name(from_id, to_id)
	node.mesh = mesh
	node.position = (lifted_from + lifted_to) * 0.5
	add_child(node)
	_look_toward(node, lifted_to)
	_sequence_count += 1


func _look_toward(node: Node3D, target: Vector3) -> void:
	if not node.is_inside_tree():
		return
	var delta: Vector3 = target - node.position
	if delta.length_squared() < 0.0000001:
		return
	var up: Vector3 = Vector3.UP
	if absf(delta.normalized().dot(Vector3.UP)) > 0.999:
		up = Vector3.FORWARD
	node.look_at(target, up)


func _clear_orders() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		var child_name: String = str(child.name)
		if child_name.begins_with(CHECKPOINT_PREFIX) or child_name.begins_with(SEQUENCE_PREFIX):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_checkpoint_count = 0
	_sequence_count = 0


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
