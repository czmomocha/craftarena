class_name MatchSnapshotMapGhost
extends RefCounted

## Solo ghost presentation. Not a live seat: no camera follow, no standings.

const NODE_NAME: String = "ghost_0"
const FADE: float = 0.5
const PATH_META: String = "ghost_visual_path"


static func apply(map: MatchSnapshotMap, follow: MatchSnapshotFollow, character_path: String) -> bool:
	if map == null:
		return false
	if follow == null or not follow.has_snapshot or follow.players.is_empty():
		clear(map)
		return false
	var raw: Variant = follow.players[0]
	if typeof(raw) != TYPE_DICTIONARY:
		clear(map)
		return false
	var body: Dictionary = raw
	var pose: Dictionary = MatchSnapshotMapPlayers.pose_from_player(body)
	if pose.is_empty():
		clear(map)
		return false
	var node: MeshInstance3D = map.get_node_or_null(NODE_NAME) as MeshInstance3D
	if node == null:
		node = _spawn(map, pose, character_path)
	else:
		_update(map, node, pose, character_path)
	return node != null


static func clear(map: MatchSnapshotMap) -> void:
	if map == null:
		return
	var stale: Node = map.get_node_or_null(NODE_NAME)
	if stale == null:
		return
	map.remove_child(stale)
	stale.free()


static func _spawn(map: MatchSnapshotMap, pose: Dictionary, character_path: String) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = MatchSnapshotMap.PLACEHOLDER_SIZE
	mesh.material = MatchSnapshotMapPlayers.unshaded(PlaceholderSpec.OWN_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = NODE_NAME
	node.mesh = mesh
	_write_pose(node, pose)
	map.add_child(node)
	_attach_visual(node, character_path)
	_fade_tree(node)
	return node


static func _update(
	map: MatchSnapshotMap, node: MeshInstance3D, pose: Dictionary, character_path: String
) -> void:
	_write_pose(node, pose)
	var current: String = ""
	if node.has_meta(PATH_META):
		current = str(node.get_meta(PATH_META))
	if current == character_path:
		return
	var stale: Node = node.get_node_or_null(MatchSnapshotMap.VISUAL_NAME)
	if stale != null:
		node.remove_child(stale)
		stale.free()
		node.layers = 1
	_attach_visual(node, character_path)
	_fade_tree(node)


static func _write_pose(node: MeshInstance3D, pose: Dictionary) -> void:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var yaw_bam: int = pose["yaw_bam"]
	node.position = Vector3(
		MatchSnapshotMap.meters_from_fixed(x),
		MatchSnapshotMap.meters_from_fixed(y),
		MatchSnapshotMap.meters_from_fixed(z)
	)
	node.rotation.y = MatchSnapshotMap.yaw_radians_from_bam(yaw_bam)


static func _attach_visual(player: MeshInstance3D, character_path: String) -> void:
	player.set_meta(PATH_META, character_path)
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate(character_path)
	if visual == null:
		return
	visual.name = MatchSnapshotMap.VISUAL_NAME
	SharedVisualAssetCatalog.fit_character_on_cell(
		visual, SharedCharacterCatalog.visual_yaw_deg_for_path(character_path)
	)
	player.add_child(visual)
	SharedVisualAssetCatalog.tint(visual, PlaceholderSpec.OWN_ALBEDO)
	player.layers = 0


static func _fade_tree(root: Node) -> void:
	var geometry: GeometryInstance3D = root as GeometryInstance3D
	if geometry != null:
		geometry.transparency = FADE
	for child: Node in root.get_children():
		_fade_tree(child)
