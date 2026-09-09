class_name RuleVmDispatch
extends RefCounted

## Binds compiled Rule VM programs by event and fires them from match / Preview.
## OnMatchStarted runs once; OnEveryTicks runs each notify. Shared int64 slots.
## Over-gas records a locatable reason and does not take down the match.
## run() still only consumes bytes. Other §2.1 events stay compile-rejected.

const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")
const RuleVmGd := preload("res://src/ugc/rule_vm.gd")

var tick_gas: int = -1
var chain_gas: int = -1
var started_count: int = 0
var tick_count: int = 0
var last_ok: bool = true
var last_reason: String = Opcodes.REASON_OK

var _programs: Dictionary = {}
var _vars: PackedInt64Array = PackedInt64Array()
var _started: bool = false


func _init() -> void:
	_vars = RuleVmGd.empty_vars()


func vars() -> PackedInt64Array:
	return _vars


func reset_run_state() -> void:
	_started = false
	_vars = RuleVmGd.empty_vars()
	started_count = 0
	tick_count = 0
	last_ok = true
	last_reason = Opcodes.REASON_OK


func bind_graph(graph: Dictionary) -> Dictionary:
	return bind_compiled(RuleVmGd.compile(graph))


func bind_compiled(compiled: Dictionary) -> Dictionary:
	var compile_ok: bool = compiled.get(Opcodes.KEY_OK, false)
	if not compile_ok:
		return _bind_fail(str(compiled.get(Opcodes.KEY_REASON, Opcodes.REASON_COMPILE_KEYS)))
	var event_name: String = compiled.get(Opcodes.KEY_EVENT, "")
	if not Opcodes.is_compile_event(event_name):
		return _bind_fail(Opcodes.REASON_COMPILE_EVENT)
	if _programs.has(event_name):
		return _bind_fail(Opcodes.REASON_BIND_DUPLICATE)
	var bytes_raw: Variant = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	if typeof(bytes_raw) != TYPE_PACKED_BYTE_ARRAY:
		return _bind_fail(Opcodes.REASON_COMPILE_ENCODE)
	var bytes: PackedByteArray = bytes_raw
	if bytes.size() < Opcodes.HEADER_SIZE:
		return _bind_fail(Opcodes.REASON_COMPILE_ENCODE)
	_programs[event_name] = bytes
	return {
		Opcodes.KEY_OK: true,
		Opcodes.KEY_REASON: Opcodes.REASON_OK,
		Opcodes.KEY_EVENT: event_name,
	}


func notify_match_started() -> Dictionary:
	if _started:
		return _remember(true, Opcodes.REASON_ALREADY_STARTED, 0)
	_started = true
	return _fire(Opcodes.EVENT_ON_MATCH_STARTED, true)


func notify_every_ticks() -> Dictionary:
	return _fire(Opcodes.EVENT_ON_EVERY_TICKS, false)


func _fire(event_name: String, is_start: bool) -> Dictionary:
	if not _programs.has(event_name):
		return _remember(true, Opcodes.REASON_OK, 0)
	var bytes: PackedByteArray = _programs[event_name]
	var ran: Dictionary = RuleVmGd.run(bytes, _vars, tick_gas, chain_gas)
	if is_start:
		started_count += 1
	else:
		tick_count += 1
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	var reason: String = str(ran.get(Opcodes.KEY_REASON, Opcodes.REASON_OK))
	var gas_used: int = ran.get(Opcodes.KEY_GAS_USED, 0)
	var next_raw: Variant = ran.get(Opcodes.KEY_VARS, _vars)
	if typeof(next_raw) == TYPE_PACKED_INT64_ARRAY:
		_vars = next_raw
	return _remember(ran_ok, reason, gas_used)


func _remember(ok: bool, reason: String, gas_used: int) -> Dictionary:
	last_ok = ok
	last_reason = reason
	return {
		Opcodes.KEY_OK: ok,
		Opcodes.KEY_REASON: reason,
		Opcodes.KEY_GAS_USED: gas_used,
		Opcodes.KEY_VARS: _vars,
	}


func _bind_fail(reason: String) -> Dictionary:
	return {
		Opcodes.KEY_OK: false,
		Opcodes.KEY_REASON: reason,
		Opcodes.KEY_EVENT: "",
	}
