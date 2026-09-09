class_name RuleVmOpcodes
extends RefCounted

## Rule VM v1 opcode table, fixed gas costs, and locatable error codes.
## Owner: CD-42 §2. Envelope + whitelist interpreter + graph compiler.
## Event dispatch, spatial queries, remaining nodes, and Preview wiring are later.

const RULESET_VERSION: int = 1
const SLOT_COUNT: int = 16
const HEADER_SIZE: int = 16

const MAGIC_0: int = 0x43
const MAGIC_1: int = 0x52
const MAGIC_2: int = 0x56
const MAGIC_3: int = 0x4D

const OP_HALT: int = 0
const OP_NOP: int = 1
const OP_LOAD_I64: int = 2
const OP_GET_VAR: int = 3
const OP_SET_VAR: int = 4
const OP_COMPARE: int = 5

const PRED_EQ: int = 0
const PRED_NE: int = 1
const PRED_LT: int = 2
const PRED_LE: int = 3
const PRED_GT: int = 4
const PRED_GE: int = 5
const PRED_MAX: int = 5

const GAS_HALT: int = 1
const GAS_NOP: int = 1
const GAS_LOAD_I64: int = 1
const GAS_GET_VAR: int = 1
const GAS_SET_VAR: int = 1
const GAS_COMPARE: int = 1

const REASON_OK: String = "ok"
const REASON_DECODE_MAGIC: String = "decode_magic"
const REASON_DECODE_VERSION: String = "decode_version"
const REASON_DECODE_RESERVED: String = "decode_reserved"
const REASON_DECODE_TRUNCATED: String = "decode_truncated"
const REASON_DECODE_TRAILING: String = "decode_trailing"
const REASON_DECODE_UNKNOWN_OPCODE: String = "decode_unknown_opcode"
const REASON_DECODE_SLOT: String = "decode_slot"
const REASON_DECODE_PREDICATE: String = "decode_predicate"
const REASON_VARS_SIZE: String = "vars_size"
const REASON_GAS_EXCEEDED: String = "gas_exceeded"
const REASON_COMPILE_KEYS: String = "compile_keys"
const REASON_COMPILE_VERSION: String = "compile_version"
const REASON_COMPILE_GAS: String = "compile_gas"
const REASON_COMPILE_EVENT: String = "compile_event"
const REASON_COMPILE_UNKNOWN_NODE: String = "compile_unknown_node"
const REASON_COMPILE_NODE_KEYS: String = "compile_node_keys"
const REASON_COMPILE_SLOT: String = "compile_slot"
const REASON_COMPILE_PREDICATE: String = "compile_predicate"
const REASON_COMPILE_ENCODE: String = "compile_encode"

const EVENT_ON_MATCH_STARTED: String = "OnMatchStarted"

const KIND_LOAD_CONST: String = "LoadConst"
const KIND_GET_VARIABLE: String = "GetVariable"
const KIND_SET_VARIABLE: String = "SetVariable"
const KIND_COMPARE: String = "Compare"
const KIND_HALT: String = "Halt"
const KIND_NOP: String = "Nop"

const PRED_NAME_EQ: String = "eq"
const PRED_NAME_NE: String = "ne"
const PRED_NAME_LT: String = "lt"
const PRED_NAME_LE: String = "le"
const PRED_NAME_GT: String = "gt"
const PRED_NAME_GE: String = "ge"

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_RULESET_VERSION: String = "ruleset_version"
const KEY_GRAPH_GAS: String = "graph_gas"
const KEY_OPS: String = "ops"
const KEY_GAS_USED: String = "gas_used"
const KEY_VARS: String = "vars"
const KEY_OP: String = "op"
const KEY_DEST: String = "dest"
const KEY_SRC: String = "src"
const KEY_LHS: String = "lhs"
const KEY_RHS: String = "rhs"
const KEY_PRED: String = "pred"
const KEY_VALUE: String = "value"
const KEY_EVENT: String = "event"
const KEY_NODES: String = "nodes"
const KEY_KIND: String = "kind"
const KEY_BYTES: String = "bytes"


static func pred_from_name(name: String) -> int:
	if name == PRED_NAME_EQ:
		return PRED_EQ
	if name == PRED_NAME_NE:
		return PRED_NE
	if name == PRED_NAME_LT:
		return PRED_LT
	if name == PRED_NAME_LE:
		return PRED_LE
	if name == PRED_NAME_GT:
		return PRED_GT
	if name == PRED_NAME_GE:
		return PRED_GE
	return -1


static func cost(op: int) -> int:
	match op:
		OP_HALT:
			return GAS_HALT
		OP_NOP:
			return GAS_NOP
		OP_LOAD_I64:
			return GAS_LOAD_I64
		OP_GET_VAR:
			return GAS_GET_VAR
		OP_SET_VAR:
			return GAS_SET_VAR
		OP_COMPARE:
			return GAS_COMPARE
		_:
			return 0


static func is_known(op: int) -> bool:
	return op >= OP_HALT and op <= OP_COMPARE


static func slot_ok(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


static func pred_ok(pred: int) -> bool:
	return pred >= PRED_EQ and pred <= PRED_MAX
