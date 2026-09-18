class_name MatchCameraView
extends RefCounted

## Shared zoom / pan / orbit / reset for SnapshotCamera and BastionCamera.
## Defaults stay D4 45° / √136; orbit is preview-only (runtime locks in match).


static func try_zoom(map: Node, steps: int) -> bool:
	if map == null or steps == 0:
		return false
	var current: float = _float_at(map, "camera_distance", PlaceholderSpec.CAMERA_DISTANCE)
	var min_d: float = _float_at(map, "camera_distance_min", PlaceholderSpec.CAMERA_DISTANCE_MIN)
	var max_d: float = _float_at(map, "camera_distance_max", PlaceholderSpec.CAMERA_DISTANCE_MAX)
	var next: float = clampf(
		current - float(steps) * PlaceholderSpec.CAMERA_ZOOM_STEP,
		min_d,
		max_d
	)
	if next == current:
		return false
	map.set("camera_distance", next)
	_aim(map)
	return true


static func try_pan(map: Node, relative: Vector2) -> bool:
	if map == null:
		return false
	if relative.x == 0.0 and relative.y == 0.0:
		return false
	var yaw: float = deg_to_rad(_float_at(map, "camera_yaw_deg", PlaceholderSpec.CAMERA_YAW_DEG))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var along: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var current: Vector3 = _vec3_at(map, "camera_pan")
	var next: Vector3 = current
	next += right * relative.x * PlaceholderSpec.CAMERA_PAN_SENS
	next += along * relative.y * PlaceholderSpec.CAMERA_PAN_SENS
	next.y = 0.0
	var limit: float = _float_at(map, "camera_pan_limit", PlaceholderSpec.CAMERA_PAN_LIMIT)
	if next.length() > limit:
		next = next.normalized() * limit
	if next.is_equal_approx(current):
		return false
	map.set("camera_pan", next)
	_aim(map)
	return true


static func try_orbit(map: Node, relative: Vector2) -> bool:
	if map == null:
		return false
	if relative.x == 0.0 and relative.y == 0.0:
		return false
	var yaw: float = _float_at(map, "camera_yaw_deg", PlaceholderSpec.CAMERA_YAW_DEG)
	var pitch: float = _float_at(map, "camera_pitch_deg", PlaceholderSpec.CAMERA_PITCH_DEG)
	var next_yaw: float = _wrap_yaw(yaw - relative.x * PlaceholderSpec.CAMERA_ORBIT_SENS)
	var next_pitch: float = clampf(
		pitch + relative.y * PlaceholderSpec.CAMERA_ORBIT_SENS,
		PlaceholderSpec.CAMERA_PITCH_MIN_DEG,
		PlaceholderSpec.CAMERA_PITCH_MAX_DEG
	)
	if is_equal_approx(next_yaw, yaw) and is_equal_approx(next_pitch, pitch):
		return false
	map.set("camera_yaw_deg", next_yaw)
	map.set("camera_pitch_deg", next_pitch)
	_aim(map)
	return true


static func reset_view(map: Node) -> void:
	if map == null:
		return
	map.set("camera_distance", PlaceholderSpec.CAMERA_DISTANCE)
	map.set("camera_pan", Vector3.ZERO)
	map.set("camera_yaw_deg", PlaceholderSpec.CAMERA_YAW_DEG)
	map.set("camera_pitch_deg", PlaceholderSpec.CAMERA_PITCH_DEG)
	_aim(map)


static func offset_of(map: Node) -> Vector3:
	if map == null:
		return PlaceholderSpec.CAMERA_OFFSET
	return PlaceholderSpec.camera_offset_at(
		_float_at(map, "camera_distance", PlaceholderSpec.CAMERA_DISTANCE),
		_float_at(map, "camera_yaw_deg", PlaceholderSpec.CAMERA_YAW_DEG),
		_float_at(map, "camera_pitch_deg", PlaceholderSpec.CAMERA_PITCH_DEG)
	)


static func _float_at(map: Node, key: String, fallback: float) -> float:
	var raw: Variant = map.get(key)
	if typeof(raw) == TYPE_FLOAT:
		var f: float = raw
		return f
	if typeof(raw) == TYPE_INT:
		var n: int = raw
		return float(n)
	return fallback


static func _vec3_at(map: Node, key: String) -> Vector3:
	var raw: Variant = map.get(key)
	if typeof(raw) == TYPE_VECTOR3:
		var vec: Vector3 = raw
		return vec
	return Vector3.ZERO


static func _wrap_yaw(yaw_deg: float) -> float:
	var wrapped: float = fmod(yaw_deg, 360.0)
	if wrapped < 0.0:
		wrapped += 360.0
	return wrapped


static func _aim(map: Node) -> void:
	if map.has_method("_aim_camera"):
		map.call("_aim_camera")
