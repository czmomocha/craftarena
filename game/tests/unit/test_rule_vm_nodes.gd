extends GutTest

## M4a chapter 4: §2.1 Query / Logic / Action subset. CountInZone charges
## extra gas equal to the result count. Host writes commit only on success.

const HostGd := preload("res://src/ugc/rule_vm_host.gd")
const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")
const RuleVmGd := preload("res://src/ugc/rule_vm.gd")


func test_logic_and_or_not() -> void:
	var compiled: Dictionary = RuleVmGd.compile(_started([
		_load_node(0, 1),
		_load_node(1, 0),
		_logic_node(2, 0, 1, Opcodes.LOGIC_NAME_AND),
		_logic_node(3, 0, 1, Opcodes.LOGIC_NAME_OR),
		_logic_node(4, 1, 0, Opcodes.LOGIC_NAME_NOT),
	], 16))
	var bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	var ran: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars())
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	assert_true(ran_ok)
	var slots: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(slots[2], 0)
	assert_eq(slots[3], 1)
	assert_eq(slots[4], 1)


func test_get_field_and_count_in_zone_charge_results() -> void:
	var host: HostGd = HostGd.new()
	host.put_field(7, Opcodes.FIELD_HEALTH_CURRENT, 12)
	host.put_zone_count(3, Opcodes.TAG_PLAYER, 4)
	var compiled: Dictionary = RuleVmGd.compile(_started([
		_load_node(0, 7),
		{
			Opcodes.KEY_KIND: Opcodes.KIND_GET_FIELD,
			Opcodes.KEY_DEST: 1,
			Opcodes.KEY_SRC: 0,
			Opcodes.KEY_FIELD: Opcodes.FIELD_NAME_HEALTH_CURRENT,
		},
		_load_node(2, 3),
		{
			Opcodes.KEY_KIND: Opcodes.KIND_COUNT_IN_ZONE,
			Opcodes.KEY_DEST: 3,
			Opcodes.KEY_SRC: 2,
			Opcodes.KEY_TAG: Opcodes.TAG_NAME_PLAYER,
		},
	], 16))
	var bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	var ran: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars(), -1, -1, host)
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	assert_true(ran_ok)
	var slots: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(slots[1], 12)
	assert_eq(slots[3], 4)
	var used: int = ran.get(Opcodes.KEY_GAS_USED, 0)
	assert_eq(used, 9)


func test_count_in_zone_over_gas_does_not_commit() -> void:
	var host: HostGd = HostGd.new()
	host.put_zone_count(1, Opcodes.TAG_PLAYER, 8)
	var compiled: Dictionary = RuleVmGd.compile(_started([
		_load_node(0, 1),
		{
			Opcodes.KEY_KIND: Opcodes.KIND_COUNT_IN_ZONE,
			Opcodes.KEY_DEST: 1,
			Opcodes.KEY_SRC: 0,
			Opcodes.KEY_TAG: Opcodes.TAG_NAME_PLAYER,
		},
	], 3))
	var bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	var start: PackedInt64Array = RuleVmGd.empty_vars()
	start[1] = 5
	var ran: Dictionary = RuleVmGd.run(bytes, start, -1, -1, host)
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	var reason: String = ran.get(Opcodes.KEY_REASON, "")
	assert_false(ran_ok)
	assert_eq(reason, Opcodes.REASON_GAS_EXCEEDED)
	var slots: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(slots[1], 5)


func test_spawn_effect_event_commit_and_rollback() -> void:
	var host: HostGd = HostGd.new()
	var compiled: Dictionary = RuleVmGd.compile(_started([
		_load_node(0, 9),
		_load_node(1, 1),
		{
			Opcodes.KEY_KIND: Opcodes.KIND_SPAWN,
			Opcodes.KEY_DEST: 2,
			Opcodes.KEY_ARCHETYPE: Opcodes.ARCHETYPE_NAME_DUMMY,
			Opcodes.KEY_SRC: 0,
			Opcodes.KEY_COUNT: 1,
		},
		{
			Opcodes.KEY_KIND: Opcodes.KIND_APPLY_EFFECT,
			Opcodes.KEY_SRC: 2,
			Opcodes.KEY_EFFECT: Opcodes.EFFECT_NAME_DAMAGE,
			Opcodes.KEY_MAGNITUDE: 1,
		},
		{
			Opcodes.KEY_KIND: Opcodes.KIND_EMIT_GAME_EVENT,
			Opcodes.KEY_NAME: Opcodes.EVENT_NAME_SIGNAL,
			Opcodes.KEY_SRC: 2,
		},
		{Opcodes.KEY_KIND: Opcodes.KIND_DESPAWN, Opcodes.KEY_SRC: 2},
	], 16))
	var bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	var ran: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars(), -1, -1, host)
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	assert_true(ran_ok)
	var slots: PackedInt64Array = ran.get(Opcodes.KEY_VARS, PackedInt64Array())
	assert_eq(slots[2], 1)
	assert_eq(host.spawned.size(), 1)
	assert_eq(host.effects.size(), 1)
	assert_eq(host.events.size(), 1)
	assert_eq(host.despawned.size(), 1)
	var tight: Dictionary = RuleVmGd.compile(_started([
		_load_node(0, 9),
		_load_node(1, 1),
		{
			Opcodes.KEY_KIND: Opcodes.KIND_SPAWN,
			Opcodes.KEY_DEST: 2,
			Opcodes.KEY_ARCHETYPE: Opcodes.ARCHETYPE_NAME_DUMMY,
			Opcodes.KEY_SRC: 0,
			Opcodes.KEY_COUNT: 1,
		},
	], 1))
	var tight_bytes: PackedByteArray = tight.get(Opcodes.KEY_BYTES, PackedByteArray())
	var host2: HostGd = HostGd.new()
	var failed: Dictionary = RuleVmGd.run(tight_bytes, RuleVmGd.empty_vars(), -1, -1, host2)
	var failed_ok: bool = failed.get(Opcodes.KEY_OK, false)
	assert_false(failed_ok)
	assert_eq(host2.spawned.size(), 0)


func test_host_missing_and_unknown_whitelist_rejected() -> void:
	var compiled: Dictionary = RuleVmGd.compile(_started([
		_load_node(0, 1),
		{
			Opcodes.KEY_KIND: Opcodes.KIND_GET_FIELD,
			Opcodes.KEY_DEST: 1,
			Opcodes.KEY_SRC: 0,
			Opcodes.KEY_FIELD: Opcodes.FIELD_NAME_HEALTH_CURRENT,
		},
	], 8))
	var bytes: PackedByteArray = compiled.get(Opcodes.KEY_BYTES, PackedByteArray())
	var ran: Dictionary = RuleVmGd.run(bytes, RuleVmGd.empty_vars())
	var ran_ok: bool = ran.get(Opcodes.KEY_OK, false)
	var reason: String = ran.get(Opcodes.KEY_REASON, "")
	assert_false(ran_ok)
	assert_eq(reason, Opcodes.REASON_HOST_MISSING)
	_assert_compile_reason(_started([
		{
			Opcodes.KEY_KIND: Opcodes.KIND_GET_FIELD,
			Opcodes.KEY_DEST: 0,
			Opcodes.KEY_SRC: 1,
			Opcodes.KEY_FIELD: "velocity.vx",
		},
	], 4), Opcodes.REASON_COMPILE_FIELD)


func _assert_compile_reason(graph: Dictionary, reason: String) -> void:
	var compiled: Dictionary = RuleVmGd.compile(graph)
	var compile_ok: bool = compiled.get(Opcodes.KEY_OK, false)
	assert_false(compile_ok, reason)
	var got: String = compiled.get(Opcodes.KEY_REASON, "")
	assert_eq(got, reason)


func _started(nodes: Array, graph_gas: int) -> Dictionary:
	return {
		Opcodes.KEY_RULESET_VERSION: Opcodes.RULESET_VERSION,
		Opcodes.KEY_GRAPH_GAS: graph_gas,
		Opcodes.KEY_EVENT: Opcodes.EVENT_ON_MATCH_STARTED,
		Opcodes.KEY_NODES: nodes,
	}


func _load_node(dest: int, value: int) -> Dictionary:
	return {
		Opcodes.KEY_KIND: Opcodes.KIND_LOAD_CONST,
		Opcodes.KEY_DEST: dest,
		Opcodes.KEY_VALUE: value,
	}


func _logic_node(dest: int, lhs: int, rhs: int, pred: String) -> Dictionary:
	return {
		Opcodes.KEY_KIND: Opcodes.KIND_LOGIC,
		Opcodes.KEY_DEST: dest,
		Opcodes.KEY_LHS: lhs,
		Opcodes.KEY_RHS: rhs,
		Opcodes.KEY_PRED: pred,
	}
