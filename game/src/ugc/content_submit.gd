class_name ContentSubmit
extends RefCounted

## Player publish payload (CD-33 §2.2). Validator must be green, then compile
## and hash. Never signs. Never invents content_id or version. The control
## plane allocates those after session auth.

const ReachGd := preload("res://src/creator/authoring_reachability.gd")
const SignGd := preload("res://src/ugc/content_sign.gd")
const CompilerGd := preload("res://src/ugc/traprush_topology_compiler.gd")

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_BUNDLE: String = "bundle"
const KEY_CONTENT_HASH: String = "content_hash"
const KEY_ID: String = "id"
const KEY_VERSION: String = "version"
const KEY_LATEST: String = "latest"

const REASON_WORLD_MISSING: String = "world_missing"
const REASON_VALIDATOR_ISSUES: String = "validator_issues"
const REASON_COMPILE_FAILED: String = "compile_failed"
const REASON_HASH_FAILED: String = "hash_failed"
const REASON_RESPONSE_INVALID: String = "response_invalid"


static func prepare(world: AuthoringWorld) -> Dictionary:
	if world == null:
		return _fail(REASON_WORLD_MISSING)
	var reach: Dictionary = ReachGd.evaluate(world)
	var ok_raw: Variant = reach.get("ok", false)
	if typeof(ok_raw) != TYPE_BOOL or not ok_raw:
		return _fail(REASON_VALIDATOR_ISSUES)
	var bundle: SimulationBundle = CompilerGd.compile(world)
	if bundle == null:
		return _fail(REASON_COMPILE_FAILED)
	var content_hash: String = SignGd.hash_hex(bundle)
	if content_hash == "":
		return _fail(REASON_HASH_FAILED)
	return {
		KEY_OK: true,
		KEY_REASON: "",
		KEY_BUNDLE: bundle.to_dictionary(),
		KEY_CONTENT_HASH: content_hash,
	}


static func request_body(prepared: Dictionary) -> Dictionary:
	var ok_raw: Variant = prepared.get(KEY_OK, false)
	if typeof(ok_raw) != TYPE_BOOL or not ok_raw:
		return {}
	return {
		KEY_BUNDLE: prepared.get(KEY_BUNDLE, {}),
		KEY_CONTENT_HASH: str(prepared.get(KEY_CONTENT_HASH, "")),
	}


static func read_view(raw: Dictionary) -> Dictionary:
	if raw.has("error"):
		return _fail(str(raw.get("error", REASON_RESPONSE_INVALID)))
	var content_id: String = str(raw.get(KEY_ID, ""))
	var version: int = _as_int(raw.get(KEY_VERSION, 0), -1)
	var latest: int = _as_int(raw.get(KEY_LATEST, 0), -1)
	var content_hash: String = str(raw.get(KEY_CONTENT_HASH, ""))
	if content_id == "" or version < 1 or latest < 1:
		return _fail(REASON_RESPONSE_INVALID)
	if content_hash == "" or raw.has(SignGd.KEY_SIGNATURE):
		return _fail(REASON_RESPONSE_INVALID)
	return {
		KEY_OK: true,
		KEY_REASON: "",
		KEY_ID: content_id,
		KEY_VERSION: version,
		KEY_LATEST: latest,
		KEY_CONTENT_HASH: content_hash,
	}


static func _fail(reason: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_REASON: reason,
	}


static func _as_int(raw: Variant, fallback: int) -> int:
	if typeof(raw) == TYPE_INT:
		var value: int = raw
		return value
	if typeof(raw) == TYPE_FLOAT:
		var number: float = raw
		if number != floor(number):
			return fallback
		return int(number)
	return fallback
