class_name BastionFieldMap
extends Node3D

## Presentation mapping for a compiled BASTION blueprint + type-6 snapshot.
## Occupancy gadgets only. Authority stays in the snapshot / session.

const StaticGd := preload("res://src/client/bastion_field_map_static.gd")
const LiveGd := preload("res://src/client/bastion_field_map_live.gd")
const PickGd := preload("res://src/client/bastion_field_map_pick.gd")

const CAMERA_NAME: String = "BastionCamera"
const LIGHT_NAME: String = "BastionLight"
const STATIC_NAME: String = "StaticField"
const LIVE_NAME: String = "LiveField"

var bundle: BastionBlueprintBundle = null
var camera_distance: float = PlaceholderSpec.CAMERA_DISTANCE
var camera_pan: Vector3 = Vector3.ZERO
var selected_kind: String = ""
var selected_id: int = 0
var _apply_count: int = 0


func apply_bundle(next: BastionBlueprintBundle) -> bool:
	if next == null:
		return false
	bundle = next
	ensure_rig()
	StaticGd.rebuild(self, next)
	LiveGd.clear(self)
	_aim_camera()
	return true


func apply_path(path: String) -> bool:
	if path == "":
		return false
	var world: AuthoringWorld = AuthoringDocument.load_from_path(path)
	if world == null:
		return false
	return apply_bundle(BastionBlueprintCompiler.compile(world))


func apply_follow(follow: BastionSnapshotFollow) -> bool:
	if follow == null or not follow.has_snapshot or bundle == null:
		return false
	ensure_rig()
	LiveGd.sync(self, bundle, follow)
	StaticGd.mark_selected(self, selected_kind, selected_id)
	_apply_count += 1
	return true


func set_selection(kind: String, id: int) -> void:
	selected_kind = kind
	selected_id = id
	StaticGd.mark_selected(self, kind, id)


func pick_at(screen: Vector2) -> Dictionary:
	return PickGd.pick(self, screen)


func core_count() -> int:
	return StaticGd.count_named(self, StaticGd.CORE_PREFIX)


func build_slot_count() -> int:
	return StaticGd.count_named(self, StaticGd.BUILD_PREFIX)


func obstacle_slot_count() -> int:
	return StaticGd.count_named(self, StaticGd.OBSTACLE_SLOT_PREFIX)


func path_count() -> int:
	return StaticGd.count_named(self, StaticGd.PATH_PREFIX)


func tower_count() -> int:
	return LiveGd.count_named(self, LiveGd.TOWER_PREFIX)


func unit_count() -> int:
	return LiveGd.count_named(self, LiveGd.UNIT_PREFIX)


func obstacle_count() -> int:
	return LiveGd.count_named(self, LiveGd.OBSTACLE_PREFIX)


func apply_count() -> int:
	return _apply_count


func camera_node() -> Camera3D:
	return get_node_or_null(CAMERA_NAME) as Camera3D


func try_zoom(steps: int) -> bool:
	if steps == 0:
		return false
	var next: float = PlaceholderSpec.clamp_camera_distance(
		camera_distance - float(steps) * PlaceholderSpec.CAMERA_ZOOM_STEP
	)
	if next == camera_distance:
		return false
	camera_distance = next
	_aim_camera()
	return true


func try_pan(relative: Vector2) -> bool:
	if relative.x == 0.0 and relative.y == 0.0:
		return false
	var right: Vector3 = Vector3(1.0, 0.0, -1.0).normalized()
	var along: Vector3 = Vector3(-1.0, 0.0, -1.0).normalized()
	var next: Vector3 = camera_pan
	next += right * relative.x * PlaceholderSpec.CAMERA_PAN_SENS
	next += along * relative.y * PlaceholderSpec.CAMERA_PAN_SENS
	next.y = 0.0
	if next.length() > PlaceholderSpec.CAMERA_PAN_LIMIT:
		next = next.normalized() * PlaceholderSpec.CAMERA_PAN_LIMIT
	if next.is_equal_approx(camera_pan):
		return false
	camera_pan = next
	_aim_camera()
	return true


func ensure_rig() -> void:
	var camera: Camera3D = camera_node()
	if camera == null:
		camera = Camera3D.new()
		camera.name = CAMERA_NAME
		camera.fov = PlaceholderSpec.CAMERA_FOV_DEG
		add_child(camera)
	camera.current = visible
	var light: DirectionalLight3D = get_node_or_null(LIGHT_NAME) as DirectionalLight3D
	if light == null:
		light = DirectionalLight3D.new()
		light.name = LIGHT_NAME
		light.rotation_degrees = PlaceholderSpec.LIGHT_ROTATION_DEG
		add_child(light)
	if get_node_or_null(STATIC_NAME) == null:
		var static_root: Node3D = Node3D.new()
		static_root.name = STATIC_NAME
		add_child(static_root)
	if get_node_or_null(LIVE_NAME) == null:
		var live_root: Node3D = Node3D.new()
		live_root.name = LIVE_NAME
		add_child(live_root)


func _aim_camera() -> void:
	var camera: Camera3D = camera_node()
	if camera == null:
		return
	var target: Vector3 = StaticGd.field_center(self) + camera_pan
	var offset: Vector3 = PlaceholderSpec.camera_offset_for_distance(camera_distance)
	camera.position = target + offset
	camera.look_at(target, Vector3.UP)
