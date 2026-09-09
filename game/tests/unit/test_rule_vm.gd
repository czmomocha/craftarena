extends GutTest

## M4a chapter 1: versioned Rule VM bytecode + whitelist interpreter + gas.
## Does not walk JSON graphs. Unknown opcode / version / reserved rejected.
## Over-gas aborts that run and leaves the caller's slots unchanged.
## Event dispatch is RuleVmDispatch. Spatial queries stay later.

const RuleVmGd := preload("res://src/ugc/rule_vm.gd")
const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")


func test_empty_program_round_trip() -> void:
	var bytes: PackedByteArray = RuleVmGd.encode(8, [])
	assert_eq(bytes.size(), Opcodes.HEADER_SIZE)
	var decoded: Dictionary = RuleVmGd.decode(bytes)
	var decode_ok: bool = decoded.get(Opcodes.KEY_OK, false)
	assert_true(decode_ok)
	var version: int = decoded.get(Opcodes.KEY_RULESET_VERSION, 0)
	var graph_gas: int = decoded.get(Opcodes.KEY_GRAPH_GAS, -1)
	assert_eq(version, Opcodes.RULESET_VERSION)
	assert_eq(graph_gas, 8)
	var ran: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars())
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	var gas_used: int = ran.get(Opcodes.KEY_GAS_USED, -1)
	assert_true(ran_ok)
	assert_eq(gas_used, 0)


func test_compare_and_set_variable() -> void:
	var ops: Array[Dictionary] = [
		{Opcodes.KEY_OP: Opcodes.OP_LOAD_I64, Opcodes.KEY_DEST: 0, Opcodes.KEY_VALUE: 5},
		{Opcodes.KEY_OP: Opcodes.OP_LOAD_I64, Opcodes.KEY_DEST: 1, Opcodes.KEY_VALUE: 5},
		{
			Opcodes.KEY_OP: Opcodes.OP_COMPARE,
			Opcodes.KEY_DEST: 2,
			Opcodes.KEY_LHS: 0,
			Opcodes.KEY_RHS: 1,
			Opcodes.KEY_PRED: Opcodes.PRED_EQ,
		},
		{Opcodes.KEY_OP: Opcodes.OP_SET_VAR, Opcodes.KEY_DEST: 3, Opcodes.KEY_SRC: 2},
		{Opcodes.KEY_OP: Opcodes.OP_HALT},
	]
	var bytes: PackedByteArray = RuleVmGd.encode(16, ops)
	var ran: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars())
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	assert_true(ran_ok)
	var gas_used: int = ran.get(Opcodes.KEY_GAS_USED, 0)
	assert_eq(gas_used, 5)
	var vars: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(vars.size(), Opcodes.SLOT_COUNT)
	assert_eq(vars[2], 1)
	assert_eq(vars[3], 1)


func test_get_var_copies_slot() -> void:
	var ops: Array[Dictionary] = [
		{Opcodes.KEY_OP: Opcodes.OP_LOAD_I64, Opcodes.KEY_DEST: 0, Opcodes.KEY_VALUE: -7},
		{Opcodes.KEY_OP: Opcodes.OP_GET_VAR, Opcodes.KEY_DEST: 4, Opcodes.KEY_SRC: 0},
	]
	var ran: Dictionary = RuleVmGd.run(RuleVmGd.encode(4, ops), RuleVmGd.empty_vars())
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	assert_true(ran_ok)
	var vars: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(vars[4], -7)


func test_compare_predicates() -> void:
	var cases: Array[Array] = [
		[Opcodes.PRED_EQ, 3, 3, 1],
		[Opcodes.PRED_EQ, 3, 4, 0],
		[Opcodes.PRED_NE, 3, 4, 1],
		[Opcodes.PRED_LT, 1, 2, 1],
		[Opcodes.PRED_LE, 2, 2, 1],
		[Opcodes.PRED_GT, 5, 1, 1],
		[Opcodes.PRED_GE, 5, 9, 0],
	]
	for row: Array in cases:
		var pred: int = row[0]
		var lhs: int = row[1]
		var rhs: int = row[2]
		var expect: int = row[3]
		var ops: Array[Dictionary] = [
			{Opcodes.KEY_OP: Opcodes.OP_LOAD_I64, Opcodes.KEY_DEST: 0, Opcodes.KEY_VALUE: lhs},
			{Opcodes.KEY_OP: Opcodes.OP_LOAD_I64, Opcodes.KEY_DEST: 1, Opcodes.KEY_VALUE: rhs},
			{
				Opcodes.KEY_OP: Opcodes.OP_COMPARE,
				Opcodes.KEY_DEST: 2,
				Opcodes.KEY_LHS: 0,
				Opcodes.KEY_RHS: 1,
				Opcodes.KEY_PRED: pred,
			},
		]
		var ran: Dictionary = RuleVmGd.run(RuleVmGd.encode(8, ops), RuleVmGd.empty_vars())
		var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
		assert_true(ran_ok, "pred %s" % pred)
		var vars: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
		assert_eq(vars[2], expect, "pred %s" % pred)


func test_decode_rejects_unknown_opcode_version_reserved() -> void:
	var good: PackedByteArray = RuleVmGd.encode(2, [{Opcodes.KEY_OP: Opcodes.OP_NOP}])
	var unknown: PackedByteArray = good.duplicate()
	unknown.encode_u8(Opcodes.HEADER_SIZE, 99)
	_assert_decode_reason(unknown, Opcodes.REASON_DECODE_UNKNOWN_OPCODE)
	var version: PackedByteArray = good.duplicate()
	version.encode_u16(4, 2)
	_assert_decode_reason(version, Opcodes.REASON_DECODE_VERSION)
	var reserved: PackedByteArray = good.duplicate()
	reserved.encode_u16(6, 1)
	_assert_decode_reason(reserved, Opcodes.REASON_DECODE_RESERVED)
	var magic: PackedByteArray = good.duplicate()
	magic.encode_u8(0, 0x00)
	_assert_decode_reason(magic, Opcodes.REASON_DECODE_MAGIC)


func test_decode_rejects_truncated_trailing_slot_pred() -> void:
	var empty: PackedByteArray = PackedByteArray()
	_assert_decode_reason(empty, Opcodes.REASON_DECODE_TRUNCATED)
	var header: PackedByteArray = RuleVmGd.encode(1, [])
	header.encode_u32(12, 4)
	_assert_decode_reason(header, Opcodes.REASON_DECODE_TRUNCATED)
	var trailing: PackedByteArray = RuleVmGd.encode(1, [{Opcodes.KEY_OP: Opcodes.OP_HALT}])
	trailing.append(0)
	_assert_decode_reason(trailing, Opcodes.REASON_DECODE_TRAILING)
	var slot_bad: PackedByteArray = RuleVmGd.encode(2, [
		{Opcodes.KEY_OP: Opcodes.OP_GET_VAR, Opcodes.KEY_DEST: 0, Opcodes.KEY_SRC: 1},
	])
	slot_bad.encode_u8(Opcodes.HEADER_SIZE + 1, 99)
	_assert_decode_reason(slot_bad, Opcodes.REASON_DECODE_SLOT)
	var pred_bad: PackedByteArray = RuleVmGd.encode(4, [
		{
			Opcodes.KEY_OP: Opcodes.OP_COMPARE,
			Opcodes.KEY_DEST: 0,
			Opcodes.KEY_LHS: 1,
			Opcodes.KEY_RHS: 2,
			Opcodes.KEY_PRED: Opcodes.PRED_EQ,
		},
	])
	pred_bad.encode_u8(Opcodes.HEADER_SIZE + 4, 9)
	_assert_decode_reason(pred_bad, Opcodes.REASON_DECODE_PREDICATE)


func test_gas_exceeded_leaves_vars_unchanged() -> void:
	var start: PackedInt64Array = RuleVmGd.empty_vars()
	start[0] = 11
	var ops: Array[Dictionary] = [
		{Opcodes.KEY_OP: Opcodes.OP_LOAD_I64, Opcodes.KEY_DEST: 0, Opcodes.KEY_VALUE: 99},
		{Opcodes.KEY_OP: Opcodes.OP_NOP},
	]
	var ran: Dictionary = RuleVmGd.run(RuleVmGd.encode(1, ops), start)
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	var reason: String = ran.get(Opcodes.KEY_REASON, "")
	assert_false(ran_ok)
	assert_eq(reason, Opcodes.REASON_GAS_EXCEEDED)
	var vars: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(vars[0], 11)
	var used: int = ran.get(Opcodes.KEY_GAS_USED, -1)
	assert_eq(used, 1)


func test_tick_and_chain_gas_tighten_graph_budget() -> void:
	var ops: Array[Dictionary] = [
		{Opcodes.KEY_OP: Opcodes.OP_NOP},
		{Opcodes.KEY_OP: Opcodes.OP_NOP},
	]
	var bytes: PackedByteArray = RuleVmGd.encode(8, ops)
	var tick: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars(), 1, -1)
	var tick_ok: bool = tick.get(Opcodes.KEY_OK, false)
	assert_false(tick_ok)
	var tick_reason: String = tick.get(Opcodes.KEY_REASON, "")
	assert_eq(tick_reason, Opcodes.REASON_GAS_EXCEEDED)
	var chain: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars(), -1, 1)
	var chain_ok: bool = chain.get(Opcodes.KEY_OK, false)
	assert_false(chain_ok)


func test_halt_skips_later_ops() -> void:
	var ops: Array[Dictionary] = [
		{Opcodes.KEY_OP: Opcodes.OP_LOAD_I64, Opcodes.KEY_DEST: 0, Opcodes.KEY_VALUE: 1},
		{Opcodes.KEY_OP: Opcodes.OP_HALT},
		{Opcodes.KEY_OP: Opcodes.OP_LOAD_I64, Opcodes.KEY_DEST: 0, Opcodes.KEY_VALUE: 99},
	]
	var ran: Dictionary = RuleVmGd.run(RuleVmGd.encode(8, ops), RuleVmGd.empty_vars())
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	assert_true(ran_ok)
	var vars: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(vars[0], 1)
	var used: int = ran.get(Opcodes.KEY_GAS_USED, 0)
	assert_eq(used, 2)


func test_encode_is_canonical_and_rejects_bad_ops() -> void:
	var ops: Array[Dictionary] = [
		{Opcodes.KEY_OP: Opcodes.OP_NOP},
		{Opcodes.KEY_OP: Opcodes.OP_HALT},
	]
	var a: PackedByteArray = RuleVmGd.encode(3, ops)
	var b: PackedByteArray = RuleVmGd.encode(3, ops)
	assert_eq(a.size(), b.size())
	var i: int = 0
	while i < a.size():
		assert_eq(a.decode_u8(i), b.decode_u8(i))
		i += 1
	assert_eq(RuleVmGd.encode(-1, ops).size(), 0)
	assert_eq(RuleVmGd.encode(1, [{Opcodes.KEY_OP: 99}]).size(), 0)
	assert_eq(RuleVmGd.encode(1, [
		{Opcodes.KEY_OP: Opcodes.OP_GET_VAR, Opcodes.KEY_DEST: 99, Opcodes.KEY_SRC: 0},
	]).size(), 0)


func test_wrong_vars_size_rejected() -> void:
	var bytes: PackedByteArray = RuleVmGd.encode(1, [])
	var ran: Dictionary = RuleVmGd.run(bytes, PackedInt64Array())
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	assert_false(ran_ok)
	var size_reason: String = ran.get(Opcodes.KEY_REASON, "")
	assert_eq(size_reason, Opcodes.REASON_VARS_SIZE)


func _assert_decode_reason(bytes: PackedByteArray, reason: String) -> void:
	var decoded: Dictionary = RuleVmGd.decode(bytes)
	var decode_ok: bool = decoded.get(Opcodes.KEY_OK, false)
	assert_false(decode_ok, reason)
	var decoded_reason: String = decoded.get(Opcodes.KEY_REASON, "")
	assert_eq(decoded_reason, reason)
	var ran: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars())
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	assert_false(ran_ok, reason)
	var ran_reason: String = ran.get(Opcodes.KEY_REASON, "")
	assert_eq(ran_reason, reason)
