class_name ContentPatch
extends RefCounted

## Sidecar P0/P1 patch identity (CD-33). Does not overwrite ContentHash.
## PatchHash is SHA-256 of StateHasher canonical encoding of the ops array.
## Signature is HMAC-SHA256 over content_id + LF + base_version + LF + seq
## + LF + patch_hash. Live matches only accept classified P0/P1.

const HasherGd := preload("res://src/shared/protocol/state_hasher.gd")
const SignGd := preload("res://src/ugc/content_sign.gd")
const LevelsGd := preload("res://src/creator/preview_patch_levels.gd")

const SCHEMA_VERSION: int = 1
const SEQ_MIN: int = 1
const SEQ_MAX: int = 1000000
const ENVELOPE_SIZE: int = 7

const BAG_VISUAL: String = "visual"
const BAG_DESTRUCTIBLES: String = "destructibles"
const BAG_HAZARDS: String = "hazards"
const FIELD_FX_REVISION: String = "fx_revision"
const FIELD_DURABILITY: String = "durability"
const FIELD_COOLDOWN: String = "cooldown_ticks"

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_SCHEMA_VERSION: String = "schema_version"
const KEY_CONTENT_ID: String = "content_id"
const KEY_BASE_VERSION: String = "base_version"
const KEY_SEQ: String = "seq"
const KEY_LEVEL: String = "level"
const KEY_PATCH_HASH: String = "patch_hash"
const KEY_SIGNATURE: String = "signature"
const KEY_OPS: String = "ops"
const KEY_CLASSIFIED: String = "classified"

const REASON_OK: String = "ok"
const REASON_OPS_INVALID: String = "ops_invalid"
const REASON_HASH_FAILED: String = "hash_failed"
const REASON_ID_INVALID: String = "id_invalid"
const REASON_VERSION_INVALID: String = "version_invalid"
const REASON_SEQ_INVALID: String = "seq_invalid"
const REASON_LEVEL_INVALID: String = "level_invalid"
const REASON_LEVEL_FORBIDDEN: String = "level_forbidden"
const REASON_KEY_INVALID: String = "key_invalid"
const REASON_ENVELOPE_KEYS: String = "envelope_keys"
const REASON_HASH_MISMATCH: String = "hash_mismatch"
const REASON_SIGNATURE_MISMATCH: String = "signature_mismatch"
const REASON_UNDERREPORTED: String = "level_underreported"


static func hash_ops(ops: Array) -> Dictionary:
	if not CanonicalPayload.is_allowed(ops):
		return _fail(REASON_OPS_INVALID)
	if not ops_ok(ops):
		return _fail(REASON_OPS_INVALID)
	var hasher: HasherGd = HasherGd.new()
	if not hasher.write_canonical(ops):
		return _fail(REASON_HASH_FAILED)
	var hex: String = hasher.digest_hex()
	if not SignGd.hex_ok(hex):
		return _fail(REASON_HASH_FAILED)
	return {
		KEY_OK: true,
		KEY_REASON: REASON_OK,
		KEY_PATCH_HASH: hex,
	}


