class_name AuthoringPreviewMapPlayer
extends RefCounted

const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")

## Preview play player marker. Reuses the node when the visual path is unchanged.
## SharedVisualAssetCatalog supplies the same character the match maps use.


func show_pose(map: AuthoringPreviewMap, pose: Dictionary) -> void:
	if typeof(pose.get("x", null)) != TYPE_INT:
		clear(map)
		return
	if typeof(pose.get("y", null)) != TYPE_INT:
		clear(map)
		return
	if typeof(pose.get("z", null)) != TYPE_INT:
		clear(map)
		return
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var yaw_bam: int = 0
	if typeof(pose.get("yaw", null)) == TYPE_INT:
		yaw_bam = pose["yaw"]
	var node: MeshInstance3D = _reusable_player_node(map)
	if node == null:
		clear(map)
		node = _create_player_node(map)
	node.position = Vector3(
		ConvertGd.meters_from_fixed(x),
		ConvertGd.meters_from_fixed(y),
		ConvertGd.meters_from_fixed(z)
	)
	node.rotation.y = ConvertGd.yaw_radians_from_bam(yaw_bam)


func clear(map: AuthoringPreviewMap) -> void:
	var node: Node = map.get_node_or_null(AuthoringPreviewMap.PLAYER_NAME)
	if node == null:
		return
	map.remove_child(node)
	node.free()


func set_anim_state(map: AuthoringPreviewMap, state: String) -> bool:
	if not PlayAnimState.contains(state):
		return false
	var player: MeshInstance3D = map.player_node()
	if player == null:
		return false
	player.set_meta(AuthoringPreviewMap.ANIM_META, state)
	var label: Label3D = map.player_anim_node()
	if label == null:
		label = Label3D.new()
		label.name = AuthoringPreviewMap.ANIM_NAME
		label.font_size = 48
		label.pixel_size = 0.015
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 8
		label.position = Vector3(0.0, AuthoringPreviewMap.ANIM_LIFT, 0.0)
		label.modulate = PlaceholderSpec.STANDING_RUNNING_ALBEDO
		player.add_child(label)
	label.text = state
	return true


func _reusable_player_node(map: AuthoringPreviewMap) -> MeshInstance3D:
	var node: MeshInstance3D = map.player_node()
	if node == null:
		return null
	if not node.has_meta(AuthoringPreviewMap.VISUAL_PATH_META):
		return null
	if str(node.get_meta(AuthoringPreviewMap.VISUAL_PATH_META)) != map.character_scene_path:
		return null
	return node


func _create_player_node(map: AuthoringPreviewMap) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = AuthoringPreviewMap.PLACEHOLDER_SIZE
	mesh.material = ConvertGd.unshaded(PlaceholderSpec.PREVIEW_PLAYER_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = AuthoringPreviewMap.PLAYER_NAME
	node.mesh = mesh
	node.set_meta(AuthoringPreviewMap.VISUAL_PATH_META, map.character_scene_path)
	map.add_child(node)
	_attach_player_visual(map, node)
	return node


## 与 MatchSnapshotMap._attach_visual 同一套：挂 `visual` 子节点、占位盒本体
## `layers = 0` 退出渲染但保留网格与色值。Preview 只有一个人，用 Preview 的
## 玩家色染薄膜。
func _attach_player_visual(map: AuthoringPreviewMap, player: MeshInstance3D) -> bool:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate(map.character_scene_path)
	if visual == null:
		return false
	visual.name = AuthoringPreviewMap.VISUAL_NAME
	visual.position = SharedVisualAssetCatalog.CHARACTER_FOOT_LIFT
	player.add_child(visual)
	SharedVisualAssetCatalog.tint(visual, PlaceholderSpec.PREVIEW_PLAYER_ALBEDO)
	player.layers = 0
	return true
