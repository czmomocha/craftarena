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
## No interpolation, prediction, or course-selection API.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const PAD_PREFIX: String = "pad_"
const PORTAL_PREFIX: String = "portal_"
const FINISH_PREFIX: String = "finish_"
const PLACEHOLDER_SIZE: Vector3 = Vector3(1.0, 1.0, 1.0)
const PENDING_ALBEDO: Color = Color(0.35, 0.9, 0.4)
const ACCEPTED_ALBEDO: Color = Color(0.16, 0.38, 0.22)
const CURRENT_ALBEDO: Color = Color(0.55, 1.0, 0.45)
const FINISH_PENDING_ALBEDO: Color = Color(0.95, 0.82, 0.2)
const FINISH_CURRENT_ALBEDO: Color = Color(1.0, 0.92, 0.35)
const FINISH_ACCEPTED_ALBEDO: Color = Color(0.42, 0.32, 0.08)
const _TWO_WAY_ALBEDO: Color = Color(0.2, 0.75, 0.95)
const _ONE_WAY_ALBEDO: Color = Color(0.95, 0.55, 0.15)

var _pad_count: int = 0
var _portal_count: int = 0
var _finish_count: int = 0
var _accepted_count: int = -1
var _finish_tick: int = -1
var _pad_orders: Dictionary = {}
var _finish_ids: Array[int] = []


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
		_remember_pad_order(pad)
		_spawn_box(
			pad_name(pad_id),
			pad,
			pad_albedo(_order_of(pad_id), _accepted_count)
		)
	for portal: Dictionary in bundle.portals:
		var portal_id: int = portal["entity_id"]
		_spawn_box(portal_name(portal_id), portal, _portal_color(portal))
	for finish: Dictionary in bundle.finish:
		var finish_id: int = finish["entity_id"]
		_remember_finish_id(finish_id)
		_spawn_box(
			finish_name(finish_id),
			finish,
			finish_albedo(_accepted_count, bundle.pads.size(), _finish_tick)
		)
	_pad_count = bundle.pads.size()
	_portal_count = bundle.portals.size()
	_finish_count = bundle.finish.size()
	return true


func apply_own_progress(accepted_count: int, finish_tick: int = -1) -> void:
	_accepted_count = accepted_count
	_finish_tick = finish_tick
	_retint_pads()
	_retint_finish()


func own_accepted_count() -> int:
	return _accepted_count


func own_finish_tick() -> int:
	return _finish_tick


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
		return _ONE_WAY_ALBEDO
	return _TWO_WAY_ALBEDO


func _spawn_box(node_name: String, bag: Dictionary, color: Color) -> void:
	var pose: Dictionary = _xyz_from_bag(bag)
	var x: int = pose["x"]
	var y: int = pose["y"]
	var z: int = pose["z"]
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = PLACEHOLDER_SIZE
	mesh.material = _unshaded(color)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = Vector3(meters_from_fixed(x), meters_from_fixed(y), meters_from_fixed(z))
	add_child(node)


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
	_pad_orders.clear()
	_finish_ids.clear()


func _remember_pad_order(pad: Dictionary) -> void:
	if not pad.has("entity_id") or typeof(pad["entity_id"]) != TYPE_INT:
		return
	if not pad.has("order") or typeof(pad["order"]) != TYPE_INT:
		return
	var pad_id: int = pad["entity_id"]
	var order: int = pad["order"]
	if pad_id < 1 or order < 0:
		return
	_pad_orders[pad_id] = order


func _order_of(entity_id: int) -> int:
	if not _pad_orders.has(entity_id):
		return -1
	var raw: Variant = _pad_orders[entity_id]
	if typeof(raw) != TYPE_INT:
		return -1
	var order: int = raw
	return order


func _remember_finish_id(entity_id: int) -> void:
	if entity_id < 1:
		return
	if _finish_ids.has(entity_id):
		return
	_finish_ids.append(entity_id)


func _retint_pads() -> void:
	for entity_raw: Variant in _pad_orders.keys():
		if typeof(entity_raw) != TYPE_INT:
			continue
		var entity_id: int = entity_raw
		_tint_node(pad_node(entity_id), pad_albedo(_order_of(entity_id), _accepted_count))


func _retint_finish() -> void:
	var color: Color = finish_albedo(_accepted_count, _pad_count, _finish_tick)
	for entity_id: int in _finish_ids:
		_tint_node(finish_node(entity_id), color)


func _tint_node(node: MeshInstance3D, color: Color) -> void:
	if node == null:
		return
	var box: BoxMesh = node.mesh as BoxMesh
	if box == null:
		return
	var material: StandardMaterial3D = box.material as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = color


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
