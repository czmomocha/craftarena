class_name AuthoringEditorShell
extends Node

## Shared editor host (CD-32 §1). AuthoringSession stays the write path.
## Creates a Godot Window in code. Not an EditorPlugin. Not in-game HUD.
## Emits existing EDIT ops only. Preview does not auto-follow.
## Never settlement.

const TITLE: String = "Editor"
const ACTOR_ID: int = 2
const CONTENT_VERSION: String = "content-v1"
const TRACE_ID: String = "trace-authoring-editor"
const _STATUS_NAME: String = "Status"
const _PLACE_CHECKPOINT_NAME: String = "PlaceCheckpoint"
const _UNDO_NAME: String = "Undo"
const _REDO_NAME: String = "Redo"
const _PREVIEW_NAME: String = "Preview"

var surface: String = AuthoringSurfaceNames.INTERNAL_DEV
var session: AuthoringSession = null
var window: Window = null
var preview: AuthoringPreviewShell = null
var _status: Label = null
var _next_command_id: int = 1
var _next_entity_id: int = 1
var _next_order: int = 0
var _next_cell_x: int = 0


static func create(p_surface: String) -> AuthoringEditorShell:
	if not AuthoringSurfaceNames.contains(p_surface):
		return null
	if not AuthoringSurfaceNames.allows_edit_commands(p_surface):
		return null
	var next_session: AuthoringSession = AuthoringSession.create(p_surface)
	if next_session == null:
		return null
	var shell := new()
	shell.surface = p_surface
	shell.session = next_session
	return shell


func open() -> bool:
	if session == null:
		return false
	_ensure_window()
	if window == null:
		return false
	_refresh_status()
	window.visible = true
	return true


func show_window() -> bool:
	if session == null or window == null:
		return false
	window.visible = true
	_refresh_status()
	return true


func hide_window() -> void:
	if window != null:
		window.visible = false


func is_window_visible() -> bool:
	return window != null and window.visible


func try_edit(payload: Dictionary) -> bool:
	if session == null:
		return false
	var command: SharedCommand = SharedCommand.create(
		_next_command_id,
		ACTOR_ID,
		_next_command_id,
		0,
		session.world.revision,
		CONTENT_VERSION,
		payload,
		TRACE_ID,
		SharedCommand.Kind.EDIT
	)
	_next_command_id += 1
	if command == null:
		_refresh_status()
		return false
	var ok: bool = session.try_apply(command)
	_refresh_status()
	return ok


func try_place_checkpoint(entity_id: int, order: int, cell_x: int, cell_y: int, cell_z: int) -> bool:
	if session == null or session.world == null or session.world.grid == null:
		return false
	var cell: int = session.world.grid.cell
	return try_edit(_checkpoint_payload(entity_id, order, cell_x * cell, cell_y * cell, cell_z * cell))


func try_place_portal(entity_id: int, target_id: int, cell_x: int, cell_y: int, cell_z: int) -> bool:
	if session == null or session.world == null or session.world.grid == null:
		return false
	var cell: int = session.world.grid.cell
	return try_edit(_portal_payload(entity_id, target_id, cell_x * cell, cell_y * cell, cell_z * cell))


func try_remove(entity_id: int) -> bool:
	return try_edit({"op": "remove", "entity_id": entity_id})


func undo() -> bool:
	if session == null:
		return false
	var ok: bool = session.undo()
	_refresh_status()
	return ok


func redo() -> bool:
	if session == null:
		return false
	var ok: bool = session.redo()
	_refresh_status()
	return ok


func open_preview() -> bool:
	if session == null:
		return false
	if preview == null:
		preview = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
		if preview == null:
			return false
		add_child(preview)
	return preview.open_from(session)


func export_document() -> Dictionary:
	if session == null:
		return {}
	return session.export_document()


func import_document(data: Dictionary) -> bool:
	if session == null:
		return false
	var ok: bool = session.import_document(data)
	_refresh_status()
	return ok


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func status_view() -> Dictionary:
	var entity_count: int = 0
	var revision: int = 0
	var can_undo: bool = false
	var can_redo: bool = false
	if session != null and session.world != null:
		entity_count = session.world.entity_count()
		revision = session.world.revision
		can_undo = session.can_undo()
		can_redo = session.can_redo()
	return {
		"surface": surface,
		"revision": revision,
		"entity_count": entity_count,
		"can_undo": can_undo,
		"can_redo": can_redo,
		"window_visible": is_window_visible(),
	}


func status_label_text() -> String:
	if _status == null:
		return ""
	return _status.text


func _ensure_window() -> void:
	if window != null:
		return
	var host_viewport: Viewport = get_viewport()
	if host_viewport != null:
		host_viewport.gui_embed_subwindows = true
	window = Window.new()
	window.title = TITLE
	window.size = Vector2i(420, 280)
	window.exclusive = false
	window.transient = false
	window.close_requested.connect(_on_close_requested)
	var root: VBoxContainer = VBoxContainer.new()
	window.add_child(root)
	_status = Label.new()
	_status.name = _STATUS_NAME
	root.add_child(_status)
	_add_button(root, _PLACE_CHECKPOINT_NAME, "Place checkpoint", _on_place_checkpoint)
	_add_button(root, _UNDO_NAME, "Undo", _on_undo)
	_add_button(root, _REDO_NAME, "Redo", _on_redo)
	_add_button(root, _PREVIEW_NAME, "Preview", _on_preview)
	add_child(window)


func _add_button(root: VBoxContainer, node_name: String, text: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.pressed.connect(handler)
	root.add_child(button)


func _on_close_requested() -> void:
	hide_window()


func _on_place_checkpoint() -> void:
	var entity_id: int = _next_entity_id
	var order: int = _next_order
	var cell_x: int = _next_cell_x
	if try_place_checkpoint(entity_id, order, cell_x, 0, 0):
		_next_entity_id += 1
		_next_order += 1
		_next_cell_x += 1


func _on_undo() -> void:
	undo()


func _on_redo() -> void:
	redo()


func _on_preview() -> void:
	open_preview()


func _refresh_status() -> void:
	if _status == null or session == null or session.world == null:
		return
	_status.text = "%s revision=%d entities=%d undo=%s redo=%s" % [
		surface,
		session.world.revision,
		session.world.entity_count(),
		str(session.can_undo()),
		str(session.can_redo()),
	]


func _checkpoint_payload(entity_id: int, order: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"checkpoint": {"order": order, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
			},
		},
	}


func _portal_payload(entity_id: int, target_id: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
			},
		},
	}
