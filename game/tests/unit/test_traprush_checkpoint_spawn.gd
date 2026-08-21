extends GutTest

## TraprushCheckpointSpawn：复活落点由调用方表 + track.reset_pose_index 决定。
## CD-21 §6：环境失败后回最近检查点；尚未完成任何点则回起点。不发明复活硬直或默认图。
## ResetToCheckpointIntent 只认名字，不接受客户端坐标。

const CheckpointSpawn := preload("res://src/games/traprush/checkpoint_spawn.gd")
const Track := preload("res://src/games/traprush/checkpoint_track.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const ONE_METER_Q48_16: int = 65536
const QUARTER_TURN_BAM: int = 16384


func test_uncompleted_track_returns_start_pose() -> void:
	var spawn: CheckpointSpawn = _two_checkpoint_spawn()
	var track: Track = Track.new(PackedInt32Array([10, 20]))
	var pose: Dictionary = spawn.pose_for(track)
	assert_true(_ok(pose))
	assert_eq(_int_field(pose, "x"), 0)
	assert_eq(_int_field(pose, "y"), ONE_METER_Q48_16)
	assert_eq(_int_field(pose, "z"), 0)
	assert_eq(_int_field(pose, "yaw_bam"), 0)


func test_pose_for_uses_reset_pose_index_into_caller_table() -> void:
	var spawn: CheckpointSpawn = _two_checkpoint_spawn()
	var track: Track = Track.new(PackedInt32Array([10, 20]))
	assert_true(track.try_accept(10))
	var first: Dictionary = spawn.pose_for(track)
	assert_true(_ok(first))
	assert_eq(_int_field(first, "x"), ONE_METER_Q48_16)
	assert_eq(_int_field(first, "y"), 0)
	assert_eq(_int_field(first, "z"), 2 * ONE_METER_Q48_16)
	assert_eq(_int_field(first, "yaw_bam"), QUARTER_TURN_BAM)
	assert_true(track.try_accept(20))
	var second: Dictionary = spawn.pose_for(track)
	assert_true(_ok(second))
	assert_eq(_int_field(second, "x"), 3 * ONE_METER_Q48_16)
	assert_eq(_int_field(second, "z"), 4 * ONE_METER_Q48_16)
	assert_eq(_int_field(second, "yaw_bam"), 0)


func test_out_of_range_index_fails_instead_of_inventing_a_pose() -> void:
	var start: Dictionary = {"x": 1, "y": 2, "z": 3, "yaw_bam": 4}
	var only_one: Array[Dictionary] = [
		{"x": 10, "y": 11, "z": 12, "yaw_bam": 13},
	]
	var spawn: CheckpointSpawn = CheckpointSpawn.new(start, only_one)
	var track: Track = Track.new(PackedInt32Array([10, 20]))
	assert_true(track.try_accept(10))
	assert_true(_ok(spawn.pose_for(track)))
	assert_true(track.try_accept(20))
	assert_eq(track.reset_pose_index(), 1)
	assert_false(_ok(spawn.pose_for(track)))


func test_empty_pose_table_still_returns_start_when_index_is_minus_one() -> void:
	var start: Dictionary = {"x": 7, "y": 8, "z": 9, "yaw_bam": 10}
	var spawn: CheckpointSpawn = CheckpointSpawn.new(start, [])
	var track: Track = Track.new(PackedInt32Array([10]))
	var at_start: Dictionary = spawn.pose_for(track)
	assert_true(_ok(at_start))
	assert_eq(_int_field(at_start, "x"), 7)
	assert_true(track.try_accept(10))
	assert_false(_ok(spawn.pose_for(track)))


func test_is_reset_intent_only_accepts_reset_to_checkpoint_name() -> void:
	assert_true(CheckpointSpawn.is_reset_intent({
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
	}))
	assert_true(CheckpointSpawn.is_reset_intent({
		"intent": "ResetToCheckpointIntent",
	}))
	assert_false(CheckpointSpawn.is_reset_intent({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
		"dz": 1,
	}))
	assert_false(CheckpointSpawn.is_reset_intent({}))
	assert_false(CheckpointSpawn.is_reset_intent({"intent": 1}))


func test_reset_intent_does_not_take_client_coordinates() -> void:
	var payload: Dictionary = {
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
		"x": 123456,
		"y": 654321,
		"z": 111,
		"yaw_bam": 99,
	}
	assert_true(CheckpointSpawn.is_reset_intent(payload))
	var spawn: CheckpointSpawn = _two_checkpoint_spawn()
	var track: Track = Track.new(PackedInt32Array([10, 20]))
	var pose: Dictionary = spawn.pose_for(track)
	assert_true(_ok(pose))
	assert_eq(_int_field(pose, "x"), 0)
	assert_eq(_int_field(pose, "y"), ONE_METER_Q48_16)
	assert_eq(_int_field(pose, "z"), 0)
	assert_ne(_int_field(pose, "x"), 123456)
	assert_false(pose.has("intent"))


func test_constructor_does_not_invent_a_default_course() -> void:
	var start: Dictionary = {"x": 0, "y": 0, "z": 0, "yaw_bam": 0}
	var spawn: CheckpointSpawn = CheckpointSpawn.new(start, [])
	var empty_track: Track = Track.new(PackedInt32Array())
	var pose: Dictionary = spawn.pose_for(empty_track)
	assert_true(_ok(pose))
	assert_eq(_int_field(pose, "x"), 0)
	assert_eq(_int_field(pose, "yaw_bam"), 0)


func _two_checkpoint_spawn() -> CheckpointSpawn:
	var start: Dictionary = {
		"x": 0,
		"y": ONE_METER_Q48_16,
		"z": 0,
		"yaw_bam": 0,
	}
	var poses: Array[Dictionary] = [
		{
			"x": ONE_METER_Q48_16,
			"y": 0,
			"z": 2 * ONE_METER_Q48_16,
			"yaw_bam": QUARTER_TURN_BAM,
		},
		{
			"x": 3 * ONE_METER_Q48_16,
			"y": 0,
			"z": 4 * ONE_METER_Q48_16,
			"yaw_bam": 0,
		},
	]
	return CheckpointSpawn.new(start, poses)


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _int_field(result: Dictionary, key: String) -> int:
	var value: int = result.get(key, 0)
	return value
