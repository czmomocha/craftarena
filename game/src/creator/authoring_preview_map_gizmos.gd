class_name AuthoringPreviewMapGizmos
extends RefCounted

const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")

## Portal / checkpoint / finish gizmos for AuthoringPreviewMap.
## Placeholders stay occupancy; these overlays are not hitboxes.

const LINK_THICKNESS: float = 0.08
const DANGLE_SIZE: Vector3 = Vector3(0.35, 0.35, 0.35)
const DIR_SIZE: Vector3 = Vector3(0.2, 0.2, 0.2)
const DANGLE_LIFT: float = 0.7
const CHECKPOINT_LIFT: float = 1.15
const FINISH_LIFT: float = 1.15
const SEQUENCE_LIFT: float = 0.25
const _MIN_LINK_LEN: float = 0.001


func spawn_portals(map: AuthoringPreviewMap, world: AuthoringWorld) -> void:
	var links: Array[Dictionary] = world.portal_links()
	for link: Dictionary in links:
		if typeof(link.get("source_id", null)) != TYPE_INT:
			continue
		if typeof(link.get("kind", null)) != TYPE_STRING:
			continue
		var source_id: int = link["source_id"]
		var kind: String = link["kind"]
		var source_record: SharedComponentRecord = world.get_record(source_id)
		var source_pose: Dictionary = ConvertGd.pose_from_record(source_record)
		if source_pose.is_empty():
			continue
		var from: Vector3 = ConvertGd.meters_from_pose(source_pose)
		if kind == AuthoringPortalKinds.DANGLING:
			_spawn_dangle(map, source_id, from)
			continue
		if typeof(link.get("dest_id", null)) != TYPE_INT:
			continue
		var dest_id: int = link["dest_id"]
		var dest_pose: Dictionary = ConvertGd.pose_from_record(world.get_record(dest_id))
		if dest_pose.is_empty():
			_spawn_dangle(map, source_id, from)
			continue
		var to: Vector3 = ConvertGd.meters_from_pose(dest_pose)
		_spawn_link(map, source_id, kind, dest_id, from, to)
		if kind == AuthoringPortalKinds.ONE_WAY:
			_spawn_direction(map, source_id, from, to)


func spawn_checkpoints(map: AuthoringPreviewMap, world: AuthoringWorld) -> void:
	var by_order: Dictionary = {}
	var poses: Dictionary = {}
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		var order: int = ConvertGd.order_from_record(record)
		if order < 0:
			continue
		if not by_order.has(order):
			var grouped: Array[int] = []
			by_order[order] = grouped
		var group: Array = by_order[order]
		group.append(entity_id)
		var pose: Dictionary = ConvertGd.pose_from_record(record)
		if pose.is_empty():
			continue
		poses[entity_id] = ConvertGd.meters_from_pose(pose)
	var order_keys: Array = by_order.keys()
	order_keys.sort()
	var unique_orders: Array[int] = []
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
			_spawn_checkpoint_mark(map, grouped_id, order, from, duplicated)
		if duplicated:
			continue
		var only_id: int = grouped_ids[0]
		if not poses.has(only_id):
			continue
		unique_orders.append(order)
		unique_entity_ids.append(only_id)
	var index: int = 0
	while index + 1 < unique_orders.size():
		var from_id: int = unique_entity_ids[index]
		var to_id: int = unique_entity_ids[index + 1]
		var from_raw: Variant = poses[from_id]
		var to_raw: Variant = poses[to_id]
		if typeof(from_raw) != TYPE_VECTOR3 or typeof(to_raw) != TYPE_VECTOR3:
			index += 1
			continue
		var from: Vector3 = from_raw
		var to: Vector3 = to_raw
		_spawn_checkpoint_seq(map, from_id, to_id, from, to)
		index += 1


func spawn_finish(map: AuthoringPreviewMap, world: AuthoringWorld) -> void:
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null or not map.occupancy.record_has_finish_tag(record):
			continue
		var pose: Dictionary = ConvertGd.pose_from_record(record)
		if pose.is_empty():
			continue
		_spawn_finish_mark(map, entity_id, ConvertGd.meters_from_pose(pose))


