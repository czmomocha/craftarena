class_name AuthoringEditorShellFollow
extends RefCounted

## Preview follow / safe-point forward for AuthoringEditorShell.
## Public open_preview stays on the shell facade so this file stays under E9.


static func open_preview(shell: AuthoringEditorShell) -> bool:
	if shell.session == null:
		return false
	if shell.preview == null:
		shell.preview = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
		if shell.preview == null:
			return false
		shell.add_child(shell.preview)
	if shell.preview_follows and shell.preview.preview != null and shell.preview.preview.connected:
		if shell.preview.show_window():
			shell.refresh_status()
			return true
	shell.preview_follows = shell.preview.open_from(shell.session)
	shell.refresh_status()
	return shell.preview_follows


static func forward_payload(shell: AuthoringEditorShell, payload: Dictionary, expected_revision: int) -> void:
	if not shell.preview_follows:
		return
	if payload.is_empty():
		shell.preview_follows = false
		return
	var command: SharedCommand = SharedCommand.create(
		shell._next_command_id,
		AuthoringEditorShell.ACTOR_ID,
		shell._next_command_id,
		0,
		expected_revision,
		AuthoringEditorShell.CONTENT_VERSION,
		payload,
		AuthoringEditorShell.TRACE_ID,
		SharedCommand.Kind.EDIT
	)
	shell._next_command_id += 1
	if command == null:
		shell.preview_follows = false
		return
	forward_command(shell, command)


static func forward_command(shell: AuthoringEditorShell, command: SharedCommand) -> void:
	if not shell.preview_follows:
		return
	if shell.preview == null or shell.preview.preview == null or shell.preview.preview.world == null:
		shell.preview_follows = false
		return
	var level: String = PreviewPatchLevels.classify(command, shell.preview.preview.world)
	if level.is_empty():
		shell.preview_follows = false
		return
	if not shell.preview.try_apply_patch(level, command):
		shell.preview_follows = false
