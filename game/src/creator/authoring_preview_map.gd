class_name AuthoringPreviewMap
extends Node3D

## Presentation mapping for AuthoringWorld (CD-32 §3). Used by Preview and Editor.
## Authority stays on AuthoringWorld Q48.16; float conversion happens only here.
## One 1×1×1 m BoxMesh per entity with transform; portal_link, checkpoint-order,
## finish Label3D, and reachability-issue gizmos. Hazard entities use HAZARD_ALBEDO. Solid
## zone tags use SOLID_ALBEDO. Finish zone tags use FINISH_ALBEDO and a "finish" mark.
## Destructible entities use CRATE_ALBEDO. Box size, camera offset, and every
## colour come from PlaceholderSpec, the same source the match maps read, so
## Preview and a live match cannot drift into two palettes.
## During Preview play, non-solid period hazards
## are hidden. Always-solid placeholders stay visible. Preview play draws the
## sim player pose as a presentation stub and marks accepted checkpoint labels
## with *. Placeholders and gizmos are not hitboxes.
## Rebuild after every editor write or preview patch. Overlay reads evaluate();
## it is not a write gate.
##
## rebuild() 是幂等的脏检查，不是无条件重建。Preview play 每帧都调它，而
## AuthoringWorld 在一局试玩里根本不变，所以之前每帧都在 free + new 整棵节点树
## （49 实体约 6.7 ms）。现在只有「世界身份 / revision / 实体数 / 格宽 /
## 角色与地块路径 / 占用视觉路径」任一变化才真重建，否则整段跳过。世界没变但节点树被别人改过时
## （典型是 apply_hazard_visibility 改显隐）调用方必须先 invalidate()。
## 另外两个每帧入口也改成幂等：show_player_pose 复用已有标记，
## mark_accepted_checkpoints 按传入集合**重写**文本而不是只追加 *，
## 否则跳过重建之后 R 复位掉的检查点会留着陈旧的 *。
##
## Preview play 的玩家标记与对局映射读同一份视觉资产
## （SharedVisualAssetCatalog，ADR-0006 Q4），所以 Preview 里看到的角色和真对局
## 里是同一个；解析失败时两边同样回退到占位盒。占用视觉按组件 / zone 标签接
## （垫+门、终点门、箱、滚柱、始终固体地块），与对局袋类型对齐；传送门实体
## 仍是占位盒。箱与滚柱保留 D4 危险色 overlay。

const CAMERA_NAME: String = "PreviewCamera"
const LIGHT_NAME: String = "PreviewLight"
const PLAYER_NAME: String = "player_marker"
const VISUAL_NAME: String = "visual"
const PLACEHOLDER_PREFIX: String = "entity_"
const LINK_PREFIX: String = "portal_link_"
const DANGLE_PREFIX: String = "portal_dangle_"
const DIR_PREFIX: String = "portal_dir_"
const CHECKPOINT_PREFIX: String = "checkpoint_mark_"
const FINISH_PREFIX: String = "finish_mark_"
const SEQUENCE_PREFIX: String = "checkpoint_seq_"
const REACH_MARK_PREFIX: String = "reach_mark_"
const REACH_SEG_PREFIX: String = "reach_seg_"
const PLACEHOLDER_SIZE: Vector3 = PlaceholderSpec.BOX_SIZE
const LINK_THICKNESS: float = 0.08
const DANGLE_SIZE: Vector3 = Vector3(0.35, 0.35, 0.35)
const DIR_SIZE: Vector3 = Vector3(0.2, 0.2, 0.2)
const DANGLE_LIFT: float = 0.7
const CHECKPOINT_LIFT: float = 1.15
const FINISH_LIFT: float = 1.15
const SEQUENCE_LIFT: float = 0.25
const REACH_LIFT: float = 1.7
const REACH_SEG_LIFT: float = 0.45
const _MIN_LINK_LEN: float = 0.001
const HAZARD_ALBEDO: Color = PlaceholderSpec.HAZARD_ALBEDO
const SOLID_ALBEDO: Color = PlaceholderSpec.SOLID_ALBEDO
const FINISH_ALBEDO: Color = PlaceholderSpec.FINISH_PENDING_ALBEDO
const CRATE_ALBEDO: Color = PlaceholderSpec.CRATE_ALBEDO
const ENTITY_META: String = "entity_id"
const ORDER_META: String = "checkpoint_order"
const VISUAL_PATH_META: String = "visual_path"
const ACCEPTED_SUFFIX: String = "*"

