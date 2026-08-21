extends GutTest

## TraprushJumpIntent：只解码 PLAYER JumpIntent 名字，不发明跳跃高度或重力。
## CD-21 §8：客户端只发意图，不得发送最终位置。跳跃数值见 CD-63，本刀不锁定。
## 本刀不调用 SimulationWorld。

const JumpIntent := preload("res://src/games/traprush/jump_intent.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")


func test_decode_requires_jump_intent_name_from_player_intent_names() -> void:
	var decoded: Dictionary = JumpIntent.decode({
		"intent": PlayerIntentNames.JUMP,
	})
	assert_true(_ok(decoded))
	assert_eq(decoded.size(), 1)


func test_zero_field_button_intent_is_valid() -> void:
	var decoded: Dictionary = JumpIntent.decode({"intent": "JumpIntent"})
	assert_true(_ok(decoded))
	assert_eq(PlayerIntentNames.JUMP, "JumpIntent")
	assert_false(decoded.has("dy"))
	assert_false(decoded.has("height"))
	assert_false(decoded.has("speed"))
	assert_false(decoded.has("y"))


func test_wrong_or_missing_intent_is_rejected() -> void:
	assert_false(_ok(JumpIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
		"dz": 1,
	})))
	assert_false(_ok(JumpIntent.decode({
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
	})))
	assert_false(_ok(JumpIntent.decode({
		"intent": PlayerIntentNames.SHOVE,
	})))
	assert_false(_ok(JumpIntent.decode({"dy": 1})))
	assert_false(_ok(JumpIntent.decode({})))
	assert_false(_ok(JumpIntent.decode({"intent": 1})))


func test_client_final_position_and_jump_metrics_are_not_decoded() -> void:
	var decoded: Dictionary = JumpIntent.decode({
		"intent": PlayerIntentNames.JUMP,
		"x": 999,
		"y": 888,
		"z": 777,
		"dy": 123,
		"height": 64,
		"speed": 10,
	})
	assert_true(_ok(decoded))
	assert_false(decoded.has("x"))
	assert_false(decoded.has("y"))
	assert_false(decoded.has("z"))
	assert_false(decoded.has("dy"))
	assert_false(decoded.has("height"))
	assert_false(decoded.has("speed"))


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag
