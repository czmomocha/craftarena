extends GutTest

## SimReplayBuffer：CD-43 命令日志 + 种子磁带。本类型不应用意图，只校验追加与稳定哈希。

const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const SimReplayBuffer := preload("res://src/simulation/replay_buffer.gd")


func test_default_seed_is_one() -> void:
	var tape: SimReplayBuffer = SimReplayBuffer.new()
	assert_eq(tape.get_seed(), 1)
	assert_eq(tape.size(), 0)


func test_init_stores_seed() -> void:
	var tape: SimReplayBuffer = SimReplayBuffer.new(42)
	assert_eq(tape.get_seed(), 42)


func test_null_command_is_rejected() -> void:
	var tape: SimReplayBuffer = SimReplayBuffer.new(1)
	var missing: SharedCommand = null
	assert_false(tape.append(missing))
	assert_eq(tape.size(), 0)
	assert_null(tape.command_at(0))


func test_append_increments_size_and_roundtrips() -> void:
	var tape: SimReplayBuffer = SimReplayBuffer.new(1)
	var first: SharedCommand = _player_move(1, 1, 1)
	var second: SharedCommand = _player_move(2, 2, 1)
	assert_true(tape.append(first))
	assert_eq(tape.size(), 1)
	assert_eq(tape.command_at(0), first)
	assert_true(tape.append(second))
	assert_eq(tape.size(), 2)
	assert_eq(tape.command_at(1), second)


func test_empty_tape_accepts_any_sequence_at_least_one() -> void:
	var tape: SimReplayBuffer = SimReplayBuffer.new(1)
	var first: SharedCommand = _player_move(1, 5, 1)
	assert_true(tape.append(first))
	assert_eq(tape.size(), 1)
	assert_true(tape.append(_player_move(2, 6, 1)))
	assert_eq(tape.size(), 2)


func test_non_increasing_sequence_is_rejected() -> void:
	var tape: SimReplayBuffer = SimReplayBuffer.new(1)
	var first: SharedCommand = _player_move(1, 1, 1)
	assert_true(tape.append(first))
	assert_false(tape.append(_player_move(2, 1, 1)))
	assert_false(tape.append(_player_move(3, 3, 1)))
	assert_eq(tape.size(), 1)
	assert_eq(tape.command_at(0), first)


func test_command_at_out_of_bounds_is_null() -> void:
	var tape: SimReplayBuffer = SimReplayBuffer.new(1)
	assert_null(tape.command_at(0))
	assert_null(tape.command_at(-1))
	assert_true(tape.append(_player_move(1, 1, 1)))
	assert_null(tape.command_at(1))
	assert_null(tape.command_at(-1))
	assert_null(tape.command_at(99))


func test_identical_tapes_hash_stably() -> void:
	var left: SimReplayBuffer = _filled_tape(1, 1)
	var right: SimReplayBuffer = _filled_tape(1, 1)
	var left_hex: String = left.hash_tape().hex_encode()
	var right_hex: String = right.hash_tape().hex_encode()
	assert_eq(left_hex, right_hex)
	assert_eq(left.hash_tape().hex_encode(), left_hex)
	assert_eq(left_hex.length(), 64)


func test_different_seeds_hash_differently() -> void:
	var left: SimReplayBuffer = _filled_tape(1, 1)
	var right: SimReplayBuffer = _filled_tape(2, 1)
	assert_ne(left.hash_tape().hex_encode(), right.hash_tape().hex_encode())
	var empty_left: SimReplayBuffer = SimReplayBuffer.new(1)
	var empty_right: SimReplayBuffer = SimReplayBuffer.new(2)
	assert_ne(empty_left.hash_tape().hex_encode(), empty_right.hash_tape().hex_encode())


func test_payload_change_changes_tape_hash() -> void:
	var left: SimReplayBuffer = _filled_tape(1, 1)
	var right: SimReplayBuffer = _filled_tape(1, 2)
	assert_ne(left.hash_tape().hex_encode(), right.hash_tape().hex_encode())


func _filled_tape(p_seed: int, dx: int) -> SimReplayBuffer:
	var tape: SimReplayBuffer = SimReplayBuffer.new(p_seed)
	assert_true(tape.append(_player_move(1, 1, dx)))
	assert_true(tape.append(_player_move(2, 2, dx)))
	return tape


func _player_move(command_id: int, sequence: int, dx: int) -> SharedCommand:
	return SharedCommand.create(
		command_id,
		9,
		sequence,
		0,
		0,
		"content-v1",
		{"intent": "MoveIntent", "dx": dx, "dz": 0},
		"trace-1",
		SharedCommand.Kind.PLAYER
	)