var _reach_ok: bool = true
var _reach_issue_count: int = 0
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


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func yaw_radians_from_bam(yaw_bam: int) -> float:
	return TAU * float(yaw_bam) / float(Fixed.BAM_TURN)


static func pose_from_record(record: SharedComponentRecord) -> Dictionary:
	if record == null:
		return {}
	if not record.components.has(SharedComponentNames.TRANSFORM):
		return {}
	var raw: Variant = record.components[SharedComponentNames.TRANSFORM]
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var body: Dictionary = raw
	if typeof(body.get("x", null)) != TYPE_INT:
		return {}
	if typeof(body.get("y", null)) != TYPE_INT:
		return {}
	if typeof(body.get("z", null)) != TYPE_INT:
		return {}
	if typeof(body.get("yaw_bam", null)) != TYPE_INT:
		return {}
	var x: int = body["x"]
	var y: int = body["y"]
	var z: int = body["z"]
	var yaw_bam: int = body["yaw_bam"]
	return {"x": x, "y": y, "z": z, "yaw_bam": yaw_bam}


static func order_from_record(record: SharedComponentRecord) -> int:
	if record == null:
		return -1
	if not record.components.has(SharedComponentNames.CHECKPOINT):
		return -1
	var raw: Variant = record.components[SharedComponentNames.CHECKPOINT]
	if typeof(raw) != TYPE_DICTIONARY:
		return -1
	var body: Dictionary = raw
	if typeof(body.get("order", null)) != TYPE_INT:
		return -1
	var order: int = body["order"]
	if order < 0:
		return -1
	return order


static func meters_from_pose(pose: Dictionary) -> Vector3:
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	return Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))


static func placeholder_name(entity_id: int) -> String:
	return "%s%d" % [PLACEHOLDER_PREFIX, entity_id]


static func link_name(source_id: int) -> String:
	return "%s%d" % [LINK_PREFIX, source_id]


static func dangle_name(source_id: int) -> String:
	return "%s%d" % [DANGLE_PREFIX, source_id]


static func direction_name(source_id: int) -> String:
	return "%s%d" % [DIR_PREFIX, source_id]


static func checkpoint_name(entity_id: int) -> String:
	return "%s%d" % [CHECKPOINT_PREFIX, entity_id]


static func finish_name(entity_id: int) -> String:
	return "%s%d" % [FINISH_PREFIX, entity_id]


static func sequence_name(from_id: int, to_id: int) -> String:
	return "%s%d_%d" % [SEQUENCE_PREFIX, from_id, to_id]


static func overlay_name(entity_id: int, code: String) -> String:
	return "%s%d_%s" % [REACH_MARK_PREFIX, entity_id, code]


static func unreachable_seg_name(from_id: int, to_id: int) -> String:
	return "%s%d_%d" % [REACH_SEG_PREFIX, from_id, to_id]


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
	_reset_reachability()
	if world == null:
		return
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		var pose: Dictionary = pose_from_record(record)
		if pose.is_empty():
			continue
		_spawn_placeholder(entity_id, pose, record)
	_spawn_portal_gizmos(world)
	_spawn_checkpoint_gizmos(world)
	_spawn_finish_gizmos(world)
	_spawn_reachability_overlay(world)


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


