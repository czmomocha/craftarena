class_name MatchLobbySampler
extends RefCounted

## L4 input: rising-edge play intents for the lobby. Keyboard sampling is
## PlayInput; this type only tracks the shell-side held flags that tests
## still poke via try_sample_play_*.

const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

var play_moving: bool = false
var reset_held: bool = false
var use_item_held: bool = false
var jump_held: bool = false
var shove_held: bool = false
var sprint_held: bool = false


func drive_keyboard(shell: MatchLobbyShell) -> void:
	var events: Dictionary = shell.play_input.sample_keyboard()
	shell.try_sample_play_vector(PlayInput.move_x_of(events), PlayInput.move_z_of(events))
	shell.try_sample_play_reset(PlayInput.flag_of(events, "reset"))
	shell.try_sample_play_use_item(PlayInput.flag_of(events, "use_item"))
	shell.try_sample_play_jump(PlayInput.flag_of(events, "jump"))
	shell.try_sample_play_shove(PlayInput.flag_of(events, "shove"))
	shell.try_sample_play_sprint(PlayInput.flag_of(events, "sprint"))


func reset_motion() -> void:
	play_moving = false


func try_vector(
	move_x: float,
	move_z: float,
	window_visible: bool,
	offline_playing: bool,
	offline: MatchOfflineSession,
	play: MatchPlaySession,
	play_move_step: int
) -> Dictionary:
	play_moving = absf(move_x) > PlayInput.IDLE or absf(move_z) > PlayInput.IDLE
	if not window_visible:
		return _empty_sample()
	if offline_playing:
		if offline == null:
			return _empty_sample()
		var offline_bytes: PackedByteArray = offline.try_encode_move_vector(
			move_x, move_z, play_move_step
		)
		return {"bytes": offline_bytes, "remap": not offline_bytes.is_empty(), "note": false}
	if play == null:
		return _empty_sample()
	var bytes: PackedByteArray = play.try_encode_move_vector(move_x, move_z, play_move_step)
	return {"bytes": bytes, "remap": not bytes.is_empty(), "note": true}


func try_axes(
	forward: bool,
	back: bool,
	left: bool,
	right: bool,
	window_visible: bool,
	offline_playing: bool,
	offline: MatchOfflineSession,
	play: MatchPlaySession,
	play_move_step: int
) -> Dictionary:
	var vector: Vector2 = PlayInput.vector_from_axes(forward, back, left, right)
	return try_vector(
		vector.x,
		vector.y,
		window_visible,
		offline_playing,
		offline,
		play,
		play_move_step
	)


func try_intent(
	intent_name: String,
	pressed: bool,
	held: bool,
	window_visible: bool,
	offline_playing: bool,
	offline: MatchOfflineSession,
	play: MatchPlaySession,
	remap_online: bool
) -> Dictionary:
	var rising: bool = pressed and not held
	if not rising or not window_visible:
		return {"bytes": PackedByteArray(), "remap": false, "note": false, "held": pressed}
	if offline_playing:
		if offline == null:
			return {"bytes": PackedByteArray(), "remap": false, "note": false, "held": pressed}
		var offline_bytes: PackedByteArray = offline.try_encode_intent(intent_name, 0, 0, 0)
		return {
			"bytes": offline_bytes,
			"remap": not offline_bytes.is_empty(),
			"note": false,
			"held": pressed,
		}
	if play == null:
		return {"bytes": PackedByteArray(), "remap": false, "note": false, "held": pressed}
	var bytes: PackedByteArray = play.try_encode_intent(intent_name, 0, 0, 0)
	return {
		"bytes": bytes,
		"remap": remap_online and not bytes.is_empty(),
		"note": true,
		"held": pressed,
	}


func try_reset(
	pressed: bool,
	window_visible: bool,
	offline_playing: bool,
	offline: MatchOfflineSession,
	play: MatchPlaySession
) -> Dictionary:
	var sample: Dictionary = try_intent(
		PlayerIntentNames.RESET_TO_CHECKPOINT,
		pressed,
		reset_held,
		window_visible,
		offline_playing,
		offline,
		play,
		false
	)
	reset_held = pressed
	return sample


func try_use_item(
	pressed: bool,
	window_visible: bool,
	offline_playing: bool,
	offline: MatchOfflineSession,
	play: MatchPlaySession
) -> Dictionary:
	var sample: Dictionary = try_intent(
		PlayerIntentNames.USE_ITEM,
		pressed,
		use_item_held,
		window_visible,
		offline_playing,
		offline,
		play,
		false
	)
	use_item_held = pressed
	return sample


func try_jump(
	pressed: bool,
	window_visible: bool,
	offline_playing: bool,
	offline: MatchOfflineSession,
	play: MatchPlaySession
) -> Dictionary:
	var sample: Dictionary = try_intent(
		PlayerIntentNames.JUMP,
		pressed,
		jump_held,
		window_visible,
		offline_playing,
		offline,
		play,
		true
	)
	jump_held = pressed
	return sample


func try_shove(
	pressed: bool,
	window_visible: bool,
	offline_playing: bool,
	offline: MatchOfflineSession,
	play: MatchPlaySession
) -> Dictionary:
	var sample: Dictionary = try_intent(
		PlayerIntentNames.SHOVE,
		pressed,
		shove_held,
		window_visible,
		offline_playing,
		offline,
		play,
		false
	)
	shove_held = pressed
	return sample


func try_sprint(
	pressed: bool,
	window_visible: bool,
	offline_playing: bool,
	offline: MatchOfflineSession,
	play: MatchPlaySession
) -> Dictionary:
	var sample: Dictionary = try_intent(
		PlayerIntentNames.SPRINT,
		pressed,
		sprint_held,
		window_visible,
		offline_playing,
		offline,
		play,
		false
	)
	sprint_held = pressed
	return sample


func _empty_sample() -> Dictionary:
	return {"bytes": PackedByteArray(), "remap": false, "note": false}
