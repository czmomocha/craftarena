extends GutTest

## Intent 名必须与 CD-21 §8、CD-22 §7.3 的锁定清单一致，防止信封层偷偷加客户端可发动作。

const PlayerIntentNames := preload("res://src/shared/commands/player_intent_names.gd")


func test_traprush_intents_are_present() -> void:
	assert_true(PlayerIntentNames.contains("MoveIntent"))
	assert_true(PlayerIntentNames.contains("JumpIntent"))
	assert_true(PlayerIntentNames.contains("ShoveIntent"))
	assert_true(PlayerIntentNames.contains("UseItemIntent"))
	assert_true(PlayerIntentNames.contains("InteractIntent"))
	assert_true(PlayerIntentNames.contains("ResetToCheckpointIntent"))


func test_bastion_intents_are_present() -> void:
	assert_true(PlayerIntentNames.contains("BuildTowerIntent"))
	assert_true(PlayerIntentNames.contains("UpgradeTowerIntent"))
	assert_true(PlayerIntentNames.contains("SellTowerIntent"))
	assert_true(PlayerIntentNames.contains("SetTowerPriorityIntent"))
	assert_true(PlayerIntentNames.contains("DonateResourceIntent"))


func test_unknown_intent_is_rejected() -> void:
	assert_false(PlayerIntentNames.contains("TeleportIntent"))
	assert_false(PlayerIntentNames.contains(""))


func test_intent_list_size_matches_locked_catalog() -> void:
	assert_eq(PlayerIntentNames.ALL.size(), 11)
