class_name MatchSolidMap
extends Node3D

## Presentation mapping for compiled TRAPRUSH always-solid occupancy (CD-43).
## Topology bags supply Q48.16 poses. Ordinary floors stay visible; compiled
## gates hide while their `link_group` is occupied (踩区开关门).
## Float conversion happens only here. Placeholders are not hitboxes.
## live_solid_boxes() returns compiled Q48.16 centers plus cell/2 half-extents
## (authoring lattice, not the 1 m placeholder), skipping currently open gates.
## `_live_solids` stays 1:1 with `_poses`; open gates are omitted at query time.
## Snapshots never move a solid; v1 frames have no solid bag. Official courses
## compile path floors. No interpolation or prediction API. Box size and colour
## come from PlaceholderSpec; this file keeps the names but no longer owns
## the values.
##
## 当 `tile_scene_path` 能解析出地块视觉（SharedVisualAssetCatalog）时，每个固体
## 节点多挂一个 `visual` 子节点，占位盒自身退出渲染（`layers = 0`）但网格与石色
## 原样保留——`live_solid_boxes()` 给的是编译拓扑的权威半长，与视觉无关，本席预测
## 读的还是同一份。视觉解析失败就是今天的行为，一个石色 1 米盒。开关 / 门 /
## 传送带 / 电梯 / 弹射垫不铺地块，改挂 OccupancyGadget，否则贴图会盖住机关。
##
## 只有**始终固体**铺地块。周期机关走 MatchHazardMap（洋红）、可破坏箱走
## MatchCrateMap（橙），两者都不铺：D4 已把危险色定成可读性的一部分。

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")
const MoverCycleGd := preload("res://src/games/traprush/mover_cycle.gd")
const GateCycleGd := preload("res://src/games/traprush/gate_cycle.gd")
const PlayStubsGd := preload("res://src/games/traprush/play_stubs.gd")
const OccupancyGadgetGd := preload("res://src/shared/occupancy_gadget.gd")
const VisualGd := preload("res://src/client/match_solid_map_visual.gd")

const SOLID_PREFIX: String = "solid_"
const VISUAL_NAME: String = "visual"
const PLACEHOLDER_SIZE: Vector3 = PlaceholderSpec.BOX_SIZE
const SOLID_ALBEDO: Color = PlaceholderSpec.SOLID_ALBEDO
const SWITCH_ALBEDO: Color = PlaceholderSpec.SWITCH_ALBEDO
const GATE_ALBEDO: Color = PlaceholderSpec.GATE_ALBEDO

## 空字符串或解析失败 ⇒ 回退占位盒。是变量而不是常量，好让测试两条分支都能跑。
var tile_scene_path: String = SharedVisualAssetCatalog.TERRAIN_TILE_SCENE_PATH
var _has_course: bool = false
var _cell: int = 0
var _poses: Array[Dictionary] = []
var _movers: Array[Dictionary] = []
var _switches: Array[Dictionary] = []
var _gates: Array[Dictionary] = []
var _switch_ids: Dictionary = {}
var _gate_ids: Dictionary = {}
var _open_gate_ids: Dictionary = {}
var _conveyor_yaw: Dictionary = {}
var _launch_yaw: Dictionary = {}
var _lift_ids: Dictionary = {}
var _live_solids: Array[Dictionary] = []
var _solid_count: int = 0
var _visual_count: int = 0


static func meters_from_fixed(value: int) -> float:
	return float(value) / float(Fixed.SCALE)


static func solid_name(entity_id: int) -> String:
	return "%s%d" % [SOLID_PREFIX, entity_id]


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
	if not _bags_are_mappable(bundle.solids):
		return false
	_has_course = true
	_cell = bundle.cell
	_poses = _copy_poses(bundle.solids)
	_movers = []
	for item: Dictionary in bundle.movers:
		_movers.append(item.duplicate(true))
	_copy_link_bags(bundle.switches, _switches, _switch_ids)
	_copy_link_bags(bundle.gates, _gates, _gate_ids)
	_conveyor_yaw = OccupancyGadgetGd.yaw_lookup(bundle.conveyors)
	_launch_yaw = OccupancyGadgetGd.yaw_lookup(bundle.launches)
	_lift_ids = OccupancyGadgetGd.lift_ids_from_movers(_movers)
	_open_gate_ids = {}
	_rebuild()
	return true


func apply_tick(tick_index: int) -> bool:
	if not _has_course:
		return false
	for item: Dictionary in _movers:
		var path_raw: Variant = item.get("path", [])
		if typeof(path_raw) != TYPE_ARRAY:
			continue
		var path: Array = path_raw
		var loop_raw: Variant = item.get("loop", true)
		var loop_on: bool = true
		if typeof(loop_raw) == TYPE_BOOL:
			loop_on = loop_raw
		var next: Dictionary = MoverCycleGd.pose_at(
			tick_index, path, PlayClock.dict_int(item, "speed", 0), loop_on
		)
		if next.is_empty():
			continue
		var entity_id: int = PlayClock.dict_int(item, "entity_id", 0)
		if entity_id < 1:
			continue
		_set_pose(
			entity_id,
			PlayClock.dict_int(next, "x", 0),
			PlayClock.dict_int(next, "y", 0),
			PlayClock.dict_int(next, "z", 0)
		)
	return true


func apply_gate_visibility(open_ids: PackedInt32Array) -> void:
	_open_gate_ids = {}
	for entity_id: int in open_ids:
		_open_gate_ids[entity_id] = true
	for item: Dictionary in _gates:
		var gate_id: int = PlayClock.dict_int(item, "entity_id", 0)
		var node: MeshInstance3D = solid_node(gate_id)
		if node != null:
			node.visible = not _open_gate_ids.has(gate_id)


