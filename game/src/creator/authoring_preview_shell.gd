class_name AuthoringPreviewShell
extends Node

## Independent Preview window host (CD-32 §4). AuthoringSession stays open.
## Creates a Godot Window in code and maps preview transforms to 1 m boxes,
## portal gizmos, checkpoint-order labels, and reachability-issue overlay.
## Does not compile SimulationBundle. Tab host is reserved and refused.
## Never settlement.

const TITLE: String = "Preview"
const _STATUS_NAME: String = "Status"
const _MAP_NAME: String = "PreviewMap"

var kind: String = AuthoringPreviewHostKinds.WINDOW
var preview: AuthoringPreview = null
var window: Window = null
var map: AuthoringPreviewMap = null
var _status: Label = null


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
	window.visible = true
	return true


func show_window() -> bool:
	if preview == null or window == null:
		return false
	if not preview.connected:
		return false
	window.visible = true
	_refresh_status()
	return true


func hide_window() -> void:
	if window != null:
		window.visible = false


func is_window_visible() -> bool:
	return window != null and window.visible


func try_apply_patch(level: String, command: SharedCommand) -> bool:
	if preview == null:
		return false
	var ok: bool = preview.try_apply_patch(level, command)
	_rebuild_map()
	_refresh_status()
	return ok


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func status_view() -> Dictionary:
	var entity_count: int = 0
	var connected: bool = false
	var preview_revision: int = 0
	var needs_restart: bool = false
	var reach_ok: bool = true
	var reach_issue_count: int = 0
	if preview != null:
		connected = preview.connected
		preview_revision = preview.preview_revision
		needs_restart = preview.needs_restart
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
		"window_visible": is_window_visible(),
		"reach_ok": reach_ok,
		"reach_issue_count": reach_issue_count,
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
	window.size = Vector2i(640, 360)
	window.exclusive = false
	window.transient = false
	window.own_world_3d = true
	window.close_requested.connect(_on_close_requested)
	_status = Label.new()
	_status.name = _STATUS_NAME
	window.add_child(_status)
	map = AuthoringPreviewMap.new()
	map.name = _MAP_NAME
	window.add_child(map)
	add_child(window)
	map.ensure_rig()


func _on_close_requested() -> void:
	hide_window()


func _rebuild_map() -> void:
	if map == null or preview == null:
		return
	map.rebuild(preview.world)


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
	_status.text = "connected=%s revision=%d entities=%d restart=%s reach_ok=%s issues=%d" % [
		str(preview.connected),
		preview.preview_revision,
		entity_count,
		str(preview.needs_restart),
		str(reach_ok),
		reach_issue_count,
	]
