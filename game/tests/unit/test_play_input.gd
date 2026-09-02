extends GutTest

## PlayInput: direction vector + rising-edge actions. Keyboard booleans and
## analog sticks produce the same snapshot. Sign-quantize to a whole step;
## analog magnitude does not enter MoveIntent. Not a product deadzone,
## turn speed, or touch UI.

const PlayInputGd := preload("res://src/shared/play_input.gd")
const MatchMoveFacing := preload("res://src/client/match_move_facing.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const STEP: int = 16
const EPS: float = 0.0001


func test_wasd_axes_match_world_xz() -> void:
	var forward: Vector2 = PlayInputGd.vector_from_axes(true, false, false, false)
	var right: Vector2 = PlayInputGd.vector_from_axes(false, false, false, true)
	var back_left: Vector2 = PlayInputGd.vector_from_axes(false, true, true, false)
	var cancelled: Vector2 = PlayInputGd.vector_from_axes(true, true, false, false)
	assert_almost_eq(forward.x, 0.0, EPS)
	assert_almost_eq(forward.y, -1.0, EPS)
	assert_almost_eq(right.x, 1.0, EPS)
	assert_almost_eq(right.y, 0.0, EPS)
	assert_almost_eq(back_left.x, -1.0, EPS)
	assert_almost_eq(back_left.y, 1.0, EPS)
	assert_almost_eq(cancelled.x, 0.0, EPS)
	assert_almost_eq(cancelled.y, 0.0, EPS)


func test_stick_clamps_and_keeps_axes() -> void:
	var over: Vector2 = PlayInputGd.vector_from_stick(2.0, -3.0)
	var under: Vector2 = PlayInputGd.vector_from_stick(-2.0, 0.4)
	assert_almost_eq(over.x, 1.0, EPS)
	assert_almost_eq(over.y, -1.0, EPS)
	assert_almost_eq(under.x, -1.0, EPS)
	assert_almost_eq(under.y, 0.4, EPS)


func test_sign_quantize_ignores_analog_magnitude() -> void:
	var full: Vector2i = PlayInputGd.step_from_vector(1.0, 0.0, STEP)
	var weak: Vector2i = PlayInputGd.step_from_vector(0.3, 0.0, STEP)
	var idle: Vector2i = PlayInputGd.step_from_vector(0.0, 0.0, STEP)
	var no_step: Vector2i = PlayInputGd.step_from_vector(1.0, 0.0, 0)
	assert_eq(full, Vector2i(STEP, 0))
	assert_eq(weak, Vector2i(STEP, 0))
	assert_eq(idle, Vector2i.ZERO)
	assert_eq(no_step, Vector2i.ZERO)


func test_vector_path_matches_boolean_move_axes() -> void:
	_assert_vector_matches_axes(true, false, false, false)
	_assert_vector_matches_axes(false, false, false, true)
	_assert_vector_matches_axes(true, false, false, true)
	_assert_vector_matches_axes(true, true, false, false)


func _assert_vector_matches_axes(forward: bool, back: bool, left: bool, right: bool) -> void:
	var from_bool: Dictionary = MatchMoveFacing.move_axes(forward, back, left, right, STEP)
	var vector: Vector2 = PlayInputGd.vector_from_axes(forward, back, left, right)
	var from_vector: Dictionary = MatchMoveFacing.move_vector(vector.x, vector.y, STEP)
	assert_eq(from_vector, from_bool)


func test_consume_emits_rising_edges_only() -> void:
	var sampler: PlayInputGd = PlayInputGd.new()
	var held: Dictionary = PlayInputGd.empty_held()
	held["jump"] = true
	held["shove"] = true
	held["use_item"] = true
	held["sprint"] = true
	held["reset"] = true
	var first: Dictionary = sampler.consume(held)
	var second: Dictionary = sampler.consume(held)
	assert_true(PlayInputGd.flag_of(first, "jump"))
	assert_true(PlayInputGd.flag_of(first, "shove"))
	assert_true(PlayInputGd.flag_of(first, "use_item"))
	assert_true(PlayInputGd.flag_of(first, "sprint"))
	assert_true(PlayInputGd.flag_of(first, "reset"))
	assert_false(PlayInputGd.flag_of(second, "jump"))
	assert_false(PlayInputGd.flag_of(second, "shove"))
	assert_false(PlayInputGd.flag_of(second, "use_item"))
	assert_false(PlayInputGd.flag_of(second, "sprint"))
	assert_false(PlayInputGd.flag_of(second, "reset"))
	held["jump"] = false
	sampler.consume(held)
	held["jump"] = true
	var again: Dictionary = sampler.consume(held)
	assert_true(PlayInputGd.flag_of(again, "jump"))


func test_reset_held_allows_another_rising_edge() -> void:
	var sampler: PlayInputGd = PlayInputGd.new()
	var held: Dictionary = PlayInputGd.empty_held()
	held["sprint"] = true
	assert_true(PlayInputGd.flag_of(sampler.consume(held), "sprint"))
	assert_false(PlayInputGd.flag_of(sampler.consume(held), "sprint"))
	sampler.reset_held()
	assert_true(PlayInputGd.flag_of(sampler.consume(held), "sprint"))


func test_move_vector_writes_yaw_and_cancel_is_empty() -> void:
	var forward: Dictionary = MatchMoveFacing.move_vector(0.0, -1.0, STEP)
	var weak_right: Dictionary = MatchMoveFacing.move_vector(0.2, 0.0, STEP)
	var cancelled: Dictionary = MatchMoveFacing.move_vector(0.0, 0.0, STEP)
	var forward_intent: String = forward.get("intent", "")
	var forward_dx: int = forward.get("dx", -1)
	var forward_dz: int = forward.get("dz", 0)
	var forward_yaw: int = forward.get("yaw_bam", -2)
	var weak_dx: int = weak_right.get("dx", 0)
	var weak_yaw: int = weak_right.get("yaw_bam", -2)
	assert_eq(forward_intent, PlayerIntentNames.MOVE)
	assert_eq(forward_dx, 0)
	assert_eq(forward_dz, -STEP)
	assert_eq(forward_yaw, MatchMoveFacing.YAW_FORWARD)
	assert_eq(weak_dx, STEP)
	assert_eq(weak_yaw, MatchMoveFacing.YAW_RIGHT)
	assert_true(cancelled.is_empty())


func test_keyboard_held_snapshot_has_play_actions() -> void:
	var held: Dictionary = PlayInputGd.read_keyboard_held()
	assert_true(held.has("move_x"))
	assert_true(held.has("move_z"))
	assert_true(held.has("jump"))
	assert_true(held.has("shove"))
	assert_true(held.has("use_item"))
	assert_true(held.has("sprint"))
	assert_true(held.has("reset"))
	assert_almost_eq(PlayInputGd.move_x_of(held), 0.0, EPS)
	assert_almost_eq(PlayInputGd.move_z_of(held), 0.0, EPS)
	assert_false(PlayInputGd.flag_of(held, "jump"))
	assert_false(PlayInputGd.flag_of(held, "shove"))
	assert_true(InputMap.has_action(PlayInputGd.ACTION_SHOVE))
	assert_true(InputMap.has_action(PlayInputGd.ACTION_SPRINT))
	assert_true(InputMap.has_action(PlayInputGd.ACTION_RESET))
