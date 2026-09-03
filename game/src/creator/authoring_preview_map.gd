class_name AuthoringPreviewMap
extends Node3D

## Presentation mapping facade for AuthoringWorld (CD-32 §3). Preview and Editor
## share it. Authority stays Q48.16; float conversion is convert. Collaborators
## are occupancy / gizmos / overlay / player so this file stays under E9 400 lines.
## Public API stays on this type. rebuild() is a dirty check, not an unconditional
## rebuild: skip when the world fingerprint is unchanged. Placeholders and gizmos
## are not hitboxes. Overlay reads evaluate(); it is not a write gate.

const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")
const OccupancyGd := preload("res://src/creator/authoring_preview_map_occupancy.gd")
const GizmosGd := preload("res://src/creator/authoring_preview_map_gizmos.gd")
const OverlayGd := preload("res://src/creator/authoring_preview_map_overlay.gd")
const PlayerGd := preload("res://src/creator/authoring_preview_map_player.gd")
const FloorGd := preload("res://src/creator/authoring_preview_map_floor.gd")

const CAMERA_NAME: String = "PreviewCamera"
const LIGHT_NAME: String = "PreviewLight"
const PLAYER_NAME: String = "player_marker"
const VISUAL_NAME: String = "visual"
const ANIM_NAME: String = "anim"
const ANIM_META: String = "anim_state"
const ANIM_LIFT: float = 1.6
const PLACEHOLDER_SIZE: Vector3 = PlaceholderSpec.BOX_SIZE
const HAZARD_ALBEDO: Color = PlaceholderSpec.HAZARD_ALBEDO
const SOLID_ALBEDO: Color = PlaceholderSpec.SOLID_ALBEDO
const FINISH_ALBEDO: Color = PlaceholderSpec.FINISH_PENDING_ALBEDO
const CRATE_ALBEDO: Color = PlaceholderSpec.CRATE_ALBEDO
const ENTITY_META: String = "entity_id"
const ORDER_META: String = "checkpoint_order"
const VISUAL_PATH_META: String = "visual_path"
const ACCEPTED_SUFFIX: String = "*"

## 空字符串或解析失败 ⇒ 回退占位盒。是变量而不是常量，好让测试两条分支都能跑。
var character_scene_path: String = SharedVisualAssetCatalog.CHARACTER_SCENE_PATH
var tile_scene_path: String = SharedVisualAssetCatalog.TERRAIN_TILE_SCENE_PATH
var pad_scene_path: String = SharedVisualAssetCatalog.CHECKPOINT_PAD_SCENE_PATH
var gate_scene_path: String = SharedVisualAssetCatalog.CHECKPOINT_GATE_SCENE_PATH
var finish_scene_path: String = SharedVisualAssetCatalog.FINISH_GATE_SCENE_PATH
var crate_scene_path: String = SharedVisualAssetCatalog.CRATE_SCENE_PATH
var hazard_scene_path: String = SharedVisualAssetCatalog.HAZARD_ROLLER_SCENE_PATH
## 上次真重建时的世界指纹。`_built_revision < 0` 表示还没建过任何一次。
## 记 instance_id 是因为 duplicate() / 回滚快照会换成同 revision 的另一个实例；
## 记 entity_count 与 cell 是因为 try_restore 能把 revision 设回一个旧值。
var _built_world_id: int = 0
var _built_revision: int = -1
var _built_entity_count: int = 0
var _built_cell: int = 0
var _built_character_path: String = ""
var _built_tile_path: String = ""
var _built_occupancy_key: String = ""
var _rebuild_count: int = 0
var _skipped_count: int = 0
var occupancy: OccupancyGd = OccupancyGd.new()
var gizmos: GizmosGd = GizmosGd.new()
var overlay: OverlayGd = OverlayGd.new()
var player_marks: PlayerGd = PlayerGd.new()


static func meters_from_fixed(value: int) -> float:
	return ConvertGd.meters_from_fixed(value)


static func yaw_radians_from_bam(yaw_bam: int) -> float:
	return ConvertGd.yaw_radians_from_bam(yaw_bam)


static func pose_from_record(record: SharedComponentRecord) -> Dictionary:
	return ConvertGd.pose_from_record(record)


static func order_from_record(record: SharedComponentRecord) -> int:
	return ConvertGd.order_from_record(record)


static func meters_from_pose(pose: Dictionary) -> Vector3:
	return ConvertGd.meters_from_pose(pose)


