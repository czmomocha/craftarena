extends RefCounted

## Static BASTION field: cores, empty slots, path marks.

const CORE_PREFIX: String = "core_"
const BUILD_PREFIX: String = "build_"
const OBSTACLE_SLOT_PREFIX: String = "oslot_"
const PATH_PREFIX: String = "path_"
const SELECT_NAME: String = "select"


static func rebuild(map: BastionFieldMap, bundle: BastionBlueprintBundle) -> void:
	var root: Node3D = map.get_node_or_null(BastionFieldMap.STATIC_NAME) as Node3D
	if root == null:
		return
	_clear(root)
	for core: Dictionary in bundle.cores:
		var node: Dictionary = bundle.node_at(_i(core, "node_id"))
		if node.is_empty():
			continue
		var team_id: int = _i(core, "team_id")
		var kind: String = OccupancyGadget.KIND_BASTION_CORE
		if team_id == BastionBlueprintBundle.TEAM_B:
			kind = OccupancyGadget.KIND_BASTION_CORE_B
		var host: MeshInstance3D = _spawn(
			root, CORE_PREFIX + str(team_id), node, kind
		)
		host.set_meta("pick_kind", "")
		host.set_meta("pick_id", 0)
		host.set_meta("team_id", team_id)
	for slot: Dictionary in bundle.build_slots:
		var pose: Dictionary = {
			"x": _i(slot, "x"),
			"y": _i(slot, "y"),
			"z": _i(slot, "z"),
		}
		var entity_id: int = _i(slot, "entity_id")
		var host: MeshInstance3D = _spawn(
			root,
			BUILD_PREFIX + str(entity_id),
			pose,
			OccupancyGadget.KIND_BASTION_BUILD_SLOT
		)
		host.set_meta("pick_kind", BastionInteract.KIND_BUILD)
		host.set_meta("pick_id", entity_id)
		host.set_meta("team_id", _i(slot, "team_id"))
	for slot: Dictionary in bundle.obstacle_slots:
		var node_id: int = _i(slot, "node_id")
		var node: Dictionary = bundle.node_at(node_id)
		if node.is_empty():
			continue
		var host: MeshInstance3D = _spawn(
			root,
			OBSTACLE_SLOT_PREFIX + str(node_id),
			node,
			OccupancyGadget.KIND_BASTION_OBSTACLE_SLOT
		)
		host.set_meta("pick_kind", BastionInteract.KIND_OBSTACLE)
		host.set_meta("pick_id", node_id)
		host.set_meta("team_id", _i(slot, "team_id"))
	for waypoint: Dictionary in bundle.waypoints:
		_spawn(
			root,
			PATH_PREFIX + str(_i(waypoint, "node_id")),
			waypoint,
			OccupancyGadget.KIND_BASTION_PATH
		)


static func mark_selected(map: BastionFieldMap, kind: String, id: int) -> void:
	var root: Node3D = map.get_node_or_null(BastionFieldMap.STATIC_NAME) as Node3D
	if root == null:
		return
	for child: Node in root.get_children():
		var host: MeshInstance3D = child as MeshInstance3D
		if host == null:
			continue
		var pick_id: int = host.get_meta("pick_id", 0)
		var wanted: bool = (
			str(host.get_meta("pick_kind", "")) == kind
			and pick_id == id
			and id > 0
		)
		_set_select(host, wanted)


static func field_center(map: BastionFieldMap) -> Vector3:
	var root: Node3D = map.get_node_or_null(BastionFieldMap.STATIC_NAME) as Node3D
	if root == null or root.get_child_count() == 0:
		return Vector3.ZERO
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for child: Node in root.get_children():
		var host: Node3D = child as Node3D
		if host == null:
			continue
		if not str(host.name).begins_with(CORE_PREFIX):
			continue
		sum += host.position
		n += 1
	if n == 0:
		return Vector3.ZERO
	return sum / float(n)


static func count_named(map: BastionFieldMap, prefix: String) -> int:
	var root: Node3D = map.get_node_or_null(BastionFieldMap.STATIC_NAME) as Node3D
	if root == null:
		return 0
	var n: int = 0
	for child: Node in root.get_children():
		if str(child.name).begins_with(prefix):
			n += 1
	return n


static func _spawn(
	root: Node3D, node_name: String, pose: Dictionary, kind: String
) -> MeshInstance3D:
	var host: MeshInstance3D = MeshInstance3D.new()
	host.name = node_name
	host.mesh = BoxMesh.new()
	(host.mesh as BoxMesh).size = Vector3(0.08, 0.08, 0.08)
	host.position = Vector3(
		float(_i(pose, "x")) / float(Fixed.SCALE),
		float(_i(pose, "y")) / float(Fixed.SCALE),
		float(_i(pose, "z")) / float(Fixed.SCALE)
	)
	host.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	OccupancyGadget.attach(host, kind, 0)
	root.add_child(host)
	return host


static func _set_select(host: MeshInstance3D, on: bool) -> void:
	var existing: Node3D = host.get_node_or_null(SELECT_NAME) as Node3D
	if on:
		if existing != null:
			return
		var mark: MeshInstance3D = MeshInstance3D.new()
		mark.name = SELECT_NAME
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(1.05, 0.08, 1.05)
		mark.mesh = mesh
		mark.position = Vector3(0.0, 0.55, 0.0)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = PlaceholderSpec.BASTION_SELECTED_ALBEDO
		mark.material_override = material
		host.add_child(mark)
		return
	if existing != null:
		existing.free()


static func _clear(root: Node3D) -> void:
	var children: Array[Node] = root.get_children()
	for child: Node in children:
		root.remove_child(child)
		child.free()


static func _i(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	return raw
