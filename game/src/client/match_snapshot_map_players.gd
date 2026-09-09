class_name MatchSnapshotMapPlayers
extends RefCounted

## Spawn / visual / camera helpers for MatchSnapshotMap.
## Public apply_players stays on the map facade so this file stays under E9.


static func spawn_player(map: MatchSnapshotMap, slot: int, body: Dictionary) -> void:
	var pose: Dictionary = map._pose_from_player(body)
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var yaw_bam: int = pose["yaw_bam"]
	var seat: Color = MatchSnapshotMap.player_albedo(slot, map.follow_slot)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = MatchSnapshotMap.PLACEHOLDER_SIZE
	mesh.material = unshaded(seat)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = MatchSnapshotMap.player_name(slot)
	node.mesh = mesh
	node.position = Vector3(
		MatchSnapshotMap.meters_from_fixed(x),
		MatchSnapshotMap.meters_from_fixed(y),
		MatchSnapshotMap.meters_from_fixed(z)
	)
	node.rotation.y = MatchSnapshotMap.yaw_radians_from_bam(yaw_bam)
	map.add_child(node)
	spawn_facing(node)
	attach_visual(map, node, seat)


static func attach_visual(map: MatchSnapshotMap, player: MeshInstance3D, seat: Color) -> bool:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate(map.character_scene_path)
	if visual == null:
		return false
	visual.name = MatchSnapshotMap.VISUAL_NAME
	SharedVisualAssetCatalog.fit_character_on_cell(visual)
	player.add_child(visual)
	SharedVisualAssetCatalog.tint(visual, seat)
	player.layers = 0
	map._visual_count += 1
	return true


static func spawn_facing(player: MeshInstance3D) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = MatchSnapshotMap.FACE_SIZE
	mesh.material = unshaded(PlaceholderSpec.FACE_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = MatchSnapshotMap.FACE_NAME
	node.mesh = mesh
	node.position = MatchSnapshotMap.FACE_OFFSET
	player.add_child(node)


static func clear_players(map: MatchSnapshotMap) -> void:
	var stale: Array[Node] = []
	for child: Node in map.get_children():
		if str(child.name).begins_with(MatchSnapshotMap.PLAYER_PREFIX):
			stale.append(child)
	for node: Node in stale:
		map.remove_child(node)
		node.free()
	map._player_count = 0
	map._visual_count = 0


## 相机看的是 `follow_transition.anchor`，不是本席位姿本身。常态下两者逐帧相等
## （`track` 直接对齐），只有传送 / 复位那种一帧跳变才会短暂分开——那正是让
## 「我从哪去了哪」看得见的那一段。没有本席时 `reset()`，下一次出现直接就位。
static func aim_camera(map: MatchSnapshotMap) -> void:
	var followed: MeshInstance3D = map.player_node(map.follow_slot)
	if followed == null:
		map.follow_transition.reset()
	elif not map.follow_transition.has_anchor():
		map.follow_transition.snap_to(followed.position)
	elif map.follow_transition.track_pose(followed.position, map.follow_grounded):
		# 被传送之后还挂着上一处的中键平移量，等于把人跟丢。
		map.camera_pan = Vector3.ZERO
	var camera: Camera3D = map.camera_node()
	if camera == null:
		return
	var anchor: Vector3 = map.follow_transition.anchor + map.camera_pan
	camera.position = anchor + PlaceholderSpec.camera_offset_for_distance(map.camera_distance)
	look_at_target(camera, anchor)


## 快照玩家袋 → Q48.16 位姿。字段缺失或类型不对返回空字典（该玩家不可映射）。
static func pose_from_player(body: Dictionary) -> Dictionary:
	var pose: Dictionary = {}
	for key: String in ["x", "y", "z", "yaw_bam"]:
		if not body.has(key) or typeof(body[key]) != TYPE_INT:
			return {}
		pose[key] = body[key]
	return pose


## C4 表现动画状态的头顶读出标签。已存在就复用，不重建。
static func ensure_anim_label(player: MeshInstance3D) -> Label3D:
	var label: Label3D = player.get_node_or_null(MatchSnapshotMap.ANIM_NAME) as Label3D
	if label != null:
		return label
	label = Label3D.new()
	label.name = MatchSnapshotMap.ANIM_NAME
	label.font_size = PlaceholderSpec.LABEL3D_ANIM_FONT_SIZE
	label.pixel_size = PlaceholderSpec.LABEL3D_ANIM_PIXEL_SIZE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = PlaceholderSpec.LABEL3D_OUTLINE_SIZE
	label.position = Vector3(0.0, MatchSnapshotMap.ANIM_LIFT, 0.0)
	label.modulate = PlaceholderSpec.STANDING_RUNNING_ALBEDO
	player.add_child(label)
	return label


static func look_at_target(camera: Camera3D, target: Vector3) -> void:
	if camera == null or not camera.is_inside_tree():
		return
	var look: Vector3 = target - camera.position
	if look.length_squared() < 0.0000001:
		return
	var up: Vector3 = Vector3.UP
	if absf(look.normalized().dot(Vector3.UP)) > 0.999:
		up = Vector3.FORWARD
	camera.look_at(target, up)


static func unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
