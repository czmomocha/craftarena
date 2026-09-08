class_name MatchCourseMap
extends Node3D

## Presentation mapping for compiled TRAPRUSH topology (CD-43).
## Pads, classified portals, and finish occupancy become 1 m boxes at the
## Q48.16 poses. Authority stays on SimulationBundle; float conversion
## happens only here. Placeholders are not hitboxes. Destructibles have
## poses in the bundle but stay undrawn here; MatchCrateMap draws them.
## Period hazards stay undrawn here; MatchHazardMap draws them.
## Portal source→dest bars stay undrawn here; MatchPortalLinkMap draws them.
## Checkpoint-order labels and sequence bars stay undrawn here;
## MatchCheckpointOrderMap draws them. Standing labels stay undrawn
## here; MatchStandingMap draws them. apply_own_progress tints pads from
## the own-seat accepted_count: done / current / pending. It also tints
## the finish zone: pending gold, current gold when every pad is done,
## accepted dark-gold after finish_tick. Idle (-1) keeps PENDING_ALBEDO
## and FINISH_PENDING_ALBEDO. Not walk-reachability or product cosmetics.
## Box size and every colour come from PlaceholderSpec; this file keeps the
## names but no longer owns the values (D4 changes one place).
##
## 垫 / 终点 / 传送门在能解析出占用视觉时挂 `visual` 子节点，占位盒 `layers = 0`
## 退出渲染但保留网格与进度色——`apply_own_progress` 仍写盒子材质，并在颜色真的
## 变了时才重套 overlay（对局壳每帧都调它）。解析失败回退 1 米色块。
## No interpolation, prediction, or course-selection API.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const CourseMapVisualGd := preload("res://src/client/match_course_map_visual.gd")
const FxGd := preload("res://src/client/match_course_map_fx.gd")

const PAD_PREFIX: String = "pad_"
const PORTAL_PREFIX: String = "portal_"
const FINISH_PREFIX: String = "finish_"
const SPAWN_NAME: String = "spawn_marker"
const VISUAL_NAME: String = "visual"
const PLACEHOLDER_SIZE: Vector3 = PlaceholderSpec.BOX_SIZE
const PENDING_ALBEDO: Color = PlaceholderSpec.PAD_PENDING_ALBEDO
const ACCEPTED_ALBEDO: Color = PlaceholderSpec.PAD_ACCEPTED_ALBEDO
const CURRENT_ALBEDO: Color = PlaceholderSpec.PAD_CURRENT_ALBEDO
const FINISH_PENDING_ALBEDO: Color = PlaceholderSpec.FINISH_PENDING_ALBEDO
const FINISH_CURRENT_ALBEDO: Color = PlaceholderSpec.FINISH_CURRENT_ALBEDO
const FINISH_ACCEPTED_ALBEDO: Color = PlaceholderSpec.FINISH_ACCEPTED_ALBEDO

## 空字符串或解析失败 ⇒ 回退占位盒。变量而不是常量，好让测试两条分支都能跑。
var pad_scene_path: String = SharedVisualAssetCatalog.CHECKPOINT_PAD_SCENE_PATH
var gate_scene_path: String = SharedVisualAssetCatalog.CHECKPOINT_GATE_SCENE_PATH
var finish_scene_path: String = SharedVisualAssetCatalog.FINISH_GATE_SCENE_PATH
var portal_scene_path: String = SharedVisualAssetCatalog.PORTAL_SCENE_PATH
var spawn_scene_path: String = SharedVisualAssetCatalog.SPAWN_MARKER_SCENE_PATH
var _pad_count: int = 0
var _portal_count: int = 0
var _finish_count: int = 0
var _visual_count: int = 0
var _accepted_count: int = -1
var _finish_tick: int = -1
var _portal_ids: Array[int] = []
var _finish_ids: Array[int] = []
## 编译袋里的垫位姿 + `order` 副本。两个用途共用一份：`PlayWayfinder` 算
## 「下一个目标在哪」要 Q48.16 权威格（节点位置是米，不能回读），三态染色与
## 呼吸动效要 `order`。留两份表迟早会有一份忘了清。
var _pad_targets: Array[Dictionary] = []
var _finish_targets: Array[Dictionary] = []


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func pad_name(entity_id: int) -> String:
	return "%s%d" % [PAD_PREFIX, entity_id]


static func portal_name(entity_id: int) -> String:
	return "%s%d" % [PORTAL_PREFIX, entity_id]


static func finish_name(entity_id: int) -> String:
	return "%s%d" % [FINISH_PREFIX, entity_id]


static func pad_albedo(order: int, accepted_count: int) -> Color:
	if accepted_count < 0 or order < 0:
		return PENDING_ALBEDO
	if order < accepted_count:
		return ACCEPTED_ALBEDO
	if order == accepted_count:
		return CURRENT_ALBEDO
	return PENDING_ALBEDO


static func finish_albedo(accepted_count: int, pad_count: int, finish_tick: int) -> Color:
	if accepted_count < 0:
		return FINISH_PENDING_ALBEDO
	if finish_tick >= 0:
		return FINISH_ACCEPTED_ALBEDO
	if pad_count > 0 and accepted_count >= pad_count:
		return FINISH_CURRENT_ALBEDO
	return FINISH_PENDING_ALBEDO


static func compile_path(path: String) -> SimulationBundle:
	if path.is_empty():
		return null
	var world: AuthoringWorld = AuthoringDocumentGd.load_from_path(path)
	if world == null:
		return null
	return TraprushTopologyCompilerGd.compile(world)


func apply_path(path: String) -> bool:
	return apply_bundle(compile_path(path))


func apply_bundle(bundle: SimulationBundle) -> bool:
	if bundle == null:
		return false
	if not _bags_are_mappable(bundle.pads):
		return false
	if not _portals_are_mappable(bundle.portals):
		return false
	if not _bags_are_mappable(bundle.finish):
		return false
	_clear_course()
	for pad: Dictionary in bundle.pads:
		var pad_id: int = pad["entity_id"]
		_remember_target(_pad_targets, pad, pad.get("order", -1))
		_spawn_box(
			pad_name(pad_id),
			pad,
			pad_albedo(_order_of(pad_id), _accepted_count),
			"checkpoint"
		)
	for portal: Dictionary in bundle.portals:
		var portal_id: int = portal["entity_id"]
		if not _portal_ids.has(portal_id):
			_portal_ids.append(portal_id)
		_spawn_box(portal_name(portal_id), portal, _portal_color(portal), "portal")
	for finish: Dictionary in bundle.finish:
		var finish_id: int = finish["entity_id"]
		_remember_finish_id(finish_id)
		_remember_target(_finish_targets, finish, -1)
		_spawn_box(
			finish_name(finish_id),
			finish,
			finish_albedo(_accepted_count, bundle.pads.size(), _finish_tick),
			"finish"
		)
	_spawn_spawn_marker()
	_pad_count = bundle.pads.size()
	_portal_count = bundle.portals.size()
	_finish_count = bundle.finish.size()
	return true


func apply_own_progress(accepted_count: int, finish_tick: int = -1) -> void:
	_accepted_count = accepted_count
	_finish_tick = finish_tick
	_retint_pads()
	_retint_finish()


## 课内动效（可玩性深化 轨 2）：传送门旋翼按权威 tick 转，当前目标垫与已开放
## 的终点呼吸。对局壳每帧调一次，不新建节点。见 `MatchCourseMapFx` 文件头。
func apply_tick(tick: int) -> int:
	return FxGd.apply_tick(self, tick)


func own_accepted_count() -> int:
	return _accepted_count


func own_finish_tick() -> int:
	return _finish_tick


## 寻路输入：垫（带 `order`）与终点的 Q48.16 位姿。只读副本。
func wayfind_pads() -> Array[Dictionary]:
	return _pad_targets


func wayfind_finish() -> Array[Dictionary]:
	return _finish_targets


func pad_count() -> int:
	return _pad_count


func portal_count() -> int:
	return _portal_count


func finish_count() -> int:
	return _finish_count


func crate_node_count() -> int:
	return 0


func hazard_node_count() -> int:
	return 0


func link_node_count() -> int:
	return 0


func checkpoint_node_count() -> int:
	return 0


func standing_node_count() -> int:
	return 0


func pad_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(pad_name(entity_id)) as MeshInstance3D


func portal_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(portal_name(entity_id)) as MeshInstance3D


func finish_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(finish_name(entity_id)) as MeshInstance3D


