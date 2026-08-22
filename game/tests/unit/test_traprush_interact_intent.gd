extends GutTest

## TraprushInteractIntent：只解码 PLAYER InteractIntent 名字，不发明道具表或爆破数值。
## CD-21 §8：客户端只发意图，不得发送障碍死亡断言。爆破数值见 CD-63，本刀不锁定。
## 本刀不调用 SimulationWorld。

const InteractIntent := preload("res://src/games/traprush/interact_intent.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")


func test_decode_requires_interact_intent_name_from_player_intent_names() -> void:
	var decoded: Dictionary = InteractIntent.decode({
		"intent": PlayerIntentNames.INTERACT,
	})
	assert_true(_ok(decoded))
	assert_eq(decoded.size(), 1)


func test_zero_field_button_intent_is_valid() -> void:
	var decoded: Dictionary = InteractIntent.decode({"intent": "InteractIntent"})
	assert_true(_ok(decoded))
	assert_eq(PlayerIntentNames.INTERACT, "InteractIntent")
	assert_false(decoded.has("damage"))
	assert_false(decoded.has("destroyed"))
	assert_false(decoded.has("x"))


func test_wrong_or_missing_intent_is_rejected() -> void:
	assert_false(_ok(InteractIntent.decode({
		"intent": PlayerIntentNames.JUMP,
	})))
	assert_false(_ok(InteractIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
		"dz": 1,
	})))
	assert_false(_ok(InteractIntent.decode({
		"intent": PlayerIntentNames.USE_ITEM,
	})))
	assert_false(_ok(InteractIntent.decode({
		"intent": PlayerIntentNames.SHOVE,
	})))
	assert_false(_ok(InteractIntent.decode({"destroyed": true})))
	assert_false(_ok(InteractIntent.decode({})))
	assert_false(_ok(InteractIntent.decode({"intent": 1})))


func test_client_position_and_destroyed_assertions_are_not_decoded() -> void:
	var decoded: Dictionary = InteractIntent.decode({
		"intent": PlayerIntentNames.INTERACT,
		"x": 999,
		"y": 888,
		"z": 777,
		"destroyed": true,
		"damage": 99,
	})
	assert_true(_ok(decoded))
	assert_false(decoded.has("x"))
	assert_false(decoded.has("y"))
	assert_false(decoded.has("z"))
	assert_false(decoded.has("destroyed"))
	assert_false(decoded.has("damage"))


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag
