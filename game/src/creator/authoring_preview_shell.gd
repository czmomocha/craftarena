class_name AuthoringPreviewShell
extends Node

## Independent Preview window host (CD-32 §4). AuthoringSession stays open.
## Creates a Godot Window in code and maps preview transforms to 1 m boxes,
## portal gizmos, checkpoint-order labels, and reachability-issue overlay.
## Play compiles the connected Preview world into a SimulationBundle, loads
## it, and draws the player pose as a presentation stub. While playing and
## visible, WASD maps to world-space MoveIntent; play_move_step is a
## presentation stub, not a product speed. Advance tick calls existing
## try_advance_play so period hazards can open; intents still do not tick.
## Reset button and R rising-edge
## encode ResetToCheckpointIntent; that sample is a stub, not a hold
## duration. Use item button and use_item rising-edge encode UseItemIntent;
## play_use_item_damage / reach are stubs, not a blast table. Jump button
## and jump rising-edge encode JumpIntent; play_jump_dy / play_support_dy
## are stubs, not a locked jump height or gravity. Play copies an 8-cell
## AABB stub onto Preview (not a product bound). Occupancy
## accepts overlapping checkpoint pads through PadAccept and portal boxes
## through PortalLanding.try_land_exit; status shows pads=n/m, floor=n,
## finish=n, crates=n/m, hazards=n/m, and solids=n/m.
## Tab host
## is reserved and refused.
## The window defaults to 1280×720 maximized; HUD buttons use
## FOCUS_NONE so Space stays jump, not Play. Re-open raises the existing
## window (grab_focus) and rebuilds it if the native instance was freed.
## Not a product FOV.
## Never settlement.

const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const TITLE: String = "Preview"
const WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
const WINDOW_MIN_SIZE: Vector2i = Vector2i(960, 540)
const PLAY_NAME: String = "Play"
const STOP_NAME: String = "Stop"
const RESET_NAME: String = "Reset"
const USE_ITEM_NAME: String = "UseItem"
const JUMP_NAME: String = "Jump"
const ADVANCE_TICK_NAME: String = "AdvanceTick"
const _USE_ITEM: String = "use_item"
const _JUMP: String = "jump"
const _STATUS_NAME: String = "Status"
const _MAP_NAME: String = "PreviewMap"
const _OVERLAY_NAME: String = "Overlay"
const _MOVE_FORWARD: String = "move_forward"
const _MOVE_BACK: String = "move_back"
const _MOVE_LEFT: String = "move_left"
const _MOVE_RIGHT: String = "move_right"

var kind: String = AuthoringPreviewHostKinds.WINDOW
var preview: AuthoringPreview = null
var window: Window = null
var map: AuthoringPreviewMap = null
var play_move_step: int = Fixed.SCALE / 16
var play_use_item_damage: int = 1
var play_use_item_reach_dx: int = 0
var play_use_item_reach_dy: int = 0
var play_use_item_reach_dz: int = Fixed.SCALE
var play_jump_dy: int = Fixed.SCALE / 4
var play_support_dy: int = -Fixed.SCALE
var play_range_half: int = OutOfRangeReset.STUB_HALF
var _status: Label = null
var _reset_held: bool = false
var _use_item_held: bool = false
var _jump_held: bool = false
var _play_view_busy: bool = false # rebuilds must not re-enter _process sampling


static func create(p_kind: String) -> AuthoringPreviewShell:
	if not AuthoringPreviewHostKinds.contains(p_kind):
		return null
	var shell: AuthoringPreviewShell = AuthoringPreviewShell.new()
	shell.kind = p_kind
	return shell


func open_from(session: AuthoringSession) -> bool:
	if session == null:
		return false
	if kind != AuthoringPreviewHostKinds.WINDOW:
		return false
	var next_preview: AuthoringPreview = AuthoringPreview.new()
	if not next_preview.connect_from(session):
		return false
	preview = next_preview
	_ensure_window()
	if window == null:
		return false
	_rebuild_map()
	_refresh_status()
	return _raise_window()


func show_window() -> bool:
	if preview == null:
		return false
	if not preview.connected:
		return false
	var rebuilt: bool = not _window_alive()
	_ensure_window()
	if window == null:
		return false
	if rebuilt:
		_rebuild_map()
	_refresh_status()
	return _raise_window()


func hide_window() -> void:
	if _window_alive():
		window.visible = false


func is_window_visible() -> bool:
	return _window_alive() and window.visible


func _window_alive() -> bool:
	return window != null and is_instance_valid(window)


func _raise_window() -> bool:
	if not _window_alive():
		return false
	window.visible = true
	if window.is_inside_tree():
		window.grab_focus()
	return true


func try_apply_patch(level: String, command: SharedCommand) -> bool:
	if preview == null:
		return false
	var ok: bool = preview.try_apply_patch(level, command)
	_rebuild_map()
	_refresh_status()
	return ok


func try_start_play(seed: int = 1, radius: int = 0, cylinder_height: int = 0) -> bool:
	if preview == null or _play_view_busy:
		return false
	_reset_held = false
	_use_item_held = false
	_jump_held = false
	_copy_use_item_stubs()
	_copy_jump_stubs()
	_copy_play_range_stub()
	_play_view_busy = true
	var ok: bool = preview.try_start_play(seed, radius, cylinder_height)
	_rebuild_map()
	_refresh_status()
	_play_view_busy = false
	return ok


func try_stop_play() -> bool:
	if preview == null or _play_view_busy:
		return false
	_reset_held = false
	_use_item_held = false
	_jump_held = false
	_play_view_busy = true
	var ok: bool = preview.try_stop_play()
	_rebuild_map()
	_refresh_status()
	_play_view_busy = false
	return ok


func try_advance_play() -> bool:
	if preview == null or _play_view_busy:
		return false
	_play_view_busy = true
	var ok: bool = preview.try_advance_play()
	_rebuild_map()
	_refresh_status()
	_play_view_busy = false
	return ok


static func move_payload_from_axes(
	forward: bool,
	back: bool,
	left: bool,
	right: bool,
	step: int
) -> Dictionary:
	if step < 1:
		return {}
	var dx: int = 0
	var dz: int = 0
	if right:
		dx += step
	if left:
		dx -= step
	if back:
		dz += step
	if forward:
		dz -= step
	if dx == 0 and dz == 0:
		return {}
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": dx,
		"dz": dz,
	}


func try_apply_play_intent(payload: Dictionary) -> bool:
	if preview == null or _play_view_busy:
		return false
	_play_view_busy = true
	var ok: bool = preview.try_apply_play_intent(payload)
	_rebuild_map()
	_refresh_status()
	_play_view_busy = false
	return ok


func try_sample_play_move(forward: bool, back: bool, left: bool, right: bool) -> bool:
	if preview == null or not preview.is_playing():
		return false
	if not _window_alive() or not window.visible:
		return false
	var payload: Dictionary = move_payload_from_axes(forward, back, left, right, play_move_step)
	if payload.is_empty():
		return false
	return try_apply_play_intent(payload)


func try_sample_play_use_item(pressed: bool) -> bool:
	if preview == null or not preview.is_playing():
		_use_item_held = pressed
		return false
	if not _window_alive() or not window.visible:
		_use_item_held = pressed
		return false
	var rising: bool = pressed and not _use_item_held
	_use_item_held = pressed
	if not rising:
		return false
	_copy_use_item_stubs()
	return try_apply_play_intent({
		"intent": PlayerIntentNames.USE_ITEM,
	})


func try_sample_play_reset(pressed: bool) -> bool:
	if preview == null or not preview.is_playing():
		_reset_held = pressed
		return false
	if not _window_alive() or not window.visible:
		_reset_held = pressed
		return false
	var rising: bool = pressed and not _reset_held
	_reset_held = pressed
	if not rising:
		return false
	return try_apply_play_intent({
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
	})


func try_sample_play_jump(pressed: bool) -> bool:
	if preview == null or not preview.is_playing():
		_jump_held = pressed
		return false
	if not _window_alive() or not window.visible:
		_jump_held = pressed
		return false
	var rising: bool = pressed and not _jump_held
	_jump_held = pressed
	if not rising:
		return false
	_copy_jump_stubs()
	return try_apply_play_intent({
		"intent": PlayerIntentNames.JUMP,
	})


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func status_view() -> Dictionary:
	var entity_count: int = 0
	var connected: bool = false
	var preview_revision: int = 0
	var needs_restart: bool = false
	var playing: bool = false
	var accepted_count: int = 0
	var checkpoint_count: int = 0
	var floor_index: int = 0
	var finish_tick: int = -1
	var crate_alive: int = 0
	var crate_count: int = 0
	var hazard_alive: int = 0
	var hazard_count: int = 0
	var reach_ok: bool = true
	var reach_issue_count: int = 0
	if preview != null:
		connected = preview.connected
		preview_revision = preview.preview_revision
		needs_restart = preview.needs_restart
		playing = preview.is_playing()
		accepted_count = preview.play_accepted_count()
		checkpoint_count = preview.play_checkpoint_count()
		floor_index = preview.play_floor_index()
		finish_tick = preview.play_finish_tick()
		crate_alive = preview.play_destructible_alive_count()
		crate_count = preview.play_destructible_count()
		hazard_alive = preview.play_hazard_solid_count()
		hazard_count = preview.play_hazard_count()
		if preview.world != null:
			entity_count = preview.world.entity_count()
	if map != null:
		reach_ok = map.reachability_ok()
		reach_issue_count = map.reachability_issue_count()
	return {
		"connected": connected,
		"preview_revision": preview_revision,
		"entity_count": entity_count,
		"needs_restart": needs_restart,
		"playing": playing,
		"accepted_count": accepted_count,
		"checkpoint_count": checkpoint_count,
		"floor_index": floor_index,
		"finish_tick": finish_tick,
		"crate_alive": crate_alive,
		"crate_count": crate_count,
		"hazard_alive": hazard_alive,
		"hazard_count": hazard_count,
		"window_visible": is_window_visible(),
		"reach_ok": reach_ok,
		"reach_issue_count": reach_issue_count,
	}


func status_label_text() -> String:
	if _status == null:
		return ""
	return _status.text


func _ensure_window() -> void:
	if _window_alive():
		return
	window = null
	map = null
	_status = null
	var host_viewport: Viewport = get_viewport()
	if host_viewport != null:
		host_viewport.gui_embed_subwindows = true
	window = Window.new()
	window.title = TITLE
	window.size = WINDOW_SIZE
	window.min_size = WINDOW_MIN_SIZE
	window.mode = Window.MODE_MAXIMIZED
	window.exclusive = false
	window.transient = false
	window.own_world_3d = true
	window.close_requested.connect(_on_close_requested)
	var overlay: VBoxContainer = VBoxContainer.new()
	overlay.name = _OVERLAY_NAME
	overlay.set_anchors_preset(Control.PRESET_TOP_WIDE)
	overlay.offset_left = 8
	overlay.offset_top = 8
	overlay.offset_right = -8
	window.add_child(overlay)
	_status = Label.new()
	_status.name = _STATUS_NAME
	overlay.add_child(_status)
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.name = "PlayActions"
	overlay.add_child(action_row)
	_add_button(action_row, PLAY_NAME, "Play", _on_play)
	_add_button(action_row, STOP_NAME, "Stop", _on_stop)
	_add_button(action_row, RESET_NAME, "Reset", _on_reset)
	_add_button(action_row, USE_ITEM_NAME, "Use item", _on_use_item)
	_add_button(action_row, JUMP_NAME, "Jump", _on_jump)
	_add_button(action_row, ADVANCE_TICK_NAME, "Advance tick", _on_advance_tick)
	map = AuthoringPreviewMap.new()
	map.name = _MAP_NAME
	window.add_child(map)
	add_child(window)
	map.ensure_rig()
	window.gui_release_focus()


