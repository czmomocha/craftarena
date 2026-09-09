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

var host: AuthoringEditorShell = null
var cursor: CursorGd = null
var params: ParamsGd = null
var batch: BatchGd = null
var _next_entity_id: int = 1
var _next_order: int = 0
var _pending_portal_id: int = 0
## 下一块传送带的朝向。每摆一块顺时针转 90°，摆四块就围出一圈，不另开方向面板。
var _next_conveyor_yaw: int = 0
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
	_next_conveyor_yaw = 0
	_next_launch_yaw = 0
	var state: Dictionary = IdsGd.adopt_state(world)
	var next_entity_id: int = state["next_entity_id"]
	var next_order: int = state["next_order"]
	var next_x: int = state["next_x"]
	_next_entity_id = next_entity_id
	_next_order = next_order
	if cursor != null:
		cursor.set_cell(next_x, 0, 0)


func mount(p_host: AuthoringEditorShell) -> void:
	host = p_host
	if get_child_count() > 0:
		return
	cursor = CursorGd.new()
	add_child(cursor)
	cursor.mount()
	if not cursor.cell_changed.is_connected(_refresh_host_status):
		cursor.cell_changed.connect(_refresh_host_status)
	var place_row: HBoxContainer = HBoxContainer.new()
	place_row.name = "PlaceRow"
	add_child(place_row)
	_add_button(place_row, PLACE_CHECKPOINT_NAME, UiCopy.PLACE_CHECKPOINT, place_next_checkpoint)
	_add_button(place_row, PLACE_PORTAL_NAME, UiCopy.PLACE_PORTAL, place_next_portal)
	_add_button(place_row, REMOVE_LAST_NAME, UiCopy.REMOVE_LAST, remove_last)
	var occupancy_row: HBoxContainer = HBoxContainer.new()
	occupancy_row.name = "OccupancyRow"
	add_child(occupancy_row)
	_add_button(occupancy_row, PLACE_SOLID_NAME, UiCopy.PLACE_SOLID, place_next_solid)
	_add_button(occupancy_row, PLACE_HAZARD_NAME, UiCopy.PLACE_HAZARD, place_next_hazard)
	_add_button(occupancy_row, PLACE_CRATE_NAME, UiCopy.PLACE_CRATE, place_next_crate)
	_add_button(occupancy_row, PLACE_FINISH_NAME, UiCopy.PLACE_FINISH, place_next_finish)
	_add_button(occupancy_row, PLACE_MOVER_NAME, UiCopy.PLACE_MOVER, place_next_mover)
	_add_button(occupancy_row, PLACE_CONVEYOR_NAME, UiCopy.PLACE_CONVEYOR, place_next_conveyor)
	_add_button(occupancy_row, PLACE_LIFT_NAME, UiCopy.PLACE_LIFT, place_next_lift)
	_add_button(occupancy_row, PLACE_LAUNCH_NAME, UiCopy.PLACE_LAUNCH, place_next_launch)
	var pickup_row: HBoxContainer = HBoxContainer.new()
	pickup_row.name = "PickupRow"
	add_child(pickup_row)
	_add_button(pickup_row, PLACE_BOMB_NAME, UiCopy.PLACE_BOMB, place_next_bomb)
	_add_button(pickup_row, PLACE_DASH_NAME, UiCopy.PLACE_DASH, place_next_dash)
	var floor_row: HBoxContainer = HBoxContainer.new()
	floor_row.name = "FloorRow"
	add_child(floor_row)
	_add_button(floor_row, FLOOR_UP_NAME, UiCopy.FLOOR_UP, floor_up)
	_add_button(floor_row, FLOOR_DOWN_NAME, UiCopy.FLOOR_DOWN, floor_down)
	# 批量生成按 CD-32 只给 internal_dev。Web 轻量拿到「矩形填充 / 框选删除」
	# 等于把内部产线工具当产品发；那也是 `allows_batch_generate` 一直没被执行的
	# 那条能力差（可玩性深化 轨 3）。
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
	if host == null or cursor == null:
		return false
	var entity_id: int = 0
	var target_id: int = 0
	if _pending_portal_id > 0:
		entity_id = _pending_pair_entity_id()
		if entity_id <= 0:
			entity_id = _peek_entity_id()
		target_id = _pending_portal_id
	else:
		entity_id = _peek_entity_id()
		target_id = entity_id + 1
		while _world_has(target_id):
			target_id += 1
	if not host.try_place_portal(entity_id, target_id, cursor.cell_x, cursor.cell_y, cursor.cell_z):
		return false
	_commit_entity_id(entity_id)
	if _pending_portal_id > 0:
		_pending_portal_id = 0
	else:
		_pending_portal_id = entity_id
	cursor.bump_x()
	_select_placed(entity_id)
	return true


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
	var yaw_bam: int = _next_conveyor_yaw
	if not _place_occupancy(func(entity_id: int) -> bool:
		return host.try_place_conveyor(
			entity_id, cursor.cell_x, cursor.cell_y, cursor.cell_z, yaw_bam
		)
	):
		return false
	_next_conveyor_yaw = (yaw_bam + Fixed.BAM_TURN / 4) % Fixed.BAM_TURN
	return true


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


func next_conveyor_yaw_bam() -> int:
	return _next_conveyor_yaw


func sync_params() -> void:
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


func _add_button(row: HBoxContainer, node_name: String, copy_key: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = UiCopy.text(copy_key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	row.add_child(button)


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
