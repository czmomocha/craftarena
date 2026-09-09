class_name RuleVmOpcodes
extends RefCounted

## Rule VM v1 opcode table, fixed gas costs, and locatable error codes.
## Owner: CD-42 §2. First chapter: versioned envelope + whitelist + per-graph gas.
## Spatial queries, Event dispatch, graph JSON, and Preview wiring are later.

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
