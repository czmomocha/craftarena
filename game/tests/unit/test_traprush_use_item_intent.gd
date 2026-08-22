extends GutTest

## TraprushUseItemIntent：只解码 PLAYER UseItemIntent 名字，不发明道具表或爆破数值。
## CD-21 §8：客户端只发意图，不得发送道具命中或障碍死亡断言。爆破数值见 CD-63，本刀不锁定。
## 本刀不调用 SimulationWorld。

const UseItemIntent := preload("res://src/games/traprush/use_item_intent.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")


func test_decode_requires_use_item_intent_name_from_player_intent_names() -> void:
	var decoded: Dictionary = UseItemIntent.decode({
		"intent": PlayerIntentNames.USE_ITEM,
	})
	assert_true(_ok(decoded))
	assert_eq(decoded.size(), 1)


func test_zero_field_button_intent_is_valid() -> void:
	var decoded: Dictionary = UseItemIntent.decode({"intent": "UseItemIntent"})
	assert_true(_ok(decoded))
	assert_eq(PlayerIntentNames.USE_ITEM, "UseItemIntent")
	assert_false(decoded.has("item_id"))
	assert_false(decoded.has("damage"))
	assert_false(decoded.has("hit"))
	assert_false(decoded.has("destroyed"))
	assert_false(decoded.has("x"))


func test_wrong_or_missing_intent_is_rejected() -> void:
	assert_false(_ok(UseItemIntent.decode({
		"intent": PlayerIntentNames.JUMP,
	})))
	assert_false(_ok(UseItemIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
		"dz": 1,
	})))
	assert_false(_ok(UseItemIntent.decode({
		"intent": PlayerIntentNames.INTERACT,
	})))
	assert_false(_ok(UseItemIntent.decode({
		"intent": PlayerIntentNames.SHOVE,
	})))
	assert_false(_ok(UseItemIntent.decode({"destroyed": true})))
	assert_false(_ok(UseItemIntent.decode({})))
	assert_false(_ok(UseItemIntent.decode({"intent": 1})))


func test_client_hit_destroyed_and_item_assertions_are_not_decoded() -> void:
	var decoded: Dictionary = UseItemIntent.decode({
		"intent": PlayerIntentNames.USE_ITEM,
		"item_id": 42,
		"x": 999,
		"y": 888,
		"z": 777,
		"hit": true,
		"destroyed": true,
		"damage": 99,
	})
	assert_true(_ok(decoded))
	assert_false(decoded.has("item_id"))
	assert_false(decoded.has("x"))
	assert_false(decoded.has("y"))
	assert_false(decoded.has("z"))
	assert_false(decoded.has("hit"))
	assert_false(decoded.has("destroyed"))
	assert_false(decoded.has("damage"))


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag
