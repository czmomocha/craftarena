class_name AuthoringPreviewShell
extends Node

## Independent Preview window host (CD-32 §4). AuthoringSession stays open.
## Collaborators are chrome / sampler / hud / play / view so this file stays
## under E9 400 lines. Public API stays on this type.
## Creates a Godot Window in code and maps preview transforms to 1 m boxes,
## portal gizmos, checkpoint-order labels, and reachability-issue overlay.
## Play compiles the connected Preview world into a SimulationBundle, loads
## it, and draws the player pose as a presentation stub. While playing and
## visible, PlayInput maps WASD / analog to a world-space MoveIntent;
## play_move_step is a presentation stub, not a product speed.
## Tab host is reserved and refused. Buttons use FOCUS_NONE so Space stays
## jump. Re-open raises the existing window and rebuilds if the native
## instance was freed. UI scales from the D4 1920×1080 base on the **main**
## window; this embedded sub-window must not set `content_scale_*`.
## Never settlement.

const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const ChromeGd := preload("res://src/creator/authoring_preview_shell_chrome.gd")
const HudGd := preload("res://src/creator/authoring_preview_shell_hud.gd")
const PlayGd := preload("res://src/creator/authoring_preview_shell_play.gd")
const SamplerGd := preload("res://src/creator/authoring_preview_shell_sampler.gd")
const ViewGd := preload("res://src/creator/authoring_preview_shell_view.gd")

const TITLE: String = ChromeGd.TITLE
const WINDOW_SIZE: Vector2i = ChromeGd.WINDOW_SIZE
const WINDOW_MIN_SIZE: Vector2i = ChromeGd.WINDOW_MIN_SIZE
const PLAY_NAME: String = ChromeGd.PLAY_NAME
const STOP_NAME: String = ChromeGd.STOP_NAME
const RESET_NAME: String = ChromeGd.RESET_NAME
const USE_ITEM_NAME: String = ChromeGd.USE_ITEM_NAME
const SPRINT_NAME: String = ChromeGd.SPRINT_NAME
const JUMP_NAME: String = ChromeGd.JUMP_NAME
const ADVANCE_TICK_NAME: String = ChromeGd.ADVANCE_TICK_NAME

var kind: String = AuthoringPreviewHostKinds.WINDOW
var preview: AuthoringPreview = null
var window: Window = null
var map: AuthoringPreviewMap = null
var play_move_step: int = PlaceholderSpec.MOVE_STEP
var play_use_item_damage: int = PlayStubs.USE_ITEM_DAMAGE
var play_use_item_reach_dx: int = PlayStubs.USE_ITEM_REACH_DX
var play_use_item_reach_dy: int = PlayStubs.USE_ITEM_REACH_DY
var play_use_item_reach_dz: int = PlayStubs.USE_ITEM_REACH_DZ
var play_sprint_step: int = PlayStubs.SPRINT_STEP
var play_item_cooldown_ticks: int = PlayStubs.ITEM_COOLDOWN_TICKS
var play_hazard_knockback_step: int = PlayStubs.HAZARD_KNOCKBACK_STEP
var play_respawn_stun_ticks: int = PlayStubs.PREVIEW_RESPAWN_STUN_TICKS
var play_jump_dy: int = PlayStubs.JUMP_DY
var play_support_dy: int = PlayStubs.SUPPORT_DY
## Advance tick is a click, not a frame, so Preview falls a whole cell per step.
var play_fall_dy: int = PlayStubs.PREVIEW_FALL_DY
var play_range_half: int = OutOfRangeReset.STUB_HALF
var play_anim: PlayAnimState = PlayAnimState.new()
var chrome: ChromeGd = ChromeGd.new()
var sampler: SamplerGd = SamplerGd.new()
var play: PlayGd = PlayGd.new()
var view: ViewGd = ViewGd.new()
var _play_view_busy: bool = false


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
	return chrome.raise_window()


func show_window() -> bool:
	if preview == null:
		return false
	if not preview.connected:
		return false
	var rebuilt: bool = not chrome.is_alive()
	_ensure_window()
	if window == null:
		return false
	if rebuilt:
		_rebuild_map()
	_refresh_status()
	return chrome.raise_window()


func hide_window() -> void:
	chrome.hide_window()


func is_window_visible() -> bool:
	return chrome.is_visible()


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
	sampler.reset_held_flags()
	sampler.play_moving = false
	play_anim.reset()
	play.copy_start_stubs(self)
	return _run_play_verb(func() -> bool: return preview.try_start_play(seed, radius, cylinder_height))


func try_stop_play() -> bool:
	if preview == null or _play_view_busy:
		return false
	sampler.reset_all()
	play_anim.reset()
	return _run_play_verb(preview.try_stop_play)


