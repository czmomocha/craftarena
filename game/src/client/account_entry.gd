class_name AccountEntry
extends Node

## Lobby window for Guest identity, register, login, and draft claim (CD-13).
## Uses the in-process AccountCatalog. Control-plane HTTP is tested separately.
## Publish and matchmaking tickets stay unbound.

const CatalogGd := preload("res://src/ugc/account_catalog.gd")

const WINDOW_NAME: String = "AccountWindow"
const USERNAME_NAME: String = "AccountUsername"
const PASSWORD_NAME: String = "AccountPassword"
const STATUS_NAME: String = "AccountStatus"
const REGISTER_NAME: String = "AccountRegister"
const LOGIN_NAME: String = "AccountLogin"
const CLAIM_NAME: String = "AccountClaim"
const CLOSE_NAME: String = "AccountClose"

var window: Window = null
var username_edit: LineEdit = null
var password_edit: LineEdit = null
var status: Label = null
var lobby_window: Window = null
var catalog: CatalogGd = CatalogGd.new()
var last_document: Dictionary = {}


static func ensure(shell: MatchLobbyShell, existing: AccountEntry) -> AccountEntry:
	if existing != null:
		return existing
	var entry := new()
	entry.lobby_window = shell.window
	shell.add_child(entry)
	return entry


func is_open() -> bool:
	return window != null and window.visible


func try_open() -> bool:
	_ensure_window()
	if window == null:
		return false
	catalog.ensure_guest()
	_refresh()
	window.visible = true
	_set_lobby_visible(false)
	return true


func try_close() -> bool:
	var lobby_hidden: bool = (
		lobby_window != null and is_instance_valid(lobby_window) and not lobby_window.visible
	)
	if not is_open() and not lobby_hidden:
		return false
	if window != null:
		window.visible = false
	_set_lobby_visible(true)
	return true


func bind_document(document: Dictionary) -> void:
	last_document = document.duplicate(true)


func try_register() -> bool:
	if not last_document.is_empty():
		catalog.put_draft(last_document)
	var result: Dictionary = catalog.register(_username(), _password())
	_refresh()
	return _ok(result)


func try_login() -> bool:
	var result: Dictionary = catalog.login(_username(), _password())
	_refresh()
	return _ok(result)


func try_claim() -> bool:
	if not last_document.is_empty() and not catalog.signed_in():
		catalog.put_draft(last_document)
	var result: Dictionary = catalog.claim()
	_refresh()
	return _ok(result)


func _ensure_window() -> void:
	if window != null:
		return
	window = Window.new()
	window.name = WINDOW_NAME
	window.title = UiCopy.text(UiCopy.WINDOW_ACCOUNT)
	window.size = Vector2i(640, 360)
	window.min_size = Vector2i(480, 280)
	window.exclusive = false
	window.transient = false
	window.close_requested.connect(_on_close)
	var root: VBoxContainer = VBoxContainer.new()
	root.name = "VBoxContainer"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	window.add_child(root)
	status = Label.new()
	status.name = STATUS_NAME
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status)
	username_edit = LineEdit.new()
	username_edit.name = USERNAME_NAME
	username_edit.placeholder_text = UiCopy.text(UiCopy.ACCOUNT_USERNAME)
	username_edit.focus_mode = Control.FOCUS_CLICK
	root.add_child(username_edit)
	password_edit = LineEdit.new()
	password_edit.name = PASSWORD_NAME
	password_edit.placeholder_text = UiCopy.text(UiCopy.ACCOUNT_PASSWORD)
	password_edit.secret = true
	password_edit.focus_mode = Control.FOCUS_CLICK
	root.add_child(password_edit)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.name = "AccountActions"
	root.add_child(actions)
	_add_button(actions, REGISTER_NAME, UiCopy.ACCOUNT_REGISTER, try_register)
	_add_button(actions, LOGIN_NAME, UiCopy.ACCOUNT_LOGIN, try_login)
	_add_button(actions, CLAIM_NAME, UiCopy.ACCOUNT_CLAIM, try_claim)
	_add_button(actions, CLOSE_NAME, UiCopy.BACK_TO_LOBBY, try_close)
	add_child(window)


func _add_button(row: BoxContainer, node_name: String, copy_key: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = UiCopy.text(copy_key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	if handler.is_valid():
		button.pressed.connect(handler)
	row.add_child(button)


func _refresh() -> void:
	if status == null:
		return
	catalog.ensure_guest()
	if catalog.signed_in():
		status.text = "%s  %s" % [UiCopy.text(UiCopy.ACCOUNT_SIGNED_IN), catalog.username]
	else:
		status.text = "%s  %s" % [UiCopy.text(UiCopy.ACCOUNT_GUEST), catalog.guest_id]


func _username() -> String:
	if username_edit == null:
		return ""
	return username_edit.text.strip_edges()


func _password() -> String:
	if password_edit == null:
		return ""
	return password_edit.text


func _ok(result: Dictionary) -> bool:
	var raw: Variant = result.get(CatalogGd.KEY_OK, false)
	return raw == true


func _on_close() -> void:
	try_close()


func _set_lobby_visible(visible: bool) -> void:
	if lobby_window == null or not is_instance_valid(lobby_window):
		return
	lobby_window.visible = visible
