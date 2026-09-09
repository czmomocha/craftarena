class_name RuleVmCodec
extends RefCounted

## Versioned Rule VM bytecode envelope. Little-endian PackedByteArray, same
## style as MatchFrameCodec. Decode rejects unknown version / opcode / slot /
## predicate, truncation, trailing bytes, and non-zero reserved. Does not walk
## JSON graphs or emit GDScript (CD-42 §2).

const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")


static func encode(graph_gas: int, ops: Array) -> PackedByteArray:
	if graph_gas < 0 or graph_gas > 4294967295:
		return PackedByteArray()
	var code: PackedByteArray = PackedByteArray()
	for item: Variant in ops:
		if typeof(item) != TYPE_DICTIONARY:
			return PackedByteArray()
		var bag: Dictionary = item
		if not _append_op(code, bag):
			return PackedByteArray()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Opcodes.HEADER_SIZE + code.size())
	bytes.encode_u8(0, Opcodes.MAGIC_0)
	bytes.encode_u8(1, Opcodes.MAGIC_1)
	bytes.encode_u8(2, Opcodes.MAGIC_2)
	bytes.encode_u8(3, Opcodes.MAGIC_3)
	bytes.encode_u16(4, Opcodes.RULESET_VERSION)
	bytes.encode_u16(6, 0)
	bytes.encode_u32(8, graph_gas)
	bytes.encode_u32(12, code.size())
	var i: int = 0
	while i < code.size():
		bytes.encode_u8(Opcodes.HEADER_SIZE + i, code.decode_u8(i))
		i += 1
	return bytes


static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < Opcodes.HEADER_SIZE:
		return _fail(Opcodes.REASON_DECODE_TRUNCATED)
	if (
		bytes.decode_u8(0) != Opcodes.MAGIC_0
		or bytes.decode_u8(1) != Opcodes.MAGIC_1
		or bytes.decode_u8(2) != Opcodes.MAGIC_2
		or bytes.decode_u8(3) != Opcodes.MAGIC_3
	):
		return _fail(Opcodes.REASON_DECODE_MAGIC)
	var version: int = bytes.decode_u16(4)
	if version != Opcodes.RULESET_VERSION:
		return _fail(Opcodes.REASON_DECODE_VERSION)
	if bytes.decode_u16(6) != 0:
		return _fail(Opcodes.REASON_DECODE_RESERVED)
	var graph_gas: int = bytes.decode_u32(8)
	var code_size: int = bytes.decode_u32(12)
	var needed: int = Opcodes.HEADER_SIZE + code_size
	if bytes.size() < needed:
		return _fail(Opcodes.REASON_DECODE_TRUNCATED)
	if bytes.size() > needed:
		return _fail(Opcodes.REASON_DECODE_TRAILING)
	var ops: Array[Dictionary] = []
	var pc: int = 0
	while pc < code_size:
		var parsed: Dictionary = _read_op(bytes, Opcodes.HEADER_SIZE + pc, code_size - pc)
		var parsed_ok: bool = parsed.get(Opcodes.KEY_OK, false)
		if not parsed_ok:
			return _fail(str(parsed.get(Opcodes.KEY_REASON, Opcodes.REASON_DECODE_TRUNCATED)))
		var bag: Dictionary = parsed.get(Opcodes.KEY_OP, {})
		if typeof(bag) != TYPE_DICTIONARY:
			return _fail(Opcodes.REASON_DECODE_UNKNOWN_OPCODE)
		ops.append(bag)
		var consumed: int = parsed.get("size", 0)
		if consumed < 1:
			return _fail(Opcodes.REASON_DECODE_TRUNCATED)
		pc += consumed
	return {
		Opcodes.KEY_OK: true,
		Opcodes.KEY_REASON: Opcodes.REASON_OK,
		Opcodes.KEY_RULESET_VERSION: version,
		Opcodes.KEY_GRAPH_GAS: graph_gas,
		Opcodes.KEY_OPS: ops,
	}


static func _append_op(code: PackedByteArray, bag: Dictionary) -> bool:
	if not bag.has(Opcodes.KEY_OP) or typeof(bag[Opcodes.KEY_OP]) != TYPE_INT:
		return false
	var op: int = bag[Opcodes.KEY_OP]
	if op == Opcodes.OP_HALT or op == Opcodes.OP_NOP:
		code.append(op)
		return true
	if op == Opcodes.OP_LOAD_I64:
		var dest: int = _int_field(bag, Opcodes.KEY_DEST)
		if not bag.has(Opcodes.KEY_VALUE) or typeof(bag[Opcodes.KEY_VALUE]) != TYPE_INT:
			return false
		var value: int = bag[Opcodes.KEY_VALUE]
		if not Opcodes.slot_ok(dest):
			return false
		var start: int = code.size()
		code.resize(start + 10)
		code.encode_u8(start, op)
		code.encode_u8(start + 1, dest)
		code.encode_s64(start + 2, value)
		return true
	if op == Opcodes.OP_GET_VAR or op == Opcodes.OP_SET_VAR:
		var dest2: int = _int_field(bag, Opcodes.KEY_DEST)
		var src: int = _int_field(bag, Opcodes.KEY_SRC)
		if not Opcodes.slot_ok(dest2) or not Opcodes.slot_ok(src):
			return false
		code.append(op)
		code.append(dest2)
		code.append(src)
		return true
	if op == Opcodes.OP_COMPARE or op == Opcodes.OP_LOGIC:
		var dest3: int = _int_field(bag, Opcodes.KEY_DEST)
		var lhs: int = _int_field(bag, Opcodes.KEY_LHS)
		var rhs: int = _int_field(bag, Opcodes.KEY_RHS)
		var pred: int = _int_field(bag, Opcodes.KEY_PRED)
		if not Opcodes.slot_ok(dest3) or not Opcodes.slot_ok(lhs) or not Opcodes.slot_ok(rhs):
			return false
		if op == Opcodes.OP_COMPARE and not Opcodes.pred_ok(pred):
			return false
		if op == Opcodes.OP_LOGIC and not Opcodes.logic_ok(pred):
			return false
		code.append(op)
		code.append(dest3)
		code.append(lhs)
		code.append(rhs)
		code.append(pred)
		return true
	if op == Opcodes.OP_GET_FIELD or op == Opcodes.OP_COUNT_IN_ZONE:
		var dest_f: int = _int_field(bag, Opcodes.KEY_DEST)
		var src_f: int = _int_field(bag, Opcodes.KEY_SRC)
		var extra_key: String = Opcodes.KEY_FIELD
		if op == Opcodes.OP_COUNT_IN_ZONE:
			extra_key = Opcodes.KEY_TAG
		var extra: int = _int_field(bag, extra_key)
		if not Opcodes.slot_ok(dest_f) or not Opcodes.slot_ok(src_f):
			return false
		if op == Opcodes.OP_GET_FIELD and not Opcodes.field_ok(extra):
			return false
		if op == Opcodes.OP_COUNT_IN_ZONE and not Opcodes.tag_ok(extra):
			return false
		code.append(op)
		code.append(dest_f)
		code.append(src_f)
		code.append(extra)
		return true
	if op == Opcodes.OP_SPAWN:
		var dest4: int = _int_field(bag, Opcodes.KEY_DEST)
		var src2: int = _int_field(bag, Opcodes.KEY_SRC)
		var count_slot: int = _int_field(bag, Opcodes.KEY_COUNT)
		var archetype: int = _int_field(bag, Opcodes.KEY_ARCHETYPE)
		if not Opcodes.slot_ok(dest4) or not Opcodes.slot_ok(src2) or not Opcodes.slot_ok(count_slot):
			return false
		if not Opcodes.archetype_ok(archetype):
			return false
		code.append(op)
		code.append(dest4)
		code.append(archetype)
		code.append(src2)
		code.append(count_slot)
		return true
	if op == Opcodes.OP_DESPAWN:
		var src3: int = _int_field(bag, Opcodes.KEY_SRC)
		if not Opcodes.slot_ok(src3):
			return false
		code.append(op)
		code.append(src3)
		return true
	if op == Opcodes.OP_APPLY_EFFECT:
		var src4: int = _int_field(bag, Opcodes.KEY_SRC)
		var mag: int = _int_field(bag, Opcodes.KEY_MAGNITUDE)
		var effect: int = _int_field(bag, Opcodes.KEY_EFFECT)
		if not Opcodes.slot_ok(src4) or not Opcodes.slot_ok(mag):
			return false
		if not Opcodes.effect_ok(effect):
			return false
		code.append(op)
		code.append(src4)
		code.append(effect)
		code.append(mag)
		return true
	if op == Opcodes.OP_EMIT_EVENT:
		var src5: int = _int_field(bag, Opcodes.KEY_SRC)
		var event_id: int = _int_field(bag, Opcodes.KEY_NAME)
		if not Opcodes.slot_ok(src5):
			return false
		if not Opcodes.event_name_ok(event_id):
			return false
		code.append(op)
		code.append(event_id)
		code.append(src5)
		return true
	return false


