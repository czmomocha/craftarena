extends GutTest

## TraprushSprintIntent：只解码 PLAYER SprintIntent 名字，不发明冲刺距离或冷却秒数。
## CD-21 §8：客户端只发意图，不得发送最终位置。步长与冷却见调用方占位桩，本刀不锁定。
## 本刀不调用 SimulationWorld。

const SprintIntent := preload("res://src/games/traprush/sprint_intent.gd")
const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")


func test_decode_requires_sprint_intent_name_from_player_intent_names() -> void:
	var decoded: Dictionary = SprintIntent.decode({
		"intent": PlayerIntentNames.SPRINT,
	})
	assert_true(_ok(decoded))
	assert_eq(decoded.size(), 1)


func test_zero_field_button_intent_is_valid() -> void:
	var decoded: Dictionary = SprintIntent.decode({"intent": "SprintIntent"})
	assert_true(_ok(decoded))
	assert_eq(PlayerIntentNames.SPRINT, "SprintIntent")
	assert_false(decoded.has("dx"))
	assert_false(decoded.has("dz"))
	assert_false(decoded.has("yaw_bam"))


func test_wrong_or_missing_intent_is_rejected() -> void:
	assert_false(_ok(SprintIntent.decode({
		"intent": PlayerIntentNames.MOVE,
		"dx": 1,
		"dz": 1,
	})))
	assert_false(_ok(SprintIntent.decode({
		"intent": PlayerIntentNames.USE_ITEM,
	})))
	assert_false(_ok(SprintIntent.decode({
		"intent": PlayerIntentNames.SHOVE,
	})))
	assert_false(_ok(SprintIntent.decode({"dx": 1})))
	assert_false(_ok(SprintIntent.decode({})))
	assert_false(_ok(SprintIntent.decode({"intent": 1})))


func test_client_final_position_is_not_decoded() -> void:
	var decoded: Dictionary = SprintIntent.decode({
		"intent": PlayerIntentNames.SPRINT,
		"x": 999,
		"y": 888,
		"z": 777,
		"dx": 4,
		"dz": 5,
		"yaw_bam": 49152,
	})
	assert_true(_ok(decoded))
	assert_false(decoded.has("x"))
	assert_false(decoded.has("dx"))
	assert_false(decoded.has("yaw_bam"))


func _ok(result: Dictionary) -> bool:
	var flag: bool = result.get("ok", false)
	return flag
