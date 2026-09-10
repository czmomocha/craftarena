class_name TraprushMatchPatch
extends RefCounted

## Live P0/P1 overlay on a locked TraprushMatchSession (CD-33).
## Queued patches apply at the next safety boundary (spawn latch or pad
## accept). Technical faults append a reverse PatchHash immediately.

const PatchGd := preload("res://src/ugc/content_patch.gd")
const CrateGd := preload("res://src/games/traprush/destructible.gd")

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const REASON_OK: String = "ok"
const REASON_BASE_MISMATCH: String = "base_mismatch"
const REASON_ID_MISMATCH: String = "id_mismatch"
const REASON_APPLY_FAILED: String = "apply_failed"
const REASON_NOTHING_TO_ROLL_BACK: String = "nothing_to_roll_back"

var content_id: String = ""
var content_version: int = 0
var fx_revision: int = 0
var _safety_latched: bool = true
var _pending: Array[Dictionary] = []
var _applied: Array[Dictionary] = []
var _hashes: PackedStringArray = PackedStringArray()


func bind(p_content_id: String, p_version: int) -> void:
	content_id = p_content_id
	content_version = p_version
	_safety_latched = true


func note_pad_accepted() -> void:
	_safety_latched = true


func patch_hashes() -> PackedStringArray:
	return _hashes.duplicate()


func pending_count() -> int:
	return _pending.size()


func applied_count() -> int:
	return _applied.size()


func enqueue(envelope: Dictionary, ops: Array, key: PackedByteArray) -> Dictionary:
	var checked: Dictionary = PatchGd.verify(envelope, ops, key)
	var checked_ok: bool = checked.get(KEY_OK, false)
	if not checked_ok:
		return checked
	var patch_id: String = str(envelope[PatchGd.KEY_CONTENT_ID])
	var base_version: int = envelope[PatchGd.KEY_BASE_VERSION]
	if patch_id != content_id:
		return _fail(REASON_ID_MISMATCH)
	if base_version != content_version:
		return _fail(REASON_BASE_MISMATCH)
	_pending.append({
		"envelope": envelope.duplicate(true),
		"ops": ops.duplicate(true),
	})
	return {
		KEY_OK: true,
		KEY_REASON: REASON_OK,
		PatchGd.KEY_PATCH_HASH: str(checked.get(PatchGd.KEY_PATCH_HASH, "")),
	}


func try_apply_pending(session: Object) -> void:
	if session == null:
		return
	if not _safety_latched:
		return
	var queued: Array[Dictionary] = _pending
	_pending = []
	_safety_latched = false
	for item: Dictionary in queued:
		_apply_one(session, item)


func note_fault(session: Object, _reason: String) -> bool:
	if session == null:
		return false
	if _applied.is_empty():
		return false
	var last: Dictionary = _applied[_applied.size() - 1]
	var already: bool = last.get("rollback", false)
	if already:
		return false
	var reverse_raw: Variant = last.get("reverse_ops", [])
	if typeof(reverse_raw) != TYPE_ARRAY:
		return false
	var reverse_ops: Array = reverse_raw
	if not _apply_ops(session, reverse_ops):
		return false
	var hashed: Dictionary = PatchGd.hash_ops(reverse_ops)
	var hash_ok: bool = hashed.get(KEY_OK, false)
	if not hash_ok:
		return false
	var reverse_hash: String = str(hashed.get(PatchGd.KEY_PATCH_HASH, ""))
	_hashes.append(reverse_hash)
	_applied.append({
		"rollback": true,
		"ops": reverse_ops,
		"patch_hash": reverse_hash,
	})
	return true


func _apply_one(session: Object, item: Dictionary) -> void:
	var ops_raw: Variant = item.get("ops", [])
	if typeof(ops_raw) != TYPE_ARRAY:
		return
	var ops: Array = ops_raw
	var reverse: Array = _snapshot_ops(session, ops)
	if reverse.is_empty():
		return
	if not _apply_ops(session, ops):
		_apply_ops(session, reverse)
		return
	var envelope_raw: Variant = item.get("envelope", {})
	if typeof(envelope_raw) != TYPE_DICTIONARY:
		return
	var envelope: Dictionary = envelope_raw
	var patch_hash: String = str(envelope.get(PatchGd.KEY_PATCH_HASH, ""))
	if patch_hash.is_empty():
		return
	_hashes.append(patch_hash)
	_applied.append({
		"rollback": false,
		"ops": ops,
		"reverse_ops": reverse,
		"patch_hash": patch_hash,
	})