static func _read_op(bytes: PackedByteArray, offset: int, remaining: int) -> Dictionary:
	if remaining < 1:
		return _fail(Opcodes.REASON_DECODE_TRUNCATED)
	var op: int = bytes.decode_u8(offset)
	if not Opcodes.is_known(op):
		return _fail(Opcodes.REASON_DECODE_UNKNOWN_OPCODE)
	if op == Opcodes.OP_HALT or op == Opcodes.OP_NOP:
		return _op_ok({Opcodes.KEY_OP: op}, 1)
	if op == Opcodes.OP_LOAD_I64:
		if remaining < 10:
			return _fail(Opcodes.REASON_DECODE_TRUNCATED)
		var dest: int = bytes.decode_u8(offset + 1)
		if not Opcodes.slot_ok(dest):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		return _op_ok({
			Opcodes.KEY_OP: op,
			Opcodes.KEY_DEST: dest,
			Opcodes.KEY_VALUE: bytes.decode_s64(offset + 2),
		}, 10)
	if op == Opcodes.OP_GET_VAR or op == Opcodes.OP_SET_VAR:
		if remaining < 3:
			return _fail(Opcodes.REASON_DECODE_TRUNCATED)
		var dest2: int = bytes.decode_u8(offset + 1)
		var src: int = bytes.decode_u8(offset + 2)
		if not Opcodes.slot_ok(dest2) or not Opcodes.slot_ok(src):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		return _op_ok({
			Opcodes.KEY_OP: op,
			Opcodes.KEY_DEST: dest2,
			Opcodes.KEY_SRC: src,
		}, 3)
	if op == Opcodes.OP_COMPARE or op == Opcodes.OP_LOGIC:
		if remaining < 5:
			return _fail(Opcodes.REASON_DECODE_TRUNCATED)
		var dest3: int = bytes.decode_u8(offset + 1)
		var lhs: int = bytes.decode_u8(offset + 2)
		var rhs: int = bytes.decode_u8(offset + 3)
		var pred: int = bytes.decode_u8(offset + 4)
		if not Opcodes.slot_ok(dest3) or not Opcodes.slot_ok(lhs) or not Opcodes.slot_ok(rhs):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		if op == Opcodes.OP_COMPARE and not Opcodes.pred_ok(pred):
			return _fail(Opcodes.REASON_DECODE_PREDICATE)
		if op == Opcodes.OP_LOGIC and not Opcodes.logic_ok(pred):
			return _fail(Opcodes.REASON_DECODE_PREDICATE)
		return _op_ok({
			Opcodes.KEY_OP: op,
			Opcodes.KEY_DEST: dest3,
			Opcodes.KEY_LHS: lhs,
			Opcodes.KEY_RHS: rhs,
			Opcodes.KEY_PRED: pred,
		}, 5)
	if op == Opcodes.OP_GET_FIELD or op == Opcodes.OP_COUNT_IN_ZONE:
		if remaining < 4:
			return _fail(Opcodes.REASON_DECODE_TRUNCATED)
		var dest4: int = bytes.decode_u8(offset + 1)
		var src2: int = bytes.decode_u8(offset + 2)
		var extra: int = bytes.decode_u8(offset + 3)
		if not Opcodes.slot_ok(dest4) or not Opcodes.slot_ok(src2):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		if op == Opcodes.OP_GET_FIELD and not Opcodes.field_ok(extra):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		if op == Opcodes.OP_COUNT_IN_ZONE and not Opcodes.tag_ok(extra):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		var extra_key: String = Opcodes.KEY_FIELD
		if op == Opcodes.OP_COUNT_IN_ZONE:
			extra_key = Opcodes.KEY_TAG
		return _op_ok({
			Opcodes.KEY_OP: op,
			Opcodes.KEY_DEST: dest4,
			Opcodes.KEY_SRC: src2,
			extra_key: extra,
		}, 4)
	if op == Opcodes.OP_SPAWN:
		if remaining < 5:
			return _fail(Opcodes.REASON_DECODE_TRUNCATED)
		var dest5: int = bytes.decode_u8(offset + 1)
		var archetype: int = bytes.decode_u8(offset + 2)
		var src3: int = bytes.decode_u8(offset + 3)
		var count_slot: int = bytes.decode_u8(offset + 4)
		if not Opcodes.slot_ok(dest5) or not Opcodes.slot_ok(src3) or not Opcodes.slot_ok(count_slot):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		if not Opcodes.archetype_ok(archetype):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		return _op_ok({
			Opcodes.KEY_OP: op,
			Opcodes.KEY_DEST: dest5,
			Opcodes.KEY_ARCHETYPE: archetype,
			Opcodes.KEY_SRC: src3,
			Opcodes.KEY_COUNT: count_slot,
		}, 5)
	if op == Opcodes.OP_DESPAWN:
		if remaining < 2:
			return _fail(Opcodes.REASON_DECODE_TRUNCATED)
		var src4: int = bytes.decode_u8(offset + 1)
		if not Opcodes.slot_ok(src4):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		return _op_ok({Opcodes.KEY_OP: op, Opcodes.KEY_SRC: src4}, 2)
	if op == Opcodes.OP_APPLY_EFFECT:
		if remaining < 4:
			return _fail(Opcodes.REASON_DECODE_TRUNCATED)
		var src5: int = bytes.decode_u8(offset + 1)
		var effect: int = bytes.decode_u8(offset + 2)
		var mag: int = bytes.decode_u8(offset + 3)
		if not Opcodes.slot_ok(src5) or not Opcodes.slot_ok(mag):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		if not Opcodes.effect_ok(effect):
			return _fail(Opcodes.REASON_DECODE_SLOT)
		return _op_ok({
			Opcodes.KEY_OP: op,
			Opcodes.KEY_SRC: src5,
			Opcodes.KEY_EFFECT: effect,
			Opcodes.KEY_MAGNITUDE: mag,
		}, 4)
	if remaining < 3:
		return _fail(Opcodes.REASON_DECODE_TRUNCATED)
	var event_id: int = bytes.decode_u8(offset + 1)
	var src6: int = bytes.decode_u8(offset + 2)
	if not Opcodes.slot_ok(src6):
		return _fail(Opcodes.REASON_DECODE_SLOT)
	if not Opcodes.event_name_ok(event_id):
		return _fail(Opcodes.REASON_DECODE_SLOT)
	return _op_ok({
		Opcodes.KEY_OP: op,
		Opcodes.KEY_NAME: event_id,
		Opcodes.KEY_SRC: src6,
	}, 3)


static func _int_field(bag: Dictionary, key: String) -> int:
	if not bag.has(key) or typeof(bag[key]) != TYPE_INT:
		return -1
	return bag[key]


static func _fail(reason: String) -> Dictionary:
	return {Opcodes.KEY_OK: false, Opcodes.KEY_REASON: reason}


static func _op_ok(bag: Dictionary, size: int) -> Dictionary:
	return {Opcodes.KEY_OK: true, Opcodes.KEY_REASON: Opcodes.REASON_OK, Opcodes.KEY_OP: bag, "size": size}
