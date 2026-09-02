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
## Collaborators are chrome / place / follow so this file stays under E9 400
## lines. Public API stays on this type.

signal world_committed

const TITLE: String = UiCopy.WINDOW_EDITOR
const ACTOR_ID: int = 2
const CONTENT_VERSION: String = "content-v1"
const TRACE_ID: String = "trace-authoring-editor"
const ChromeGd := preload("res://src/creator/authoring_editor_shell_chrome.gd")
const FollowGd := preload("res://src/creator/authoring_editor_shell_follow.gd")
const PlaceGd := preload("res://src/creator/authoring_editor_shell_place.gd")
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
var chrome: ChromeGd = ChromeGd.new()
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
	_rebuild_map(true)
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
	chrome.hide_window()


func is_window_visible() -> bool:
	return chrome.is_visible()


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
		FollowGd.forward_command(self, command)
	_rebuild_map()
	_refresh_status()
	return ok


func try_place_checkpoint(entity_id: int, order: int, cell_x: int, cell_y: int, cell_z: int) -> bool:
	return PlaceGd.try_place_checkpoint(self, entity_id, order, cell_x, cell_y, cell_z)


func try_place_portal(entity_id: int, target_id: int, cell_x: int, cell_y: int, cell_z: int) -> bool:
	return PlaceGd.try_place_portal(self, entity_id, target_id, cell_x, cell_y, cell_z)


func try_place_solid(entity_id: int, cell_x: int, cell_y: int, cell_z: int) -> bool:
	return PlaceGd.try_place_solid(self, entity_id, cell_x, cell_y, cell_z)


func try_place_finish(entity_id: int, cell_x: int, cell_y: int, cell_z: int) -> bool:
	return PlaceGd.try_place_finish(self, entity_id, cell_x, cell_y, cell_z)


func try_place_hazard(entity_id: int, cell_x: int, cell_y: int, cell_z: int) -> bool:
	return PlaceGd.try_place_hazard(self, entity_id, cell_x, cell_y, cell_z)


func try_place_crate(entity_id: int, cell_x: int, cell_y: int, cell_z: int) -> bool:
	return PlaceGd.try_place_crate(self, entity_id, cell_x, cell_y, cell_z)


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
		FollowGd.forward_payload(self, payload, revision_before)
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
		FollowGd.forward_payload(self, payload, revision_before)
	_rebuild_map()
	_refresh_status()
	return ok


func open_preview() -> bool:
	return FollowGd.open_preview(self)


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
	_rebuild_map(true)
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
	return chrome.status_text()


func refresh_status() -> void:
	_refresh_status()


func restore_document(data: Dictionary) -> bool:
	if session == null:
		return false
	if not session.import_document(data):
		return false
	preview_follows = false
	_sync_tools_from_world()
	_rebuild_map(true)
	_refresh_status()
	return true


func note_draft_write(ok: bool) -> void:
	last_draft_ok = ok
	_refresh_status()


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
	chrome.ensure(self, {
		"undo": _on_undo,
		"redo": _on_redo,
		"preview": _on_preview,
		"close": _on_close_requested,
	})
	window = chrome.window
	map = chrome.map
	tools = chrome.tools
	validator = chrome.validator


func _on_close_requested() -> void:
	hide_window()


func _on_undo() -> void:
	undo()


func _on_redo() -> void:
	redo()


func _on_preview() -> void:
	open_preview()


## force=true 给「revision 可能被整体换掉而不是 +1」的入口用：try_restore 会把
## revision 设成文档里的值，理论上能和当前值撞上，脏检查就会误判「没变」。
func _rebuild_map(force: bool = false) -> void:
	if map == null or session == null:
		return
	if force:
		map.invalidate()
	map.rebuild(session.world)
	if validator != null:
		validator.refresh(session.world)


func _refresh_status() -> void:
	var line: String = chrome.format_line(self)
	if line.is_empty():
		return
	chrome.set_status_text(line)
