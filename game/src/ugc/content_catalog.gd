class_name ContentCatalog
extends RefCounted

## In-memory published versions plus a latest pointer (CD-33).
## publish verifies the ContentSign sidecar, writes the version first,
## then moves latest. Versions are immutable; the next version is max+1
## so latest can roll back without reusing a number. New rooms resolve
## latest; running sessions keep the hash from create. P0/P1 patches
## fan out to rooms locked on the same base_version.

const BundleGd := preload("res://src/ugc/simulation_bundle.gd")
const PatchApplyGd := preload("res://src/games/traprush/match_session_patch.gd")
const PatchGd := preload("res://src/ugc/content_patch.gd")
const SignGd := preload("res://src/ugc/content_sign.gd")
const SessionGd := preload("res://src/games/traprush/match_session.gd")

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_ENVELOPE: String = "envelope"
const KEY_BUNDLE: String = "bundle"
const KEY_SESSION: String = "session"
const KEY_OPS: String = "ops"
const KEY_PATCHES: String = "patches"

const REASON_VERSION_EXISTS: String = "version_exists"
const REASON_VERSION_NOT_NEXT: String = "version_not_next"
const REASON_LATEST_MISSING: String = "latest_missing"
const REASON_SEQ_NOT_NEXT: String = "seq_not_next"
const REASON_ALREADY_LATEST: String = "already_latest"
const REASON_VERSION_MISSING: String = "version_missing"

var _versions: Dictionary = {}
var _latest: Dictionary = {}
var _patches: Dictionary = {}
var _rooms: Array[Dictionary] = []


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
	var max_version: int = _max_version(content_id)
	if version != max_version + 1:
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


func rollback_latest(content_id: String, version: int) -> Dictionary:
	if not _versions.has(content_id):
		return _fail(REASON_LATEST_MISSING)
	var rows: Dictionary = _versions[content_id]
	if not rows.has(version):
		return _fail(REASON_VERSION_MISSING)
	var current: int = 0
	if _latest.has(content_id):
		current = _latest[content_id]
	if current == version:
		return _fail(REASON_ALREADY_LATEST)
	_latest[content_id] = version
	return {
		KEY_OK: true,
		KEY_REASON: SignGd.REASON_OK,
		SignGd.KEY_CONTENT_ID: content_id,
		SignGd.KEY_VERSION: version,
	}


func publish_patch(envelope: Dictionary, ops: Array, key: PackedByteArray) -> Dictionary:
	var checked: Dictionary = PatchGd.verify(envelope, ops, key)
	var checked_ok: bool = checked.get(KEY_OK, false)
	if not checked_ok:
		return checked
	var content_id: String = str(envelope[PatchGd.KEY_CONTENT_ID])
	var base_version: int = envelope[PatchGd.KEY_BASE_VERSION]
	var seq: int = envelope[PatchGd.KEY_SEQ]
	if not _versions.has(content_id):
		return _fail(REASON_LATEST_MISSING)
	var rows: Dictionary = _versions[content_id]
	if not rows.has(base_version):
		return _fail(REASON_VERSION_MISSING)
	var chain: Array = _patch_chain(content_id, base_version)
	var expected_seq: int = chain.size() + 1
	if seq != expected_seq:
		return _fail(REASON_SEQ_NOT_NEXT)
	var record: Dictionary = {
		KEY_ENVELOPE: envelope.duplicate(true),
		KEY_OPS: ops.duplicate(true),
	}
	chain.append(record)
	_store_chain(content_id, base_version, chain)
	_fanout(content_id, base_version, envelope, ops, key)
	return {
		KEY_OK: true,
		KEY_REASON: SignGd.REASON_OK,
		PatchGd.KEY_CONTENT_ID: content_id,
		PatchGd.KEY_BASE_VERSION: base_version,
		PatchGd.KEY_SEQ: seq,
		PatchGd.KEY_PATCH_HASH: str(checked.get(PatchGd.KEY_PATCH_HASH, "")),
	}


func list_patches(content_id: String, base_version: int) -> Dictionary:
	if not _versions.has(content_id):
		return _fail(REASON_LATEST_MISSING)
	var rows: Dictionary = _versions[content_id]
	if not rows.has(base_version):
		return _fail(REASON_VERSION_MISSING)
	return {
		KEY_OK: true,
		KEY_REASON: SignGd.REASON_OK,
		KEY_PATCHES: _patch_chain(content_id, base_version).duplicate(true),
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
	var version: int = record[SignGd.KEY_VERSION]
	var overlay: PatchApplyGd = session.live_patch as PatchApplyGd
	if overlay == null:
		return _fail(SignGd.REASON_HASH_FAILED)
	overlay.bind(content_id, version)
	_apply_stored_patches(session, overlay, content_id, version, key)
	_rooms.append({
		SignGd.KEY_CONTENT_ID: content_id,
		SignGd.KEY_VERSION: version,
		KEY_SESSION: session,
	})
	return {
		KEY_OK: true,
		KEY_REASON: SignGd.REASON_OK,
		SignGd.KEY_CONTENT_ID: content_id,
		SignGd.KEY_VERSION: version,
		SignGd.KEY_CONTENT_HASH: session.content_hash,
		KEY_SESSION: session,
	}


func _apply_stored_patches(
	session: SessionGd,
	overlay: PatchApplyGd,
	content_id: String,
	version: int,
	key: PackedByteArray
) -> void:
	var chain: Array = _patch_chain(content_id, version)
	if chain.is_empty():
		return
	for item: Variant in chain:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = item
		var envelope: Dictionary = record[KEY_ENVELOPE]
		var ops: Array = record[KEY_OPS]
		overlay.enqueue(envelope, ops, key)
	overlay.try_apply_pending(session)


func _fanout(
	content_id: String,
	base_version: int,
	envelope: Dictionary,
	ops: Array,
	key: PackedByteArray
) -> void:
	for room: Dictionary in _rooms:
		var room_id: String = str(room.get(SignGd.KEY_CONTENT_ID, ""))
		var room_version: int = room.get(SignGd.KEY_VERSION, 0)
		if room_id != content_id or room_version != base_version:
			continue
		var session_raw: Variant = room.get(KEY_SESSION, null)
		if not (session_raw is SessionGd):
			continue
		var session: SessionGd = session_raw
		var overlay: PatchApplyGd = session.live_patch as PatchApplyGd
		if overlay == null:
			continue
		overlay.enqueue(envelope, ops, key)


func _max_version(content_id: String) -> int:
	if not _versions.has(content_id):
		return 0
	var rows: Dictionary = _versions[content_id]
	var highest: int = 0
	for key: Variant in rows.keys():
		if typeof(key) != TYPE_INT:
			continue
		var version: int = key
		if version > highest:
			highest = version
	return highest


func _patch_chain(content_id: String, base_version: int) -> Array:
	if not _patches.has(content_id):
		return []
	var by_base: Dictionary = _patches[content_id]
	if not by_base.has(base_version):
		return []
	return by_base[base_version]


func _store_chain(content_id: String, base_version: int, chain: Array) -> void:
	if not _patches.has(content_id):
		_patches[content_id] = {}
	var by_base: Dictionary = _patches[content_id]
	by_base[base_version] = chain


func _fail(reason: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_REASON: reason,
	}