func _spawn_dangle(map: AuthoringPreviewMap, source_id: int, from: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = DANGLE_SIZE
	mesh.material = ConvertGd.unshaded(PlaceholderSpec.PORTAL_DANGLE_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = ConvertGd.dangle_name(source_id)
	node.mesh = mesh
	node.position = from + Vector3(0.0, DANGLE_LIFT, 0.0)
	map.add_child(node)


func _spawn_link(
	map: AuthoringPreviewMap,
	source_id: int,
	kind: String,
	dest_id: int,
	from: Vector3,
	to: Vector3
) -> void:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < _MIN_LINK_LEN:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(LINK_THICKNESS, LINK_THICKNESS, length)
	var color: Color = PlaceholderSpec.PORTAL_TWO_WAY_ALBEDO
	if kind == AuthoringPortalKinds.ONE_WAY:
		color = PlaceholderSpec.PORTAL_ONE_WAY_ALBEDO
	mesh.material = ConvertGd.unshaded(color)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = ConvertGd.link_name(source_id)
	node.mesh = mesh
	node.position = (from + to) * 0.5
	node.set_meta("kind", kind)
	node.set_meta("dest_id", dest_id)
	map.add_child(node)
	ConvertGd.look_toward(node, to)


func _spawn_direction(map: AuthoringPreviewMap, source_id: int, from: Vector3, to: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = DIR_SIZE
	mesh.material = ConvertGd.unshaded(PlaceholderSpec.PORTAL_ONE_WAY_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = ConvertGd.direction_name(source_id)
	node.mesh = mesh
	node.position = from.lerp(to, 0.8) + Vector3(0.0, 0.15, 0.0)
	map.add_child(node)


func _spawn_checkpoint_mark(
	map: AuthoringPreviewMap,
	entity_id: int,
	order: int,
	from: Vector3,
	duplicated: bool
) -> void:
	var label: Label3D = Label3D.new()
	label.name = ConvertGd.checkpoint_name(entity_id)
	label.text = str(order)
	label.set_meta(AuthoringPreviewMap.ENTITY_META, entity_id)
	label.set_meta(AuthoringPreviewMap.ORDER_META, order)
	label.font_size = 64
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	if duplicated:
		label.modulate = PlaceholderSpec.CHECKPOINT_DUP_ALBEDO
	else:
		label.modulate = PlaceholderSpec.CHECKPOINT_ALBEDO
	label.position = from + Vector3(0.0, CHECKPOINT_LIFT, 0.0)
	map.add_child(label)


func _spawn_finish_mark(map: AuthoringPreviewMap, entity_id: int, from: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.name = ConvertGd.finish_name(entity_id)
	label.text = "finish"
	label.font_size = 48
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	label.modulate = AuthoringPreviewMap.FINISH_ALBEDO
	label.position = from + Vector3(0.0, FINISH_LIFT, 0.0)
	map.add_child(label)


func _spawn_checkpoint_seq(
	map: AuthoringPreviewMap,
	from_id: int,
	to_id: int,
	from: Vector3,
	to: Vector3
) -> void:
	var lifted_from: Vector3 = from + Vector3(0.0, SEQUENCE_LIFT, 0.0)
	var lifted_to: Vector3 = to + Vector3(0.0, SEQUENCE_LIFT, 0.0)
	var delta: Vector3 = lifted_to - lifted_from
	var length: float = delta.length()
	if length < _MIN_LINK_LEN:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(LINK_THICKNESS, LINK_THICKNESS, length)
	mesh.material = ConvertGd.unshaded(PlaceholderSpec.CHECKPOINT_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = ConvertGd.sequence_name(from_id, to_id)
	node.mesh = mesh
	node.position = (lifted_from + lifted_to) * 0.5
	map.add_child(node)
	ConvertGd.look_toward(node, lifted_to)
