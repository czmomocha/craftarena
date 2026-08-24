extends Node

## F6 visual sandbox for the first official TRAPRUSH course.
## Not the main scene. Not CI. Play current scene (F6), not the project (F5).
## Imports the published AuthoringDocument. Validator should be empty.
## editor_sandbox.tscn still seeds a dangling portal for validator visuals.
## Open Preview, then Play: the player marker sits on the first checkpoint pad.
## WASD moves the marker in world XZ while the Preview window is visible.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")

const COURSE_PATH := "res://content/official/traprush/course_01.json"


func _ready() -> void:
	var shell: AuthoringEditorShell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(shell)
	shell.open()
	var data: Dictionary = AuthoringDocument.load_json(COURSE_PATH)
	if data.is_empty() or not shell.import_document(data):
		push_error("official TRAPRUSH course failed to load")
