class_name AuthoringEditorShellPublish
extends RefCounted

## Publish button path on AuthoringEditorShell. Prepares the player payload
## and either hands it to an injected submit callback or stores it for tests.
## Never calls POST /content/publish. Never holds CONTENT_SIGN_KEY.

const SubmitGd := preload("res://src/ugc/content_submit.gd")


static func try_publish(shell: AuthoringEditorShell) -> bool:
	if shell == null or shell.session == null:
		return false
	var prepared: Dictionary = SubmitGd.prepare(shell.session.world)
	shell.last_publish = prepared
	if not _ok(prepared):
		shell.refresh_status()
		return false
	if shell.on_submit.is_valid():
		var raw: Variant = shell.on_submit.call(SubmitGd.request_body(prepared))
		if typeof(raw) != TYPE_DICTIONARY:
			return raw == true
		var view: Dictionary = raw
		return apply_view(shell, view)
	shell.refresh_status()
	return true


static func apply_view(shell: AuthoringEditorShell, raw: Dictionary) -> bool:
	var view: Dictionary = SubmitGd.read_view(raw)
	shell.last_publish = view
	shell.refresh_status()
	return _ok(view)


static func status_token(shell: AuthoringEditorShell) -> String:
	if shell == null:
		return ""
	var raw: Dictionary = shell.last_publish
	if raw.is_empty():
		return "idle"
	if not _ok(raw):
		return str(raw.get(SubmitGd.KEY_REASON, "error"))
	if raw.has(SubmitGd.KEY_ID):
		var version_raw: Variant = raw.get(SubmitGd.KEY_VERSION, 0)
		var version: int = 0
		if typeof(version_raw) == TYPE_INT:
			version = version_raw
		return "%s@%d" % [str(raw.get(SubmitGd.KEY_ID, "")), version]
	return "ready"


static func _ok(raw: Dictionary) -> bool:
	var flag: Variant = raw.get(SubmitGd.KEY_OK, false)
	return typeof(flag) == TYPE_BOOL and flag
