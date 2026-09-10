extends GutTest

## M4b chapter 5: Guest identity, username+password, claim drafts.
## Publish HTTP and match tickets stay unbound.

const AccountCatalogGd := preload("res://src/ugc/account_catalog.gd")
const AccountEntryGd := preload("res://src/client/account_entry.gd")
const MatchLobbyChromeGd := preload("res://src/client/match_lobby_chrome.gd")
const MatchLobbyShellGd := preload("res://src/client/match_lobby_shell.gd")

const DOCUMENT: Dictionary = {
	"schema_version": 1,
	"cell": 65536,
	"revision": 1,
	"entities": [],
}


var _shell: MatchLobbyShellGd = null
var _identity: String = ""


func before_each() -> void:
	_identity = "user://account_catalog_test_%s.json" % str(Time.get_ticks_usec())


func after_each() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.free()
	_shell = null
	var abs_path: String = OS.get_user_data_dir().path_join(_identity.substr(7))
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func test_guest_persists_and_register_claims_the_draft() -> void:
	var catalog: AccountCatalogGd = AccountCatalogGd.new()
	catalog.identity_path = _identity
	var guest: Dictionary = catalog.ensure_guest()
	assert_true(_flag(guest, AccountCatalogGd.KEY_OK, false))
	assert_true(str(guest.get(AccountCatalogGd.KEY_GUEST_ID, "")).begins_with("gst_"))
	assert_true(_flag(catalog.put_draft(DOCUMENT), AccountCatalogGd.KEY_OK, false))
	var registered: Dictionary = catalog.register("warm_forge", "password1")
	assert_true(_flag(registered, AccountCatalogGd.KEY_OK, false))
	assert_eq(_text(registered, AccountCatalogGd.KEY_USERNAME), "warm_forge")
	var owned: Dictionary = catalog.get_draft()
	assert_true(_flag(owned, AccountCatalogGd.KEY_OK, false))
	assert_eq(_text(owned, "owner_kind"), "account")
	var taken: Dictionary = catalog.register("warm_forge", "password1")
	assert_false(_flag(taken, AccountCatalogGd.KEY_OK, true))
	assert_eq(_text(taken, AccountCatalogGd.KEY_REASON), AccountCatalogGd.REASON_USERNAME_TAKEN)


func test_login_rejects_bad_password_and_free_text_usernames() -> void:
	var catalog: AccountCatalogGd = AccountCatalogGd.new()
	catalog.identity_path = _identity
	assert_true(_flag(catalog.register("quiet_lane", "password1"), AccountCatalogGd.KEY_OK, false))
	var wrong: Dictionary = catalog.login("quiet_lane", "nope____")
	assert_false(_flag(wrong, AccountCatalogGd.KEY_OK, true))
	assert_eq(_text(wrong, AccountCatalogGd.KEY_REASON), AccountCatalogGd.REASON_CREDENTIALS)
	var prose: Dictionary = catalog.register("has space", "password1")
	assert_false(_flag(prose, AccountCatalogGd.KEY_OK, true))
	assert_eq(_text(prose, AccountCatalogGd.KEY_REASON), AccountCatalogGd.REASON_USERNAME_INVALID)


func test_second_claim_of_the_same_guest_is_rejected() -> void:
	var catalog: AccountCatalogGd = AccountCatalogGd.new()
	catalog.identity_path = _identity
	assert_true(_flag(catalog.register("swift_gate", "password1"), AccountCatalogGd.KEY_OK, false))
	var again: Dictionary = catalog.claim()
	assert_false(_flag(again, AccountCatalogGd.KEY_OK, true))
	assert_eq(_text(again, AccountCatalogGd.KEY_REASON), AccountCatalogGd.REASON_GUEST_CLAIMED)


func test_lobby_account_window_registers_and_returns() -> void:
	_shell = MatchLobbyShellGd.create()
	add_child(_shell)
	assert_true(_shell.open())
	var button: Button = _shell.window.get_node(
		"VBoxContainer/MatchActions/%s" % MatchLobbyChromeGd.ACCOUNT_NAME
	) as Button
	assert_not_null(button)
	assert_eq(button.text, UiCopy.text(UiCopy.ACCOUNT))
	assert_true(_shell.try_open_account())
	assert_true(_shell.account.is_open())
	assert_false(_shell.window.visible)
	_shell.account.catalog.identity_path = _identity
	_shell.account.catalog.ensure_guest()
	_shell.account.username_edit.text = "iron_spire"
	_shell.account.password_edit.text = "password1"
	_shell.account.bind_document(DOCUMENT)
	assert_true(_shell.account.try_register())
	assert_true(_shell.account.catalog.signed_in())
	assert_eq(_shell.account.catalog.username, "iron_spire")
	var owned: Dictionary = _shell.account.catalog.get_draft()
	assert_true(_flag(owned, AccountCatalogGd.KEY_OK, false))
	assert_true(_shell.try_close_account())
	assert_false(_shell.account.is_open())
	assert_true(_shell.window.visible)


func _flag(result: Dictionary, key: String, fallback: bool) -> bool:
	var raw: Variant = result.get(key, fallback)
	return raw == true


func _text(result: Dictionary, key: String) -> String:
	return str(result.get(key, ""))
