extends Node

## F6 visual sandbox for the authoring editor shell.
## Not the main scene. Not CI. Play current scene (F6), not the project (F5).
## Seeds a checkpoint and one dangling portal so the Editor shows validator details.
## TRAPRUSH tools can pair the portal; Preview stays a snapshot.

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")


func _ready() -> void:
	var shell: AuthoringEditorShell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(shell)
	shell.open()
	shell.tools.place_next_checkpoint()
	shell.tools.place_next_portal()
