class_name RuleVm
extends RefCounted

## Versioned bytecode interpreter for Rule VM v1 (CD-42 §2).
## Client and server run this same static-typed GDScript. Over-gas aborts this
## content logic with a locatable reason and does not commit variable writes.
## Graphs compile to bytecode first; run() never walks JSON, generates
## GDScript, or loads scripts. Preview / match fire programs via RuleVmDispatch.

const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")
const CodecGd := preload("res://src/ugc/rule_vm_codec.gd")
const CompilerGd := preload("res://src/ugc/rule_vm_compiler.gd")
const ApplyGd := preload("res://src/ugc/rule_vm_apply.gd")
const HostGd := preload("res://src/ugc/rule_vm_host.gd")


static func encode(graph_gas: int, ops: Array) -> PackedByteArray:
	return CodecGd.encode(graph_gas, ops)


static func decode(bytes: PackedByteArray) -> Dictionary:
	return CodecGd.decode(bytes)


static func compile(graph: Dictionary) -> Dictionary:
	return CompilerGd.compile(graph)


static func empty_vars() -> PackedInt64Array:
	var vars: PackedInt64Array = PackedInt64Array()
	vars.resize(Opcodes.SLOT_COUNT)
	return vars


static func run(
	bytes: PackedByteArray,
	vars: PackedInt64Array,
	tick_gas: int = -1,
	chain_gas: int = -1,
	host: HostGd = null
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
	if host != null:
		host.begin()
	var work: PackedInt64Array = vars.duplicate()
	var gas_used: int = 0
	var raw_ops: Variant = decoded.get(Opcodes.KEY_OPS, [])
	if typeof(raw_ops) != TYPE_ARRAY:
		return _abort(host, false, Opcodes.REASON_DECODE_UNKNOWN_OPCODE, 0, vars)
	var ops: Array = raw_ops
	for item: Variant in ops:
		if typeof(item) != TYPE_DICTIONARY:
			return _abort(host, false, Opcodes.REASON_DECODE_UNKNOWN_OPCODE, gas_used, vars)
		var bag: Dictionary = item
		var op: int = bag.get(Opcodes.KEY_OP, -1)
		var cost: int = Opcodes.cost(op)
		if cost < 1 or gas_used > budget - cost:
			return _abort(host, false, Opcodes.REASON_GAS_EXCEEDED, gas_used, vars)
		gas_used += cost
		var step: Dictionary = ApplyGd.apply(work, bag, host)
		var step_ok: bool = step.get(Opcodes.KEY_OK, false)
		if not step_ok:
			return _abort(
				host,
				false,
				str(step.get(Opcodes.KEY_REASON, Opcodes.REASON_DECODE_UNKNOWN_OPCODE)),
				gas_used,
				vars
			)
		var extra: int = step.get(Opcodes.KEY_EXTRA_GAS, 0)
		if extra < 0 or gas_used > budget - extra:
			return _abort(host, false, Opcodes.REASON_GAS_EXCEEDED, gas_used, vars)
		gas_used += extra
		if op == Opcodes.OP_HALT:
			break
	if host != null:
		host.commit()
	return _finish(true, Opcodes.REASON_OK, gas_used, work)


static func _abort(
	host: HostGd,
	ok: bool,
	reason: String,
	gas_used: int,
	vars: PackedInt64Array
) -> Dictionary:
	if host != null:
		host.rollback()
	return _finish(ok, reason, gas_used, vars)


static func _finish(ok: bool, reason: String, gas_used: int, vars: PackedInt64Array) -> Dictionary:
	return {
		Opcodes.KEY_OK: ok,
		Opcodes.KEY_REASON: reason,
		Opcodes.KEY_GAS_USED: gas_used,
		Opcodes.KEY_VARS: vars,
	}