func ensure_rig() -> void:
	var camera: Camera3D = get_node_or_null(CAMERA_NAME) as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = CAMERA_NAME
		camera.position = PlaceholderSpec.CAMERA_OFFSET
		camera.fov = PlaceholderSpec.CAMERA_FOV_DEG
		camera.current = true
		add_child(camera)
		if is_inside_tree():
			camera.look_at(Vector3.ZERO)
	var light: DirectionalLight3D = get_node_or_null(LIGHT_NAME) as DirectionalLight3D
	if light == null:
		light = DirectionalLight3D.new()
		light.name = LIGHT_NAME
		light.rotation_degrees = PlaceholderSpec.LIGHT_ROTATION_DEG
		add_child(light)


func rebuild(world: AuthoringWorld) -> void:
	ensure_rig()
	if _built_fingerprint_matches(world):
		_skipped_count += 1
		return
	_rebuild_count += 1
	_remember_built(world)
	_clear_meshes()
	overlay.reset()
	if world == null:
		return
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		var pose: Dictionary = pose_from_record(record)
		if pose.is_empty():
			continue
		occupancy.spawn_placeholder(self, entity_id, pose, record)
	gizmos.spawn_portals(self, world)
	gizmos.spawn_checkpoints(self, world)
	gizmos.spawn_finish(self, world)
	overlay.spawn(self, world)


## 强制下一次 rebuild 真做。调用方在自己改过节点树（显隐、标记）而世界指纹
## 没变时必须用它，否则脏检查会认为「已经是想要的样子」。
func invalidate() -> void:
	_built_revision = -1


## 真正重建过几次。测试用它证明「世界没变就不重建」，不是性能阈值。
func rebuild_count() -> int:
	return _rebuild_count


func skipped_rebuild_count() -> int:
	return _skipped_count


func _built_fingerprint_matches(world: AuthoringWorld) -> bool:
	if _built_revision < 0:
		return false
	if _built_character_path != character_scene_path:
		return false
	if _built_tile_path != tile_scene_path:
		return false
	if _built_occupancy_key != _occupancy_key():
		return false
	if world == null:
		return _built_world_id == 0
	if _built_world_id != world.get_instance_id():
		return false
	if _built_revision != world.revision:
		return false
	if _built_entity_count != world.entity_count():
		return false
	return _built_cell == _cell_of(world)


func _remember_built(world: AuthoringWorld) -> void:
	_built_character_path = character_scene_path
	_built_tile_path = tile_scene_path
	_built_occupancy_key = _occupancy_key()
	if world == null:
		_built_world_id = 0
		_built_revision = 0
		_built_entity_count = 0
		_built_cell = 0
		return
	_built_world_id = world.get_instance_id()
	_built_revision = world.revision
	_built_entity_count = world.entity_count()
	_built_cell = _cell_of(world)


func _occupancy_key() -> String:
	return "%s\n%s\n%s\n%s\n%s" % [
		pad_scene_path,
		gate_scene_path,
		finish_scene_path,
		crate_scene_path,
		hazard_scene_path,
	]


func _cell_of(world: AuthoringWorld) -> int:
	if world.grid == null:
		return 0
	return world.grid.cell


func show_player_pose(pose: Dictionary) -> void:
	player_marks.show_pose(self, pose)


func clear_player_pose() -> void:
	player_marks.clear(self)


func player_node() -> MeshInstance3D:
	return get_node_or_null(PLAYER_NAME) as MeshInstance3D


func player_visual_node() -> Node3D:
	var player: MeshInstance3D = player_node()
	if player == null:
		return null
	return player.get_node_or_null(VISUAL_NAME) as Node3D


func player_anim_node() -> Label3D:
	var player: MeshInstance3D = player_node()
	if player == null:
		return null
	return player.get_node_or_null(ANIM_NAME) as Label3D


func player_anim_state() -> String:
	var player: MeshInstance3D = player_node()
	if player == null or not player.has_meta(ANIM_META):
		return ""
	return str(player.get_meta(ANIM_META))


func set_anim_state(state: String) -> bool:
	return player_marks.set_anim_state(self, state)


func mapped_count() -> int:
	return _count_mesh_prefix(ConvertGd.PLACEHOLDER_PREFIX)


func link_count() -> int:
	return _count_mesh_prefix(ConvertGd.LINK_PREFIX)


func dangle_count() -> int:
	return _count_mesh_prefix(ConvertGd.DANGLE_PREFIX)


func checkpoint_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is Label3D and str(child.name).begins_with(ConvertGd.CHECKPOINT_PREFIX):
			count += 1
	return count


func finish_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is Label3D and str(child.name).begins_with(ConvertGd.FINISH_PREFIX):
			count += 1
	return count


func sequence_count() -> int:
	return _count_mesh_prefix(ConvertGd.SEQUENCE_PREFIX)


