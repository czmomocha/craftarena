class_name ContentSign
extends RefCounted

## Sidecar content identity + platform signature (CD-33). Does not write
## fields into SimulationBundle. ContentHash is SHA-256 of StateHasher
## canonical encoding of bundle.to_dictionary() (v2 wire). Visual latest
## is not in that dictionary. Signature is HMAC-SHA256 over
## content_id + LF + version + LF + content_hash. Official matches lock
## the hash at create and do not require an envelope.

const HasherGd := preload("res://src/shared/protocol/state_hasher.gd")
const BundleGd := preload("res://src/ugc/simulation_bundle.gd")

const SCHEMA_VERSION: int = 1
const HASH_HEX_LEN: int = 64
const ID_MAX: int = 64
const VERSION_MIN: int = 1
const VERSION_MAX: int = 1000000
const KEY_MIN: int = 16
const KEY_MAX: int = 64
const HMAC_BLOCK: int = 64

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_SCHEMA_VERSION: String = "schema_version"
const KEY_CONTENT_ID: String = "content_id"
const KEY_VERSION: String = "version"
const KEY_CONTENT_HASH: String = "content_hash"
const KEY_SIGNATURE: String = "signature"

const REASON_OK: String = "ok"
const REASON_BUNDLE_MISSING: String = "bundle_missing"
const REASON_HASH_FAILED: String = "hash_failed"
const REASON_ID_INVALID: String = "id_invalid"
const REASON_VERSION_INVALID: String = "version_invalid"
const REASON_KEY_INVALID: String = "key_invalid"
const REASON_ENVELOPE_KEYS: String = "envelope_keys"
const REASON_HASH_MISMATCH: String = "hash_mismatch"
const REASON_SIGNATURE_MISMATCH: String = "signature_mismatch"

## Documented test / long-term-test key. Not a production secret.
## Callers pass a PackedByteArray; this string is only a fixture.
const DEV_KEY_TEXT: String = "craftarena-content-sign-dev-key"


static func dev_key() -> PackedByteArray:
	return DEV_KEY_TEXT.to_utf8_buffer()


static func hash_bundle(bundle: BundleGd) -> Dictionary:
	if bundle == null:
		return _fail(REASON_BUNDLE_MISSING)
	var body: Dictionary = bundle.to_dictionary()
	if not CanonicalPayload.is_allowed(body):
		return _fail(REASON_HASH_FAILED)
	var hasher: HasherGd = HasherGd.new()
	if not hasher.write_canonical(body):
		return _fail(REASON_HASH_FAILED)
	var hex: String = hasher.digest_hex()
	if not hex_ok(hex):
		return _fail(REASON_HASH_FAILED)
	return {
		KEY_OK: true,
		KEY_REASON: REASON_OK,
		KEY_CONTENT_HASH: hex,
	}


static func hash_hex(bundle: BundleGd) -> String:
	var hashed: Dictionary = hash_bundle(bundle)
	var ok: bool = hashed.get(KEY_OK, false)
	if not ok:
		return ""
	return str(hashed.get(KEY_CONTENT_HASH, ""))


static func sign(
	content_id: String,
	version: int,
	bundle: BundleGd,
	key: PackedByteArray
) -> Dictionary:
	if not id_ok(content_id):
		return _fail(REASON_ID_INVALID)
	if not version_ok(version):
		return _fail(REASON_VERSION_INVALID)
	if not key_ok(key):
		return _fail(REASON_KEY_INVALID)
	var hashed: Dictionary = hash_bundle(bundle)
	var hash_ok: bool = hashed.get(KEY_OK, false)
	if not hash_ok:
		return hashed
	var content_hash: String = str(hashed.get(KEY_CONTENT_HASH, ""))
	var mac: PackedByteArray = hmac_sha256(key, _sign_bytes(content_id, version, content_hash))
	if mac.size() != 32:
		return _fail(REASON_HASH_FAILED)
	return {
		KEY_OK: true,
		KEY_REASON: REASON_OK,
		KEY_SCHEMA_VERSION: SCHEMA_VERSION,
		KEY_CONTENT_ID: content_id,
		KEY_VERSION: version,
		KEY_CONTENT_HASH: content_hash,
		KEY_SIGNATURE: mac.hex_encode(),
	}


