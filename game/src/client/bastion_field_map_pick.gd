extends RefCounted

## Screen-space pick of BASTION static slots. No physics shapes; gadgets
## are presentation-only so a camera ray vs cell AABB is the whole hit.

const CELL_M: float = PlaceholderSpec.METERS_PER_CELL


static func pick(map: BastionFieldMap, screen: Vector2) -> Dictionary:
	var failed: Dictionary = {"ok": false, "kind": "", "id": 0}
	if map == null or not map.visible:
		return failed
	var camera: Camera3D = map.camera_node()
	if camera == null:
		return failed
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	if direction.length_squared() < 0.0001:
		return failed
	var root: Node3D = map.get_node_or_null(BastionFieldMap.STATIC_NAME) as Node3D
	if root == null:
		return failed
	var best_kind: String = ""
	var best_id: int = 0
	var best_dist: float = 1.0e9
	for child: Node in root.get_children():
		var host: MeshInstance3D = child as MeshInstance3D
		if host == null:
			continue
		var kind: String = str(host.get_meta("pick_kind", ""))
		var id: int = host.get_meta("pick_id", 0)
		if kind == "" or id < 1:
			continue
		var hit: float = _ray_aabb(origin, direction, host.position)
		if hit < 0.0 or hit >= best_dist:
			continue
		best_dist = hit
		best_kind = kind
		best_id = id
	if best_id < 1:
		return failed
	return {"ok": true, "kind": best_kind, "id": best_id}


static func _ray_aabb(origin: Vector3, direction: Vector3, center: Vector3) -> float:
	var half: Vector3 = Vector3(CELL_M * 0.5, CELL_M * 0.5, CELL_M * 0.5)
	var min_p: Vector3 = center - half
	var max_p: Vector3 = center + half
	var tmin: float = 0.0
	var tmax: float = 1.0e9
	for axis: int in range(3):
		var origin_i: float = origin[axis]
		var dir_i: float = direction[axis]
		var min_i: float = min_p[axis]
		var max_i: float = max_p[axis]
		if absf(dir_i) < 0.000001:
			if origin_i < min_i or origin_i > max_i:
				return -1.0
			continue
		var inv: float = 1.0 / dir_i
		var t1: float = (min_i - origin_i) * inv
		var t2: float = (max_i - origin_i) * inv
		if t1 > t2:
			var swap: float = t1
			t1 = t2
			t2 = swap
		if t1 > tmin:
			tmin = t1
		if t2 < tmax:
			tmax = t2
		if tmin > tmax:
			return -1.0
	return tmin
