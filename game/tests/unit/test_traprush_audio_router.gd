extends GutTest

## M5 B1: TRAPRUSH event → cue routing and Solo observe. Headless silent.
## Does not assert placeholder colours.

const AuthoringDocumentGd := preload("res://src/creator/authoring_document.gd")
const CatalogGd := preload("res://src/shared/schema/audio_cue_catalog.gd")
const ObserveGd := preload("res://src/games/traprush/traprush_audio_observe.gd")
const PlayerIntentNamesGd := preload("res://src/shared/commands/player_intent_names.gd")
const RouterGd := preload("res://src/games/traprush/traprush_audio_router.gd")
const TraprushMatchSessionGd := preload("res://src/games/traprush/match_session.gd")
const TraprushTopologyCompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536


func test_every_router_event_maps_to_a_catalog_id() -> void:
	for event: String in RouterGd.EVENTS:
		var cue_id: String = RouterGd.cue(event)
		assert_true(cue_id != "", event)
		assert_true(CatalogGd.has_id(cue_id), "%s -> %s" % [event, cue_id])
	assert_eq(RouterGd.cue(RouterGd.EVENT_JUMP), CatalogGd.JUMP)
	assert_eq(RouterGd.break_event("rubble"), RouterGd.EVENT_BREAK_RUBBLE)
	assert_eq(RouterGd.fail_event(PlaySetback.HAZARD), RouterGd.EVENT_FAIL_HAZARD)
	assert_eq(RouterGd.cue("nope"), "")


func test_observe_does_not_change_hash_state() -> void:
	var session: TraprushMatchSessionGd = _session()
	assert_not_null(session)
	var before: String = session.hash_state()
	var observe: ObserveGd = ObserveGd.new()
	observe.collect(observe.sample_session(session, 0))
	assert_eq(session.hash_state(), before)
	assert_true(session.apply_player_intent(0, _move(CELL / 16, 0)))
	session.commit_tick()
	var after: String = session.hash_state()
	observe.collect(observe.sample_session(session, 0))
	observe.loops_session(session)
	assert_eq(session.hash_state(), after)


func test_observe_throttles_steps_to_stride() -> void:
	var observe: ObserveGd = ObserveGd.new()
	observe.step_stride = 10
	var first: Dictionary = _sample({"x": 0, "z": 0})
	assert_eq(observe.collect(first).size(), 0)
	var small: PackedStringArray = observe.collect(_sample({"x": 4, "z": 0}))
	assert_false(small.has(RouterGd.EVENT_STEP))
	var stepped: PackedStringArray = observe.collect(_sample({"x": 12, "z": 0}))
	assert_true(stepped.has(RouterGd.EVENT_STEP))


func test_observe_emits_jump_land_checkpoint_and_reset() -> void:
	var observe: ObserveGd = ObserveGd.new()
	observe.collect(_sample({}))
	var jump: PackedStringArray = observe.collect(_sample({"air": true, "y": CELL}))
	assert_true(jump.has(RouterGd.EVENT_JUMP))
	var land: PackedStringArray = observe.collect(_sample({"air": false, "y": 0}))
	assert_true(land.has(RouterGd.EVENT_LAND))
	var pad: PackedStringArray = observe.collect(_sample({"accepted": 2}))
	assert_true(pad.has(RouterGd.EVENT_CHECKPOINT))
	var reset: PackedStringArray = observe.collect(_sample({
		"intent": PlayerIntentNamesGd.RESET_TO_CHECKPOINT,
	}))
	assert_true(reset.has(RouterGd.EVENT_RESET))
	var fail: PackedStringArray = observe.collect(_sample({
		"setback": 1,
		"reason": PlaySetback.OUT_OF_RANGE,
	}))
	assert_true(fail.has(RouterGd.EVENT_FAIL_RANGE))
	assert_false(fail.has(RouterGd.EVENT_LAND))
	var ticks: PackedStringArray = observe.collect(_sample({
		"setback": 1,
		"reason": PlaySetback.OUT_OF_RANGE,
		"shove": 4,
		"sprint": 8,
	}))
	assert_true(ticks.has(RouterGd.EVENT_SHOVE))
	assert_true(ticks.has(RouterGd.EVENT_SPRINT))


func test_observe_emits_break_kind_and_finish() -> void:
	var observe: ObserveGd = ObserveGd.new()
	observe.collect(_sample({
		"health": {3: 1},
		"kinds": {3: "wall"},
	}))
	var broke: PackedStringArray = observe.collect(_sample({
		"health": {3: 0},
		"kinds": {3: "wall"},
	}))
	assert_true(broke.has(RouterGd.EVENT_BREAK_WALL))
	var finish: PackedStringArray = observe.collect(_sample({
		"health": {3: 0},
		"kinds": {3: "wall"},
		"finish": 12,
	}))
	assert_true(finish.has(RouterGd.EVENT_FINISH))
	assert_true(finish.has(RouterGd.EVENT_SETTLED))


func _session() -> TraprushMatchSessionGd:
	var world: AuthoringWorld = AuthoringDocumentGd.load_from_path(COURSE)
	if world == null:
		return null
	var bundle: SimulationBundle = TraprushTopologyCompilerGd.compile(world)
	return TraprushMatchSessionGd.create(
		bundle, 1, 1, [{"dx": 0, "dy": 0, "dz": 0}], CELL / 8, CELL / 8
	)


func _move(dx: int, dz: int) -> Dictionary:
	return {"intent": PlayerIntentNamesGd.MOVE, "dx": dx, "dz": dz}


func _sample(overrides: Dictionary) -> Dictionary:
	var body: Dictionary = {
		ObserveGd.KEY_TICK: 0,
		ObserveGd.KEY_X: 0,
		ObserveGd.KEY_Y: 0,
		ObserveGd.KEY_Z: 0,
		ObserveGd.KEY_AIR: false,
		ObserveGd.KEY_ACCEPTED: 1,
		ObserveGd.KEY_FINISH: -1,
		ObserveGd.KEY_BOMB: 0,
		ObserveGd.KEY_DASH: 0,
		ObserveGd.KEY_TAKEN: 0,
		ObserveGd.KEY_SETBACK: 0,
		ObserveGd.KEY_REASON: "",
		ObserveGd.KEY_SHOVE: -1,
		ObserveGd.KEY_USE: -1,
		ObserveGd.KEY_SPRINT: -1,
		ObserveGd.KEY_LATCH: false,
		ObserveGd.KEY_INTENT: "",
		ObserveGd.KEY_HEALTH: {},
		ObserveGd.KEY_KINDS: {},
	}
	for key: Variant in overrides.keys():
		body[key] = overrides[key]
	return body
