extends GutTest

## M4a chapter 5: Preview P3 rebinds graphs at a safe point; public matches
## refuse rule patches. AuthoringDocument still has no rule-graph field.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringPreview := preload("res://src/creator/authoring_preview.gd")
const AuthoringSession := preload("res://src/creator/authoring_session.gd")
const AuthoringWorld := preload("res://src/creator/authoring_world.gd")
const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")
const SimulationBundle := preload("res://src/ugc/simulation_bundle.gd")
const TraprushMatchSession := preload("res://src/games/traprush/match_session.gd")
const TraprushPlayStubs := preload("res://src/games/traprush/play_stubs.gd")
const TraprushTopologyCompiler := preload("res://src/ugc/traprush_topology_compiler.gd")

const COURSE_01_PATH: String = "res://content/official/traprush/course_01.json"
const CELL: int = 65536
const PLAY_RADIUS: int = CELL / 8


func test_preview_rebind_at_safe_point_then_start() -> void:
	var preview: AuthoringPreview = _connected_course()
	assert_true(preview.try_replace_rule_graphs([
		_graph(Opcodes.EVENT_ON_MATCH_STARTED, [_load_node(0, 7)]),
	]))
	assert_true(preview.try_start_play(
		1, TraprushPlayStubs.CAPSULE_RADIUS, TraprushPlayStubs.CAPSULE_HEIGHT
	))
	var started_n: int = preview.rule_vm.started_count
	assert_eq(started_n, 1)
	var slots: PackedInt64Array = preview.rule_vm.vars()
	assert_eq(slots[0], 7)
	assert_false(preview.try_replace_rule_graphs([
		_graph(Opcodes.EVENT_ON_EVERY_TICKS, [_load_node(1, 9)]),
	]))
	assert_true(preview.try_stop_play())
	assert_true(preview.try_replace_rule_graphs([
		_graph(Opcodes.EVENT_ON_MATCH_STARTED, [_load_node(0, 3)]),
		_graph(Opcodes.EVENT_ON_EVERY_TICKS, [_load_node(1, 9)]),
	]))
	assert_true(preview.try_start_play(
		1, TraprushPlayStubs.CAPSULE_RADIUS, TraprushPlayStubs.CAPSULE_HEIGHT
	))
	started_n = preview.rule_vm.started_count
	assert_eq(started_n, 1)
	slots = preview.rule_vm.vars()
	assert_eq(slots[0], 3)
	assert_true(preview.try_advance_play())
	var tick_n: int = preview.rule_vm.tick_count
	assert_eq(tick_n, 1)
	slots = preview.rule_vm.vars()
	assert_eq(slots[1], 9)


func test_bad_rebind_keeps_previous_graphs() -> void:
	var preview: AuthoringPreview = _connected_course()
	assert_true(preview.try_replace_rule_graphs([
		_graph(Opcodes.EVENT_ON_MATCH_STARTED, [_load_node(0, 4)]),
	]))
	assert_false(preview.try_replace_rule_graphs([
		_graph(Opcodes.EVENT_ON_ENTERED_ZONE, []),
	]))
	assert_true(preview.try_start_play(
		1, TraprushPlayStubs.CAPSULE_RADIUS, TraprushPlayStubs.CAPSULE_HEIGHT
	))
	var slots: PackedInt64Array = preview.rule_vm.vars()
	assert_eq(slots[0], 4)


func test_public_match_refuses_rule_patch() -> void:
	var world: AuthoringWorld = AuthoringDocument.load_from_path(COURSE_01_PATH)
	assert_not_null(world)
	var bundle: SimulationBundle = TraprushTopologyCompiler.compile(world)
	assert_not_null(bundle)
	var offsets: Array[Dictionary] = [{"dx": 0, "dy": 0, "dz": 0}]
	var session: TraprushMatchSession = TraprushMatchSession.create(
		bundle, 1, 1, offsets, PLAY_RADIUS, PLAY_RADIUS
	)
	assert_not_null(session)
	assert_false(session.try_replace_rule_graphs([
		_graph(Opcodes.EVENT_ON_EVERY_TICKS, [_load_node(1, 9)]),
	]))
	var tick_n: int = session.rule_vm.tick_count
	assert_eq(tick_n, 0)
	session.advance_sim_tick()
	tick_n = session.rule_vm.tick_count
	assert_eq(tick_n, 0)


func _connected_course() -> AuthoringPreview:
	var session: AuthoringSession = AuthoringSession.new()
	assert_true(session.import_document(AuthoringDocument.load_json(COURSE_01_PATH)))
	var preview: AuthoringPreview = AuthoringPreview.new()
	assert_true(preview.connect_from(session))
	return preview


func _graph(event_name: String, nodes: Array) -> Dictionary:
	return {
		Opcodes.KEY_RULESET_VERSION: Opcodes.RULESET_VERSION,
		Opcodes.KEY_GRAPH_GAS: 8,
		Opcodes.KEY_EVENT: event_name,
		Opcodes.KEY_NODES: nodes,
	}


func _load_node(dest: int, value: int) -> Dictionary:
	return {
		Opcodes.KEY_KIND: Opcodes.KIND_LOAD_CONST,
		Opcodes.KEY_DEST: dest,
		Opcodes.KEY_VALUE: value,
	}