func placeholder_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(ConvertGd.placeholder_name(entity_id)) as MeshInstance3D


func placeholder_visual_node(entity_id: int) -> Node3D:
	var placeholder: MeshInstance3D = placeholder_node(entity_id)
	if placeholder == null:
		return null
	return placeholder.get_node_or_null(VISUAL_NAME) as Node3D


func focus_entity(entity_id: int) -> bool:
	ensure_rig()
	var placeholder: MeshInstance3D = placeholder_node(entity_id)
	if placeholder == null:
		return false
	var camera: Camera3D = get_node_or_null(CAMERA_NAME) as Camera3D
	if camera == null:
		return false
	var target: Vector3 = placeholder.position
	camera.position = target + PlaceholderSpec.CAMERA_OFFSET
	if camera.is_inside_tree():
		var up: Vector3 = Vector3.UP
		var look: Vector3 = target - camera.position
		if look.length_squared() < 0.0000001:
			return true
		if absf(look.normalized().dot(Vector3.UP)) > 0.999:
			up = Vector3.FORWARD
		camera.look_at(target, up)
	return true


func link_node(source_id: int) -> MeshInstance3D:
	return get_node_or_null(ConvertGd.link_name(source_id)) as MeshInstance3D


func dangle_node(source_id: int) -> MeshInstance3D:
	return get_node_or_null(ConvertGd.dangle_name(source_id)) as MeshInstance3D


func direction_node(source_id: int) -> MeshInstance3D:
	return get_node_or_null(ConvertGd.direction_name(source_id)) as MeshInstance3D


func checkpoint_node(entity_id: int) -> Label3D:
	return get_node_or_null(ConvertGd.checkpoint_name(entity_id)) as Label3D


func finish_node(entity_id: int) -> Label3D:
	return get_node_or_null(ConvertGd.finish_name(entity_id)) as Label3D


## 按传入集合重写每个检查点标签的文本，而不是只往已验收的那些追加 *。
## rebuild 会被脏检查跳过，所以「取消验收」（R 复位）只能靠这里把 * 去掉。
func mark_accepted_checkpoints(entity_ids: PackedInt32Array) -> void:
	var accepted: Dictionary[int, bool] = {}
	for index: int in range(entity_ids.size()):
		accepted[entity_ids[index]] = true
	for child: Node in get_children():
		var label: Label3D = child as Label3D
		if label == null:
			continue
		if not str(label.name).begins_with(ConvertGd.CHECKPOINT_PREFIX):
			continue
		if not label.has_meta(ENTITY_META) or not label.has_meta(ORDER_META):
			continue
		var entity_raw: Variant = label.get_meta(ENTITY_META)
		var order_raw: Variant = label.get_meta(ORDER_META)
		if typeof(entity_raw) != TYPE_INT or typeof(order_raw) != TYPE_INT:
			continue
		var entity_id: int = entity_raw
		var order: int = order_raw
		var wanted: String = str(order)
		if accepted.has(entity_id):
			wanted = "%s%s" % [wanted, ACCEPTED_SUFFIX]
		if label.text != wanted:
			label.text = wanted


func sequence_node(from_id: int, to_id: int) -> MeshInstance3D:
	return get_node_or_null(ConvertGd.sequence_name(from_id, to_id)) as MeshInstance3D


func overlay_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is Label3D and str(child.name).begins_with(ConvertGd.REACH_MARK_PREFIX):
			count += 1
	return count


func unreachable_seg_count() -> int:
	return _count_mesh_prefix(ConvertGd.REACH_SEG_PREFIX)


func overlay_node(entity_id: int, code: String) -> Label3D:
	return get_node_or_null(ConvertGd.overlay_name(entity_id, code)) as Label3D


func unreachable_seg_node(from_id: int, to_id: int) -> MeshInstance3D:
	return get_node_or_null(ConvertGd.unreachable_seg_name(from_id, to_id)) as MeshInstance3D


func reachability_ok() -> bool:
	return overlay.ok


func reachability_issue_count() -> int:
	return overlay.issue_count


func apply_hazard_visibility(solid_by_entity: Dictionary) -> void:
	occupancy.apply_hazard_visibility(self, solid_by_entity)


func _count_mesh_prefix(prefix: String) -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is MeshInstance3D and str(child.name).begins_with(prefix):
			count += 1
	return count


func _clear_meshes() -> void:
	var doomed: Array[Node] = []
	for child: Node in get_children():
		if not (child is MeshInstance3D or child is Label3D):
			continue
		if FloorGd.is_guide_name(str(child.name)):
			continue
		doomed.append(child)
	for child: Node in doomed:
		remove_child(child)
		child.free()
