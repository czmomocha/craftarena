class_name AuthoringPreviewMapCamera
extends RefCounted

## Editor / Preview camera aim. MatchCameraView owns zoom / pan / orbit math;
## this helper only writes the Camera3D so AuthoringPreviewMap stays under E9.

const MatchCameraViewGd := preload("res://src/client/match_camera_view.gd")
const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")


static func bind_defaults(map: AuthoringPreviewMap) -> void:
	if map == null:
		return
	map.camera_distance = PlaceholderSpec.CAMERA_DISTANCE
	map.camera_pan = Vector3.ZERO
	map.camera_yaw_deg = PlaceholderSpec.CAMERA_YAW_DEG
	map.camera_pitch_deg = PlaceholderSpec.CAMERA_PITCH_DEG
	map.camera_pan_limit = PlaceholderSpec.CAMERA_EDIT_PAN_LIMIT
	map.camera_distance_min = PlaceholderSpec.CAMERA_EDIT_DISTANCE_MIN
	map.camera_distance_max = PlaceholderSpec.CAMERA_EDIT_DISTANCE_MAX


static func aim(map: AuthoringPreviewMap) -> void:
	if map == null:
		return
	var camera: Camera3D = map.get_node_or_null(AuthoringPreviewMap.CAMERA_NAME) as Camera3D
	if camera == null:
		return
	var target: Vector3 = map.camera_pan
	camera.fov = PlaceholderSpec.CAMERA_FOV_DEG
	camera.position = target + MatchCameraViewGd.offset_of(map)
	ConvertGd.look_toward(camera, target)


static func focus_at(map: AuthoringPreviewMap, target: Vector3) -> void:
	if map == null:
		return
	map.camera_pan = target
	aim(map)
