class_name MatchSolidMapOcclusion
extends RefCounted

## Presentation-only cutaway for compiled solids. The camera itself stays
## locked to the 45-degree rig. Solids above the followed player are faded only
## when they cover the player's column or block the camera-to-player sight
## line. A platform merely ahead of the player is not an occluder: fading it
## makes distant floors look transparent and hides the course silhouette.
##
## The project renders with Compatibility, where GeometryInstance3D.transparency
## is ignored. Faded tiles therefore hide their detailed visual and show a
## translucent placeholder box through `material_override` instead.
##
## This is presentation only: `live_solid_boxes` and prediction keep the same
## occupancy, and no snapshot or replay data is changed.

## Horizontal radius, in cells, of the opening directly above the player. The
## camera-to-player line alone misses the platform covering the player's head:
## the camera sits outside the platform, so the line enters through the open
## side. This local opening is what lets the player see the next floor.
const CUTAWAY_NEAR_RADIUS_CELLS: float = 2.5
## Keep the floor silhouette readable while making the route behind it visible.
const CUTAWAY_TRANSPARENCY: float = 0.85

var _occluded_ids: Dictionary = {}
var _ghost_material: StandardMaterial3D = null


func update(
	map: MatchSolidMap, camera_position: Vector3, focus_position: Vector3, enabled: bool
) -> int:
	var next: Dictionary = {}
	if enabled:
		next = ids_for_cutaway(map._poses, map._cell, camera_position, focus_position)
	var changed: Dictionary = {}
	for key: Variant in _occluded_ids.keys():
		changed[key] = true
	for key: Variant in next.keys():
		changed[key] = true
	_occluded_ids = next
	for key: Variant in changed.keys():
		if typeof(key) == TYPE_INT:
			var entity_id: int = key
			refresh_visibility(map, entity_id)
	return _occluded_ids.size()


func count() -> int:
	return _occluded_ids.size()


func reset() -> void:
	_occluded_ids = {}


func clear(map: MatchSolidMap) -> void:
	reset()
	for pose: Dictionary in map._poses:
		var entity_id: int = PlayClock.dict_int(pose, "entity_id", 0)
		if entity_id > 0:
			refresh_visibility(map, entity_id)


func refresh_visibility(map: MatchSolidMap, entity_id: int) -> void:
	var node: MeshInstance3D = map.solid_node(entity_id)
	if node == null:
		return
	var gate_open: bool = map._open_gate_ids.has(entity_id)
	node.visible = not gate_open
	_set_cutaway(node, _occluded_ids.has(entity_id))


## Pure geometry for deterministic tests. Same-floor / support geometry is
## excluded by taking only boxes whose center is more than half a cell above
## the followed player.
static func ids_for_cutaway(
	poses: Array[Dictionary],
	cell: int,
	camera_position: Vector3,
	focus_position: Vector3,
	near_radius_cells: float = CUTAWAY_NEAR_RADIUS_CELLS
) -> Dictionary:
	var hidden: Dictionary = {}
	if cell < 1 or camera_position.is_equal_approx(focus_position):
		return hidden
	var cell_m: float = float(cell) / float(Fixed.SCALE)
	var half: float = cell_m * 0.5
	var near_radius: float = cell_m * maxf(near_radius_cells, 0.0)
	for pose: Dictionary in poses:
		var id_raw: Variant = pose.get("entity_id", 0)
		if typeof(id_raw) != TYPE_INT:
			continue
		var fixed_x: int = PlayClock.dict_int(pose, "x", 0)
		var fixed_y: int = PlayClock.dict_int(pose, "y", 0)
		var fixed_z: int = PlayClock.dict_int(pose, "z", 0)
		var center: Vector3 = Vector3(
			float(fixed_x) / float(Fixed.SCALE),
			float(fixed_y) / float(Fixed.SCALE),
			float(fixed_z) / float(Fixed.SCALE)
		)
		if center.y <= focus_position.y + half:
			continue
		var flat_delta: Vector2 = Vector2(center.x - focus_position.x, center.z - focus_position.z)
		if flat_delta.length_squared() <= near_radius * near_radius:
			hidden[id_raw] = true
			continue
		if _segment_hits_box(camera_position, focus_position, center, half):
			hidden[id_raw] = true
	return hidden


func _set_cutaway(node: MeshInstance3D, faded: bool) -> void:
	var visual: Node3D = node.get_node_or_null("visual") as Node3D
	if faded:
		if visual != null:
			visual.visible = false
		node.layers = 1
		node.material_override = ghost_material()
		return
	if visual != null:
		visual.visible = true
		node.layers = 0
	else:
		node.layers = 1
	node.material_override = null


func ghost_material() -> StandardMaterial3D:
	if _ghost_material != null:
		return _ghost_material
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ghost_color: Color = PlaceholderSpec.SOLID_ALBEDO
	ghost_color.a = 1.0 - CUTAWAY_TRANSPARENCY
	_ghost_material.albedo_color = ghost_color
	_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _ghost_material


static func _segment_hits_box(
	start: Vector3, finish: Vector3, center: Vector3, half: float
) -> bool:
	var direction: Vector3 = finish - start
	var t_min: float = 0.0
	var t_max: float = 1.0
	for axis: int in [0, 1, 2]:
		var origin: float = start[axis]
		var delta: float = direction[axis]
		var low: float = center[axis] - half
		var high: float = center[axis] + half
		if absf(delta) < 0.000001:
			if origin < low or origin > high:
				return false
			continue
		var first: float = (low - origin) / delta
		var second: float = (high - origin) / delta
		if first > second:
			var swap: float = first
			first = second
			second = swap
		t_min = maxf(t_min, first)
		t_max = minf(t_max, second)
		if t_min > t_max:
			return false
	return true
