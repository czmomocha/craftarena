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
## follow_slot aims SnapshotCamera at that player's presentation pose
## with the same offset as AuthoringPreviewMap; < 0 or a missing slot
## looks at the origin. The offset and FOV are D4 values read from
## PlaceholderSpec (45° yaw / 45° pitch, distance and FOV unchanged),
## not a locked product camera rig. follow_slot also tints that box as the own seat
## (OWN_ALBEDO); other seats use REMOTE_ALBEDO. Not product cosmetics.
## Box size, camera offset, and every colour come from PlaceholderSpec; this
## file keeps the names but no longer owns the values (D4 changes one place).
## Each player box has a local -Z facing marker so yaw is visible on a
## cube. Not a product turn speed.
##
## 当 `character_scene_path` 能解析出视觉资产（SharedVisualAssetCatalog，
## ADR-0006 Q4）时，每个玩家节点多挂一个 `visual` 子节点，占位盒自身退出渲染
## （`layers = 0`）但**节点、网格与座位色材质原样保留**：座位色仍由它定义，
## 名次标签、朝向标记与预测 overlay 读的还是同一个节点位姿。视觉解析失败就是
## 今天的行为，一个 1 米盒。视觉从不参与裁决，权威胶囊仍是
## PlaceholderSpec.CHARACTER_RADIUS / HEIGHT。
##
## apply_players 复用席位节点，只有席位数变化才增删（见 `_sync_players`）。
## 这不是优化偏好，是每帧预算：全清全建会每帧重新 instantiate 角色 `.glb`。
##
## `set_anim_state` 把 C4 表现动画状态写到席位 metadata 与子 Label3D `anim`。
## 那是契约读出，不是 HUD 字段、也不是 clip。在线快照缺接地 / 硬直字段，
## 大厅只在 Solo 接线。

const MatchSnapshotFollowGd := preload("res://src/client/match_snapshot_follow.gd")
const PlayersGd := preload("res://src/client/match_snapshot_map_players.gd")

const CAMERA_NAME: String = "SnapshotCamera"
const LIGHT_NAME: String = "SnapshotLight"
const PLAYER_PREFIX: String = "player_"
const PLACEHOLDER_SIZE: Vector3 = PlaceholderSpec.BOX_SIZE
const CAMERA_OFFSET: Vector3 = PlaceholderSpec.CAMERA_OFFSET
const CAMERA_FOV_DEG: float = PlaceholderSpec.CAMERA_FOV_DEG
const FACE_NAME: String = "face"
const FACE_OFFSET: Vector3 = Vector3(0.0, 0.15, -0.55)
const FACE_SIZE: Vector3 = Vector3(0.18, 0.18, 0.28)
const VISUAL_NAME: String = "visual"
const ANIM_NAME: String = "anim"
const ANIM_META: String = "anim_state"
const ANIM_LIFT: float = 1.6
const OWN_ALBEDO: Color = PlaceholderSpec.OWN_ALBEDO
const REMOTE_ALBEDO: Color = PlaceholderSpec.REMOTE_ALBEDO

var follow_slot: int = -1
## 空字符串或解析失败 ⇒ 回退占位盒。是变量而不是常量，好让测试两条分支都能跑。
var character_scene_path: String = SharedVisualAssetCatalog.CHARACTER_SCENE_PATH
var _player_count: int = 0
var _visual_count: int = 0


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func yaw_radians_from_bam(yaw_bam: int) -> float:
	return TAU * float(yaw_bam) / float(Fixed.BAM_TURN)


static func player_name(slot: int) -> String:
	return "%s%d" % [PLAYER_PREFIX, slot]


static func player_albedo(slot: int, followed: int) -> Color:
	if followed >= 0 and slot == followed:
		return OWN_ALBEDO
	return REMOTE_ALBEDO


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
	_sync_players(players)
	_aim_camera()
	return true


## 复用已有席位节点：只写位姿与座位色，不 free、也不重新 instantiate。
##
## 存在的理由是每帧成本，不是代码整洁。本函数在 `MatchLobbyShell._process` 里
## **每帧**被调一次。它此前是"全清全建"，而 C4 第 5 章给玩家接上 `.glb` 之后，
## 那等于每帧 free 掉一个 3000 三角面的角色实例、再 `PackedScene.instantiate()`
## 一遍，外加两个 `StandardMaterial3D.new()`。开发机实测 2 席 **12.76 ms/帧**，
## 复用后 **0.44 ms/帧**（29×）。60 FPS 只有 16.7 ms 预算，所以旧路径单这一项
## 就吃掉 77%，并把输入采样率一起拖下来——采样在 `_process` 里按帧走，不按固定
## 时钟，帧时间翻倍就等于按键响应翻倍。
##
## 只有席位数变化才增删节点：变少删尾部，变多补新的。slot 是稳定键（与
## `MatchStandingMap` 一致），所以"第 1 席换了人"仍复用第 1 席的节点——视觉是
## 同一个角色资产，位姿与座位色每帧都会被覆盖，没有可残留的状态。
func _sync_players(players: Array) -> void:
	var wanted: int = players.size()
	if wanted == 0:
		_clear_players()
		return
	for slot: int in range(wanted, _player_count):
		_despawn_player(slot)
	var index: int = 0
	for raw: Variant in players:
		var body: Dictionary = raw
		var existing: MeshInstance3D = player_node(index)
		if existing == null:
			_spawn_player(index, body)
		else:
			_update_player(existing, index, body)
		index += 1
	_player_count = wanted