## 每帧都被调用，所以复用已有标记：只有还没有标记、或者标记是按另一条视觉资产
## 路径建的（测试会切 character_scene_path），才重新造一个。
func show_player_pose(pose: Dictionary) -> void:
	if typeof(pose.get("x", null)) != TYPE_INT:
		clear_player_pose()
		return
	if typeof(pose.get("y", null)) != TYPE_INT:
		clear_player_pose()
		return
	if typeof(pose.get("z", null)) != TYPE_INT:
		clear_player_pose()
		return
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var yaw_bam: int = 0
	if typeof(pose.get("yaw", null)) == TYPE_INT:
		yaw_bam = pose["yaw"]
	var node: MeshInstance3D = _reusable_player_node()
	if node == null:
		clear_player_pose()
		node = _create_player_node()
	node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))
	node.rotation.y = yaw_radians_from_bam(yaw_bam)


func _reusable_player_node() -> MeshInstance3D:
	var node: MeshInstance3D = player_node()
	if node == null:
		return null
	if not node.has_meta(VISUAL_PATH_META):
		return null
	if str(node.get_meta(VISUAL_PATH_META)) != character_scene_path:
		return null
	return node


func _create_player_node() -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	mesh.material = _unshaded(PlaceholderSpec.PREVIEW_PLAYER_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = PLAYER_NAME
	node.mesh = mesh
	node.set_meta(VISUAL_PATH_META, character_scene_path)
	add_child(node)
	_attach_player_visual(node)
	return node


## 与 MatchSnapshotMap._attach_visual 同一套：挂 `visual` 子节点、占位盒本体
## `layers = 0` 退出渲染但保留网格与色值。Preview 只有一个人，用 Preview 的
## 玩家色染薄膜。
func _attach_player_visual(player: MeshInstance3D) -> bool:
	var visual: Node3D = SharedVisualAssetCatalog.try_instantiate(character_scene_path)
	if visual == null:
		return false
	visual.name = VISUAL_NAME
	visual.position = SharedVisualAssetCatalog.CHARACTER_FOOT_LIFT
	player.add_child(visual)
	SharedVisualAssetCatalog.tint(visual, PlaceholderSpec.PREVIEW_PLAYER_ALBEDO)
	player.layers = 0
	return true


func clear_player_pose() -> void:
	var node: Node = get_node_or_null(PLAYER_NAME)
	if node == null:
		return
	remove_child(node)
	node.free()


func player_node() -> MeshInstance3D:
	return get_node_or_null(PLAYER_NAME) as MeshInstance3D


func player_visual_node() -> Node3D:
	var player: MeshInstance3D = player_node()
	if player == null:
		return null
	return player.get_node_or_null(VISUAL_NAME) as Node3D


func mapped_count() -> int:
	return _count_mesh_prefix(PLACEHOLDER_PREFIX)


func link_count() -> int:
	return _count_mesh_prefix(LINK_PREFIX)


func dangle_count() -> int:
	return _count_mesh_prefix(DANGLE_PREFIX)


func checkpoint_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is Label3D and str(child.name).begins_with(CHECKPOINT_PREFIX):
			count += 1
	return count


func finish_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is Label3D and str(child.name).begins_with(FINISH_PREFIX):
			count += 1
	return count


func sequence_count() -> int:
	return _count_mesh_prefix(SEQUENCE_PREFIX)


func placeholder_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(placeholder_name(entity_id)) as MeshInstance3D


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
	return get_node_or_null(link_name(source_id)) as MeshInstance3D


func dangle_node(source_id: int) -> MeshInstance3D:
	return get_node_or_null(dangle_name(source_id)) as MeshInstance3D


func direction_node(source_id: int) -> MeshInstance3D:
	return get_node_or_null(direction_name(source_id)) as MeshInstance3D


func checkpoint_node(entity_id: int) -> Label3D:
	return get_node_or_null(checkpoint_name(entity_id)) as Label3D


func finish_node(entity_id: int) -> Label3D:
	return get_node_or_null(finish_name(entity_id)) as Label3D


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
		if not str(label.name).begins_with(CHECKPOINT_PREFIX):
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
	return get_node_or_null(sequence_name(from_id, to_id)) as MeshInstance3D


func overlay_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is Label3D and str(child.name).begins_with(REACH_MARK_PREFIX):
			count += 1
	return count


func unreachable_seg_count() -> int:
	return _count_mesh_prefix(REACH_SEG_PREFIX)


func overlay_node(entity_id: int, code: String) -> Label3D:
	return get_node_or_null(overlay_name(entity_id, code)) as Label3D


func unreachable_seg_node(from_id: int, to_id: int) -> MeshInstance3D:
	return get_node_or_null(unreachable_seg_name(from_id, to_id)) as MeshInstance3D


func reachability_ok() -> bool:
	return _reach_ok


func reachability_issue_count() -> int:
	return _reach_issue_count


func _count_mesh_prefix(prefix: String) -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is MeshInstance3D and str(child.name).begins_with(prefix):
			count += 1
	return count


func _clear_meshes() -> void:
	var doomed: Array[Node] = []
	for child: Node in get_children():
		if child is MeshInstance3D or child is Label3D:
			doomed.append(child)
	for child: Node in doomed:
		remove_child(child)
		child.free()


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


## 逐实例改显隐，不动世界。因此它改过之后世界指纹仍然没变：想让占位盒回到
## 默认可见，调用方必须 invalidate() 再 rebuild()（Preview 在开玩 / 停玩切换时做）。
func apply_hazard_visibility(solid_by_entity: Dictionary) -> void:
	for key: Variant in solid_by_entity.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		var node: MeshInstance3D = placeholder_node(entity_id)
		if node == null:
			continue
		var solid_raw: Variant = solid_by_entity[entity_id]
		if typeof(solid_raw) != TYPE_BOOL:
			continue
		var solid: bool = solid_raw
		node.visible = solid


func _record_has_solid_tag(record: SharedComponentRecord) -> bool:
	return _record_has_zone_tag(record, "solid")


func _record_has_finish_tag(record: SharedComponentRecord) -> bool:
	return _record_has_zone_tag(record, "finish")


func _record_has_zone_tag(record: SharedComponentRecord, tag_name: String) -> bool:
	if not record.components.has(SharedComponentNames.ZONE):
		return false
	var raw: Variant = record.components[SharedComponentNames.ZONE]
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var zone: Dictionary = raw
	var tags_raw: Variant = zone.get("tags", [])
	if typeof(tags_raw) != TYPE_ARRAY:
		return false
	var tags: Array = tags_raw
	for item: Variant in tags:
		if typeof(item) != TYPE_STRING:
			continue
		var tag: String = item
		if tag == tag_name:
			return true
	return false


func _spawn_placeholder(entity_id: int, pose: Dictionary, record: SharedComponentRecord) -> void:
	var albedo: Color = PlaceholderSpec.ENTITY_STUB_ALBEDO
	var kind: String = ""
	if record != null and record.components.has(SharedComponentNames.HAZARD):
		albedo = HAZARD_ALBEDO
		kind = "hazard"
	elif record != null and _record_has_solid_tag(record):
		albedo = SOLID_ALBEDO
		kind = "tile"
	elif record != null and record.components.has(SharedComponentNames.DESTRUCTIBLE):
		albedo = CRATE_ALBEDO
		kind = "crate"
	elif record != null and _record_has_finish_tag(record):
		albedo = FINISH_ALBEDO
		kind = "finish"
	elif record != null and record.components.has(SharedComponentNames.CHECKPOINT):
		albedo = PlaceholderSpec.PAD_PENDING_ALBEDO
		kind = "checkpoint"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	mesh.material = _unshaded(albedo)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = placeholder_name(entity_id)
	node.mesh = mesh
	node.position = meters_from_pose(pose)
	var yaw_bam: int = pose["yaw_bam"]
	node.rotation.y = yaw_radians_from_bam(yaw_bam)
	add_child(node)
	_attach_kind_visual(node, kind, albedo)


## 按组件 / zone 标签接占用视觉，与对局袋类型对齐。机关与箱子走 overlay，
## 不铺成地块：D4 已把危险色定成可读性的一部分。
func _attach_kind_visual(placeholder: MeshInstance3D, kind: String, albedo: Color) -> bool:
	var visual: Node3D = null
	if kind == "tile":
		visual = SharedVisualAssetCatalog.try_instantiate_fitted_tile_from(tile_scene_path)
	elif kind == "checkpoint":
		visual = SharedVisualAssetCatalog.try_instantiate_checkpoint(
			pad_scene_path,
			gate_scene_path
		)
	elif kind == "finish":
		visual = SharedVisualAssetCatalog.try_instantiate_fitted_prop(finish_scene_path)
	elif kind == "crate":
		visual = SharedVisualAssetCatalog.try_instantiate_fitted_prop(crate_scene_path)
	elif kind == "hazard":
		visual = SharedVisualAssetCatalog.try_instantiate_fitted_prop(hazard_scene_path)
	if visual == null:
		return false
	visual.name = VISUAL_NAME
	placeholder.add_child(visual)
	if kind != "tile":
		SharedVisualAssetCatalog.tint(visual, albedo)
	placeholder.layers = 0
	return true


func _spawn_portal_gizmos(world: AuthoringWorld) -> void:
	var links: Array[Dictionary] = world.portal_links()
	for link: Dictionary in links:
		if typeof(link.get("source_id", null)) != TYPE_INT:
			continue
		if typeof(link.get("kind", null)) != TYPE_STRING:
			continue
		var source_id: int = link["source_id"]
		var kind: String = link["kind"]
		var source_record: SharedComponentRecord = world.get_record(source_id)
		var source_pose: Dictionary = pose_from_record(source_record)
		if source_pose.is_empty():
			continue
		var from: Vector3 = meters_from_pose(source_pose)
		if kind == AuthoringPortalKinds.DANGLING:
			_spawn_dangle(source_id, from)
			continue
		if typeof(link.get("dest_id", null)) != TYPE_INT:
			continue
		var dest_id: int = link["dest_id"]
		var dest_pose: Dictionary = pose_from_record(world.get_record(dest_id))
		if dest_pose.is_empty():
			_spawn_dangle(source_id, from)
			continue
		var to: Vector3 = meters_from_pose(dest_pose)
		_spawn_link(source_id, kind, dest_id, from, to)
		if kind == AuthoringPortalKinds.ONE_WAY:
			_spawn_direction(source_id, from, to)


func _spawn_dangle(source_id: int, from: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = DANGLE_SIZE
	mesh.material = _unshaded(PlaceholderSpec.PORTAL_DANGLE_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = dangle_name(source_id)
	node.mesh = mesh
	node.position = from + Vector3(0.0, DANGLE_LIFT, 0.0)
	add_child(node)


func _spawn_link(
	source_id: int,
	kind: String,
	dest_id: int,
	from: Vector3,
	to: Vector3
) -> void:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < _MIN_LINK_LEN:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(LINK_THICKNESS, LINK_THICKNESS, length)
	var color: Color = PlaceholderSpec.PORTAL_TWO_WAY_ALBEDO
	if kind == AuthoringPortalKinds.ONE_WAY:
		color = PlaceholderSpec.PORTAL_ONE_WAY_ALBEDO
	mesh.material = _unshaded(color)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = link_name(source_id)
	node.mesh = mesh
	node.position = (from + to) * 0.5
	node.set_meta("kind", kind)
	node.set_meta("dest_id", dest_id)
	add_child(node)
	_look_toward(node, to)


func _spawn_direction(source_id: int, from: Vector3, to: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = DIR_SIZE
	mesh.material = _unshaded(PlaceholderSpec.PORTAL_ONE_WAY_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = direction_name(source_id)
	node.mesh = mesh
	node.position = from.lerp(to, 0.8) + Vector3(0.0, 0.15, 0.0)
	add_child(node)


func _spawn_checkpoint_gizmos(world: AuthoringWorld) -> void:
	var by_order: Dictionary = {}
	var poses: Dictionary = {}
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		var order: int = order_from_record(record)
		if order < 0:
			continue
		if not by_order.has(order):
			var grouped: Array[int] = []
			by_order[order] = grouped
		var group: Array = by_order[order]
		group.append(entity_id)
		var pose: Dictionary = pose_from_record(record)
		if pose.is_empty():
			continue
		poses[entity_id] = meters_from_pose(pose)
	var order_keys: Array = by_order.keys()
	order_keys.sort()
	var unique_orders: Array[int] = []
	var unique_entity_ids: Array[int] = []
	for order_value: Variant in order_keys:
		var order: int = order_value
		var group: Array = by_order[order]
		var grouped_ids: Array[int] = []
		for grouped_id_value: Variant in group:
			var grouped_id: int = grouped_id_value
			grouped_ids.append(grouped_id)
		grouped_ids.sort()
		var duplicated: bool = grouped_ids.size() != 1
		for grouped_id: int in grouped_ids:
			if not poses.has(grouped_id):
				continue
			var from_raw: Variant = poses[grouped_id]
			if typeof(from_raw) != TYPE_VECTOR3:
				continue
			var from: Vector3 = from_raw
			_spawn_checkpoint_mark(grouped_id, order, from, duplicated)
		if duplicated:
			continue
		var only_id: int = grouped_ids[0]
		if not poses.has(only_id):
			continue
		unique_orders.append(order)
		unique_entity_ids.append(only_id)
	var index: int = 0
	while index + 1 < unique_orders.size():
		var from_id: int = unique_entity_ids[index]
		var to_id: int = unique_entity_ids[index + 1]
		var from_raw: Variant = poses[from_id]
		var to_raw: Variant = poses[to_id]
		if typeof(from_raw) != TYPE_VECTOR3 or typeof(to_raw) != TYPE_VECTOR3:
			index += 1
			continue
		var from: Vector3 = from_raw
		var to: Vector3 = to_raw
		_spawn_checkpoint_seq(from_id, to_id, from, to)
		index += 1


func _spawn_checkpoint_mark(entity_id: int, order: int, from: Vector3, duplicated: bool) -> void:
	var label: Label3D = Label3D.new()
	label.name = checkpoint_name(entity_id)
	label.text = str(order)
	label.set_meta(ENTITY_META, entity_id)
	label.set_meta(ORDER_META, order)
	label.font_size = 64
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	if duplicated:
		label.modulate = PlaceholderSpec.CHECKPOINT_DUP_ALBEDO
	else:
		label.modulate = PlaceholderSpec.CHECKPOINT_ALBEDO
	label.position = from + Vector3(0.0, CHECKPOINT_LIFT, 0.0)
	add_child(label)


func _spawn_finish_gizmos(world: AuthoringWorld) -> void:
	var ids: Array[int] = world.entity_ids()
	for entity_id: int in ids:
		var record: SharedComponentRecord = world.get_record(entity_id)
		if record == null or not _record_has_finish_tag(record):
			continue
		var pose: Dictionary = pose_from_record(record)
		if pose.is_empty():
			continue
		_spawn_finish_mark(entity_id, meters_from_pose(pose))


func _spawn_finish_mark(entity_id: int, from: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.name = finish_name(entity_id)
	label.text = "finish"
	label.font_size = 48
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	label.modulate = FINISH_ALBEDO
	label.position = from + Vector3(0.0, FINISH_LIFT, 0.0)
	add_child(label)


func _spawn_checkpoint_seq(from_id: int, to_id: int, from: Vector3, to: Vector3) -> void:
	var lifted_from: Vector3 = from + Vector3(0.0, SEQUENCE_LIFT, 0.0)
	var lifted_to: Vector3 = to + Vector3(0.0, SEQUENCE_LIFT, 0.0)
	var delta: Vector3 = lifted_to - lifted_from
	var length: float = delta.length()
	if length < _MIN_LINK_LEN:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(LINK_THICKNESS, LINK_THICKNESS, length)
	mesh.material = _unshaded(PlaceholderSpec.CHECKPOINT_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = sequence_name(from_id, to_id)
	node.mesh = mesh
	node.position = (lifted_from + lifted_to) * 0.5
	add_child(node)
	_look_toward(node, lifted_to)


func _reset_reachability() -> void:
	_reach_ok = true
	_reach_issue_count = 0


func _spawn_reachability_overlay(world: AuthoringWorld) -> void:
	var result: Dictionary = AuthoringReachability.evaluate(world)
	var ok_raw: Variant = result.get("ok", false)
	if typeof(ok_raw) == TYPE_BOOL:
		_reach_ok = ok_raw
	else:
		_reach_ok = false
	var issues_raw: Variant = result.get("issues", [])
	if typeof(issues_raw) != TYPE_ARRAY:
		_reach_issue_count = 0
		return
	var issues: Array = issues_raw
	_reach_issue_count = issues.size()
	for issue_value: Variant in issues:
		if typeof(issue_value) != TYPE_DICTIONARY:
			continue
		var issue: Dictionary = issue_value
		if typeof(issue.get("code", null)) != TYPE_STRING:
			continue
		var code: String = issue["code"]
		if not AuthoringReachabilityCodes.contains(code):
			continue
		var ids_raw: Variant = issue.get("entity_ids", [])
		if typeof(ids_raw) != TYPE_ARRAY:
			continue
		var ids: Array = ids_raw
		var posed: Array[int] = []
		for id_value: Variant in ids:
			if typeof(id_value) != TYPE_INT:
				continue
			var entity_id: int = id_value
			var record: SharedComponentRecord = world.get_record(entity_id)
			var pose: Dictionary = pose_from_record(record)
			if pose.is_empty():
				continue
			posed.append(entity_id)
			_spawn_reach_mark(entity_id, code, meters_from_pose(pose))
		if code != AuthoringReachabilityCodes.UNREACHABLE_CHECKPOINT:
			continue
		if posed.size() != 2:
			continue
		var from_id: int = posed[0]
		var to_id: int = posed[1]
		var from_pose: Dictionary = pose_from_record(world.get_record(from_id))
		var to_pose: Dictionary = pose_from_record(world.get_record(to_id))
		if from_pose.is_empty() or to_pose.is_empty():
			continue
		_spawn_unreachable_seg(from_id, to_id, meters_from_pose(from_pose), meters_from_pose(to_pose))


func _spawn_reach_mark(entity_id: int, code: String, from: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.name = overlay_name(entity_id, code)
	label.text = code
	label.font_size = 28
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.modulate = PlaceholderSpec.REACH_ALBEDO
	label.position = from + Vector3(0.0, REACH_LIFT, 0.0)
	add_child(label)


func _spawn_unreachable_seg(from_id: int, to_id: int, from: Vector3, to: Vector3) -> void:
	var lifted_from: Vector3 = from + Vector3(0.0, REACH_SEG_LIFT, 0.0)
	var lifted_to: Vector3 = to + Vector3(0.0, REACH_SEG_LIFT, 0.0)
	var delta: Vector3 = lifted_to - lifted_from
	var length: float = delta.length()
	if length < _MIN_LINK_LEN:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(LINK_THICKNESS, LINK_THICKNESS, length)
	mesh.material = _unshaded(PlaceholderSpec.REACH_ALBEDO)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = unreachable_seg_name(from_id, to_id)
	node.mesh = mesh
	node.position = (lifted_from + lifted_to) * 0.5
	add_child(node)
	_look_toward(node, lifted_to)


func _look_toward(node: Node3D, target: Vector3) -> void:
	if not node.is_inside_tree():
		return
	var delta: Vector3 = target - node.position
	if delta.length_squared() < 0.0000001:
		return
	var up: Vector3 = Vector3.UP
	if absf(delta.normalized().dot(Vector3.UP)) > 0.999:
		up = Vector3.FORWARD
	node.look_at(target, up)
