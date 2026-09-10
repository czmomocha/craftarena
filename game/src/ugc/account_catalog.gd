class_name AccountCatalog
extends RefCounted

## In-memory Guest / register / login / claim (CD-13). Control-plane HTTP
## is the durable store; this type lets GUT and the lobby window exercise
## the same verbs without sockets. Publish and match tickets stay unbound.

const KEY_OK: String = "ok"
const KEY_REASON: String = "reason"
const KEY_GUEST_ID: String = "guest_id"
const KEY_RECOVERY_KEY: String = "recovery_key"
const KEY_ACCOUNT_ID: String = "account_id"
const KEY_USERNAME: String = "username"
const KEY_SESSION: String = "session"
const KEY_DOCUMENT: String = "document"
const KEY_HAD_DRAFT: String = "had_draft"
const REASON_USERNAME_INVALID: String = "username_invalid"
const REASON_PASSWORD_INVALID: String = "password_invalid"
const REASON_USERNAME_TAKEN: String = "username_taken"
const REASON_CREDENTIALS: String = "credentials_invalid"
const REASON_GUEST_MISSING: String = "guest_not_found"
const REASON_GUEST_CLAIMED: String = "guest_claimed"
const REASON_SESSION: String = "session_invalid"
const REASON_DRAFT_MISSING: String = "draft_missing"
const REASON_DRAFT_CONFLICT: String = "draft_conflict"
const REASON_DOCUMENT: String = "document_invalid"

const USERNAME_RE: String = "^[A-Za-z0-9][A-Za-z0-9._-]{2,23}$"
const GUEST_FILE: String = "user://guest_identity.json"

var guest_id: String = ""
var recovery_key: String = ""
var session: String = ""
var username: String = ""
var account_id: String = ""
var identity_path: String = GUEST_FILE
var _guests: Dictionary = {}
var _accounts: Dictionary = {}
var _sessions: Dictionary = {}
var _drafts: Dictionary = {}
var _claimed: Dictionary = {}
var _passwords: Dictionary = {}


func ensure_guest() -> Dictionary:
	if guest_id != "" and _guests.has(guest_id):
		return _ok_guest()
	if _load_identity():
		return _ok_guest()
	guest_id = "gst_%s" % _hex(16)
	recovery_key = _hex(32)
	_guests[guest_id] = recovery_key
	_save_identity()
	return _ok_guest()


func register(next_username: String, password: String) -> Dictionary:
	if not _username_ok(next_username):
		return _fail(REASON_USERNAME_INVALID)
	if not _password_ok(password):
		return _fail(REASON_PASSWORD_INVALID)
	if _accounts.has(next_username):
		return _fail(REASON_USERNAME_TAKEN)
	ensure_guest()
	var next_id: String = "acc_%s" % _hex(16)
	_accounts[next_username] = next_id
	_passwords[next_username] = password
	var claimed: Dictionary = claim_for(next_id, guest_id, recovery_key)
	if not _flag(claimed, KEY_OK, false) and _text(claimed, KEY_REASON) != REASON_GUEST_CLAIMED:
		return claimed
	return _open_session(next_id, next_username)


func login(next_username: String, password: String) -> Dictionary:
	if not _accounts.has(next_username):
		return _fail(REASON_CREDENTIALS)
	if str(_passwords.get(next_username, "")) != password:
		return _fail(REASON_CREDENTIALS)
	return _open_session(str(_accounts[next_username]), next_username)


func put_draft(document: Dictionary) -> Dictionary:
	if document.is_empty():
		return _fail(REASON_DOCUMENT)
	if session != "":
		_drafts["account\n%s" % account_id] = document.duplicate(true)
		return _ok_draft("account", account_id, document)
	ensure_guest()
	if _claimed.has(guest_id):
		return _fail(REASON_GUEST_CLAIMED)
	_drafts["guest\n%s" % guest_id] = document.duplicate(true)
	return _ok_draft("guest", guest_id, document)


