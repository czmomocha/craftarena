class_name OccupancyGadget
extends RefCounted

## Procedural occupancy placeholders (playability batch 5).
##
## Conveyors / lifts / launches / switches / gates / energy walls used to
## look like terrain tiles or 1 m colour cubes. This builder hangs a named
## `gadget` child so those cells stay readable without a new `.glb`.
## Colours come from PlaceholderSpec. Authority is still the lattice box.

const NODE_NAME: String = "gadget"

const KIND_CONVEYOR: String = "conveyor"
const KIND_LAUNCH: String = "launch"
const KIND_LIFT: String = "lift"
const KIND_SWITCH: String = "switch"
const KIND_GATE: String = "gate"
const KIND_ENERGY_WALL: String = "energy_wall"


static func attach(parent: Node3D, kind: String, yaw_bam: int) -> bool:
	if parent == null or kind.is_empty():
		return false
	var gadget: Node3D = Node3D.new()
	gadget.name = NODE_NAME
	match kind:
		KIND_CONVEYOR:
			_fill_conveyor(gadget)
		KIND_LAUNCH:
			_fill_launch(gadget)
		KIND_LIFT:
			_fill_lift(gadget)
		KIND_SWITCH:
			_fill_switch(gadget)
		KIND_GATE:
			_fill_gate(gadget)
		KIND_ENERGY_WALL:
			_fill_energy_wall(gadget)
		_:
			gadget.free()
			return false
	gadget.rotation.y = yaw_radians(yaw_bam)
	parent.add_child(gadget)
	return true


static func gadget_node(parent: Node3D) -> Node3D:
	if parent == null:
		return null
	return parent.get_node_or_null(NODE_NAME) as Node3D


static func yaw_radians(yaw_bam: int) -> float:
	return float(yaw_bam) / float(Fixed.BAM_TURN) * TAU


