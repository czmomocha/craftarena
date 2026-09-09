class_name RuleVm
extends RefCounted

## Versioned bytecode interpreter for Rule VM v1 (CD-42 §2).
## Client and server run this same static-typed GDScript. Over-gas aborts this
## content logic with a locatable reason and does not commit variable writes.
## Does not walk JSON, generate GDScript, or load scripts. Not wired to Preview
## or the match loop in this chapter.

const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")
const CodecGd := preload("res://src/ugc/rule_vm_codec.gd")


static func encode(graph_gas: int, ops: Array) -> PackedByteArray:
	return CodecGd.encode(graph_gas, ops)


static func decode(bytes: PackedByteArray) -> Dictionary:
	return CodecGd.decode(bytes)


static func empty_vars() -> PackedInt64Array:
	var vars: PackedInt64Array = PackedInt64Array()
	vars.resize(Opcodes.SLOT_COUNT)
	return vars


static func run(
	bytes: PackedByteArray,
	vars: PackedInt64Array,
	tick_gas: int = -1,
	chain_gas: int = -1
) -> Dictionary:
	var decoded: Dictionary = CodecGd.decode(bytes)
	var decode_ok: bool = decoded.get(Opcodes.KEY_OK, false)
	if not decode_ok:
		return _finish(
			false,
			str(decoded.get(Opcodes.KEY_REASON, Opcodes.REASON_DECODE_TRUNCATED)),
			0,
			vars
		)
	if vars.size() != Opcodes.SLOT_COUNT:
		return _finish(false, Opcodes.REASON_VARS_SIZE, 0, vars)
	var graph_gas: int = decoded.get(Opcodes.KEY_GRAPH_GAS, 0)
	var budget: int = graph_gas
	if tick_gas >= 0 and tick_gas < budget:
		budget = tick_gas
	if chain_gas >= 0 and chain_gas < budget:
		budget = chain_gas
	var work: PackedInt64Array = vars.duplicate()
	var gas_used: int = 0
	var raw_ops: Variant = decoded.get(Opcodes.KEY_OPS, [])
	if typeof(raw_ops) != TYPE_ARRAY:
		return _finish(false, Opcodes.REASON_DECODE_UNKNOWN_OPCODE, 0, vars)
	var ops: Array = raw_ops
	for item: Variant in ops:
		if typeof(item) != TYPE_DICTIONARY:
			return _finish(false, Opcodes.REASON_DECODE_UNKNOWN_OPCODE, gas_used, vars)
		var bag: Dictionary = item
		var op: int = bag.get(Opcodes.KEY_OP, -1)
		var cost: int = Opcodes.cost(op)
		if cost < 1 or gas_used > budget - cost:
			return _finish(false, Opcodes.REASON_GAS_EXCEEDED, gas_used, vars)
		gas_used += cost
		if not _apply(work, bag):
			return _finish(false, Opcodes.REASON_DECODE_UNKNOWN_OPCODE, gas_used, vars)
		if op == Opcodes.OP_HALT:
			break
	return _finish(true, Opcodes.REASON_OK, gas_used, work)


static func _apply(work: PackedInt64Array, bag: Dictionary) -> bool:
	var op: int = bag.get(Opcodes.KEY_OP, -1)
	if op == Opcodes.OP_HALT or op == Opcodes.OP_NOP:
		return true
	if op == Opcodes.OP_LOAD_I64:
		var dest: int = bag.get(Opcodes.KEY_DEST, -1)
		if not Opcodes.slot_ok(dest):
			return false
		work[dest] = bag.get(Opcodes.KEY_VALUE, 0)
		return true
	if op == Opcodes.OP_GET_VAR or op == Opcodes.OP_SET_VAR:
		var dest2: int = bag.get(Opcodes.KEY_DEST, -1)
		var src: int = bag.get(Opcodes.KEY_SRC, -1)
		if not Opcodes.slot_ok(dest2) or not Opcodes.slot_ok(src):
			return false
		work[dest2] = work[src]
		return true
	if op == Opcodes.OP_COMPARE:
		var dest3: int = bag.get(Opcodes.KEY_DEST, -1)
		var lhs: int = bag.get(Opcodes.KEY_LHS, -1)
		var rhs: int = bag.get(Opcodes.KEY_RHS, -1)
		var pred: int = bag.get(Opcodes.KEY_PRED, -1)
		if not Opcodes.slot_ok(dest3) or not Opcodes.slot_ok(lhs) or not Opcodes.slot_ok(rhs):
			return false
		if not Opcodes.pred_ok(pred):
			return false
		work[dest3] = _compare(work[lhs], work[rhs], pred)
		return true
	return false


static func _compare(lhs: int, rhs: int, pred: int) -> int:
	var hit: bool = false
	if pred == Opcodes.PRED_EQ:
		hit = lhs == rhs
	elif pred == Opcodes.PRED_NE:
		hit = lhs != rhs
	elif pred == Opcodes.PRED_LT:
		hit = lhs < rhs
	elif pred == Opcodes.PRED_LE:
		hit = lhs <= rhs
	elif pred == Opcodes.PRED_GT:
		hit = lhs > rhs
	elif pred == Opcodes.PRED_GE:
		hit = lhs >= rhs
	if hit:
		return 1
	return 0


static func _finish(ok: bool, reason: String, gas_used: int, vars: PackedInt64Array) -> Dictionary:
	return {
		Opcodes.KEY_OK: ok,
		Opcodes.KEY_REASON: reason,
		Opcodes.KEY_GAS_USED: gas_used,
		Opcodes.KEY_VARS: vars,
	}