func visual_node(entity_id: int) -> Node3D:
	var node: MeshInstance3D = pad_node(entity_id)
	if node == null:
		node = finish_node(entity_id)
	if node == null:
		node = portal_node(entity_id)
	if node == null:
		return null
	return node.get_node_or_null(VISUAL_NAME) as Node3D


func visual_count() -> int:
	return _visual_count


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _bags_are_mappable(bags: Array[Dictionary]) -> bool:
	for bag: Dictionary in bags:
		if _xyz_from_bag(bag).is_empty():
			return false
	return true


func _portals_are_mappable(bags: Array[Dictionary]) -> bool:
	for bag: Dictionary in bags:
		if _xyz_from_bag(bag).is_empty():
			return false
		if not bag.has("kind") or typeof(bag["kind"]) != TYPE_STRING:
			return false
		var kind: String = bag["kind"]
		if kind != AuthoringPortalKinds.TWO_WAY and kind != AuthoringPortalKinds.ONE_WAY:
			return false
	return true


func _xyz_from_bag(bag: Dictionary) -> Dictionary:
	if not bag.has("entity_id") or typeof(bag["entity_id"]) != TYPE_INT:
		return {}
	var entity_id: int = bag["entity_id"]
	if entity_id < 1:
		return {}
	if not bag.has("x") or typeof(bag["x"]) != TYPE_INT:
		return {}
	if not bag.has("y") or typeof(bag["y"]) != TYPE_INT:
		return {}
	if not bag.has("z") or typeof(bag["z"]) != TYPE_INT:
		return {}
	var x: int = bag["x"]
	var y: int = bag["y"]
	var z: int = bag["z"]
	return {
		"entity_id": entity_id,
		"x": x,
		"y": y,
		"z": z,
	}


func _portal_color(bag: Dictionary) -> Color:
	var kind: String = bag["kind"]
	if kind == AuthoringPortalKinds.ONE_WAY:
		return PlaceholderSpec.PORTAL_ONE_WAY_ALBEDO
	return PlaceholderSpec.PORTAL_TWO_WAY_ALBEDO


func _spawn_box(node_name: String, bag: Dictionary, color: Color, kind: String) -> void:
	var pose: Dictionary = _xyz_from_bag(bag)
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	mesh.material = CourseMapVisualGd.unshaded(color)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))
	add_child(node)
	if CourseMapVisualGd.attach(self, node, kind, color):
		_visual_count += 1


func _clear_course() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		var child_name: String = str(child.name)
		if (
			child_name.begins_with(PAD_PREFIX)
			or child_name.begins_with(PORTAL_PREFIX)
			or child_name.begins_with(FINISH_PREFIX)
		):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_pad_count = 0
	_portal_count = 0
	_finish_count = 0
	_visual_count = 0
	_portal_ids.clear()
	_finish_ids.clear()
	_pad_targets.clear()
	_finish_targets.clear()


func _spawn_spawn_marker() -> void:
	MatchCourseMapSpawn.attach(self)


func _order_of(entity_id: int) -> int:
	for bag: Dictionary in _pad_targets:
		var bag_id: int = bag["entity_id"]
		if bag_id == entity_id:
			var order: int = bag["order"]
			return order
	return -1


func _remember_target(into: Array[Dictionary], bag: Dictionary, order_raw: Variant) -> void:
	var pose: Dictionary = _xyz_from_bag(bag)
	if pose.is_empty():
		return
	var order: int = -1
	if typeof(order_raw) == TYPE_INT:
		order = order_raw
	pose["order"] = order
	into.append(pose)


func _remember_finish_id(entity_id: int) -> void:
	if entity_id < 1:
		return
	if _finish_ids.has(entity_id):
		return
	_finish_ids.append(entity_id)


func _retint_pads() -> void:
	for bag: Dictionary in _pad_targets:
		var entity_id: int = bag["entity_id"]
		var order: int = bag["order"]
		CourseMapVisualGd.tint(pad_node(entity_id), pad_albedo(order, _accepted_count))


func _retint_finish() -> void:
	var color: Color = finish_albedo(_accepted_count, _pad_count, _finish_tick)
	for entity_id: int in _finish_ids:
		CourseMapVisualGd.tint(finish_node(entity_id), color)
