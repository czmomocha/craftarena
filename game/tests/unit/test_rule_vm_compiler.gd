extends GutTest

## M4a chapter 2: compile a typed OnMatchStarted graph to v1 bytecode.
## Extra keys / unknown events / unknown node kinds rejected.
## run() still only consumes bytes. Preview / match dispatch stay later.

const RuleVmGd := preload("res://src/ugc/rule_vm.gd")
const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")


func test_compare_set_graph_compiles_and_runs() -> void:
	var compiled: Dictionary = RuleVmGd.compile(_started_graph(16, [
		_load_node(0, 5),
		_load_node(1, 5),
		_compare_node(2, 0, 1, Opcodes.PRED_NAME_EQ),
		_set_var(3, 2),
	]))
	var compile_ok: bool = compiled.get(Opcodes.KEY_OK, false)
	assert_true(compile_ok)
	var event_name: String = compiled.get(Opcodes.KEY_EVENT, "")
	assert_eq(event_name, Opcodes.EVENT_ON_MATCH_STARTED)
	var bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	var decoded: Dictionary = RuleVmGd.decode(bytes)
	var decode_ok: bool = decoded.get(Opcodes.KEY_OK, false)
	assert_true(decode_ok)
	var ran: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars())
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	assert_true(ran_ok)
	var vars: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(vars[3], 1)
	var used: int = ran.get(Opcodes.KEY_GAS_USED, 0)
	assert_eq(used, 5)


func test_empty_on_match_started_is_empty_program() -> void:
	var compiled: Dictionary = RuleVmGd.compile(_started_graph(4, []))
	var compile_ok: bool = compiled.get(Opcodes.KEY_OK, false)
	assert_true(compile_ok)
	var bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	assert_eq(bytes.size(), Opcodes.HEADER_SIZE)
	var ran: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars())
	var used: int = ran.get(Opcodes.KEY_GAS_USED, -1)
	assert_eq(used, 0)


func test_get_variable_and_auto_halt() -> void:
	var compiled: Dictionary = RuleVmGd.compile(_started_graph(8, [
		_load_node(0, -3),
		{
			Opcodes.KEY_KIND: Opcodes.KIND_GET_VARIABLE,
			Opcodes.KEY_DEST: 7,
			Opcodes.KEY_SRC: 0,
		},
	]))
	var bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	var decoded: Dictionary = RuleVmGd.decode(bytes)
	var raw_ops: Variant = decoded.get(Opcodes.KEY_OPS, [])
	assert_eq(typeof(raw_ops), TYPE_ARRAY)
	var ops: Array = raw_ops
	assert_eq(ops.size(), 3)
	var halt_item: Variant = ops[2]
	assert_eq(typeof(halt_item), TYPE_DICTIONARY)
	var halt_bag: Dictionary = halt_item
	var halt_op: int = halt_bag.get(Opcodes.KEY_OP, -1)
	assert_eq(halt_op, Opcodes.OP_HALT)
	var ran: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars())
	var vars: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(vars[7], -3)


func test_json_whole_floats_coerce() -> void:
	var parsed: Variant = JSON.parse_string(
		'{"ruleset_version":1.0,"graph_gas":8.0,"event":"OnMatchStarted","nodes":[{"kind":"LoadConst","dest":0.0,"value":4.0}]}'
	)
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	var body: Dictionary = parsed
	var compiled: Dictionary = RuleVmGd.compile(body)
	var compile_ok: bool = compiled.get(Opcodes.KEY_OK, false)
	assert_true(compile_ok)
	var json_bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	var ran: Dictionary = RuleVmGd.run(json_bytes, RuleVmGd.empty_vars())
	var vars: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(vars[0], 4)


func test_rejects_extra_keys_unknown_event_and_kind() -> void:
	var extra: Dictionary = _started_graph(4, [])
	extra["note"] = "nope"
	_assert_compile_reason(extra, Opcodes.REASON_COMPILE_KEYS)
	_assert_compile_reason(_graph(1, 4, "OnEveryTicks", []), Opcodes.REASON_COMPILE_EVENT)
	_assert_compile_reason(_started_graph(4, [
		{Opcodes.KEY_KIND: "Spawn", Opcodes.KEY_DEST: 0, Opcodes.KEY_SRC: 1},
	]), Opcodes.REASON_COMPILE_UNKNOWN_NODE)
	_assert_compile_reason(_graph(2, 4, Opcodes.EVENT_ON_MATCH_STARTED, []), Opcodes.REASON_COMPILE_VERSION)
	var negative: Dictionary = _started_graph(4, [])
	negative[Opcodes.KEY_GRAPH_GAS] = -1
	_assert_compile_reason(negative, Opcodes.REASON_COMPILE_GAS)


func test_rejects_bad_node_shape_slot_and_pred() -> void:
	_assert_compile_reason(_started_graph(4, [
		{Opcodes.KEY_KIND: Opcodes.KIND_NOP, "extra": 1},
	]), Opcodes.REASON_COMPILE_NODE_KEYS)
	_assert_compile_reason(_started_graph(4, [
		_load_node(99, 1),
	]), Opcodes.REASON_COMPILE_SLOT)
	_assert_compile_reason(_started_graph(4, [
		_compare_node(0, 1, 2, "equals"),
	]), Opcodes.REASON_COMPILE_PREDICATE)


func test_compile_matches_hand_encoded_bytes() -> void:
	var ops: Array[Dictionary] = [
		{Opcodes.KEY_OP: Opcodes.OP_LOAD_I64, Opcodes.KEY_DEST: 0, Opcodes.KEY_VALUE: 9},
		{Opcodes.KEY_OP: Opcodes.OP_HALT},
	]
	var hand: PackedByteArray = RuleVmGd.encode(6, ops)
	var compiled: Dictionary = RuleVmGd.compile(_started_graph(6, [
		_load_node(0, 9),
		{Opcodes.KEY_KIND: Opcodes.KIND_HALT},
	]))
	var bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	assert_eq(hand.size(), bytes.size())
	var i: int = 0
	while i < hand.size():
		assert_eq(hand.decode_u8(i), bytes.decode_u8(i))
		i += 1


func test_run_does_not_accept_a_graph_dictionary() -> void:
	var graph: Dictionary = _started_graph(8, [_load_node(0, 1)])
	var ran: Dictionary = RuleVmGd.run(PackedByteArray(), RuleVmGd.empty_vars())
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	assert_false(ran_ok)
	assert_true(graph.has(Opcodes.KEY_NODES))


func _assert_compile_reason(graph: Dictionary, reason: String) -> void:
	var compiled: Dictionary = RuleVmGd.compile(graph)
	var compile_ok: bool = compiled.get(Opcodes.KEY_OK, false)
	assert_false(compile_ok, reason)
	var got: String = compiled.get(Opcodes.KEY_REASON, "")
	assert_eq(got, reason)
	var bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	assert_eq(bytes.size(), 0)


func _started_graph(graph_gas: int, nodes: Array) -> Dictionary:
	return _graph(Opcodes.RULESET_VERSION, graph_gas, Opcodes.EVENT_ON_MATCH_STARTED, nodes)


func _graph(version: int, graph_gas: int, event_name: String, nodes: Array) -> Dictionary:
	return {
		Opcodes.KEY_RULESET_VERSION: version,
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


func _set_var(dest: int, src: int) -> Dictionary:
	return {
		Opcodes.KEY_KIND: Opcodes.KIND_SET_VARIABLE,
		Opcodes.KEY_DEST: dest,
		Opcodes.KEY_SRC: src,
	}


func _compare_node(dest: int, lhs: int, rhs: int, pred: String) -> Dictionary:
	return {
		Opcodes.KEY_KIND: Opcodes.KIND_COMPARE,
		Opcodes.KEY_DEST: dest,
		Opcodes.KEY_LHS: lhs,
		Opcodes.KEY_RHS: rhs,
		Opcodes.KEY_PRED: pred,
	}
