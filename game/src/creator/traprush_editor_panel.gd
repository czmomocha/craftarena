class_name TraprushEditorPanel
extends VBoxContainer

## TRAPRUSH tool strip on AuthoringEditorShell (CD-32 §1).
## Emits existing EDIT ops only. Bastion panel is not this chapter.
## The cell cursor (X/Y/Z SpinBoxes; 3D click sets X/Z) is the next place.
## Floor up/down still changes Y. Place bomb / dash writes inventory.item_state.
## Occupancy ids skip the reserved dangling portal target. Never settlement.

const PLACE_CHECKPOINT_NAME: String = "PlaceCheckpoint"
const PLACE_PORTAL_NAME: String = "PlacePortal"
const PLACE_SOLID_NAME: String = "PlaceSolid"
const PLACE_HAZARD_NAME: String = "PlaceHazard"
const PLACE_CRATE_NAME: String = "PlaceCrate"
const PLACE_FINISH_NAME: String = "PlaceFinish"
const PLACE_BOMB_NAME: String = "PlaceBomb"
const PLACE_DASH_NAME: String = "PlaceDash"
const PLACE_MOVER_NAME: String = "PlaceMover"
const PLACE_CONVEYOR_NAME: String = "PlaceConveyor"
const PLACE_LIFT_NAME: String = "PlaceLift"
const PLACE_LAUNCH_NAME: String = "PlaceLaunch"
const PLACE_SWITCH_NAME: String = "PlaceSwitch"
const PLACE_GATE_NAME: String = "PlaceGate"
const PLACE_ENERGY_WALL_NAME: String = "PlaceEnergyWall"
const PLACE_GATED_PORTAL_NAME: String = "PlaceGatedPortal"
const REMOVE_LAST_NAME: String = "RemoveLast"
const FLOOR_UP_NAME: String = "FloorUp"
const FLOOR_DOWN_NAME: String = "FloorDown"
const HAZARD_COOLDOWN_STUB: int = 1
const CRATE_DURABILITY_STUB: int = 1
const CRATE_REGEN_POLICY_STUB: int = 0
const CursorGd := preload("res://src/creator/traprush_editor_panel_cursor.gd")
const PickupKindsGd := preload("res://src/ugc/traprush_pickup_kinds.gd")
const ParamsGd := preload("res://src/creator/traprush_editor_panel_params.gd")
const BatchGd := preload("res://src/creator/traprush_editor_panel_batch.gd")
const IdsGd := preload("res://src/creator/traprush_editor_panel_ids.gd")
const TrapsGd := preload("res://src/creator/traprush_editor_panel_traps.gd")
const LayoutGd := preload("res://src/creator/traprush_editor_panel_layout.gd")

var host: AuthoringEditorShell = null
var cursor: CursorGd = null
var params: ParamsGd = null
var batch: BatchGd = null
var traps: TrapsGd = null
var _next_entity_id: int = 1
var _next_order: int = 0
var _pending_portal_id: int = 0
## 传送带轴向：false = 左右（yaw 0），true = 上下（yaw 90°）。点击箭头按钮切换。
var conveyor_vertical: bool = false
var _next_launch_yaw: int = 0

var floor_index: int:
	get:
		if cursor == null:
			return 0
		return cursor.cell_y
	set(value):
		if cursor != null:
			cursor.set_cell(cursor.cell_x, value, cursor.cell_z)

var cell_x: int:
	get:
		if cursor == null:
			return 0
		return cursor.cell_x
	set(value):
		if cursor != null:
			cursor.set_cell(value, cursor.cell_y, cursor.cell_z)

var cell_z: int:
	get:
		if cursor == null:
			return 0
		return cursor.cell_z
	set(value):
		if cursor != null:
			cursor.set_cell(cursor.cell_x, cursor.cell_y, value)


func adopt_world(world: AuthoringWorld) -> void:
	_pending_portal_id = 0
	conveyor_vertical = false
	_next_launch_yaw = 0
	var state: Dictionary = IdsGd.adopt_state(world)
	var next_entity_id: int = state["next_entity_id"]
	var next_order: int = state["next_order"]
	var next_x: int = state["next_x"]
	_next_entity_id = next_entity_id
	_next_order = next_order
	if cursor != null:
		cursor.set_cell(next_x, 0, 0)
	TraprushEditorPanelSky.sync_panel(self, world)
	LayoutGd.sync_conveyor_dir(self)


func mount(p_host: AuthoringEditorShell) -> void:
	host = p_host
	if get_child_count() > 0:
		return
	cursor = CursorGd.new()
	add_child(cursor)
	cursor.mount()
	if not cursor.cell_changed.is_connected(_refresh_host_status):
		cursor.cell_changed.connect(_refresh_host_status)
	traps = TrapsGd.new()
	add_child(traps)
	traps.visible = false
	traps.panel = self
	LayoutGd.mount(self)
	if host != null and AuthoringSurfaceNames.allows_batch_generate(host.surface):
		batch = BatchGd.new()
		add_child(batch)
		batch.mount(host, self)
	params = ParamsGd.new()
	add_child(params)
	params.mount(host)


func place_next_checkpoint() -> bool:
	if host == null or cursor == null:
		return false
	var entity_id: int = _peek_entity_id()
	var order: int = _next_order
	if not host.try_place_checkpoint(entity_id, order, cursor.cell_x, cursor.cell_y, cursor.cell_z):
		return false
	_commit_entity_id(entity_id)
	_next_order += 1
	cursor.bump_x()
	_select_placed(entity_id)
	return true


func place_next_portal() -> bool:
	return IdsGd.place_next_portal(self, false)


func place_next_gated_portal() -> bool:
	return IdsGd.place_next_portal(self, true)


func place_next_solid() -> bool:
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_solid(entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z)
	)


func place_next_hazard() -> bool:
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_hazard(entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z)
	)


func place_next_crate() -> bool:
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_crate(entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z)
	)


func place_next_finish() -> bool:
	if not _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_finish(entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z)
	):
		return false
	if host.map != null:
		host.map.focus_entity(_last_placed_id())
	return true


func place_next_bomb() -> bool:
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_pickup(
			entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z, PickupKindsGd.BOMB
		)
	)


func place_next_dash() -> bool:
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_pickup(
			entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z, PickupKindsGd.DASH
		)
	)


func place_next_mover() -> bool:
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_mover(entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z)
	)


func place_next_conveyor() -> bool:
	var yaw_bam: int = next_conveyor_yaw_bam()
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_conveyor(
			entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z, yaw_bam
		)
	)


func toggle_conveyor_axis() -> void:
	conveyor_vertical = not conveyor_vertical
	LayoutGd.sync_conveyor_dir(self)


func place_next_lift() -> bool:
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_lift(entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z)
	)


func place_next_launch() -> bool:
	var yaw_bam: int = _next_launch_yaw
	if not _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_launch(
			entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z, yaw_bam
		)
	):
		return false
	_next_launch_yaw = (yaw_bam + Fixed.BAM_TURN / 4) % Fixed.BAM_TURN
	return true


func place_next_switch() -> bool:
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_switch(entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z)
	)


func place_next_gate() -> bool:
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_gate(entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z)
	)


func place_next_energy_wall() -> bool:
	return _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_energy_wall(entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z)
	)


func place_next_spike() -> bool:
	return traps != null and traps.place_next_spike()
func place_next_flame() -> bool:
	return traps != null and traps.place_next_flame()
func place_next_crusher() -> bool:
	return traps != null and traps.place_next_crusher()
func place_next_roller() -> bool:
	return traps != null and traps.place_next_roller()
func place_next_rubble() -> bool:
	return traps != null and traps.place_next_rubble()
func place_next_obstacle_core() -> bool:
	return traps != null and traps.place_next_obstacle_core()
func place_next_pendulum() -> bool:
	return traps != null and traps.place_next_pendulum()
func place_next_ice() -> bool:
	return traps != null and traps.place_next_ice()


func next_conveyor_yaw_bam() -> int:
	if conveyor_vertical:
		return Fixed.BAM_TURN / 4
	return 0


func sync_params() -> void:
	TraprushEditorPanelSky.sync_panel(self, _world())
	if params != null:
		params.sync_selection()


func try_pick_cell_from_screen(screen: Vector2) -> bool:
	if host == null or host.map == null or cursor == null:
		return false
	var camera: Camera3D = host.map.get_node_or_null(AuthoringPreviewMap.CAMERA_NAME) as Camera3D
	if camera == null:
		return false
	if not cursor.try_pick_from_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen)):
		return false
	_refresh_host_status()
	return true


func remove_last() -> bool:
	if host == null or host.session == null or host.session.world == null:
		return false
	var ids: Array[int] = host.session.world.entity_ids()
	if ids.is_empty():
		return false
	var entity_id: int = ids[ids.size() - 1]
	if not host.try_remove(entity_id):
		return false
	if _pending_portal_id == entity_id:
		_pending_portal_id = 0
	return true


func floor_up() -> void:
	floor_index += 1
	_refresh_host_status()


func floor_down() -> void:
	floor_index -= 1
	_refresh_host_status()


func _place_occupancy(writer: Callable) -> bool:
	if host == null or cursor == null:
		return false
	var entity_id: int = _peek_entity_id()
	if not writer.call(entity_id):
		return false
	_commit_entity_id(entity_id)
	cursor.bump_x()
	_select_placed(entity_id)
	return true


func _select_placed(entity_id: int) -> void:
	if host == null or host.chrome == null:
		return
	host.chrome.selected_id = entity_id
	host.chrome.sync_guides()
	sync_params()


func _last_placed_id() -> int:
	return _next_entity_id - 1


func _refresh_host_status() -> void:
	if host != null:
		host.refresh_status()
	sync_params()
	LayoutGd.sync_conveyor_dir(self)


func _peek_entity_id() -> int:
	var entity_id: int = _next_entity_id
	var reserved: Dictionary = _dangling_target_ids()
	while reserved.has(entity_id) or _world_has(entity_id):
		entity_id += 1
	return entity_id


func _commit_entity_id(entity_id: int) -> void:
	if entity_id >= _next_entity_id:
		_next_entity_id = entity_id + 1


func _world_has(entity_id: int) -> bool:
	if host == null or host.session == null or host.session.world == null:
		return false
	return host.session.world.has_entity(entity_id)

func _dangling_target_ids() -> Dictionary:
	return IdsGd.dangling_target_ids(_world())

func _pending_pair_entity_id() -> int:
	return IdsGd.pending_pair_entity_id(_world(), _pending_portal_id)

func _world() -> AuthoringWorld:
	if host == null or host.session == null:
		return null
	return host.session.world