static func verify(envelope: Dictionary, bundle: BundleGd, key: PackedByteArray) -> Dictionary:
	if not envelope_keys_ok(envelope):
		return _fail(REASON_ENVELOPE_KEYS)
	if envelope.get(KEY_SCHEMA_VERSION, -1) != SCHEMA_VERSION:
		return _fail(REASON_ENVELOPE_KEYS)
	var content_id: String = str(envelope.get(KEY_CONTENT_ID, ""))
	var version: int = envelope.get(KEY_VERSION, 0)
	var claimed: String = str(envelope.get(KEY_CONTENT_HASH, ""))
	var signature: String = str(envelope.get(KEY_SIGNATURE, ""))
	if not id_ok(content_id):
		return _fail(REASON_ID_INVALID)
	if not version_ok(version):
		return _fail(REASON_VERSION_INVALID)
	if not hex_ok(claimed) or not hex_ok(signature):
		return _fail(REASON_ENVELOPE_KEYS)
	if not key_ok(key):
		return _fail(REASON_KEY_INVALID)
	var hashed: Dictionary = hash_bundle(bundle)
	var hash_ok: bool = hashed.get(KEY_OK, false)
	if not hash_ok:
		return hashed
	var actual: String = str(hashed.get(KEY_CONTENT_HASH, ""))
	if not _hex_eq(actual, claimed):
		return _fail(REASON_HASH_MISMATCH)
	var mac: PackedByteArray = hmac_sha256(key, _sign_bytes(content_id, version, claimed))
	if mac.size() != 32:
		return _fail(REASON_HASH_FAILED)
	if not _hex_eq(mac.hex_encode(), signature):
		return _fail(REASON_SIGNATURE_MISMATCH)
	return {
		KEY_OK: true,
		KEY_REASON: REASON_OK,
		KEY_CONTENT_ID: content_id,
		KEY_VERSION: version,
		KEY_CONTENT_HASH: actual,
	}


static func envelope_keys_ok(envelope: Dictionary) -> bool:
	if envelope.size() != 5:
		return false
	if not envelope.has(KEY_SCHEMA_VERSION):
		return false
	if not envelope.has(KEY_CONTENT_ID):
		return false
	if not envelope.has(KEY_VERSION):
		return false
	if not envelope.has(KEY_CONTENT_HASH):
		return false
	if not envelope.has(KEY_SIGNATURE):
		return false
	if typeof(envelope[KEY_SCHEMA_VERSION]) != TYPE_INT:
		return false
	if typeof(envelope[KEY_CONTENT_ID]) != TYPE_STRING:
		return false
	if typeof(envelope[KEY_VERSION]) != TYPE_INT:
		return false
	if typeof(envelope[KEY_CONTENT_HASH]) != TYPE_STRING:
		return false
	if typeof(envelope[KEY_SIGNATURE]) != TYPE_STRING:
		return false
	return true


static func id_ok(content_id: String) -> bool:
	if content_id.is_empty() or content_id.length() > ID_MAX:
		return false
	if content_id.strip_edges() != content_id:
		return false
	for index: int in range(content_id.length()):
		var code: int = content_id.unicode_at(index)
		var is_digit: bool = code >= 48 and code <= 57
		var is_upper: bool = code >= 65 and code <= 90
		var is_lower: bool = code >= 97 and code <= 122
		var is_mark: bool = code == 46 or code == 45 or code == 95
		if not is_digit and not is_upper and not is_lower and not is_mark:
			return false
	return true


static func version_ok(version: int) -> bool:
	return version >= VERSION_MIN and version <= VERSION_MAX


static func key_ok(key: PackedByteArray) -> bool:
	return key.size() >= KEY_MIN and key.size() <= KEY_MAX


static func hex_ok(text: String) -> bool:
	if text.length() != HASH_HEX_LEN:
		return false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		var is_digit: bool = code >= 48 and code <= 57
		var is_af: bool = code >= 97 and code <= 102
		if not is_digit and not is_af:
			return false
	return true


static func hmac_sha256(key: PackedByteArray, message: PackedByteArray) -> PackedByteArray:
	var block_key: PackedByteArray = key.duplicate()
	if block_key.size() > HMAC_BLOCK:
		block_key = _sha256_bytes(block_key)
	while block_key.size() < HMAC_BLOCK:
		block_key.append(0)
	var ipad: PackedByteArray = PackedByteArray()
	var opad: PackedByteArray = PackedByteArray()
	ipad.resize(HMAC_BLOCK)
	opad.resize(HMAC_BLOCK)
	for index: int in range(HMAC_BLOCK):
		ipad[index] = block_key[index] ^ 0x36
		opad[index] = block_key[index] ^ 0x5c
	var inner: PackedByteArray = PackedByteArray()
	inner.append_array(ipad)
	inner.append_array(message)
	var inner_hash: PackedByteArray = _sha256_bytes(inner)
	var outer: PackedByteArray = PackedByteArray()
	outer.append_array(opad)
	outer.append_array(inner_hash)
	return _sha256_bytes(outer)


static func _sign_bytes(content_id: String, version: int, content_hash: String) -> PackedByteArray:
	return ("%s\n%d\n%s" % [content_id, version, content_hash]).to_utf8_buffer()


static func _sha256_bytes(payload: PackedByteArray) -> PackedByteArray:
	var ctx: HashingContext = HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		return PackedByteArray()
	if not payload.is_empty():
		if ctx.update(payload) != OK:
			return PackedByteArray()
	return ctx.finish()


static func _hex_eq(left: String, right: String) -> bool:
	if left.length() != right.length():
		return false
	var mix: int = 0
	for index: int in range(left.length()):
		mix |= left.unicode_at(index) ^ right.unicode_at(index)
	return mix == 0


static func _fail(reason: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_REASON: reason,
	}
