extends Node

## F6 visual sandbox for the authoring editor shell.
## Not the main scene. Not CI. Play current scene (F6), not the project (F5).
## Place checkpoint, then Preview. Editor stays open; Preview does not auto-follow.

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")


func _ready() -> void:
	var shell: AuthoringEditorShell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(shell)
	shell.open()
