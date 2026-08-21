extends GutTest

## TraprushMoveIntent：只解码 PLAYER MoveIntent 的 Q48.16 位移，不发明默认速度。
## CD-21 §8：客户端只发意图，不得发送最终位置。本刀不调用 SimulationWorld.try_move_xz。

const MoveIntent := preload("res://src/games/traprush/move_intent.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")

const ONE_METER_Q48_16: int = 65536


func test_decode_requires_move_intent_name_from_player_intent_names() -> void:
	var decoded: Dictionary = MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": ONE_METER_Q48_16,
		"dz": -ONE_METER_Q48_16,
	})
	assert_true(_ok(decoded))
	assert_eq(_int_field(decoded, "dx"), ONE_METER_Q48_16)
	assert_eq(_int_field(decoded, "dz"), -ONE_METER_Q48_16)


func test_wrong_or_missing_intent_is_rejected() -> void:
	assert_false(_ok(MoveIntent.decode({
		"intent": PlayerIntentNames.JUMP,
		"dx": 1,
		"dz": 1,
	})))
	assert_false(_ok(MoveIntent.decode({
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
		"dx": 1,
		"dz": 1,
	})))
	assert_false(_ok(MoveIntent.decode({"dx": 1, "dz": 1})))
	assert_false(_ok(MoveIntent.decode({})))
	assert_false(_ok(MoveIntent.decode({"intent": 1, "dx": 1, "dz": 1})))


func test_string_move_intent_literal_matches_preloaded_const() -> void:
	var decoded: Dictionary = MoveIntent.decode({
		"intent": "MoveIntent",
		"dx": 0,
		"dz": 0,
	})
	assert_true(_ok(decoded))
	assert_eq(PlayerIntentNames.MOVE, "MoveIntent")


func test_missing_or_non_int_displacement_is_rejected_without_default_speed() -> void:
	assert_false(_ok(MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dz": 1,
	})))
	assert_false(_ok(MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
	})))
	assert_false(_ok(MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 0.5,
		"dz": 1,
	})))
	assert_false(_ok(MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
		"dz": 0.25,
	})))
	assert_false(_ok(MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": "1",
		"dz": 1,
	})))


func test_zero_displacement_is_valid_and_not_replaced_by_a_speed() -> void:
	var decoded: Dictionary = MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 0,
		"dz": 0,
	})
	assert_true(_ok(decoded))
	assert_eq(_int_field(decoded, "dx"), 0)
	assert_eq(_int_field(decoded, "dz"), 0)
	assert_false(decoded.has("speed"))


func test_omitted_yaw_bam_uses_minus_one_sentinel() -> void:
	var decoded: Dictionary = MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 8,
		"dz": 16,
	})
	assert_true(_ok(decoded))
	assert_eq(_int_field(decoded, "yaw_bam"), -1)


func test_present_int_yaw_bam_is_kept_including_zero() -> void:
	var decoded: Dictionary = MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
		"dz": 2,
		"yaw_bam": 0,
	})
	assert_true(_ok(decoded))
	assert_eq(_int_field(decoded, "yaw_bam"), 0)
	var turned: Dictionary = MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
		"dz": 2,
		"yaw_bam": 16384,
	})
	assert_true(_ok(turned))
	assert_eq(_int_field(turned, "yaw_bam"), 16384)


func test_non_int_yaw_bam_is_rejected() -> void:
	assert_false(_ok(MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
		"dz": 2,
		"yaw_bam": 1.5,
	})))


func test_client_final_position_fields_are_not_decoded_as_destination() -> void:
	var decoded: Dictionary = MoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 4,
		"dz": 5,
		"x": 999,
		"y": 888,
		"z": 777,
	})
	assert_true(_ok(decoded))
	assert_eq(_int_field(decoded, "dx"), 4)
	assert_eq(_int_field(decoded, "dz"), 5)
	assert_false(decoded.has("x"))
	assert_false(decoded.has("y"))
	assert_false(decoded.has("z"))


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag


func _int_field(result: Dictionary, key: String) -> int:
	var value: int = result.get(key, 0)
	return value
