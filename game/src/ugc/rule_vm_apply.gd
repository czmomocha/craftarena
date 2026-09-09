class_name RuleVmApply
extends RefCounted

## Applies one decoded Rule VM op to working slots. Host ops go through
## RuleVmHost. CountInZone reports extra gas equal to the result count.

const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")
const HostGd := preload("res://src/ugc/rule_vm_host.gd")


static func apply(work: PackedInt64Array, bag: Dictionary, host: HostGd) -> Dictionary:
	var op: int = bag.get(Opcodes.KEY_OP, -1)
	if op == Opcodes.OP_HALT or op == Opcodes.OP_NOP:
		return _ok(0)
	if op == Opcodes.OP_LOAD_I64:
		var dest: int = bag.get(Opcodes.KEY_DEST, -1)
		if not Opcodes.slot_ok(dest):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		work[dest] = bag.get(Opcodes.KEY_VALUE, 0)
		return _ok(0)
	if op == Opcodes.OP_GET_VAR or op == Opcodes.OP_SET_VAR:
		var dest2: int = bag.get(Opcodes.KEY_DEST, -1)
		var src: int = bag.get(Opcodes.KEY_SRC, -1)
		if not Opcodes.slot_ok(dest2) or not Opcodes.slot_ok(src):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		work[dest2] = work[src]
		return _ok(0)
	if op == Opcodes.OP_COMPARE:
		return _compare(work, bag)
	if op == Opcodes.OP_LOGIC:
		return _logic(work, bag)
	if host == null:
		return _fail(Opcodes.REASON_HOST_MISSING)
	if op == Opcodes.OP_GET_FIELD:
		return _get_field(work, bag, host)
	if op == Opcodes.OP_COUNT_IN_ZONE:
		return _count_in_zone(work, bag, host)
	if op == Opcodes.OP_SPAWN:
		return _spawn(work, bag, host)
	if op == Opcodes.OP_DESPAWN:
		return _despawn(work, bag, host)
	if op == Opcodes.OP_APPLY_EFFECT:
		return _apply_effect(work, bag, host)
	if op == Opcodes.OP_EMIT_EVENT:
		return _emit_event(work, bag, host)
	return _fail(Opcodes.REASON_DECODE_UNKNOWN_OPCODE)


static func _compare(work: PackedInt64Array, bag: Dictionary) -> Dictionary:
	var dest: int = bag.get(Opcodes.KEY_DEST, -1)
	var lhs: int = bag.get(Opcodes.KEY_LHS, -1)
	var rhs: int = bag.get(Opcodes.KEY_RHS, -1)
	var pred: int = bag.get(Opcodes.KEY_PRED, -1)
	if not Opcodes.slot_ok(dest) or not Opcodes.slot_ok(lhs) or not Opcodes.slot_ok(rhs):
		return _fail(Opcodes.REASON_DECODE_SLOT)
	if not Opcodes.pred_ok(pred):
		return _fail(Opcodes.REASON_DECODE_PREDICATE)
	var left: int = work[lhs]
	var right: int = work[rhs]
	var hit: bool = false
	if pred == Opcodes.PRED_EQ:
		hit = left == right
	elif pred == Opcodes.PRED_NE:
		hit = left != right
	elif pred == Opcodes.PRED_LT:
		hit = left < right
	elif pred == Opcodes.PRED_LE:
		hit = left <= right
	elif pred == Opcodes.PRED_GT:
		hit = left > right
	elif pred == Opcodes.PRED_GE:
		hit = left >= right
	if hit:
		work[dest] = 1
	else:
		work[dest] = 0
	return _ok(0)


static func _logic(work: PackedInt64Array, bag: Dictionary) -> Dictionary:
	var dest: int = bag.get(Opcodes.KEY_DEST, -1)
	var lhs: int = bag.get(Opcodes.KEY_LHS, -1)
	var rhs: int = bag.get(Opcodes.KEY_RHS, -1)
	var pred: int = bag.get(Opcodes.KEY_PRED, -1)
	if not Opcodes.slot_ok(dest) or not Opcodes.slot_ok(lhs) or not Opcodes.slot_ok(rhs):
		return _fail(Opcodes.REASON_DECODE_SLOT)
	if not Opcodes.logic_ok(pred):
		return _fail(Opcodes.REASON_DECODE_PREDICATE)
	var left: bool = work[lhs] != 0
	var right: bool = work[rhs] != 0
	var hit: bool = false
	if pred == Opcodes.LOGIC_AND:
		hit = left and right
	elif pred == Opcodes.LOGIC_OR:
		hit = left or right
	elif pred == Opcodes.LOGIC_NOT:
		hit = not left
	if hit:
		work[dest] = 1
	else:
		work[dest] = 0
	return _ok(0)


static func _get_field(work: PackedInt64Array, bag: Dictionary, host: HostGd) -> Dictionary:
	var dest: int = bag.get(Opcodes.KEY_DEST, -1)
	var src: int = bag.get(Opcodes.KEY_SRC, -1)
	var field_id: int = bag.get(Opcodes.KEY_FIELD, -1)
	if not Opcodes.slot_ok(dest) or not Opcodes.slot_ok(src):
		return _fail(Opcodes.REASON_DECODE_SLOT)
	if not Opcodes.field_ok(field_id):
		return _fail(Opcodes.REASON_HOST_REFUSED)
	var got: Dictionary = host.get_field(work[src], field_id)
	var ok: bool = got.get(Opcodes.KEY_OK, false)
	if not ok:
		return _fail(Opcodes.REASON_HOST_REFUSED)
	work[dest] = got.get(Opcodes.KEY_VALUE, 0)
	return _ok(0)


static func _count_in_zone(work: PackedInt64Array, bag: Dictionary, host: HostGd) -> Dictionary:
	var dest: int = bag.get(Opcodes.KEY_DEST, -1)
	var src: int = bag.get(Opcodes.KEY_SRC, -1)
	var tag_id: int = bag.get(Opcodes.KEY_TAG, -1)
	if not Opcodes.slot_ok(dest) or not Opcodes.slot_ok(src):
		return _fail(Opcodes.REASON_DECODE_SLOT)
	if not Opcodes.tag_ok(tag_id):
		return _fail(Opcodes.REASON_HOST_REFUSED)
	var got: Dictionary = host.count_in_zone(work[src], tag_id)
	var ok: bool = got.get(Opcodes.KEY_OK, false)
	if not ok:
		return _fail(Opcodes.REASON_HOST_REFUSED)
	var count: int = got.get(Opcodes.KEY_COUNT, 0)
	if count < 0:
		return _fail(Opcodes.REASON_HOST_REFUSED)
	work[dest] = count
	return _ok(count)


static func _spawn(work: PackedInt64Array, bag: Dictionary, host: HostGd) -> Dictionary:
	var dest: int = bag.get(Opcodes.KEY_DEST, -1)
	var src: int = bag.get(Opcodes.KEY_SRC, -1)
	var count_slot: int = bag.get(Opcodes.KEY_COUNT, -1)
	var archetype: int = bag.get(Opcodes.KEY_ARCHETYPE, -1)
	if not Opcodes.slot_ok(dest) or not Opcodes.slot_ok(src) or not Opcodes.slot_ok(count_slot):
		return _fail(Opcodes.REASON_DECODE_SLOT)
	if not Opcodes.archetype_ok(archetype):
		return _fail(Opcodes.REASON_HOST_REFUSED)
	var got: Dictionary = host.spawn(archetype, work[src], work[count_slot])
	var ok: bool = got.get(Opcodes.KEY_OK, false)
	if not ok:
		return _fail(Opcodes.REASON_HOST_REFUSED)
	work[dest] = got.get("entity_id", 0)
	return _ok(0)


static func _despawn(work: PackedInt64Array, bag: Dictionary, host: HostGd) -> Dictionary:
	var src: int = bag.get(Opcodes.KEY_SRC, -1)
	if not Opcodes.slot_ok(src):
		return _fail(Opcodes.REASON_DECODE_SLOT)
	var got: Dictionary = host.despawn(work[src])
	var ok: bool = got.get(Opcodes.KEY_OK, false)
	if not ok:
		return _fail(Opcodes.REASON_HOST_REFUSED)
	return _ok(0)


static func _apply_effect(work: PackedInt64Array, bag: Dictionary, host: HostGd) -> Dictionary:
	var src: int = bag.get(Opcodes.KEY_SRC, -1)
	var mag: int = bag.get(Opcodes.KEY_MAGNITUDE, -1)
	var effect: int = bag.get(Opcodes.KEY_EFFECT, -1)
	if not Opcodes.slot_ok(src) or not Opcodes.slot_ok(mag):
		return _fail(Opcodes.REASON_DECODE_SLOT)
	if not Opcodes.effect_ok(effect):
		return _fail(Opcodes.REASON_HOST_REFUSED)
	var got: Dictionary = host.apply_effect(work[src], effect, work[mag])
	var ok: bool = got.get(Opcodes.KEY_OK, false)
	if not ok:
		return _fail(Opcodes.REASON_HOST_REFUSED)
	return _ok(0)


static func _emit_event(work: PackedInt64Array, bag: Dictionary, host: HostGd) -> Dictionary:
	var src: int = bag.get(Opcodes.KEY_SRC, -1)
	var event_id: int = bag.get(Opcodes.KEY_NAME, -1)
	if not Opcodes.slot_ok(src):
		return _fail(Opcodes.REASON_DECODE_SLOT)
	if not Opcodes.event_name_ok(event_id):
		return _fail(Opcodes.REASON_HOST_REFUSED)
	var got: Dictionary = host.emit_event(event_id, work[src])
	var ok: bool = got.get(Opcodes.KEY_OK, false)
	if not ok:
		return _fail(Opcodes.REASON_HOST_REFUSED)
	return _ok(0)


static func _ok(extra_gas: int) -> Dictionary:
	return {
		Opcodes.KEY_OK: true,
		Opcodes.KEY_REASON: Opcodes.REASON_OK,
		Opcodes.KEY_EXTRA_GAS: extra_gas,
	}


static func _fail(reason: String) -> Dictionary:
	return {
		Opcodes.KEY_OK: false,
		Opcodes.KEY_REASON: reason,
		Opcodes.KEY_EXTRA_GAS: 0,
	}