func _snapshot_ops(session: Object, ops: Array) -> Array:
	var reverse: Array = []
	for item: Variant in ops:
		if typeof(item) != TYPE_DICTIONARY:
			return []
		var op: Dictionary = item
		var previous: int = _read_value(session, op)
		if previous < 0:
			return []
		reverse.append({
			"bag": str(op["bag"]),
			"entity_id": op["entity_id"],
			"field": str(op["field"]),
			"value": previous,
		})
	return reverse


func _apply_ops(session: Object, ops: Array) -> bool:
	for item: Variant in ops:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var op: Dictionary = item
		if not _apply_op(session, op):
			return false
	return true


func _apply_op(session: Object, op: Dictionary) -> bool:
	var bag: String = str(op.get("bag", ""))
	var field: String = str(op.get("field", ""))
	var entity_id: int = op.get("entity_id", -1)
	var value: int = op.get("value", -1)
	if value < 0:
		return false
	if bag == PatchGd.BAG_VISUAL and field == PatchGd.FIELD_FX_REVISION:
		fx_revision = value
		return true
	if bag == PatchGd.BAG_DESTRUCTIBLES and field == PatchGd.FIELD_DURABILITY:
		return _set_crate(session, entity_id, value)
	if bag == PatchGd.BAG_HAZARDS and field == PatchGd.FIELD_COOLDOWN:
		return _set_hazard(session, entity_id, value)
	return false


func _read_value(session: Object, op: Dictionary) -> int:
	var bag: String = str(op.get("bag", ""))
	var field: String = str(op.get("field", ""))
	var entity_id: int = op.get("entity_id", -1)
	if bag == PatchGd.BAG_VISUAL and field == PatchGd.FIELD_FX_REVISION:
		return fx_revision
	if bag == PatchGd.BAG_DESTRUCTIBLES and field == PatchGd.FIELD_DURABILITY:
		return _crate_max(session, entity_id)
	if bag == PatchGd.BAG_HAZARDS and field == PatchGd.FIELD_COOLDOWN:
		return _hazard_cooldown(session, entity_id)
	return -1


func _crate_max(session: Object, entity_id: int) -> int:
	var crates: Dictionary = _crates(session)
	if not crates.has(entity_id):
		return -1
	var crate_raw: Variant = crates[entity_id]
	if not (crate_raw is CrateGd):
		return -1
	var crate: CrateGd = crate_raw
	return crate.max_health()


func _set_crate(session: Object, entity_id: int, value: int) -> bool:
	var crates: Dictionary = _crates(session)
	if not crates.has(entity_id):
		return false
	var crate_raw: Variant = crates[entity_id]
	if not (crate_raw is CrateGd):
		return false
	var crate: CrateGd = crate_raw
	return crate.try_set_max_health(value)


func _hazard_cooldown(session: Object, entity_id: int) -> int:
	for item_raw: Variant in _hazard_rows(session):
		if typeof(item_raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_raw
		var hazard_id: int = item.get("entity_id", -1)
		if hazard_id != entity_id:
			continue
		var cooldown: int = item.get("cooldown_ticks", -1)
		return cooldown
	return -1


func _set_hazard(session: Object, entity_id: int, value: int) -> bool:
	for item_raw: Variant in _hazard_rows(session):
		if typeof(item_raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_raw
		var hazard_id: int = item.get("entity_id", -1)
		if hazard_id != entity_id:
			continue
		item["cooldown_ticks"] = value
		return true
	return false


func _crates(session: Object) -> Dictionary:
	var raw: Variant = session.get("_crate_health")
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func _hazard_rows(session: Object) -> Array:
	var raw: Variant = session.get("_hazard_cycle")
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw


func _fail(reason: String) -> Dictionary:
	return {
		KEY_OK: false,
		KEY_REASON: reason,
	}
