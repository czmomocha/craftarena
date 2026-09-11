class_name ContentSubmitHttp
extends RefCounted

## Player submit HTTP (CD-33 §2.2). Mints a control-plane Guest when the
## lobby account window has no session. Never calls POST /content/publish.
## Guest file is not AccountCatalog.GUEST_FILE.

const HttpGd := preload("res://src/client/control_plane_http.gd")
const SubmitGd := preload("res://src/ugc/content_submit.gd")

const GUEST_FILE: String = "user://content_submit_guest.json"
const PATH_GUEST: String = "/accounts/guest"
const PATH_SUBMIT: String = "/content/submit"
const KEY_GUEST_ID: String = "guest_id"
const KEY_RECOVERY_KEY: String = "recovery_key"
const HEADER_GUEST_ID: String = "x-guest-id"
const HEADER_GUEST_KEY: String = "x-guest-key"


static func submit_player(
	base: String,
	payload: Dictionary,
	transport: Callable = Callable(),
	guest_path: String = GUEST_FILE
) -> Dictionary:
	var guest: Dictionary = ensure_guest(base, guest_path, transport)
	if not _ok(guest):
		return {"error": str(guest.get(SubmitGd.KEY_REASON, SubmitGd.REASON_RESPONSE_INVALID))}
	var headers: PackedStringArray = PackedStringArray([
		"%s: %s" % [HEADER_GUEST_ID, str(guest.get(KEY_GUEST_ID, ""))],
		"%s: %s" % [HEADER_GUEST_KEY, str(guest.get(KEY_RECOVERY_KEY, ""))],
	])
	var exchanged: Dictionary = HttpGd.post_json(base, PATH_SUBMIT, headers, payload, transport)
	var body_raw: Variant = exchanged.get(HttpGd.KEY_BODY, {})
	if typeof(body_raw) != TYPE_DICTIONARY:
		return {"error": HttpGd.REASON_RESPONSE}
	var body: Dictionary = body_raw
	if not _flag(exchanged, HttpGd.KEY_OK):
		if body.has("error"):
			return body
		return {"error": str(exchanged.get(HttpGd.KEY_REASON, HttpGd.REASON_TRANSPORT))}
	return body


static func ensure_guest(
	base: String,
	guest_path: String = GUEST_FILE,
	transport: Callable = Callable()
) -> Dictionary:
	var loaded: Dictionary = load_guest(guest_path)
	if _ok(loaded):
		return loaded
	var exchanged: Dictionary = HttpGd.post_json(base, PATH_GUEST, PackedStringArray(), {}, transport)
	var body_raw: Variant = exchanged.get(HttpGd.KEY_BODY, {})
	if not _flag(exchanged, HttpGd.KEY_OK) or typeof(body_raw) != TYPE_DICTIONARY:
		return _fail(str(exchanged.get(HttpGd.KEY_REASON, HttpGd.REASON_TRANSPORT)))
	var minted_body: Dictionary = body_raw
	var minted: Dictionary = read_mint(minted_body)
	if not _ok(minted):
		return minted
	save_guest(guest_path, minted)
	return minted


static func read_mint(raw: Dictionary) -> Dictionary:
	if raw.has("error"):
		return _fail(str(raw.get("error", SubmitGd.REASON_RESPONSE_INVALID)))
	var guest_id: String = str(raw.get(KEY_GUEST_ID, ""))
	var recovery_key: String = str(raw.get(KEY_RECOVERY_KEY, ""))
	if not guest_id.begins_with("gst_") or recovery_key.length() < 32:
		return _fail(SubmitGd.REASON_RESPONSE_INVALID)
	return {
		SubmitGd.KEY_OK: true,
		SubmitGd.KEY_REASON: "",
		KEY_GUEST_ID: guest_id,
		KEY_RECOVERY_KEY: recovery_key,
	}


static func load_guest(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return _fail(SubmitGd.REASON_RESPONSE_INVALID)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail(SubmitGd.REASON_RESPONSE_INVALID)
	var body: Dictionary = parsed
	return read_mint(body)


static func save_guest(path: String, guest: Dictionary) -> void:
	if path.is_empty() or path.begins_with("res://"):
		return
	var abs_path: String = path
	if path.begins_with("user://"):
		abs_path = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		KEY_GUEST_ID: str(guest.get(KEY_GUEST_ID, "")),
		KEY_RECOVERY_KEY: str(guest.get(KEY_RECOVERY_KEY, "")),
	}))
	file.close()


static func _fail(reason: String) -> Dictionary:
	return {
		SubmitGd.KEY_OK: false,
		SubmitGd.KEY_REASON: reason,
	}


static func _ok(raw: Dictionary) -> bool:
	return _flag(raw, SubmitGd.KEY_OK)


static func _flag(raw: Dictionary, key: String) -> bool:
	var flag: Variant = raw.get(key, false)
	return typeof(flag) == TYPE_BOOL and flag
