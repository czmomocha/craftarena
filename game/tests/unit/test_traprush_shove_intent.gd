extends GutTest

## TraprushShoveIntent：只解码 PLAYER ShoveIntent 名字，不发明推击力度或击退向量。
## CD-21 §8：客户端只发意图，不得发送最终位置。推击力度与冷却见 CD-63，本刀不锁定。
## 本刀不调用 SimulationWorld，也不读取 TraprushShoveGate 的冷却秒数。

const ShoveIntent := preload("res://src/games/traprush/shove_intent.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")


func test_decode_requires_shove_intent_name_from_player_intent_names() -> void:
	var decoded: Dictionary = ShoveIntent.decode({
		"intent": PlayerIntentNames.SHOVE,
	})
	assert_true(_ok(decoded))
	assert_eq(decoded.size(), 1)


func test_zero_field_button_intent_is_valid() -> void:
	var decoded: Dictionary = ShoveIntent.decode({"intent": "ShoveIntent"})
	assert_true(_ok(decoded))
	assert_eq(PlayerIntentNames.SHOVE, "ShoveIntent")
	assert_false(decoded.has("impulse"))
	assert_false(decoded.has("force"))
	assert_false(decoded.has("dx"))
	assert_false(decoded.has("dz"))


func test_wrong_or_missing_intent_is_rejected() -> void:
	assert_false(_ok(ShoveIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
		"dz": 1,
	})))
	assert_false(_ok(ShoveIntent.decode({
		"intent": PlayerIntentNames.RESET_TO_CHECKPOINT,
	})))
	assert_false(_ok(ShoveIntent.decode({
		"intent": PlayerIntentNames.JUMP,
	})))
	assert_false(_ok(ShoveIntent.decode({"impulse": 1})))
	assert_false(_ok(ShoveIntent.decode({})))
	assert_false(_ok(ShoveIntent.decode({"intent": 1})))


func test_client_final_position_and_shove_metrics_are_not_decoded() -> void:
	var decoded: Dictionary = ShoveIntent.decode({
		"intent": PlayerIntentNames.SHOVE,
		"x": 999,
		"y": 888,
		"z": 777,
		"impulse": 50,
		"force": 12,
		"dx": 4,
		"dz": 5,
	})
	assert_true(_ok(decoded))
	assert_false(decoded.has("x"))
	assert_false(decoded.has("y"))
	assert_false(decoded.has("z"))
	assert_false(decoded.has("impulse"))
	assert_false(decoded.has("force"))
	assert_false(decoded.has("dx"))
	assert_false(decoded.has("dz"))


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag
