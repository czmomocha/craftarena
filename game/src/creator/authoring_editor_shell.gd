class_name AuthoringEditorShell
extends Node

## Shared editor host (CD-32 §1). AuthoringSession stays the write path.
## Creates a Godot Window in code. The EditorPlugin opens this shell;
## this class is not itself an EditorPlugin. Not in-game HUD.
## Hosts the TRAPRUSH tool strip and read-only validator details.
## Emits existing EDIT ops only. Overlay is not a write gate.
## Maps AuthoringWorld through AuthoringPreviewMap.
## A connected Preview follows committed writes: the same EDIT command is
## forwarded as a safe-point patch at its classified level. A refused forward
## drops the follow link instead of rolling back the authoring write.
## Optional AuthoringDraftStore restores after crash. Never settlement.
## In the Godot editor, FileAccess runs in the @tool plugin, not here.

signal world_committed

const TITLE: String = "Editor"
const ACTOR_ID: int = 2
const CONTENT_VERSION: String = "content-v1"
const TRACE_ID: String = "trace-authoring-editor"
const _STATUS_NAME: String = "Status"
const _MAP_NAME: String = "EditorMap"
const _TOOLS_NAME: String = "TraprushTools"
const _VALIDATOR_NAME: String = "ValidatorDetails"
const _UNDO_NAME: String = "Undo"
const _REDO_NAME: String = "Redo"
const _PREVIEW_NAME: String = "Preview"
const TraprushEditorPanelGd := preload("res://src/creator/traprush_editor_panel.gd")
const AuthoringValidatorPanelGd := preload("res://src/creator/authoring_validator_panel.gd")

var surface: String = AuthoringSurfaceNames.INTERNAL_DEV
var session: AuthoringSession = null
var window: Window = null
var map: AuthoringPreviewMap = null
var preview: AuthoringPreviewShell = null
var tools: TraprushEditorPanelGd = null
var validator: AuthoringValidatorPanelGd = null
var draft_store: AuthoringDraftStore = null
var last_draft_ok: bool = false
var preview_follows: bool = false
var _status: Label = null
var _next_command_id: int = 1


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
	_restore_draft_if_empty()
	_sync_tools_from_world()
	_rebuild_map()
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
		_rebuild_map()
		_refresh_status()
		return false
	var ok: bool = session.try_apply(command)
	if ok:
		_persist_draft()
		_forward_command(command)
	_rebuild_map()
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
	var payload: Dictionary = session.peek_undo_payload()
	var revision_before: int = session.world.revision
	var ok: bool = session.undo()
	if ok:
		_persist_draft()
		_forward_payload(payload, revision_before)
	_rebuild_map()
	_refresh_status()
	return ok


func redo() -> bool:
	if session == null:
		return false
	var payload: Dictionary = session.peek_redo_payload()
	var revision_before: int = session.world.revision
	var ok: bool = session.redo()
	if ok:
		_persist_draft()
		_forward_payload(payload, revision_before)
	_rebuild_map()
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
	preview_follows = preview.open_from(session)
	_refresh_status()
	return preview_follows


func export_document() -> Dictionary:
	if session == null:
		return {}
	return session.export_document()


func import_document(data: Dictionary) -> bool:
	if session == null:
		return false
	var ok: bool = session.import_document(data)
	if ok:
		_persist_draft()
		preview_follows = false
	_rebuild_map()
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
		"preview_follows": preview_follows,
	}


func status_label_text() -> String:
	if _status == null:
		return ""
	return _status.text


func refresh_status() -> void:
	_refresh_status()


func restore_document(data: Dictionary) -> bool:
	if session == null:
		return false
	if not session.import_document(data):
		return false
	preview_follows = false
	_sync_tools_from_world()
	_rebuild_map()
	_refresh_status()
	return true


func note_draft_write(ok: bool) -> void:
	last_draft_ok = ok
	_refresh_status()


func _forward_payload(payload: Dictionary, expected_revision: int) -> void:
	if not preview_follows:
		return
	if payload.is_empty():
		preview_follows = false
		return
	var command: SharedCommand = SharedCommand.create(
		_next_command_id,
		ACTOR_ID,
		_next_command_id,
		0,
		expected_revision,
		CONTENT_VERSION,
		payload,
		TRACE_ID,
		SharedCommand.Kind.EDIT
	)
	_next_command_id += 1
	if command == null:
		preview_follows = false
		return
	_forward_command(command)


func _forward_command(command: SharedCommand) -> void:
	if not preview_follows:
		return
	if preview == null or preview.preview == null or preview.preview.world == null:
		preview_follows = false
		return
	var level: String = PreviewPatchLevels.classify(command, preview.preview.world)
	if level.is_empty():
		preview_follows = false
		return
	if not preview.try_apply_patch(level, command):
		preview_follows = false


func _restore_draft_if_empty() -> void:
	if Engine.is_editor_hint():
		return
	if draft_store == null or session == null or session.world == null:
		return
	if session.world.revision != 0 or session.world.entity_count() != 0:
		return
	var loaded: AuthoringWorld = draft_store.try_load_latest()
	if loaded == null:
		return
	var encoded: Dictionary = AuthoringDocument.encode(loaded)
	if encoded.is_empty():
		return
	session.import_document(encoded)


func _persist_draft() -> void:
	world_committed.emit()
	if Engine.is_editor_hint():
		return
	if draft_store == null or session == null:
		last_draft_ok = false
		return
	last_draft_ok = draft_store.record(session.world)


func _sync_tools_from_world() -> void:
	if tools == null or session == null:
		return
	tools.adopt_world(session.world)


func _ensure_window() -> void:
	if window != null:
		return
	if not Engine.is_editor_hint():
		var host_viewport: Viewport = get_viewport()
		if host_viewport != null:
			host_viewport.gui_embed_subwindows = true
	window = Window.new()
	window.title = TITLE
	window.size = Vector2i(640, 560)
	window.exclusive = false
	window.transient = false
	window.own_world_3d = true
	window.close_requested.connect(_on_close_requested)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	window.add_child(root)
	_status = Label.new()
	_status.name = _STATUS_NAME
	root.add_child(_status)
	tools = TraprushEditorPanelGd.new()
	tools.name = _TOOLS_NAME
	root.add_child(tools)
	tools.mount(self)
	validator = AuthoringValidatorPanelGd.new()
	validator.name = _VALIDATOR_NAME
	root.add_child(validator)
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.name = "SharedActions"
	root.add_child(action_row)
	_add_button(action_row, _UNDO_NAME, "Undo", _on_undo)
	_add_button(action_row, _REDO_NAME, "Redo", _on_redo)
	_add_button(action_row, _PREVIEW_NAME, "Preview", _on_preview)
	map = AuthoringPreviewMap.new()
	map.name = _MAP_NAME
	window.add_child(map)
	add_child(window)
	map.ensure_rig()
	if validator != null:
		validator.mount(map)


func _rebuild_map() -> void:
	if map == null or session == null:
		return
	map.rebuild(session.world)
	if validator != null:
		validator.refresh(session.world)


func _add_button(row: BoxContainer, node_name: String, text: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	row.add_child(button)


func _on_close_requested() -> void:
	hide_window()


func _on_undo() -> void:
	undo()


func _on_redo() -> void:
	redo()


func _on_preview() -> void:
	open_preview()


func _refresh_status() -> void:
	if _status == null or session == null or session.world == null:
		return
	var floor_index: int = 0
	if tools != null:
		floor_index = tools.floor_index
	var reach_ok_flag: bool = true
	var issue_n: int = 0
	if validator != null:
		reach_ok_flag = validator.reach_ok()
		issue_n = validator.issue_count()
	_status.text = "%s revision=%d entities=%d floor=%d undo=%s redo=%s reach_ok=%s issues=%d draft=%s disk=%s follow=%s" % [
		surface,
		session.world.revision,
		session.world.entity_count(),
		floor_index,
		str(session.can_undo()),
		str(session.can_redo()),
		str(reach_ok_flag),
		issue_n,
		str(draft_store != null),
		str(last_draft_ok),
		str(preview_follows),
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