func get_draft() -> Dictionary:
	var key: String = ""
	var kind: String = ""
	var owner: String = ""
	if session != "":
		kind = "account"
		owner = account_id
		key = "account\n%s" % account_id
	else:
		ensure_guest()
		if _claimed.has(guest_id):
			return _fail(REASON_GUEST_CLAIMED)
		kind = "guest"
		owner = guest_id
		key = "guest\n%s" % guest_id
	if not _drafts.has(key):
		return _fail(REASON_DRAFT_MISSING)
	var stored: Dictionary = _drafts[key]
	return _ok_draft(kind, owner, stored)


func claim() -> Dictionary:
	if session == "":
		return _fail(REASON_SESSION)
	return claim_for(account_id, guest_id, recovery_key)


func claim_for(next_account: String, next_guest: String, next_key: String) -> Dictionary:
	if not _guests.has(next_guest) or str(_guests[next_guest]) != next_key:
		return _fail(REASON_GUEST_MISSING)
	if _claimed.has(next_guest):
		return _fail(REASON_GUEST_CLAIMED)
	var guest_key: String = "guest\n%s" % next_guest
	var account_key: String = "account\n%s" % next_account
	var had: bool = _drafts.has(guest_key)
	if had and _drafts.has(account_key):
		return _fail(REASON_DRAFT_CONFLICT)
	_claimed[next_guest] = next_account
	if had:
		_drafts[account_key] = _drafts[guest_key]
		_drafts.erase(guest_key)
	return { KEY_OK: true, KEY_REASON: "", KEY_HAD_DRAFT: had }


func signed_in() -> bool:
	return session != ""


func _open_session(next_id: String, next_username: String) -> Dictionary:
	session = _hex(32)
	account_id = next_id
	username = next_username
	_sessions[session] = next_id
	return {
		KEY_OK: true,
		KEY_REASON: "",
		KEY_ACCOUNT_ID: account_id,
		KEY_USERNAME: username,
		KEY_SESSION: session,
	}


func _ok_guest() -> Dictionary:
	return {
		KEY_OK: true,
		KEY_REASON: "",
		KEY_GUEST_ID: guest_id,
		KEY_RECOVERY_KEY: recovery_key,
	}


func _ok_draft(kind: String, owner: String, document: Dictionary) -> Dictionary:
	return {
		KEY_OK: true,
		KEY_REASON: "",
		"owner_kind": kind,
		"owner_id": owner,
		KEY_DOCUMENT: document.duplicate(true),
	}


func _fail(reason: String) -> Dictionary:
	return { KEY_OK: false, KEY_REASON: reason }


func _username_ok(value: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile(USERNAME_RE)
	return regex.search(value) != null


func _password_ok(value: String) -> bool:
	return value.length() >= 8 and value.length() <= 64


func _hex(byte_count: int) -> String:
	var crypto: Crypto = Crypto.new()
	return crypto.generate_random_bytes(byte_count).hex_encode()


func _save_identity() -> void:
	var body: Dictionary = { KEY_GUEST_ID: guest_id, KEY_RECOVERY_KEY: recovery_key }
	var abs_path: String = _resolved(identity_path)
	if abs_path.is_empty() or abs_path.begins_with("res://"):
		return
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(body))
	file.close()


func _load_identity() -> bool:
	var abs_path: String = _resolved(identity_path)
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(abs_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var body: Dictionary = parsed
	var loaded_id: String = str(body.get(KEY_GUEST_ID, ""))
	var loaded_key: String = str(body.get(KEY_RECOVERY_KEY, ""))
	if not loaded_id.begins_with("gst_") or loaded_key.length() < 32:
		return false
	guest_id = loaded_id
	recovery_key = loaded_key
	if not _guests.has(guest_id):
		_guests[guest_id] = recovery_key
	return true


func _resolved(path: String) -> String:
	if path.begins_with("user://"):
		return OS.get_user_data_dir().path_join(path.substr(7))
	return ProjectSettings.globalize_path(path)


func _flag(result: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = result.get(key, fallback)
	return raw == true


func _text(result: Dictionary, key: String) -> String:
	return str(result.get(key, ""))
