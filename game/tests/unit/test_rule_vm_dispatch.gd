extends GutTest

## M4a chapter 3: Event dispatch for OnMatchStarted (once) and OnEveryTicks
## (each notify). Shared slots. Over-gas is locatable and does not take down
## match / Preview. Official courses stay a no-op until something is bound.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")
const RuleVmDispatchGd := preload("res://src/ugc/rule_vm_dispatch.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushPlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8


func test_started_once_ticks_each_call_share_slots() -> void:
	var dispatch: RuleVmDispatchGd = RuleVmDispatchGd.new()
	_assert_bind_ok(dispatch.bind_graph(_graph(
		Opcodes.EVENT_ON_MATCH_STARTED, 8, [_load_node(0, 7)]
	)))
	_assert_bind_ok(dispatch.bind_graph(_graph(
		Opcodes.EVENT_ON_EVERY_TICKS, 8, [_load_node(1, 9)]
	)))
	var started: Dictionary = dispatch.notify_match_started()
	var started_ok: bool = started.get(Opcodes.KEY_OK, false)
	assert_true(started_ok)
	var started_n: int = dispatch.started_count
	assert_eq(started_n, 1)
	var slots: PackedInt64Array = dispatch.vars()
	assert_eq(slots[0], 7)
	var again: Dictionary = dispatch.notify_match_started()
	var again_reason: String = again.get(Opcodes.KEY_REASON, "")
	assert_eq(again_reason, Opcodes.REASON_ALREADY_STARTED)
	started_n = dispatch.started_count
	assert_eq(started_n, 1)
	var i: int = 0
	while i < 3:
		var ticks: Dictionary = dispatch.notify_every_ticks()
		var ticks_ok: bool = ticks.get(Opcodes.KEY_OK, false)
		assert_true(ticks_ok)
		i += 1
	var tick_n: int = dispatch.tick_count
	assert_eq(tick_n, 3)
	slots = dispatch.vars()
	assert_eq(slots[0], 7)
	assert_eq(slots[1], 9)


func test_missing_program_is_silent_and_duplicate_bind_fails() -> void:
	var dispatch: RuleVmDispatchGd = RuleVmDispatchGd.new()
	var silent: Dictionary = dispatch.notify_match_started()
	var silent_ok: bool = silent.get(Opcodes.KEY_OK, false)
	assert_true(silent_ok)
	var started_n: int = dispatch.started_count
	assert_eq(started_n, 0)
	var first: Dictionary = dispatch.bind_graph(_graph(
		Opcodes.EVENT_ON_MATCH_STARTED, 4, []
	))
	_assert_bind_ok(first)
	var dup: Dictionary = dispatch.bind_graph(_graph(
		Opcodes.EVENT_ON_MATCH_STARTED, 4, [_load_node(0, 1)]
	))
	var dup_ok: bool = dup.get(Opcodes.KEY_OK, false)
	var dup_reason: String = dup.get(Opcodes.KEY_REASON, "")
	assert_false(dup_ok)
	assert_eq(dup_reason, Opcodes.REASON_BIND_DUPLICATE)


func test_over_gas_keeps_slots_and_does_not_take_down() -> void:
	var dispatch: RuleVmDispatchGd = RuleVmDispatchGd.new()
	_assert_bind_ok(dispatch.bind_graph(_graph(
		Opcodes.EVENT_ON_EVERY_TICKS, 1, [_load_node(0, 4)]
	)))
	var ran: Dictionary = dispatch.notify_every_ticks()
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	var reason: String = ran.get(Opcodes.KEY_REASON, "")
	assert_false(ran_ok)
	assert_eq(reason, Opcodes.REASON_GAS_EXCEEDED)
	var last_reason: String = dispatch.last_reason
	assert_eq(last_reason, Opcodes.REASON_GAS_EXCEEDED)
	var tick_n: int = dispatch.tick_count
	assert_eq(tick_n, 1)
	var slots: PackedInt64Array = dispatch.vars()
	assert_eq(slots[0], 0)
	dispatch.notify_every_ticks()
	tick_n = dispatch.tick_count
	assert_eq(tick_n, 2)
	slots = dispatch.vars()
	assert_eq(slots[0], 0)


func test_other_events_still_compile_rejected() -> void:
	var dispatch: RuleVmDispatchGd = RuleVmDispatchGd.new()
	var bound: Dictionary = dispatch.bind_graph(_graph(
		Opcodes.EVENT_ON_ENTERED_ZONE, 4, []
	))
	var bound_ok: bool = bound.get(Opcodes.KEY_OK, false)
	var reason: String = bound.get(Opcodes.KEY_REASON, "")
	assert_false(bound_ok)
	assert_eq(reason, Opcodes.REASON_COMPILE_EVENT)


func test_reset_run_state_keeps_binds() -> void:
	var dispatch: RuleVmDispatchGd = RuleVmDispatchGd.new()
	_assert_bind_ok(dispatch.bind_graph(_graph(
		Opcodes.EVENT_ON_MATCH_STARTED, 8, [_load_node(0, 3)]
	)))
	dispatch.notify_match_started()
	var slots: PackedInt64Array = dispatch.vars()
	assert_eq(slots[0], 3)
	dispatch.reset_run_state()
	var started_n: int = dispatch.started_count
	assert_eq(started_n, 0)
	slots = dispatch.vars()
	assert_eq(slots[0], 0)
	dispatch.notify_match_started()
	started_n = dispatch.started_count
	assert_eq(started_n, 1)
	slots = dispatch.vars()
	assert_eq(slots[0], 3)


func test_official_match_stays_noop_until_bound() -> void:
	var session: TraprushMatchSession = _course_session()
	var vm: RuleVmDispatchGd = session.rule_vm
	var started_n: int = vm.started_count
	var tick_n: int = vm.tick_count
	assert_eq(started_n, 0)
	assert_eq(tick_n, 0)
	session.advance_sim_tick()
	tick_n = vm.tick_count
	assert_eq(tick_n, 0)
	var slots: PackedInt64Array = vm.vars()
	assert_eq(slots[0], 0)


func test_match_every_ticks_after_create() -> void:
	var session: TraprushMatchSession = _course_session()
	var vm: RuleVmDispatchGd = session.rule_vm
	_assert_bind_ok(vm.bind_graph(_graph(
		Opcodes.EVENT_ON_EVERY_TICKS, 8, [_load_node(1, 9)]
	)))
	session.advance_sim_tick()
	session.advance_sim_tick()
	var tick_n: int = vm.tick_count
	assert_eq(tick_n, 2)
	var slots: PackedInt64Array = vm.vars()
	assert_eq(slots[1], 9)
	var last_reason: String = vm.last_reason
	assert_eq(last_reason, Opcodes.REASON_OK)


func test_preview_start_and_ticks_use_binds() -> void:
	var preview: AuthoringPreview = _connected_course()
	var vm: RuleVmDispatchGd = preview.rule_vm
	_assert_bind_ok(vm.bind_graph(_graph(
		Opcodes.EVENT_ON_MATCH_STARTED, 8, [_load_node(0, 7)]
	)))
	_assert_bind_ok(vm.bind_graph(_graph(
		Opcodes.EVENT_ON_EVERY_TICKS, 8, [_load_node(1, 9)]
	)))
	assert_true(preview.try_start_play(
		1, TraprushPlayStubs.CAPSULE_RADIUS, TraprushPlayStubs.CAPSULE_HEIGHT
	))
	var started_n: int = vm.started_count
	assert_eq(started_n, 1)
	var slots: PackedInt64Array = vm.vars()
	assert_eq(slots[0], 7)
	assert_true(preview.try_advance_play())
	assert_true(preview.try_advance_play())
	var tick_n: int = vm.tick_count
	assert_eq(tick_n, 2)
	slots = vm.vars()
	assert_eq(slots[1], 9)
	assert_true(preview.try_stop_play())
	started_n = vm.started_count
	assert_eq(started_n, 0)
	assert_true(preview.try_start_play(
		1, TraprushPlayStubs.CAPSULE_RADIUS, TraprushPlayStubs.CAPSULE_HEIGHT
	))
	started_n = vm.started_count
	assert_eq(started_n, 1)
	slots = vm.vars()
	assert_eq(slots[0], 7)


func _assert_bind_ok(bound: Dictionary) -> void:
	var bound_ok: bool = bound.get(Opcodes.KEY_OK, false)
	var reason: String = bound.get(Opcodes.KEY_REASON, "")
	assert_true(bound_ok, reason)


func _course_session() -> TraprushMatchSession:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	return session


func _connected_course() -> AuthoringPreview:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	return preview


func _graph(event_name: String, graph_gas: int, nodes: Array) -> Dictionary:
	return {
		Opcodes.KEY_RULESET_VERSION: Opcodes.RULESET_VERSION,
		Opcodes.KEY_GRAPH_GAS: graph_gas,
		Opcodes.KEY_EVENT: event_name,
		Opcodes.KEY_NODES: nodes,
	}


func _load_node(dest: int, value: int) -> Dictionary:
	return {
		Opcodes.KEY_KIND: Opcodes.KIND_LOAD_CONST,
		Opcodes.KEY_DEST: dest,
		Opcodes.KEY_VALUE: value,
	}