func try_advance_play() -> bool:
	if preview == null or _play_view_busy:
		return false
	return _run_play_verb(preview.try_advance_play)


static func move_payload_from_vector(move_x: float, move_z: float, step: int) -> Dictionary:
	return SamplerGd.move_payload_from_vector(move_x, move_z, step)


static func move_payload_from_axes(
	forward: bool,
	back: bool,
	left: bool,
	right: bool,
	step: int
) -> Dictionary:
	return SamplerGd.move_payload_from_axes(forward, back, left, right, step)


func try_apply_play_intent(payload: Dictionary) -> bool:
	if preview == null or _play_view_busy:
		return false
	return _run_play_verb(func() -> bool: return preview.try_apply_play_intent(payload))


func try_sample_play_vector(move_x: float, move_z: float) -> bool:
	var payload: Dictionary = sampler.try_vector(
		move_x, move_z, play_move_step, _is_playing(), chrome.is_visible()
	)
	if payload.is_empty():
		return false
	return try_apply_play_intent(payload)


func try_sample_play_move(forward: bool, back: bool, left: bool, right: bool) -> bool:
	var vector: Vector2 = PlayInput.vector_from_axes(forward, back, left, right)
	return try_sample_play_vector(vector.x, vector.y)


func try_sample_play_use_item(pressed: bool) -> bool:
	if not sampler.try_rising(pressed, "use_item", _is_playing(), chrome.is_visible()):
		return false
	play.copy_use_item_stubs(self)
	return try_apply_play_intent(play.use_item_intent())


func try_sample_play_sprint(pressed: bool) -> bool:
	if not sampler.try_rising(pressed, "sprint", _is_playing(), chrome.is_visible()):
		return false
	play.copy_sprint_stubs(self)
	return try_apply_play_intent(play.sprint_intent())


func try_sample_play_reset(pressed: bool) -> bool:
	if not sampler.try_rising(pressed, "reset", _is_playing(), chrome.is_visible()):
		return false
	return try_apply_play_intent(play.reset_intent())


func try_sample_play_jump(pressed: bool) -> bool:
	if not sampler.try_rising(pressed, "jump", _is_playing(), chrome.is_visible()):
		return false
	play.copy_jump_stubs(self)
	return try_apply_play_intent(play.jump_intent())


func allows_settlement() -> bool:
	return false


func allows_online_writes() -> bool:
	return false


func status_view() -> Dictionary:
	return HudGd.build_view(preview, map, is_window_visible())


func status_label_text() -> String:
	return chrome.status_text()


func _apply_play_anim() -> void:
	view.apply_play_anim(self)


func _process(_delta: float) -> void:
	if _play_view_busy:
		return
	if not _is_playing() or not chrome.is_visible():
		return
	sampler.drive_keyboard(self)
	_apply_play_anim()


func _ensure_window() -> void:
	if chrome.is_alive() and view.map_alive():
		window = chrome.window
		map = view.map
		return
	if not chrome.is_alive():
		window = null
		map = null
		view.clear()
		window = chrome.attach(self, {
			"play": _on_play,
			"stop": _on_stop,
			"reset": _on_reset,
			"use_item": _on_use_item,
			"sprint": _on_sprint,
			"jump": _on_jump,
			"advance": _on_advance_tick,
			"close": _on_close_requested,
		})
		add_child(window)
	else:
		window = chrome.window
	map = view.mount(window)
	if map != null:
		map.ensure_rig()
	chrome.release_focus()


func _on_close_requested() -> void:
	hide_window()


func _on_play() -> void:
	try_start_play()


func _on_stop() -> void:
	try_stop_play()


func _on_reset() -> void:
	try_apply_play_intent(play.reset_intent())


func _on_use_item() -> void:
	play.copy_use_item_stubs(self)
	try_apply_play_intent(play.use_item_intent())


func _on_sprint() -> void:
	play.copy_sprint_stubs(self)
	try_apply_play_intent(play.sprint_intent())


func _on_jump() -> void:
	play.copy_jump_stubs(self)
	try_apply_play_intent(play.jump_intent())


func _on_advance_tick() -> void:
	try_advance_play()


func _rebuild_map() -> void:
	view.rebuild(self)
	if view.map_alive():
		map = view.map


func _refresh_status() -> void:
	chrome.set_status_text(HudGd.format_line(preview, map))


func _is_playing() -> bool:
	return preview != null and preview.is_playing()


func _run_play_verb(verb: Callable) -> bool:
	_play_view_busy = true
	var ok: bool = verb.call()
	_rebuild_map()
	_refresh_status()
	_play_view_busy = false
	return ok