static func sign(
	content_id: String,
	base_version: int,
	seq: int,
	level: String,
	ops: Array,
	key: PackedByteArray
) -> Dictionary:
	if not SignGd.id_ok(content_id):
		return _fail(REASON_ID_INVALID)
	if not SignGd.version_ok(base_version):
		return _fail(REASON_VERSION_INVALID)
	if not seq_ok(seq):
		return _fail(REASON_SEQ_INVALID)
	if not SignGd.key_ok(key):
		return _fail(REASON_KEY_INVALID)
	var classified: String = classify_ops(ops)
	if classified.is_empty():
		return _fail(REASON_OPS_INVALID)
	if not live_level_ok(classified):
		return _fail(REASON_LEVEL_FORBIDDEN)
	if not live_level_ok(level):
		return _fail(REASON_LEVEL_INVALID)
	if LevelsGd.rank(level) < LevelsGd.rank(classified):
		return _fail(REASON_UNDERREPORTED)
	var hashed: Dictionary = hash_ops(ops)
	var hash_ok: bool = hashed.get(KEY_OK, false)
	if not hash_ok:
		return hashed
	var patch_hash: String = str(hashed.get(KEY_PATCH_HASH, ""))
	var mac: PackedByteArray = SignGd.hmac_sha256(
		key, _sign_bytes(content_id, base_version, seq, patch_hash)
	)
	if mac.size() != 32:
		return _fail(REASON_HASH_FAILED)
	return {
		KEY_OK: true,
		KEY_REASON: REASON_OK,
		KEY_SCHEMA_VERSION: SCHEMA_VERSION,
		KEY_CONTENT_ID: content_id,
		KEY_BASE_VERSION: base_version,
		KEY_SEQ: seq,
		KEY_LEVEL: level,
		KEY_PATCH_HASH: patch_hash,
		KEY_SIGNATURE: mac.hex_encode(),
		KEY_CLASSIFIED: classified,
	}


static func verify(envelope: Dictionary, ops: Array, key: PackedByteArray) -> Dictionary:
	if not envelope_keys_ok(envelope):
		return _fail(REASON_ENVELOPE_KEYS)
	if envelope.get(KEY_SCHEMA_VERSION, -1) != SCHEMA_VERSION:
		return _fail(REASON_ENVELOPE_KEYS)
	var content_id: String = str(envelope.get(KEY_CONTENT_ID, ""))
	var base_version: int = envelope.get(KEY_BASE_VERSION, 0)
	var seq: int = envelope.get(KEY_SEQ, 0)
	var level: String = str(envelope.get(KEY_LEVEL, ""))
	var claimed: String = str(envelope.get(KEY_PATCH_HASH, ""))
	var signature: String = str(envelope.get(KEY_SIGNATURE, ""))
	if not SignGd.id_ok(content_id):
		return _fail(REASON_ID_INVALID)
	if not SignGd.version_ok(base_version):
		return _fail(REASON_VERSION_INVALID)
	if not seq_ok(seq):
		return _fail(REASON_SEQ_INVALID)
	if not SignGd.hex_ok(claimed) or not SignGd.hex_ok(signature):
		return _fail(REASON_ENVELOPE_KEYS)
	if not SignGd.key_ok(key):
		return _fail(REASON_KEY_INVALID)
	var classified: String = classify_ops(ops)
	if classified.is_empty():
		return _fail(REASON_OPS_INVALID)
	if not live_level_ok(classified):
		return _fail(REASON_LEVEL_FORBIDDEN)
	if not live_level_ok(level):
		return _fail(REASON_LEVEL_INVALID)
	if LevelsGd.rank(level) < LevelsGd.rank(classified):
		return _fail(REASON_UNDERREPORTED)
	var hashed: Dictionary = hash_ops(ops)
	var hash_ok: bool = hashed.get(KEY_OK, false)
	if not hash_ok:
		return hashed
	var actual: String = str(hashed.get(KEY_PATCH_HASH, ""))
	if not _hex_eq(actual, claimed):
		return _fail(REASON_HASH_MISMATCH)
	var mac: PackedByteArray = SignGd.hmac_sha256(
		key, _sign_bytes(content_id, base_version, seq, claimed)
	)
	if mac.size() != 32:
		return _fail(REASON_HASH_FAILED)
	if not _hex_eq(mac.hex_encode(), signature):
		return _fail(REASON_SIGNATURE_MISMATCH)
	return {
		KEY_OK: true,
		KEY_REASON: REASON_OK,
		KEY_CONTENT_ID: content_id,
		KEY_BASE_VERSION: base_version,
		KEY_SEQ: seq,
		KEY_LEVEL: level,
		KEY_PATCH_HASH: actual,
		KEY_CLASSIFIED: classified,
	}


static func classify_ops(ops: Array) -> String:
	if ops.is_empty():
		return ""
	if not ops_ok(ops):
		return ""
	var required: String = LevelsGd.P0
	for item: Variant in ops:
		var op: Dictionary = item
		var classified: String = classify_op(op)
		if classified.is_empty():
			return ""
		if LevelsGd.rank(classified) > LevelsGd.rank(required):
			required = classified
	return required


static func classify_op(op: Dictionary) -> String:
	var bag: String = str(op.get("bag", ""))
	var field: String = str(op.get("field", ""))
	if bag == BAG_VISUAL and field == FIELD_FX_REVISION:
		return LevelsGd.P0
	if bag == BAG_DESTRUCTIBLES and field == FIELD_DURABILITY:
		return LevelsGd.P1
	if bag == BAG_HAZARDS and field == FIELD_COOLDOWN:
		return LevelsGd.P1
	if bag.is_empty() or field.is_empty():
		return ""
	return LevelsGd.P2


static func ops_ok(ops: Array) -> bool:
	if ops.is_empty():
		return false
	for item: Variant in ops:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var op: Dictionary = item
		if op.size() != 4:
			return false
		if not op.has("bag") or typeof(op["bag"]) != TYPE_STRING:
			return false
		if not op.has("entity_id") or typeof(op["entity_id"]) != TYPE_INT:
			return false
		if not op.has("field") or typeof(op["field"]) != TYPE_STRING:
			return false
		if not op.has("value") or typeof(op["value"]) != TYPE_INT:
			return false
		var entity_id: int = op["entity_id"]
		var value: int = op["value"]
		if entity_id < 0:
			return false
		if value < 0:
			return false
		var classified: String = classify_op(op)
		if classified.is_empty():
			return false
	return true


static func envelope_keys_ok(envelope: Dictionary) -> bool:
	if envelope.size() != ENVELOPE_SIZE:
		return false
	if not envelope.has(KEY_SCHEMA_VERSION) or typeof(envelope[KEY_SCHEMA_VERSION]) != TYPE_INT:
		return false
	if not envelope.has(KEY_CONTENT_ID) or typeof(envelope[KEY_CONTENT_ID]) != TYPE_STRING:
		return false
	if not envelope.has(KEY_BASE_VERSION) or typeof(envelope[KEY_BASE_VERSION]) != TYPE_INT:
		return false
	if not envelope.has(KEY_SEQ) or typeof(envelope[KEY_SEQ]) != TYPE_INT:
		return false
	if not envelope.has(KEY_LEVEL) or typeof(envelope[KEY_LEVEL]) != TYPE_STRING:
		return false
	if not envelope.has(KEY_PATCH_HASH) or typeof(envelope[KEY_PATCH_HASH]) != TYPE_STRING:
		return false
	if not envelope.has(KEY_SIGNATURE) or typeof(envelope[KEY_SIGNATURE]) != TYPE_STRING:
		return false
	return true


static func seq_ok(seq: int) -> bool:
	return seq >= SEQ_MIN and seq <= SEQ_MAX


static func live_level_ok(level: String) -> bool:
	return LevelsGd.public_match_allows(level)


static func envelope_of(signed: Dictionary) -> Dictionary:
	return {
		KEY_SCHEMA_VERSION: signed[KEY_SCHEMA_VERSION],
		KEY_CONTENT_ID: signed[KEY_CONTENT_ID],
		KEY_BASE_VERSION: signed[KEY_BASE_VERSION],
		KEY_SEQ: signed[KEY_SEQ],
		KEY_LEVEL: signed[KEY_LEVEL],
		KEY_PATCH_HASH: signed[KEY_PATCH_HASH],
		KEY_SIGNATURE: signed[KEY_SIGNATURE],
	}


static func _sign_bytes(
	content_id: String, base_version: int, seq: int, patch_hash: String
) -> PackedByteArray:
	return ("%s\n%d\n%d\n%s" % [content_id, base_version, seq, patch_hash]).to_utf8_buffer()


static func _hex_eq(left: String, right: String) -> bool:
	return SignGd.hex_ok(left) and SignGd.hex_ok(right) and left == right


static func _fail(reason: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_REASON: reason,
	}
