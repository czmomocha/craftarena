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
	visual.position = SharedVisualAssetCatalog.CHARACTER_FOOT_LIFT
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


static func aim_camera(map: MatchSnapshotMap) -> void:
	var target: Vector3 = Vector3.ZERO
	var followed: MeshInstance3D = map.player_node(map.follow_slot)
	if followed != null:
		target = followed.position
	var camera: Camera3D = map.camera_node()
	if camera == null:
		return
	camera.position = target + MatchSnapshotMap.CAMERA_OFFSET
	look_at_target(camera, target)


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
