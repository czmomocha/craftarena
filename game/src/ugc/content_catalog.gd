class_name ContentCatalog
extends RefCounted

## In-memory published versions plus a latest pointer (CD-33).
## publish verifies the ContentSign sidecar, writes the version first,
## then moves latest. Versions are immutable and must increment by one.
## New rooms resolve latest; running sessions keep the hash from create.

const BundleGd := preload("res://src/ugc/simulation_bundle.gd")
const SignGd := preload("res://src/ugc/content_sign.gd")
const SessionGd := preload("res://src/games/traprush/match_session.gd")

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_ENVELOPE: String = "envelope"
const KEY_BUNDLE: String = "bundle"
const KEY_SESSION: String = "session"

const REASON_VERSION_EXISTS: String = "version_exists"
const REASON_VERSION_NOT_NEXT: String = "version_not_next"
const REASON_LATEST_MISSING: String = "latest_missing"

var _versions: Dictionary = {}
var _latest: Dictionary = {}


func publish(envelope: Dictionary, bundle: BundleGd, key: PackedByteArray) -> Dictionary:
	var checked: Dictionary = SignGd.verify(envelope, bundle, key)
	var checked_ok: bool = checked.get(SignGd.KEY_OK, false)
	if not checked_ok:
		return checked
	var content_id: String = str(envelope[SignGd.KEY_CONTENT_ID])
	var version: int = envelope[SignGd.KEY_VERSION]
	var stored: Dictionary = {}
	if _versions.has(content_id):
		stored = _versions[content_id]
	if stored.has(version):
		return _fail(REASON_VERSION_EXISTS)
	var latest_version: int = 0
	if _latest.has(content_id):
		latest_version = _latest[content_id]
	if latest_version == 0:
		if version != SignGd.VERSION_MIN:
			return _fail(REASON_VERSION_NOT_NEXT)
	elif version != latest_version + 1:
		return _fail(REASON_VERSION_NOT_NEXT)
	var copy: BundleGd = BundleGd.from_dictionary(bundle.to_dictionary())
	if copy == null:
		return _fail(SignGd.REASON_HASH_FAILED)
	if not _versions.has(content_id):
		_versions[content_id] = {}
	var rows: Dictionary = _versions[content_id]
	rows[version] = {
		KEY_ENVELOPE: envelope.duplicate(true),
		KEY_BUNDLE: copy,
	}
	_latest[content_id] = version
	return {
		KEY_OK: true,
		KEY_REASON: SignGd.REASON_OK,
		SignGd.KEY_CONTENT_ID: content_id,
		SignGd.KEY_VERSION: version,
		SignGd.KEY_CONTENT_HASH: str(checked.get(SignGd.KEY_CONTENT_HASH, "")),
	}


func latest(content_id: String) -> Dictionary:
	if not _latest.has(content_id):
		return _fail(REASON_LATEST_MISSING)
	var latest_version: int = _latest[content_id]
	return get_version(content_id, latest_version)


func get_version(content_id: String, version: int) -> Dictionary:
	if not _versions.has(content_id):
		return _fail(REASON_LATEST_MISSING)
	var rows: Dictionary = _versions[content_id]
	if not rows.has(version):
		return _fail(REASON_LATEST_MISSING)
	var row: Dictionary = rows[version]
	var envelope: Dictionary = row[KEY_ENVELOPE]
	return {
		KEY_OK: true,
		KEY_REASON: SignGd.REASON_OK,
		SignGd.KEY_CONTENT_ID: content_id,
		SignGd.KEY_VERSION: version,
		SignGd.KEY_CONTENT_HASH: str(envelope[SignGd.KEY_CONTENT_HASH]),
		KEY_ENVELOPE: envelope,
		KEY_BUNDLE: row[KEY_BUNDLE],
	}


func try_create_match(
	content_id: String,
	seed: int,
	count: int,
	spawn_offsets: Array,
	radius: int,
	cylinder_height: int,
	key: PackedByteArray
) -> Dictionary:
	var record: Dictionary = latest(content_id)
	var record_ok: bool = record.get(KEY_OK, false)
	if not record_ok:
		return record
	var envelope: Dictionary = record[KEY_ENVELOPE]
	var stored: BundleGd = record[KEY_BUNDLE]
	var checked: Dictionary = SignGd.verify(envelope, stored, key)
	var checked_ok: bool = checked.get(SignGd.KEY_OK, false)
	if not checked_ok:
		return checked
	var loaded: BundleGd = BundleGd.from_dictionary(stored.to_dictionary())
	if loaded == null:
		return _fail(SignGd.REASON_HASH_FAILED)
	var session: SessionGd = SessionGd.create(
		loaded, seed, count, spawn_offsets, radius, cylinder_height
	)
	if session == null:
		return _fail(SignGd.REASON_HASH_FAILED)
	var expected: String = str(checked.get(SignGd.KEY_CONTENT_HASH, ""))
	if session.content_hash != expected:
		return _fail(SignGd.REASON_HASH_MISMATCH)
	return {
		KEY_OK: true,
		KEY_REASON: SignGd.REASON_OK,
		SignGd.KEY_CONTENT_ID: content_id,
		SignGd.KEY_VERSION: record[SignGd.KEY_VERSION],
		SignGd.KEY_CONTENT_HASH: session.content_hash,
		KEY_SESSION: session,
	}


func _fail(reason: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_REASON: reason,
	}
