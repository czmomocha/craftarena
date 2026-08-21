extends GutTest

## 命令信封：CD-42 公共字段 + PLAYER Intent 白名单 + 非权威类型拒绝。

const SharedCommand := preload("res://src/shared/commands/shared_command.gd")
const StateHasher := preload("res://src/shared/protocol/state_hasher.gd")


func test_valid_player_move_command_is_accepted() -> void:
	var command: SharedCommand = _player_move(1, 9)
	assert_not_null(command)
	assert_eq(command.command_id, 1)
	assert_eq(command.actor_id, 9)
	assert_eq(command.kind, SharedCommand.Kind.PLAYER)
	var stored_intent: String = command.payload.get("intent", "")
	assert_eq(stored_intent, "MoveIntent")


func test_player_command_requires_known_intent() -> void:
	var command: SharedCommand = SharedCommand.create(
		1, 9, 1, 0, 0, "content-v1", {"intent": "FakeIntent"}, "trace-1", SharedCommand.Kind.PLAYER
	)
	assert_null(command)


func test_player_command_requires_intent_field() -> void:
	var command: SharedCommand = SharedCommand.create(
		1, 9, 1, 0, 0, "content-v1", {"dx": 1}, "trace-1", SharedCommand.Kind.PLAYER
	)
	assert_null(command)


func test_invalid_ids_and_sequence_are_rejected() -> void:
	assert_null(_create_player({"intent": "MoveIntent"}, 0, 9, 1))
	assert_null(_create_player({"intent": "MoveIntent"}, 1, 0, 1))
	assert_null(_create_player({"intent": "MoveIntent"}, 1, 9, 0))


func test_system_command_may_omit_actor() -> void:
	var command: SharedCommand = SharedCommand.create(
		7, 0, 1, 0, 0, "content-v1", {"reason": "tick"}, "trace-sys", SharedCommand.Kind.SYSTEM
	)
	assert_not_null(command)
	assert_eq(command.actor_id, 0)


func test_payload_float_is_rejected() -> void:
	assert_null(_create_player({"intent": "MoveIntent", "dx": 0.5}, 1, 9, 1))


func test_empty_trace_or_content_version_is_rejected() -> void:
	assert_null(SharedCommand.create(
		1, 9, 1, 0, 0, "", {"intent": "MoveIntent"}, "trace-1", SharedCommand.Kind.PLAYER
	))
	assert_null(SharedCommand.create(
		1, 9, 1, 0, 0, "content-v1", {"intent": "MoveIntent"}, "", SharedCommand.Kind.PLAYER
	))


func test_duplicate_payload_is_decoupled_from_caller() -> void:
	var payload: Dictionary = {"intent": "MoveIntent", "dx": 1}
	var command: SharedCommand = _create_player(payload, 1, 9, 1)
	payload["dx"] = 99
	var stored_dx: int = command.payload.get("dx", 0)
	assert_eq(stored_dx, 1)


func test_feed_hasher_is_stable() -> void:
	var left: StateHasher = StateHasher.new()
	var right: StateHasher = StateHasher.new()
	_player_move(1, 9).feed_hasher(left)
	_player_move(1, 9).feed_hasher(right)
	assert_eq(left.digest_hex(), right.digest_hex())
	assert_eq(left.digest_hex().length(), 64)


func _player_move(command_id: int, actor_id: int) -> SharedCommand:
	return _create_player({"intent": "MoveIntent", "dx": 1, "dz": 0}, command_id, actor_id, 1)


func _create_player(payload: Dictionary, command_id: int, actor_id: int, sequence: int) -> SharedCommand:
	return SharedCommand.create(
		command_id,
		actor_id,
		sequence,
		0,
		0,
		"content-v1",
		payload,
		"trace-1",
		SharedCommand.Kind.PLAYER
	)