static func yaw_lookup(bags: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for raw: Variant in bags:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var bag: Dictionary = raw
		if typeof(bag.get("entity_id", null)) != TYPE_INT:
			continue
		var entity_id: int = bag["entity_id"]
		if entity_id < 1:
			continue
		var yaw_bam: int = 0
		if typeof(bag.get("yaw_bam", null)) == TYPE_INT:
			yaw_bam = bag["yaw_bam"]
		lookup[entity_id] = yaw_bam
	return lookup


static func lift_ids_from_movers(movers: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for raw: Variant in movers:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var bag: Dictionary = raw
		if typeof(bag.get("entity_id", null)) != TYPE_INT:
			continue
		var entity_id: int = bag["entity_id"]
		var path_raw: Variant = bag.get("path", [])
		if typeof(path_raw) != TYPE_ARRAY:
			continue
		var path: Array = path_raw
		if is_lift_path(path):
			lookup[entity_id] = true
	return lookup


static func id_lookup(bags: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for raw: Variant in bags:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var bag: Dictionary = raw
		if typeof(bag.get("entity_id", null)) != TYPE_INT:
			continue
		var entity_id: int = bag["entity_id"]
		if entity_id >= 1:
			lookup[entity_id] = true
	return lookup


static func solid_kind(
	entity_id: int,
	conveyor_yaw: Dictionary,
	launch_yaw: Dictionary,
	lift_ids: Dictionary,
	switch_ids: Dictionary,
	gate_ids: Dictionary
) -> String:
	if conveyor_yaw.has(entity_id):
		return KIND_CONVEYOR
	if launch_yaw.has(entity_id):
		return KIND_LAUNCH
	if lift_ids.has(entity_id):
		return KIND_LIFT
	if switch_ids.has(entity_id):
		return KIND_SWITCH
	if gate_ids.has(entity_id):
		return KIND_GATE
	return ""


static func is_lift_path(path: Array) -> bool:
	if path.size() < 2:
		return false
	var first_raw: Variant = path[0]
	if typeof(first_raw) != TYPE_DICTIONARY:
		return false
	var first: Dictionary = first_raw
	if typeof(first.get("x", null)) != TYPE_INT or typeof(first.get("z", null)) != TYPE_INT:
		return false
	var x0: int = first["x"]
	var z0: int = first["z"]
	var saw_y: bool = false
	var y0: int = 0
	if typeof(first.get("y", null)) == TYPE_INT:
		y0 = first["y"]
	for raw: Variant in path:
		if typeof(raw) != TYPE_DICTIONARY:
			return false
		var point: Dictionary = raw
		if typeof(point.get("x", null)) != TYPE_INT or typeof(point.get("z", null)) != TYPE_INT:
			return false
		if point["x"] != x0 or point["z"] != z0:
			return false
		if typeof(point.get("y", null)) != TYPE_INT:
			return false
		var y: int = point["y"]
		if y != y0:
			saw_y = true
	return saw_y


static func _fill_conveyor(gadget: Node3D) -> void:
	_mesh(
		gadget,
		"Belt",
		_box(Vector3(0.92, 0.08, 0.92)),
		PlaceholderSpec.CONVEYOR_ALBEDO,
		Vector3(0.0, -0.42, 0.0)
	)
	var offset: float = -0.28
	while offset <= 0.28:
		_mesh(
			gadget,
			"Chevron",
			_box(Vector3(0.22, 0.04, 0.12)),
			PlaceholderSpec.CONVEYOR_MARK_ALBEDO,
			Vector3(0.0, -0.36, offset)
		)
		offset += 0.28


static func _fill_launch(gadget: Node3D) -> void:
	_mesh(
		gadget,
		"Pad",
		_box(Vector3(0.9, 0.1, 0.9)),
		PlaceholderSpec.LAUNCH_ALBEDO,
		Vector3(0.0, -0.4, 0.0)
	)
	_mesh(
		gadget,
		"Arrow",
		_box(Vector3(0.18, 0.08, 0.42)),
		PlaceholderSpec.LAUNCH_MARK_ALBEDO,
		Vector3(0.0, -0.32, -0.12)
	)


static func _fill_lift(gadget: Node3D) -> void:
	_mesh(
		gadget,
		"Deck",
		_box(Vector3(0.9, 0.1, 0.9)),
		PlaceholderSpec.LIFT_ALBEDO,
		Vector3(0.0, -0.4, 0.0)
	)
	var posts: Array[Vector3] = [
		Vector3(-0.38, 0.05, -0.38),
		Vector3(0.38, 0.05, -0.38),
		Vector3(-0.38, 0.05, 0.38),
		Vector3(0.38, 0.05, 0.38),
	]
	for pos: Vector3 in posts:
		_mesh(gadget, "Post", _box(Vector3(0.08, 0.9, 0.08)), PlaceholderSpec.LIFT_MARK_ALBEDO, pos)


static func _fill_switch(gadget: Node3D) -> void:
	_mesh(
		gadget,
		"Plate",
		_box(Vector3(0.78, 0.12, 0.78)),
		PlaceholderSpec.SWITCH_ALBEDO,
		Vector3(0.0, -0.38, 0.0)
	)


static func _fill_gate(gadget: Node3D) -> void:
	_mesh(
		gadget,
		"Slab",
		_box(Vector3(0.92, 0.92, 0.18)),
		PlaceholderSpec.GATE_ALBEDO,
		Vector3(0.0, 0.0, 0.0)
	)


static func _fill_energy_wall(gadget: Node3D) -> void:
	_mesh(
		gadget,
		"Panel",
		_box(Vector3(0.92, 0.92, 0.14)),
		PlaceholderSpec.ENERGY_WALL_ALBEDO,
		Vector3(0.0, 0.0, 0.0),
		true
	)


static func _box(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh


static func _mesh(
	gadget: Node3D,
	node_name: String,
	mesh: BoxMesh,
	albedo: Color,
	offset: Vector3,
	translucent: bool = false
) -> void:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = offset
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = albedo
	if translucent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	gadget.add_child(node)