func occupied_groups_from_players(players: Array) -> Dictionary:
	return GateCycleGd.presentation_occupied_groups(
		_posed_link_bags(_switches),
		_posed_link_bags(_gates),
		players,
		_cell,
		PlayStubsGd.CAPSULE_RADIUS,
		PlayStubsGd.CAPSULE_HEIGHT,
		PlayStubsGd.SUPPORT_DY
	)


## 线上无开合字段：用快照位姿近似。Solo 读会话 open_gate_entity_ids。
func open_ids_from_players(players: Array) -> PackedInt32Array:
	return GateCycleGd.presentation_open_entity_ids(
		_posed_link_bags(_switches),
		_posed_link_bags(_gates),
		players,
		_cell,
		PlayStubsGd.CAPSULE_RADIUS,
		PlayStubsGd.CAPSULE_HEIGHT,
		PlayStubsGd.SUPPORT_DY
	)


func solid_count() -> int:
	return _solid_count


func solid_total() -> int:
	return _poses.size()


func solid_node(entity_id: int) -> MeshInstance3D:
	return get_node_or_null(solid_name(entity_id)) as MeshInstance3D


func visual_node(entity_id: int) -> Node3D:
	var solid: MeshInstance3D = solid_node(entity_id)
	if solid == null:
		return null
	return solid.get_node_or_null(VISUAL_NAME) as Node3D


## 有多少个固体真的铺上了地块。0 表示全部回退到占位盒。
func visual_count() -> int:
	return _visual_count


func live_solid_boxes() -> Array:
	var boxes: Array = []
	if _cell < 1:
		return boxes
	var half: int = _cell / 2
	for pose: Dictionary in _live_solids:
		var entity_id: int = PlayClock.dict_int(pose, "entity_id", 0)
		if _open_gate_ids.has(entity_id):
			continue
		boxes.append({
			"x": pose["x"],
			"y": pose["y"],
			"z": pose["z"],
			"hx": half,
			"hy": half,
			"hz": half,
		})
	return boxes


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


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func _bags_are_mappable(bags: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for bag: Dictionary in bags:
		var pose: Dictionary = _xyz_from_bag(bag)
		if pose.is_empty():
			return false
		var entity_id: int = pose["entity_id"]
		if seen.has(entity_id):
			return false
		seen[entity_id] = true
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


func _copy_poses(bags: Array[Dictionary]) -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	for bag: Dictionary in bags:
		poses.append(_xyz_from_bag(bag))
	return poses


func _copy_link_bags(
	bags: Array, dest: Array[Dictionary], lookup: Dictionary
) -> void:
	dest.clear()
	lookup.clear()
	if bags == null:
		return
	for item: Dictionary in bags:
		dest.append(item.duplicate(true))
		var entity_id: int = PlayClock.dict_int(item, "entity_id", 0)
		if entity_id > 0:
			lookup[entity_id] = true


func _posed_link_bags(bags: Array[Dictionary]) -> Array[Dictionary]:
	var posed: Array[Dictionary] = []
	for item: Dictionary in bags:
		var entity_id: int = PlayClock.dict_int(item, "entity_id", 0)
		var pose: Dictionary = _pose_of(entity_id)
		if pose.is_empty():
			continue
		posed.append({
			"entity_id": entity_id,
			"link_group": PlayClock.dict_int(item, "link_group", 0),
			"x": pose["x"],
			"y": pose["y"],
			"z": pose["z"],
		})
	return posed


func _pose_of(entity_id: int) -> Dictionary:
	for pose: Dictionary in _poses:
		if PlayClock.dict_int(pose, "entity_id", 0) == entity_id:
			return pose
	return {}


func _set_pose(entity_id: int, x: int, y: int, z: int) -> void:
	var index: int = 0
	while index < _poses.size():
		if PlayClock.dict_int(_poses[index], "entity_id", 0) == entity_id:
			_poses[index]["x"] = x
			_poses[index]["y"] = y
			_poses[index]["z"] = z
			break
		index += 1
	if index < _live_solids.size():
		_live_solids[index]["x"] = x
		_live_solids[index]["y"] = y
		_live_solids[index]["z"] = z
	var node: MeshInstance3D = solid_node(entity_id)
	if node != null:
		node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))


func _rebuild() -> void:
	_clear_solids()
	_live_solids = []
	for pose: Dictionary in _poses:
		_live_solids.append({
			"entity_id": pose["entity_id"],
			"x": pose["x"],
			"y": pose["y"],
			"z": pose["z"],
		})
		var entity_id: int = pose["entity_id"]
		var albedo: Color = SOLID_ALBEDO
		if _switch_ids.has(entity_id):
			albedo = SWITCH_ALBEDO
		elif _gate_ids.has(entity_id):
			albedo = GATE_ALBEDO
		var kind: String = OccupancyGadgetGd.solid_kind(
			entity_id, _conveyor_yaw, _launch_yaw, _lift_ids, _switch_ids, _gate_ids
		)
		var yaw_bam: int = 0
		if _conveyor_yaw.has(entity_id):
			yaw_bam = _conveyor_yaw[entity_id]
		elif _launch_yaw.has(entity_id):
			yaw_bam = _launch_yaw[entity_id]
		if VisualGd.spawn_box(
			self, solid_name(entity_id), pose, albedo, kind, yaw_bam, tile_scene_path
		):
			_visual_count += 1
	_solid_count = _visible_count()


func _visible_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if str(child.name).begins_with(SOLID_PREFIX):
			count += 1
	return count


func _clear_solids() -> void:
	var stale: Array[Node] = []
	for child: Node in get_children():
		if str(child.name).begins_with(SOLID_PREFIX):
			stale.append(child)
	for node: Node in stale:
		remove_child(node)
		node.free()
	_solid_count = 0
	_visual_count = 0
