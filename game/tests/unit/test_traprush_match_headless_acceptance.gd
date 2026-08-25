extends GutTest

## CD-61 §4.1 2-player Headless acceptance: official course_01, MatchRealtime
## one-command-per-slot-per-tick gate, both finish, live standings, same tape
## same snapshot/hash, settlement payload after all finish. No online writes.

const TraprushMatchHeadlessAcceptance := preload("res://src/games/traprush/match_headless_acceptance.gd")


func test_two_player_official_course_finishes_under_command_gate() -> void:
	var result: Dictionary = TraprushMatchHeadlessAcceptance.try_run()
	var ok: bool = result.get("ok", false)
	var flood_applied_cells: int = result.get("flood_applied_cells", 0)
	var finish0: int = result.get("finish0", -1)
	var finish1: int = result.get("finish1", -1)
	var mvp_slot: int = result.get("mvp_slot", -2)
	var replay_match: bool = result.get("replay_match", false)
	var allows_settlement: bool = result.get("allows_settlement", false)
	var settlement_hash: String = result.get("settlement_hash", "")
	var allows_online_writes: bool = result.get("allows_online_writes", true)
	assert_true(ok)
	assert_eq(flood_applied_cells, 1)
	assert_eq(finish0, 4)
	assert_eq(finish1, 4)
	assert_eq(mvp_slot, 0)
	assert_true(replay_match)
	assert_true(allows_settlement)
	assert_false(settlement_hash.is_empty())
	assert_false(allows_online_writes)
