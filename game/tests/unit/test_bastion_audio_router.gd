extends GutTest

## M6 E4: BASTION event → already-registered cue ids. No new OGG.
## Headless stays silent because the audio module is.

const BastionFrameCodec := preload("res://src/shared/protocol/bastion_frame_codec.gd")
const BastionMatchSession := preload("res://src/games/bastion/match_session.gd")
const BastionSnapshotFollowGd := preload("res://src/client/bastion_snapshot_follow.gd")
const CatalogGd := preload("res://src/shared/schema/audio_cue_catalog.gd")
const ObserveGd := preload("res://src/games/bastion/audio_observe.gd")
const RouterGd := preload("res://src/games/bastion/audio_router.gd")
const SnapshotGd := preload("res://src/shared/protocol/bastion_frame_snapshot.gd")
const Priorities := preload("res://src/shared/schema/tower_target_priorities.gd")

const TEAM_A: int = 1
const TEAM_B: int = 2


func test_every_router_event_maps_to_a_catalog_id() -> void:
	assert_gt(RouterGd.EVENTS.size(), 0)
	for event: String in RouterGd.EVENTS:
		var cue_id: String = RouterGd.cue(event)
		assert_true(cue_id != "", event)
		assert_true(CatalogGd.has_id(cue_id), "%s -> %s" % [event, cue_id])
	assert_eq(RouterGd.cue(RouterGd.EVENT_SELECT), CatalogGd.UI_SELECT)
	assert_eq(RouterGd.cue(RouterGd.EVENT_CONFIRM), CatalogGd.UI_CONFIRM)
	assert_eq(RouterGd.cue(RouterGd.EVENT_HIT), CatalogGd.CRATE)
	assert_eq(RouterGd.cue(RouterGd.EVENT_SETTLED), CatalogGd.SETTLED)
	assert_eq(RouterGd.cue("nope"), "")
	assert_false(RouterGd.has_event("nope"))


func test_observe_emits_place_lock_reveal_build_without_mutating_follow() -> void:
	var follow: BastionSnapshotFollowGd = BastionSnapshotFollowGd.new()
	var observe: ObserveGd = ObserveGd.new()
	assert_true(follow.apply_frame(_snap(1, SnapshotGd.PHASE_SETUP, _teams(false, [], []))))
	assert_eq(observe.collect(follow).size(), 0)
	var placed: PackedStringArray = observe.collect(_follow(_snap(
		2, SnapshotGd.PHASE_SETUP, _teams(false, [], [{"node_id": 40, "prototype_id": 21}])
	)))
	assert_true(placed.has(RouterGd.EVENT_PLACE))
	var locked: PackedStringArray = observe.collect(_follow(_snap(
		3, SnapshotGd.PHASE_SETUP, _teams(true, [], [{"node_id": 40, "prototype_id": 21}])
	)))
	assert_true(locked.has(RouterGd.EVENT_LOCK))
	var revealed: PackedStringArray = observe.collect(_follow(_snap(
		4, BastionMatchSession.PHASE_PREP, _teams(true, [], [{"node_id": 40, "prototype_id": 21}])
	)))
	assert_true(revealed.has(RouterGd.EVENT_REVEAL))
	var built: PackedStringArray = observe.collect(_follow(_snap(
		5,
		BastionMatchSession.PHASE_PREP,
		_teams(true, [{
			"slot_id": 30,
			"prototype_id": 1,
			"level": 1,
			"target_priority": Priorities.FRONT,
			"cooldown_left": 0,
		}], [{"node_id": 40, "prototype_id": 21}])
	)))
	assert_true(built.has(RouterGd.EVENT_BUILD))
	assert_eq(follow.tick, 1)


func _follow(bytes: PackedByteArray) -> BastionSnapshotFollowGd:
	var follow: BastionSnapshotFollowGd = BastionSnapshotFollowGd.new()
	assert_true(follow.apply_frame(bytes))
	return follow


func _snap(tick: int, phase: int, teams: Array[Dictionary]) -> PackedByteArray:
	return BastionFrameCodec.encode_snapshot(tick, phase, 0, 0, teams, TEAM_A)


func _teams(locked: bool, towers: Array, obstacles: Array) -> Array[Dictionary]:
	return [
		{
			"team_id": TEAM_A,
			"core_health": 100,
			"gold": 200,
			"leaked": 0,
			"kills": 0,
			"locked": 1 if locked else 0,
			"towers": towers,
			"units": [],
			"obstacles": obstacles,
		},
		{
			"team_id": TEAM_B,
			"core_health": 100,
			"gold": 200,
			"leaked": 0,
			"kills": 0,
			"locked": 0,
			"towers": [],
			"units": [],
			"obstacles": [],
		},
	]