func _on_close_requested() -> void:
	hide_window()


func _on_play() -> void:
	try_start_play()


func _on_stop() -> void:
	try_stop_play()


func _on_reset() -> void:
	try_apply_play_intent({
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
	})


func _on_use_item() -> void:
	_copy_use_item_stubs()
	try_apply_play_intent({
		"intent": PlayerIntentNames.USE_ITEM,
	})


func _on_jump() -> void:
	_copy_jump_stubs()
	try_apply_play_intent({
		"intent": PlayerIntentNames.JUMP,
	})


func _on_advance_tick() -> void:
	try_advance_play()


func _copy_use_item_stubs() -> void:
	if preview == null:
		return
	preview.play_use_item_damage = play_use_item_damage
	preview.play_use_item_reach_dx = play_use_item_reach_dx
	preview.play_use_item_reach_dy = play_use_item_reach_dy
	preview.play_use_item_reach_dz = play_use_item_reach_dz


func _copy_jump_stubs() -> void:
	if preview == null:
		return
	preview.play_jump_dy = play_jump_dy
	preview.play_support_dy = play_support_dy


func _copy_play_range_stub() -> void:
	if preview == null:
		return
	preview.enable_play_range(play_range_half)


func _process(_delta: float) -> void:
	if _play_view_busy:
		return
	if preview == null or not preview.is_playing():
		return
	if not _window_alive() or not window.visible:
		return
	try_sample_play_move(
		Input.is_action_pressed(_MOVE_FORWARD),
		Input.is_action_pressed(_MOVE_BACK),
		Input.is_action_pressed(_MOVE_LEFT),
		Input.is_action_pressed(_MOVE_RIGHT)
	)
	try_sample_play_reset(Input.is_physical_key_pressed(KEY_R))
	try_sample_play_use_item(Input.is_action_pressed(_USE_ITEM))
	try_sample_play_jump(Input.is_action_pressed(_JUMP))


func _add_button(row: BoxContainer, node_name: String, text: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(handler)
	row.add_child(button)


func _rebuild_map() -> void:
	if map == null or preview == null:
		return
	map.rebuild(preview.world)
	if preview.is_playing() and preview.play_world != null:
		map.show_player_pose(preview.play_world.get_pose(preview.player_id))
		map.mark_accepted_checkpoints(preview.play_accepted_ids())
		_apply_play_hazard_visibility()
	else:
		map.clear_player_pose()


func _apply_play_hazard_visibility() -> void:
	if map == null or preview == null or not preview.is_playing():
		return
	var lookup: Dictionary = {}
	for key: Variant in preview.play_hazard_ids.keys():
		if typeof(key) != TYPE_INT:
			continue
		var entity_id: int = key
		lookup[entity_id] = preview.play_is_hazard_solid(entity_id)
	map.apply_hazard_visibility(lookup)


func _refresh_status() -> void:
	if _status == null or preview == null:
		return
	var entity_count: int = 0
	if preview.world != null:
		entity_count = preview.world.entity_count()
	var reach_ok: bool = true
	var reach_issue_count: int = 0
	if map != null:
		reach_ok = map.reachability_ok()
		reach_issue_count = map.reachability_issue_count()
	_status.text = "connected=%s revision=%d entities=%d restart=%s playing=%s pads=%d/%d floor=%d finish=%d crates=%d/%d hazards=%d/%d solids=%d/%d reach_ok=%s issues=%d" % [
		str(preview.connected),
		preview.preview_revision,
		entity_count,
		str(preview.needs_restart),
		str(preview.is_playing()),
		preview.play_accepted_count(),
		preview.play_checkpoint_count(),
		preview.play_floor_index(),
		preview.play_finish_tick(),
		preview.play_destructible_alive_count(),
		preview.play_destructible_count(),
		preview.play_hazard_solid_count(),
		preview.play_hazard_count(),
		preview.play_solid_count(),
		preview.play_solid_count(),
		str(reach_ok),
		reach_issue_count,
	]
