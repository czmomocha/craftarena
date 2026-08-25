class_name MatchSnapshotMap
extends Node3D

## Presentation mapping for the latest authoritative match snapshot (CD-43).
## Each snapshot player becomes a 1 m box at the Q48.16 pose. Authority
## stays in MatchSnapshotFollow; float conversion happens only here.
## Placeholders are not hitboxes. Crates have no pose in the v1 snapshot
## frame, so they are not drawn here; MatchCrateMap uses topology poses.
## Portal source→dest bars stay undrawn here; MatchPortalLinkMap draws them.
## Checkpoint-order gizmos stay undrawn here; MatchCheckpointOrderMap
## draws them. Standing labels stay undrawn here; MatchStandingMap
## draws them. This node does not interpolate; the lobby may pass
## sampled poses from MatchSnapshotInterp. The lobby may then overlay
## MatchLocalPredict on the local seat. This node does not predict.

const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")

const CAMERA_NAME: String = "SnapshotCamera"
const LIGHT_NAME: String = "SnapshotLight"
const PLAYER_PREFIX: String = "player_"
const PLACEHOLDER_SIZE: Vector3 = Vector3(1.0, 1.0, 1.0)
const _CAMERA_POS: Vector3 = Vector3(6.0, 8.0, 6.0)
const _LIGHT_ROT_DEG: Vector3 = Vector3(-50.0, -30.0, 0.0)
const _PLAYER_ALBEDO: Color = Color(0.2, 0.45, 0.95)

var _player_count: int = 0


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func yaw_radians_from_bam(yaw_bam: int) -> float:
	return TAU * float(yaw_bam) / float(Fixed.BAM_TURN)


static func player_name(slot: int) -> String:
	return "%s%d" % [PLAYER_PREFIX, slot]


func apply_follow(follow: MatchSnapshotFollowGd) -> bool:
	if follow == null or not follow.has_snapshot:
		return false
	return apply_players(follow.players, follow.crates)


func apply_players(players: Array, crates: Array = []) -> bool:
	if not _players_are_mappable(players):
		return false
	if typeof(crates) != TYPE_ARRAY:
		return false
	ensure_rig()
	_clear_players()
	var index: int = 0
	for raw: Variant in players:
		var body: Dictionary = raw
		_spawn_player(index, body)
		index += 1
	_player_count = players.size()
	return true


func player_count() -> int:
	return _player_count


func crate_node_count() -> int:
	return 0


func link_node_count() -> int:
	return 0


func checkpoint_node_count() -> int:
	return 0


func standing_node_count() -> int:
	return 0


func player_node(slot: int) -> MeshInstance3D:
	return get_node_or_null(player_name(slot)) as MeshInstance3D


func ensure_rig() -> void:
	var camera: Camera3D = get_node_or_null(CAMERA_NAME) as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = CAMERA_NAME
		camera.position = _CAMERA_POS
		camera.current = true
		add_child(camera)
		if is_inside_tree():
			camera.look_at(Vector3.ZERO)
	var light: DirectionalLight3D = get_node_or_null(LIGHT_NAME) as DirectionalLight3D
	if light == null:
		light = DirectionalLight3D.new()
		light.name = LIGHT_NAME
		light.rotation_degrees = _LIGHT_ROT_DEG
		add_child(light)


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _players_are_mappable(players: Array) -> bool:
	for raw: Variant in players:
		if typeof(raw) != TYPE_DICTIONARY:
			return false
		var body: Dictionary = raw
		if _pose_from_player(body).is_empty():
			return false
	return true


func _pose_from_player(body: Dictionary) -> Dictionary:
	if not body.has("x") or not body.has("y") or not body.has("z") or not body.has("yaw_bam"):
		return {}
	if typeof(body["x"]) != TYPE_INT:
		return {}
	if typeof(body["y"]) != TYPE_INT:
		return {}
	if typeof(body["z"]) != TYPE_INT:
		return {}
	if typeof(body["yaw_bam"]) != TYPE_INT:
		return {}
	var x: int = body["x"]
	var y: int = body["y"]
	var z: int = body["z"]
	var yaw_bam: int = body["yaw_bam"]
	return {
		"x": x,
		"y": y,
		"z": z,
		"yaw_bam": yaw_bam,
	}


func _spawn_player(slot: int, body: Dictionary) -> void:
	var pose: Dictionary = _pose_from_player(body)
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var yaw_bam: int = pose["yaw_bam"]
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	mesh.material = _unshaded(_PLAYER_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = player_name(slot)
	node.mesh = mesh
	node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))
	node.rotation.y = yaw_radians_from_bam(yaw_bam)
	add_child(node)


func _clear_players() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		if str(child.name).begins_with(PLAYER_PREFIX):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_player_count = 0


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
