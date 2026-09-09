class_name RuleVmOpcodes
extends RefCounted

## Rule VM v1 opcode table, fixed gas costs, and locatable error codes.
## Owner: CD-42 §2. Envelope + interpreter + compiler + dispatch + §2.1
## Query / Logic / Action subset. Preview P3 rebinds at a safe point.

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
const OP_LOGIC: int = 6
const OP_GET_FIELD: int = 7
const OP_COUNT_IN_ZONE: int = 8
const OP_SPAWN: int = 9
const OP_DESPAWN: int = 10
const OP_APPLY_EFFECT: int = 11
const OP_EMIT_EVENT: int = 12
const OP_MAX: int = 12

const PRED_EQ: int = 0
const PRED_NE: int = 1
const PRED_LT: int = 2
const PRED_LE: int = 3
const PRED_GT: int = 4
const PRED_GE: int = 5
const PRED_MAX: int = 5

const LOGIC_AND: int = 0
const LOGIC_OR: int = 1
const LOGIC_NOT: int = 2
const LOGIC_MAX: int = 2

const FIELD_HEALTH_CURRENT: int = 0
const FIELD_MAX: int = 0

const TAG_PLAYER: int = 0
const TAG_MAX: int = 0

const ARCHETYPE_DUMMY: int = 0
const ARCHETYPE_MAX: int = 0

const EFFECT_DAMAGE: int = 0
const EFFECT_MAX: int = 0

const EVENT_SIGNAL: int = 0
const EVENT_NAME_MAX: int = 0

const GAS_HALT: int = 1
const GAS_NOP: int = 1
const GAS_LOAD_I64: int = 1
const GAS_GET_VAR: int = 1
const GAS_SET_VAR: int = 1
const GAS_COMPARE: int = 1
const GAS_LOGIC: int = 1
const GAS_GET_FIELD: int = 1
const GAS_COUNT_IN_ZONE: int = 1
const GAS_SPAWN: int = 1
const GAS_DESPAWN: int = 1
const GAS_APPLY_EFFECT: int = 1
const GAS_EMIT_EVENT: int = 1

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
const REASON_BIND_DUPLICATE: String = "bind_duplicate"
const REASON_ALREADY_STARTED: String = "already_started"
const REASON_HOST_MISSING: String = "host_missing"
const REASON_HOST_REFUSED: String = "host_refused"
const REASON_COMPILE_FIELD: String = "compile_field"
const REASON_COMPILE_TAG: String = "compile_tag"
const REASON_COMPILE_ARCHETYPE: String = "compile_archetype"
const REASON_COMPILE_EFFECT: String = "compile_effect"
const REASON_COMPILE_NAME: String = "compile_name"
const REASON_COMPILE_LOGIC: String = "compile_logic"

const EVENT_ON_MATCH_STARTED: String = "OnMatchStarted"
const EVENT_ON_EVERY_TICKS: String = "OnEveryTicks"
const EVENT_ON_ENTERED_ZONE: String = "OnEnteredZone"
const EVENT_ON_ENTITY_DIED: String = "OnEntityDied"
const EVENT_ON_VARIABLE_THRESHOLD: String = "OnVariableThreshold"

const KIND_LOAD_CONST: String = "LoadConst"
const KIND_GET_VARIABLE: String = "GetVariable"
const KIND_SET_VARIABLE: String = "SetVariable"
const KIND_COMPARE: String = "Compare"
const KIND_HALT: String = "Halt"
const KIND_NOP: String = "Nop"
const KIND_GET_FIELD: String = "GetField"
const KIND_COUNT_IN_ZONE: String = "CountInZone"
const KIND_LOGIC: String = "Logic"
const KIND_SPAWN: String = "Spawn"
const KIND_DESPAWN: String = "Despawn"
const KIND_APPLY_EFFECT: String = "ApplyEffect"
const KIND_EMIT_GAME_EVENT: String = "EmitGameEvent"

const LOGIC_NAME_AND: String = "and"
const LOGIC_NAME_OR: String = "or"
const LOGIC_NAME_NOT: String = "not"

const FIELD_NAME_HEALTH_CURRENT: String = "health.current"
const TAG_NAME_PLAYER: String = "player"
const ARCHETYPE_NAME_DUMMY: String = "dummy"
const EFFECT_NAME_DAMAGE: String = "damage"
const EVENT_NAME_SIGNAL: String = "signal"

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
const KEY_FIELD: String = "field"
const KEY_TAG: String = "tag"
const KEY_ARCHETYPE: String = "archetype"
const KEY_COUNT: String = "count"
const KEY_EFFECT: String = "effect"
const KEY_MAGNITUDE: String = "magnitude"
const KEY_NAME: String = "name"
const KEY_EXTRA_GAS: String = "extra_gas"


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
		OP_LOGIC:
			return GAS_LOGIC
		OP_GET_FIELD:
			return GAS_GET_FIELD
		OP_COUNT_IN_ZONE:
			return GAS_COUNT_IN_ZONE
		OP_SPAWN:
			return GAS_SPAWN
		OP_DESPAWN:
			return GAS_DESPAWN
		OP_APPLY_EFFECT:
			return GAS_APPLY_EFFECT
		OP_EMIT_EVENT:
			return GAS_EMIT_EVENT
		_:
			return 0


static func is_known(op: int) -> bool:
	return op >= OP_HALT and op <= OP_MAX


static func slot_ok(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


static func pred_ok(pred: int) -> bool:
	return pred >= PRED_EQ and pred <= PRED_MAX


static func is_compile_event(event_name: String) -> bool:
	return event_name == EVENT_ON_MATCH_STARTED or event_name == EVENT_ON_EVERY_TICKS


static func logic_from_name(name: String) -> int:
	if name == LOGIC_NAME_AND:
		return LOGIC_AND
	if name == LOGIC_NAME_OR:
		return LOGIC_OR
	if name == LOGIC_NAME_NOT:
		return LOGIC_NOT
	return -1


static func logic_ok(pred: int) -> bool:
	return pred >= LOGIC_AND and pred <= LOGIC_MAX


static func field_from_name(name: String) -> int:
	if name == FIELD_NAME_HEALTH_CURRENT:
		return FIELD_HEALTH_CURRENT
	return -1


static func field_ok(field_id: int) -> bool:
	return field_id >= FIELD_HEALTH_CURRENT and field_id <= FIELD_MAX


static func tag_from_name(name: String) -> int:
	if name == TAG_NAME_PLAYER:
		return TAG_PLAYER
	return -1


static func tag_ok(tag_id: int) -> bool:
	return tag_id >= TAG_PLAYER and tag_id <= TAG_MAX


static func archetype_from_name(name: String) -> int:
	if name == ARCHETYPE_NAME_DUMMY:
		return ARCHETYPE_DUMMY
	return -1


static func archetype_ok(archetype: int) -> bool:
	return archetype >= ARCHETYPE_DUMMY and archetype <= ARCHETYPE_MAX


static func effect_from_name(name: String) -> int:
	if name == EFFECT_NAME_DAMAGE:
		return EFFECT_DAMAGE
	return -1


static func effect_ok(effect: int) -> bool:
	return effect >= EFFECT_DAMAGE and effect <= EFFECT_MAX


static func event_from_name(name: String) -> int:
	if name == EVENT_NAME_SIGNAL:
		return EVENT_SIGNAL
	return -1


static func event_name_ok(event_id: int) -> bool:
	return event_id >= EVENT_SIGNAL and event_id <= EVENT_NAME_MAX
