class_name AuthoringPreviewMapConvert
extends RefCounted

## Fixed→meters, pose decode, node names, and shared spatial helpers.
## Authority stays Q48.16; float conversion happens only here.

const PLACEHOLDER_PREFIX: String = "entity_"
const LINK_PREFIX: String = "portal_link_"
const DANGLE_PREFIX: String = "portal_dangle_"
const DIR_PREFIX: String = "portal_dir_"
const CHECKPOINT_PREFIX: String = "checkpoint_mark_"
const FINISH_PREFIX: String = "finish_mark_"
const SEQUENCE_PREFIX: String = "checkpoint_seq_"
const REACH_MARK_PREFIX: String = "reach_mark_"
const REACH_SEG_PREFIX: String = "reach_seg_"


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func yaw_radians_from_bam(yaw_bam: int) -> float:
	return TAU * float(yaw_bam) / float(Fixed.BAM_TURN)


static func pose_from_record(record: SharedComponentRecord) -> Dictionary:
	if record == null:
		return {}
	if not record.components.has(SharedComponentNames.TRANSFORM):
		return {}
	var raw: Variant = record.components[SharedComponentNames.TRANSFORM]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	if typeof(body.get("x", null)) != TYPE_INT:
		return {}
	if typeof(body.get("y", null)) != TYPE_INT:
		return {}
	if typeof(body.get("z", null)) != TYPE_INT:
		return {}
	if typeof(body.get("yaw_bam", null)) != TYPE_INT:
		return {}
	var x: int = body["x"]
	var y: int = body["y"]
	var z: int = body["z"]
	var yaw_bam: int = body["yaw_bam"]
	return {"x": x, "y": y, "z": z, "yaw_bam": yaw_bam}


static func order_from_record(record: SharedComponentRecord) -> int:
	if record == null:
		return -1
	if not record.components.has(SharedComponentNames.CHECKPOINT):
		return -1
	var raw: Variant = record.components[SharedComponentNames.CHECKPOINT]
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	var body: Dictionary = raw
	if typeof(body.get("order", null)) != TYPE_INT:
		return -1
	var order: int = body["order"]
	if order < 0:
		return -1
	return order


static func meters_from_pose(pose: Dictionary) -> Vector3:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	return Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))


static func unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


static func placeholder_name(entity_id: int) -> String:
	return "%s%d" % [PLACEHOLDER_PREFIX, entity_id]


static func link_name(source_id: int) -> String:
	return "%s%d" % [LINK_PREFIX, source_id]


static func dangle_name(source_id: int) -> String:
	return "%s%d" % [DANGLE_PREFIX, source_id]


static func direction_name(source_id: int) -> String:
	return "%s%d" % [DIR_PREFIX, source_id]


static func checkpoint_name(entity_id: int) -> String:
	return "%s%d" % [CHECKPOINT_PREFIX, entity_id]


static func finish_name(entity_id: int) -> String:
	return "%s%d" % [FINISH_PREFIX, entity_id]


static func sequence_name(from_id: int, to_id: int) -> String:
	return "%s%d_%d" % [SEQUENCE_PREFIX, from_id, to_id]


static func overlay_name(entity_id: int, code: String) -> String:
	return "%s%d_%s" % [REACH_MARK_PREFIX, entity_id, code]


static func unreachable_seg_name(from_id: int, to_id: int) -> String:
	return "%s%d_%d" % [REACH_SEG_PREFIX, from_id, to_id]


static func look_toward(node: Node3D, target: Vector3) -> void:
	if not node.is_inside_tree():
		return
	var delta: Vector3 = target - node.position
	if delta.length_squared() < 0.0000001:
		return
	var up: Vector3 = Vector3.UP
	if absf(delta.normalized().dot(Vector3.UP)) > 0.999:
		up = Vector3.FORWARD
	node.look_at(target, up)


## Intersect a camera ray with the floor plane y = floor_y_meters (1 cell = 1 m).
## Returns {ok, x, z} in cell indices. Misses (parallel / behind) return ok=false.
static func try_cell_xz_from_ray(origin: Vector3, direction: Vector3, floor_y_meters: float) -> Dictionary:
	if absf(direction.y) < 0.0001:
		return {"ok": false}
	var t: float = (floor_y_meters - origin.y) / direction.y
	if t <= 0.0:
		return {"ok": false}
	var hit: Vector3 = origin + direction * t
	return {"ok": true, "x": roundi(hit.x), "z": roundi(hit.z)}


## Closest 1 m placeholder along a camera ray. Presentation pick only.
static func try_entity_from_ray(
	map: Node3D, origin: Vector3, direction: Vector3, half: Vector3
) -> Dictionary:
	if map == null:
		return {"ok": false}
	var best_t: float = 256.0
	var best_id: int = 0
	var found: bool = false
	for child: Node in map.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh == null or not mesh.visible:
			continue
		var node_name: String = str(mesh.name)
		if not node_name.begins_with(PLACEHOLDER_PREFIX):
			continue
		var id_text: String = node_name.substr(PLACEHOLDER_PREFIX.length())
		if not id_text.is_valid_int():
			continue
		var entity_id: int = id_text.to_int()
		var aabb: AABB = AABB(mesh.position - half, half * 2.0)
		var t: float = _ray_aabb_t(origin, direction, aabb)
		if t < 0.0 or t >= best_t:
			continue
		best_t = t
		best_id = entity_id
		found = true
	if not found:
		return {"ok": false}
	return {"ok": true, "id": best_id}


static func _ray_aabb_t(origin: Vector3, dir: Vector3, aabb: AABB) -> float:
	var t0: float = 0.0
	var t1: float = 256.0
	var i: int = 0
	while i < 3:
		var origin_i: float = origin[i]
		var dir_i: float = dir[i]
		var mn: float = aabb.position[i]
		var mx: float = aabb.position[i] + aabb.size[i]
		if absf(dir_i) < 0.0000001:
			if origin_i < mn or origin_i > mx:
				return -1.0
			i += 1
			continue
		var inv: float = 1.0 / dir_i
		var a: float = (mn - origin_i) * inv
		var b: float = (mx - origin_i) * inv
		if a > b:
			var tmp: float = a
			a = b
			b = tmp
		if a > t0:
			t0 = a
		if b < t1:
			t1 = b
		if t0 > t1:
			return -1.0
		i += 1
	return t0
