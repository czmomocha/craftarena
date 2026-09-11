class_name AuthoringPreviewShell
extends Node

## Independent Preview window host (CD-32 §4). Facade + chrome/sampler/hud/play/view/audio.

const OutOfRangeReset := preload("res://src/games/traprush/out_of_range_reset.gd")
const PlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const ChromeGd := preload("res://src/creator/authoring_preview_shell_chrome.gd")
const HudGd := preload("res://src/creator/authoring_preview_shell_hud.gd")
const PlayGd := preload("res://src/creator/authoring_preview_shell_play.gd")
const SamplerGd := preload("res://src/creator/authoring_preview_shell_sampler.gd")
const ViewGd := preload("res://src/creator/authoring_preview_shell_view.gd")
const AudioGd := preload("res://src/creator/authoring_preview_shell_audio.gd")
const PlayClockGd := preload("res://src/shared/play_clock.gd")
const PlaySplitTrackerGd := preload("res://src/shared/play_split_tracker.gd")

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
var play_conveyor_step: int = PlayStubs.CONVEYOR_STEP
var play_ice_step: int = PlayStubs.ICE_STEP
var play_launch_dy: int = PlayStubs.LAUNCH_DY
var play_launch_xz: int = PlayStubs.LAUNCH_XZ
## 手动 Advance 时 1 拍就过（点 60 下不是调试）；自动推进时用对局那 1.0 s。
## `set_auto_tick` 在两者之间切换，见该函数注释。
var play_respawn_stun_ticks: int = PlayStubs.RESPAWN_STUN_TICKS
## 连续试玩（可玩性深化 轨 3：改完立刻试）。默认开。
var play_auto_tick: bool = true
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
var audio: AudioGd = AudioGd.new()
var split_tracker: PlaySplitTrackerGd = PlaySplitTrackerGd.new()
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
	var ok: bool = _run_play_verb(
		func() -> bool: return preview.try_start_play(seed, radius, cylinder_height)
	)
	if ok:
		chrome.focus_window()
	return ok


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


## 连续试玩开关（可玩性深化 轨 3）。
##
## 此前 Preview 只在点「Advance tick」时推进一拍：创作者摆完一段路，要走过去
## 看看，得点几百下。对拿到链接的外人来说那不是试玩。打开后仿真按引擎 physics
## 连续跑，与 Solo 同一节奏。
##
## 硬直随着一起换：手动单步时 1 拍就过（否则一次机关命中要多点 60 下），
## 连续跑时用对局那 1.0 s（D5），否则「改完立刻试」试到的惩罚不是真的那一个。
func set_auto_tick(on: bool) -> void:
	play_auto_tick = on
	play_respawn_stun_ticks = (
		PlayStubs.RESPAWN_STUN_TICKS if on else PlayStubs.PREVIEW_RESPAWN_STUN_TICKS
	)
	play.copy_hazard_hit_stubs(self)


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
	audio.note_intent(payload)
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


func clock_label_text() -> String:
	return chrome.clock_text()


func settlement_panel_visible() -> bool:
	return chrome.settlement_visible()


func _apply_play_anim() -> void:
	view.apply_play_anim(self)


func _process(_delta: float) -> void:
	if _play_view_busy:
		return
	if not _is_playing() or not chrome.is_visible():
		return
	sampler.drive_keyboard(self)
	_apply_play_anim()


## 连续试玩跟 physics 走，与 Solo 同一时钟；输入仍在 `_process` 按帧采样。
func _physics_process(_delta: float) -> void:
	if not play_auto_tick or _play_view_busy:
		return
	if not _is_playing() or not chrome.is_visible():
		return
	try_advance_play()


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
			"auto_tick": set_auto_tick,
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
	var hud_view: Dictionary = HudGd.build_view(preview, map, chrome.is_visible())
	var accepted: int = PlayClockGd.dict_int(hud_view, "accepted_count", -1)
	var play_tick: int = PlayClockGd.dict_int(hud_view, "play_tick", -1)
	var finish_tick: int = PlayClockGd.dict_int(hud_view, "finish_tick", -1)
	if not _is_playing():
		split_tracker.reset()
	else:
		split_tracker.observe(accepted, PlayClockGd.clock_tick(play_tick, finish_tick))
	hud_view["play_hud_active"] = _is_playing()
	hud_view["clock_tick"] = PlayClockGd.clock_tick(play_tick, finish_tick)
	hud_view["split_line"] = split_tracker.popup_line()
	if finish_tick >= 0:
		hud_view["settlement_board"] = {
			"ok": true,
			"mvp_slot": 0,
			"pad_total": PlayClockGd.dict_int(hud_view, "checkpoint_count", 0),
			"rows": [{
				"place": 1,
				"slot": 0,
				"finish_tick": finish_tick,
				"accepted_count": accepted,
			}],
		}
	else:
		hud_view["settlement_board"] = {"ok": false}
	chrome.set_status_text(HudGd.format_line(preview, map))
	chrome.sync_play_hud(hud_view)


func _is_playing() -> bool:
	return preview != null and preview.is_playing()


func _run_play_verb(verb: Callable) -> bool:
	_play_view_busy = true
	var ok: bool = verb.call()
	_rebuild_map()
	_refresh_status()
	audio.pump(self)
	_play_view_busy = false
	return ok
