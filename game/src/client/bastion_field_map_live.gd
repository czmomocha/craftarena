extends RefCounted

## Live BASTION snapshot overlay: towers, units, placed obstacles.
## Reuses nodes by id so apply_follow can run every frame.

const TOWER_PREFIX: String = "tower_"
const UNIT_PREFIX: String = "unit_"
const OBSTACLE_PREFIX: String = "obstacle_"
const BastionGd := preload("res://src/shared/occupancy_gadget_bastion.gd")


static func clear(map: BastionFieldMap) -> void:
	var root: Node3D = map.get_node_or_null(BastionFieldMap.LIVE_NAME) as Node3D
	if root == null:
		return
	var children: Array[Node] = root.get_children()
	for child: Node in children:
		root.remove_child(child)
		child.free()


static func sync(
	map: BastionFieldMap, bundle: BastionBlueprintBundle, follow: BastionSnapshotFollow
) -> void:
	var root: Node3D = map.get_node_or_null(BastionFieldMap.LIVE_NAME) as Node3D
	if root == null:
		return
	var wanted: Dictionary = {}
	for item: Variant in follow.teams:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var team: Dictionary = item
		_want_towers(wanted, bundle, team)
		_want_units(wanted, team)
		_want_obstacles(wanted, bundle, team)
	var stale: Array[Node] = []
	for child: Node in root.get_children():
		if wanted.has(child.name):
			continue
		stale.append(child)
	for child: Node in stale:
		root.remove_child(child)
		child.free()
	for key: Variant in wanted.keys():
		var name: String = str(key)
		var spec: Dictionary = wanted[name]
		var existing: MeshInstance3D = root.get_node_or_null(name) as MeshInstance3D
		if existing == null:
			_spawn(root, name, spec)
		else:
			var pos: Vector3 = spec["pos"]
			var scale: Vector3 = spec["scale"]
			existing.position = pos
			existing.scale = scale


static func count_named(map: BastionFieldMap, prefix: String) -> int:
	var root: Node3D = map.get_node_or_null(BastionFieldMap.LIVE_NAME) as Node3D
	if root == null:
		return 0
	var n: int = 0
	for child: Node in root.get_children():
		if str(child.name).begins_with(prefix):
			n += 1
	return n


static func _want_towers(wanted: Dictionary, bundle: BastionBlueprintBundle, team: Dictionary) -> void:
	var towers: Array = _arr(team, "towers")
	for item: Variant in towers:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var tower: Dictionary = item
		var slot_id: int = _i(tower, "slot_id")
		var slot: Dictionary = bundle.build_slot_at(slot_id)
		if slot.is_empty():
			continue
		var kind: String = BastionGd.kind_for_tower(_i(tower, "prototype_id"))
		if kind == "":
			continue
		var level: int = _i(tower, "level")
		if level < 1:
			level = 1
		var scale: float = 1.0 + 0.12 * float(maxi(level - 1, 0))
		wanted[TOWER_PREFIX + str(slot_id)] = {
			"kind": kind,
			"pos": _meters(_i(slot, "x"), _i(slot, "y"), _i(slot, "z")),
			"scale": Vector3(scale, scale, scale),
		}


static func _want_units(wanted: Dictionary, team: Dictionary) -> void:
	var units: Array = _arr(team, "units")
	for item: Variant in units:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = item
		var kind: String = BastionGd.kind_for_unit(_i(unit, "prototype_id"))
		if kind == "":
			continue
		var unit_id: int = _i(unit, "unit_id")
		wanted[UNIT_PREFIX + str(unit_id)] = {
			"kind": kind,
			"pos": _meters(_i(unit, "x"), _i(unit, "y"), _i(unit, "z")),
			"scale": Vector3.ONE,
		}


static func _want_obstacles(
	wanted: Dictionary, bundle: BastionBlueprintBundle, team: Dictionary
) -> void:
	var obstacles: Array = _arr(team, "obstacles")
	for item: Variant in obstacles:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var obstacle: Dictionary = item
		var node_id: int = _i(obstacle, "node_id")
		var node: Dictionary = bundle.node_at(node_id)
		if node.is_empty():
			continue
		var kind: String = BastionGd.kind_for_obstacle(_i(obstacle, "prototype_id"))
		if kind == "":
			continue
		wanted[OBSTACLE_PREFIX + str(node_id)] = {
			"kind": kind,
			"pos": _meters(_i(node, "x"), _i(node, "y"), _i(node, "z")),
			"scale": Vector3.ONE,
		}


static func _spawn(root: Node3D, node_name: String, spec: Dictionary) -> void:
	var host: MeshInstance3D = MeshInstance3D.new()
	host.name = node_name
	host.mesh = BoxMesh.new()
	(host.mesh as BoxMesh).size = Vector3(0.08, 0.08, 0.08)
	var pos: Vector3 = spec["pos"]
	var scale: Vector3 = spec["scale"]
	host.position = pos
	host.scale = scale
	host.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	OccupancyGadget.attach(host, str(spec.get("kind", "")), 0)
	root.add_child(host)


static func _meters(x: int, y: int, z: int) -> Vector3:
	var scale: float = float(Fixed.SCALE)
	return Vector3(float(x) / scale, float(y) / scale, float(z) / scale)


static func _i(body: Dictionary, key: String) -> int:
	var raw: Variant = body.get(key, 0)
	if typeof(raw) != TYPE_INT:
		return 0
	return raw


static func _arr(body: Dictionary, key: String) -> Array:
	var raw: Variant = body.get(key, [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw
