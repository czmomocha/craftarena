class_name RuleVmCompiler
extends RefCounted

## Compiles a typed Rule VM graph to v1 bytecode (CD-42 §2).
## The interpreter still only runs PackedByteArray — this file is compile-time.
## It does not generate GDScript or load scripts. Chapter 4 accepts
## OnMatchStarted / OnEveryTicks plus the §2.1 Query / Logic / Action subset.
## LoadConst is a literal helper, not a §2.1 product node. Extra keys and
## unknown kinds/events are rejected.

const Opcodes := preload("res://src/ugc/rule_vm_opcodes.gd")
const CodecGd := preload("res://src/ugc/rule_vm_codec.gd")


static func compile(graph: Dictionary) -> Dictionary:
	var coerced: Variant = _coerce_json_ints(graph)
	if typeof(coerced) != TYPE_DICTIONARY:
		return _fail(Opcodes.REASON_COMPILE_KEYS)
	var body: Dictionary = coerced
	if body.size() != 4:
		return _fail(Opcodes.REASON_COMPILE_KEYS)
	if not body.has(Opcodes.KEY_RULESET_VERSION) or typeof(body[Opcodes.KEY_RULESET_VERSION]) != TYPE_INT:
		return _fail(Opcodes.REASON_COMPILE_KEYS)
	var version: int = body[Opcodes.KEY_RULESET_VERSION]
	if version != Opcodes.RULESET_VERSION:
		return _fail(Opcodes.REASON_COMPILE_VERSION)
	if not body.has(Opcodes.KEY_GRAPH_GAS) or typeof(body[Opcodes.KEY_GRAPH_GAS]) != TYPE_INT:
		return _fail(Opcodes.REASON_COMPILE_KEYS)
	var graph_gas: int = body[Opcodes.KEY_GRAPH_GAS]
	if graph_gas < 0 or graph_gas > 4294967295:
		return _fail(Opcodes.REASON_COMPILE_GAS)
	if not body.has(Opcodes.KEY_EVENT) or typeof(body[Opcodes.KEY_EVENT]) != TYPE_STRING:
		return _fail(Opcodes.REASON_COMPILE_KEYS)
	var event_name: String = body[Opcodes.KEY_EVENT]
	if not Opcodes.is_compile_event(event_name):
		return _fail(Opcodes.REASON_COMPILE_EVENT)
	if not body.has(Opcodes.KEY_NODES) or typeof(body[Opcodes.KEY_NODES]) != TYPE_ARRAY:
		return _fail(Opcodes.REASON_COMPILE_KEYS)
	var raw_nodes: Array = body[Opcodes.KEY_NODES]
	var ops: Array[Dictionary] = []
	for item: Variant in raw_nodes:
		if typeof(item) != TYPE_DICTIONARY:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var node: Dictionary = item
		var compiled: Dictionary = _compile_node(node)
		var node_ok: bool = compiled.get(Opcodes.KEY_OK, false)
		if not node_ok:
			return _fail(str(compiled.get(Opcodes.KEY_REASON, Opcodes.REASON_COMPILE_UNKNOWN_NODE)))
		var op_bag: Dictionary = compiled.get(Opcodes.KEY_OP, {})
		if typeof(op_bag) != TYPE_DICTIONARY:
			return _fail(Opcodes.REASON_COMPILE_UNKNOWN_NODE)
		ops.append(op_bag)
	if not ops.is_empty():
		var last: Dictionary = ops[ops.size() - 1]
		var last_op: int = last.get(Opcodes.KEY_OP, -1)
		if last_op != Opcodes.OP_HALT:
			ops.append({Opcodes.KEY_OP: Opcodes.OP_HALT})
	var bytes: PackedByteArray = CodecGd.encode(graph_gas, ops)
	if bytes.is_empty():
		return _fail(Opcodes.REASON_COMPILE_ENCODE)
	return {
		Opcodes.KEY_OK: true,
		Opcodes.KEY_REASON: Opcodes.REASON_OK,
		Opcodes.KEY_EVENT: event_name,
		Opcodes.KEY_BYTES: bytes,
	}


static func _compile_node(node: Dictionary) -> Dictionary:
	if not node.has(Opcodes.KEY_KIND) or typeof(node[Opcodes.KEY_KIND]) != TYPE_STRING:
		return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
	var kind: String = node[Opcodes.KEY_KIND]
	if kind == Opcodes.KIND_HALT or kind == Opcodes.KIND_NOP:
		if node.size() != 1:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var op: int = Opcodes.OP_HALT if kind == Opcodes.KIND_HALT else Opcodes.OP_NOP
		return _op_ok({Opcodes.KEY_OP: op})
	if kind == Opcodes.KIND_LOAD_CONST:
		if node.size() != 3:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var dest: int = _int_field(node, Opcodes.KEY_DEST)
		if not node.has(Opcodes.KEY_VALUE) or typeof(node[Opcodes.KEY_VALUE]) != TYPE_INT:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		if not Opcodes.slot_ok(dest):
			return _fail(Opcodes.REASON_COMPILE_SLOT)
		return _op_ok({
			Opcodes.KEY_OP: Opcodes.OP_LOAD_I64,
			Opcodes.KEY_DEST: dest,
			Opcodes.KEY_VALUE: node[Opcodes.KEY_VALUE],
		})
	if kind == Opcodes.KIND_GET_VARIABLE or kind == Opcodes.KIND_SET_VARIABLE:
		if node.size() != 3:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var dest2: int = _int_field(node, Opcodes.KEY_DEST)
		var src: int = _int_field(node, Opcodes.KEY_SRC)
		if not Opcodes.slot_ok(dest2) or not Opcodes.slot_ok(src):
			return _fail(Opcodes.REASON_COMPILE_SLOT)
		var copy_op: int = Opcodes.OP_GET_VAR if kind == Opcodes.KIND_GET_VARIABLE else Opcodes.OP_SET_VAR
		return _op_ok({
			Opcodes.KEY_OP: copy_op,
			Opcodes.KEY_DEST: dest2,
			Opcodes.KEY_SRC: src,
		})
	if kind == Opcodes.KIND_COMPARE or kind == Opcodes.KIND_LOGIC:
		if node.size() != 5:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var dest3: int = _int_field(node, Opcodes.KEY_DEST)
		var lhs: int = _int_field(node, Opcodes.KEY_LHS)
		var rhs: int = _int_field(node, Opcodes.KEY_RHS)
		if not node.has(Opcodes.KEY_PRED) or typeof(node[Opcodes.KEY_PRED]) != TYPE_STRING:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var pred_name: String = node[Opcodes.KEY_PRED]
		var pred: int = Opcodes.pred_from_name(pred_name)
		if kind == Opcodes.KIND_LOGIC:
			pred = Opcodes.logic_from_name(pred_name)
		if not Opcodes.slot_ok(dest3) or not Opcodes.slot_ok(lhs) or not Opcodes.slot_ok(rhs):
			return _fail(Opcodes.REASON_COMPILE_SLOT)
		if kind == Opcodes.KIND_COMPARE and not Opcodes.pred_ok(pred):
			return _fail(Opcodes.REASON_COMPILE_PREDICATE)
		if kind == Opcodes.KIND_LOGIC and not Opcodes.logic_ok(pred):
			return _fail(Opcodes.REASON_COMPILE_LOGIC)
		var cond_op: int = Opcodes.OP_COMPARE
		if kind == Opcodes.KIND_LOGIC:
			cond_op = Opcodes.OP_LOGIC
		return _op_ok({
			Opcodes.KEY_OP: cond_op,
			Opcodes.KEY_DEST: dest3,
			Opcodes.KEY_LHS: lhs,
			Opcodes.KEY_RHS: rhs,
			Opcodes.KEY_PRED: pred,
		})
	if kind == Opcodes.KIND_GET_FIELD or kind == Opcodes.KIND_COUNT_IN_ZONE:
		if node.size() != 4:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var dest4: int = _int_field(node, Opcodes.KEY_DEST)
		var src2: int = _int_field(node, Opcodes.KEY_SRC)
		if not Opcodes.slot_ok(dest4) or not Opcodes.slot_ok(src2):
			return _fail(Opcodes.REASON_COMPILE_SLOT)
		if kind == Opcodes.KIND_GET_FIELD:
			if not node.has(Opcodes.KEY_FIELD) or typeof(node[Opcodes.KEY_FIELD]) != TYPE_STRING:
				return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
			var field_name: String = node[Opcodes.KEY_FIELD]
			var field_id: int = Opcodes.field_from_name(field_name)
			if not Opcodes.field_ok(field_id):
				return _fail(Opcodes.REASON_COMPILE_FIELD)
			return _op_ok({
				Opcodes.KEY_OP: Opcodes.OP_GET_FIELD,
				Opcodes.KEY_DEST: dest4,
				Opcodes.KEY_SRC: src2,
				Opcodes.KEY_FIELD: field_id,
			})
		if not node.has(Opcodes.KEY_TAG) or typeof(node[Opcodes.KEY_TAG]) != TYPE_STRING:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var tag_name: String = node[Opcodes.KEY_TAG]
		var tag_id: int = Opcodes.tag_from_name(tag_name)
		if not Opcodes.tag_ok(tag_id):
			return _fail(Opcodes.REASON_COMPILE_TAG)
		return _op_ok({
			Opcodes.KEY_OP: Opcodes.OP_COUNT_IN_ZONE,
			Opcodes.KEY_DEST: dest4,
			Opcodes.KEY_SRC: src2,
			Opcodes.KEY_TAG: tag_id,
		})
	if kind == Opcodes.KIND_SPAWN:
		if node.size() != 5:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var dest5: int = _int_field(node, Opcodes.KEY_DEST)
		var marker: int = _int_field(node, Opcodes.KEY_SRC)
		var count_slot: int = _int_field(node, Opcodes.KEY_COUNT)
		if not node.has(Opcodes.KEY_ARCHETYPE) or typeof(node[Opcodes.KEY_ARCHETYPE]) != TYPE_STRING:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var arch_name: String = node[Opcodes.KEY_ARCHETYPE]
		var archetype: int = Opcodes.archetype_from_name(arch_name)
		if not Opcodes.slot_ok(dest5) or not Opcodes.slot_ok(marker) or not Opcodes.slot_ok(count_slot):
			return _fail(Opcodes.REASON_COMPILE_SLOT)
		if not Opcodes.archetype_ok(archetype):
			return _fail(Opcodes.REASON_COMPILE_ARCHETYPE)
		return _op_ok({
			Opcodes.KEY_OP: Opcodes.OP_SPAWN,
			Opcodes.KEY_DEST: dest5,
			Opcodes.KEY_ARCHETYPE: archetype,
			Opcodes.KEY_SRC: marker,
			Opcodes.KEY_COUNT: count_slot,
		})
	if kind == Opcodes.KIND_DESPAWN:
		if node.size() != 2:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var src3: int = _int_field(node, Opcodes.KEY_SRC)
		if not Opcodes.slot_ok(src3):
			return _fail(Opcodes.REASON_COMPILE_SLOT)
		return _op_ok({Opcodes.KEY_OP: Opcodes.OP_DESPAWN, Opcodes.KEY_SRC: src3})
	if kind == Opcodes.KIND_APPLY_EFFECT:
		if node.size() != 4:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var src4: int = _int_field(node, Opcodes.KEY_SRC)
		var mag: int = _int_field(node, Opcodes.KEY_MAGNITUDE)
		if not node.has(Opcodes.KEY_EFFECT) or typeof(node[Opcodes.KEY_EFFECT]) != TYPE_STRING:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var effect_name: String = node[Opcodes.KEY_EFFECT]
		var effect: int = Opcodes.effect_from_name(effect_name)
		if not Opcodes.slot_ok(src4) or not Opcodes.slot_ok(mag):
			return _fail(Opcodes.REASON_COMPILE_SLOT)
		if not Opcodes.effect_ok(effect):
			return _fail(Opcodes.REASON_COMPILE_EFFECT)
		return _op_ok({
			Opcodes.KEY_OP: Opcodes.OP_APPLY_EFFECT,
			Opcodes.KEY_SRC: src4,
			Opcodes.KEY_EFFECT: effect,
			Opcodes.KEY_MAGNITUDE: mag,
		})
	if kind == Opcodes.KIND_EMIT_GAME_EVENT:
		if node.size() != 3:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var src5: int = _int_field(node, Opcodes.KEY_SRC)
		if not node.has(Opcodes.KEY_NAME) or typeof(node[Opcodes.KEY_NAME]) != TYPE_STRING:
			return _fail(Opcodes.REASON_COMPILE_NODE_KEYS)
		var emit_name: String = node[Opcodes.KEY_NAME]
		var event_id: int = Opcodes.event_from_name(emit_name)
		if not Opcodes.slot_ok(src5):
			return _fail(Opcodes.REASON_COMPILE_SLOT)
		if not Opcodes.event_name_ok(event_id):
			return _fail(Opcodes.REASON_COMPILE_NAME)
		return _op_ok({
			Opcodes.KEY_OP: Opcodes.OP_EMIT_EVENT,
			Opcodes.KEY_NAME: event_id,
			Opcodes.KEY_SRC: src5,
		})
	return _fail(Opcodes.REASON_COMPILE_UNKNOWN_NODE)


static func _int_field(node: Dictionary, key: String) -> int:
	if not node.has(key) or typeof(node[key]) != TYPE_INT:
		return -1
	return node[key]


static func _coerce_json_ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			var number: float = value
			if not is_finite(number):
				return value
			var as_int: int = int(number)
			if float(as_int) != number:
				return value
			return as_int
		TYPE_ARRAY:
			var items: Array = value
			var next_items: Array = []
			for item: Variant in items:
				next_items.append(_coerce_json_ints(item))
			return next_items
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var next_body: Dictionary = {}
			for key: Variant in source:
				next_body[key] = _coerce_json_ints(source[key])
			return next_body
		_:
			return value


static func _fail(reason: String) -> Dictionary:
	return {
		Opcodes.KEY_OK: false,
		Opcodes.KEY_REASON: reason,
		Opcodes.KEY_EVENT: "",
		Opcodes.KEY_BYTES: PackedByteArray(),
	}


static func _op_ok(bag: Dictionary) -> Dictionary:
	return {Opcodes.KEY_OK: true, Opcodes.KEY_REASON: Opcodes.REASON_OK, Opcodes.KEY_OP: bag}
