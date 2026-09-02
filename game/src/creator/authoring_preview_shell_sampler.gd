class_name AuthoringPreviewShellSampler
extends RefCounted

## Preview input: PlayInput snapshot plus shell-side held flags.
## Rising-edge try_sample_play_* stay on the facade so existing tests
## still poke the public API.

const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

var play_input: PlayInput = PlayInput.new()
var play_moving: bool = false
var reset_held: bool = false
var use_item_held: bool = false
var sprint_held: bool = false
var jump_held: bool = false


func reset_motion() -> void:
	play_moving = false
	play_input.reset_held()


func reset_held_flags() -> void:
	reset_held = false
	use_item_held = false
	sprint_held = false
	jump_held = false


func reset_all() -> void:
	reset_held_flags()
	reset_motion()


func drive_keyboard(shell: AuthoringPreviewShell) -> void:
	var events: Dictionary = play_input.sample_keyboard()
	shell.try_sample_play_vector(PlayInput.move_x_of(events), PlayInput.move_z_of(events))
	shell.try_sample_play_reset(PlayInput.flag_of(events, "reset"))
	shell.try_sample_play_use_item(PlayInput.flag_of(events, "use_item"))
	shell.try_sample_play_sprint(PlayInput.flag_of(events, "sprint"))
	shell.try_sample_play_jump(PlayInput.flag_of(events, "jump"))


static func move_payload_from_vector(move_x: float, move_z: float, step: int) -> Dictionary:
	var axes: Vector2i = PlayInput.step_from_vector(move_x, move_z, step)
	if axes == Vector2i.ZERO:
		return {}
	return {
		"intent": PlayerIntentNames.MOVE,
		"dx": axes.x,
		"dz": axes.y,
	}


static func move_payload_from_axes(
	forward: bool,
	back: bool,
	left: bool,
	right: bool,
	step: int
) -> Dictionary:
	var vector: Vector2 = PlayInput.vector_from_axes(forward, back, left, right)
	return move_payload_from_vector(vector.x, vector.y, step)


func note_move_vector(move_x: float, move_z: float) -> void:
	play_moving = absf(move_x) > PlayInput.IDLE or absf(move_z) > PlayInput.IDLE


func try_vector(move_x: float, move_z: float, step: int, playing: bool, visible: bool) -> Dictionary:
	note_move_vector(move_x, move_z)
	if not playing or not visible:
		return {}
	return move_payload_from_vector(move_x, move_z, step)


func try_rising(pressed: bool, held_name: String, playing: bool, visible: bool) -> bool:
	var held: bool = _held(held_name)
	if not playing or not visible:
		_set_held(held_name, pressed)
		return false
	var rising: bool = pressed and not held
	_set_held(held_name, pressed)
	return rising


func _held(held_name: String) -> bool:
	match held_name:
		"reset":
			return reset_held
		"use_item":
			return use_item_held
		"sprint":
			return sprint_held
		"jump":
			return jump_held
		_:
			return false


func _set_held(held_name: String, pressed: bool) -> void:
	match held_name:
		"reset":
			reset_held = pressed
		"use_item":
			use_item_held = pressed
		"sprint":
			sprint_held = pressed
		"jump":
			jump_held = pressed
