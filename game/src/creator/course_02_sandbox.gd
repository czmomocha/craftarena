extends Node

## F6 visual sandbox for the second official TRAPRUSH course.
## Not the main scene. Not CI. Play current scene (F6), not the project (F5).
## Imports the published AuthoringDocument. Validator should be empty.
## Open Preview, then Play: the player marker sits on the first checkpoint pad.
## WASD moves the marker in world XZ while the Preview window is visible.
## Occupancy accepts checkpoint pads; walking into a portal marker lands upstairs.
## After the last pad, walking onto the finish marker records finish=n.
## Status shows pads=n/m, floor=n, and finish=n.

const AuthoringDocument := preload("res://src/creator/authoring_document.gd")
const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")

const COURSE_PATH := "res://content/official/traprush/course_02.json"


func _ready() -> void:
	var shell: AuthoringEditorShell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(shell)
	shell.open()
	var data: Dictionary = AuthoringDocument.load_json(COURSE_PATH)
	if data.is_empty() or not shell.import_document(data):
		push_error("official TRAPRUSH course 02 failed to load")
