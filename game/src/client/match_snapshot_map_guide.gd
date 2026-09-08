class_name MatchSnapshotMapGuide
extends RefCounted

## 本席头顶的世界导航箭头（可玩性深化，轨 1：传送与镜头）。
##
## 存在的理由是多层课的方向感：HUD 那一行 `next=` 告诉玩家「右下、上一层、6 米」，
## 但读一行字要低头；世界里插一支指着目标的箭头，抬眼就能跟。两者是同一份
## `PlayWayfinder` 计划的两个读出，不各自算方向。
##
## 只挂在本席。远端席位不挂——别人的目标与你的不是同一个，画出来只是噪声。
## 表现读出，不进裁决、不进快照、不发网络。
##
## 公开 API 仍在 `MatchSnapshotMap` 门面上，本文件只是让门面低于 E9 400 行。

const GUIDE_NAME: String = "guide"


## 按楼层差分色：方向已经由朝向给出，颜色只回答「同层找 / 上楼 / 下楼」。
static func albedo(floor_delta: int) -> Color:
	if floor_delta > 0:
		return PlaceholderSpec.GUIDE_UP_ALBEDO
	if floor_delta < 0:
		return PlaceholderSpec.GUIDE_DOWN_ALBEDO
	return PlaceholderSpec.GUIDE_SAME_ALBEDO


## 让局部 -Z 指向 `direction` 所需的偏航（弧度）。与 `face` 标记同一约定。
static func yaw_radians(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## 复用同一个节点，只写位姿与色。对局壳每帧调一次，不能全清全建。
static func apply(
	map: MatchSnapshotMap,
	slot: int,
	direction: Vector3,
	floor_delta: int
) -> bool:
	var player: MeshInstance3D = map.player_node(slot)
	if player == null:
		return false
	var node: MeshInstance3D = player.get_node_or_null(GUIDE_NAME) as MeshInstance3D
	if node == null:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = PlaceholderSpec.GUIDE_SIZE
		mesh.material = MatchSnapshotMapPlayers.unshaded(albedo(floor_delta))
		node = MeshInstance3D.new()
		node.name = GUIDE_NAME
		node.mesh = mesh
		player.add_child(node)
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z).normalized()
	node.position = flat * PlaceholderSpec.GUIDE_FORWARD_M + Vector3(
		0.0, PlaceholderSpec.GUIDE_LIFT, 0.0
	)
	# 箭头挂在玩家节点下，而玩家节点带偏航；抵消掉才不会跟着人转。
	node.rotation.y = yaw_radians(flat) - player.rotation.y
	_retint(node, albedo(floor_delta))
	return true


static func clear(map: MatchSnapshotMap, slot: int) -> void:
	var player: MeshInstance3D = map.player_node(slot)
	if player == null:
		return
	var node: Node = player.get_node_or_null(GUIDE_NAME)
	if node == null:
		return
	player.remove_child(node)
	node.free()


static func count(map: MatchSnapshotMap, player_count: int) -> int:
	var total: int = 0
	for slot: int in range(player_count):
		if node_of(map, slot) != null:
			total += 1
	return total


static func node_of(map: MatchSnapshotMap, slot: int) -> MeshInstance3D:
	var player: MeshInstance3D = map.player_node(slot)
	if player == null:
		return null
	return player.get_node_or_null(GUIDE_NAME) as MeshInstance3D


static func _retint(node: MeshInstance3D, wanted: Color) -> void:
	var mesh: BoxMesh = node.mesh as BoxMesh
	if mesh == null:
		return
	var material: StandardMaterial3D = mesh.material as StandardMaterial3D
	if material == null or material.albedo_color == wanted:
		return
	material.albedo_color = wanted