func _despawn_player(slot: int) -> void:
	var stale: MeshInstance3D = player_node(slot)
	if stale == null:
		return
	if stale.get_node_or_null(VISUAL_NAME) != null:
		_visual_count -= 1
	remove_child(stale)
	stale.free()


## 复用路径：写位姿，必要时改座位色。不碰网格、材质实例与视觉子节点。
func _update_player(node: MeshInstance3D, slot: int, body: Dictionary) -> void:
	var pose: Dictionary = _pose_from_player(body)
	if pose.is_empty():
		return
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var yaw_bam: int = pose["yaw_bam"]
	node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))
	node.rotation.y = yaw_radians_from_bam(yaw_bam)
	_retint(node, player_albedo(slot, follow_slot))


## 座位色只在真的变了时才写。`follow_slot` 一局里基本不变，所以每帧的常态是
## 一次 Color 比较，不是一次材质上传。占位盒与视觉薄膜总是一起设，所以拿盒子
## 当前的 albedo 当作"这个席位现在是什么颜色"的判据。
func _retint(node: MeshInstance3D, seat: Color) -> void:
	var mesh: BoxMesh = node.mesh as BoxMesh
	if mesh == null:
		return
	var material: StandardMaterial3D = mesh.material as StandardMaterial3D
	if material == null or material.albedo_color == seat:
		return
	material.albedo_color = seat
	var visual: Node3D = node.get_node_or_null(VISUAL_NAME) as Node3D
	if visual != null:
		SharedVisualAssetCatalog.tint(visual, seat)


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


func facing_node(slot: int) -> MeshInstance3D:
	var player: MeshInstance3D = player_node(slot)
	if player == null:
		return null
	return player.get_node_or_null(FACE_NAME) as MeshInstance3D


func visual_node(slot: int) -> Node3D:
	var player: MeshInstance3D = player_node(slot)
	if player == null:
		return null
	return player.get_node_or_null(VISUAL_NAME) as Node3D


func anim_node(slot: int) -> Label3D:
	var player: MeshInstance3D = player_node(slot)
	if player == null:
		return null
	return player.get_node_or_null(ANIM_NAME) as Label3D


func anim_state(slot: int) -> String:
	var player: MeshInstance3D = player_node(slot)
	if player == null or not player.has_meta(ANIM_META):
		return ""
	return str(player.get_meta(ANIM_META))


## 把表现状态写到席位。未知名字拒绝，避免 HUD 打出随便一个字符串。
## 标签是契约读出：人眼能在 Solo 里看见 idle/run/jump，clip 仍不播。
func set_anim_state(slot: int, state: String) -> bool:
	if not PlayAnimState.contains(state):
		return false
	var player: MeshInstance3D = player_node(slot)
	if player == null:
		return false
	player.set_meta(ANIM_META, state)
	var label: Label3D = anim_node(slot)
	if label == null:
		label = Label3D.new()
		label.name = ANIM_NAME
		label.font_size = 48
		label.pixel_size = 0.015
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 8
		label.position = Vector3(0.0, ANIM_LIFT, 0.0)
		label.modulate = PlaceholderSpec.STANDING_RUNNING_ALBEDO
		player.add_child(label)
	label.text = state
	return true


## 有多少个席位真的用上了视觉资产。0 表示全部回退到占位盒。
func visual_count() -> int:
	return _visual_count


func camera_node() -> Camera3D:
	return get_node_or_null(CAMERA_NAME) as Camera3D


func ensure_rig() -> void:
	var camera: Camera3D = get_node_or_null(CAMERA_NAME) as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = CAMERA_NAME
		camera.position = CAMERA_OFFSET
		camera.fov = CAMERA_FOV_DEG
		camera.current = true
		add_child(camera)
		_look_at_target(camera, Vector3.ZERO)
	var light: DirectionalLight3D = get_node_or_null(LIGHT_NAME) as DirectionalLight3D
	if light == null:
		light = DirectionalLight3D.new()
		light.name = LIGHT_NAME
		light.rotation_degrees = PlaceholderSpec.LIGHT_ROTATION_DEG
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
	PlayersGd.spawn_player(self, slot, body)


## 视觉资产在时：挂 `visual` 子节点并让占位盒本体退出渲染层。用 `layers = 0`
## 而不是 `visible = false`，因为后者会连带隐藏 `face` 与 `visual` 两个子节点。
func _attach_visual(player: MeshInstance3D, seat: Color) -> bool:
	return PlayersGd.attach_visual(self, player, seat)


func _spawn_facing(player: MeshInstance3D) -> void:
	PlayersGd.spawn_facing(player)


func _clear_players() -> void:
	PlayersGd.clear_players(self)


func _aim_camera() -> void:
	PlayersGd.aim_camera(self)


func _look_at_target(camera: Camera3D, target: Vector3) -> void:
	PlayersGd.look_at_target(camera, target)


func _unshaded(color: Color) -> StandardMaterial3D:
	return PlayersGd.unshaded(color)
