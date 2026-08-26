extends Node

## F6 visual sandbox for the authoring editor shell.
## Not the main scene. Not CI. Play current scene (F6), not the project (F5).
## Seeds a checkpoint and one dangling portal so the Editor shows validator details.
## TRAPRUSH tools can pair the portal, or Place solid / Place hazard / Place crate
## / Place finish on the occupancy row. Press Preview, then keep editing: a
## connected Preview follows committed writes, and the status bar shows follow.
## Preview Play compiles the current Preview world; WASD moves the capsule
## while the Preview window is visible. Overlapping checkpoint pads accept
## ordered progress. Overlapping portal boxes land through try_land_exit.
## Overlapping the finish box after every pad records finish_tick.
## Reset or R snaps back to the last accepted pad.
## Stop leaves the sim.

const AuthoringEditorShell := preload("res://src/creator/authoring_editor_shell.gd")
const AuthoringSurfaceNames := preload("res://src/creator/authoring_surface_names.gd")


func _ready() -> void:
	var shell: AuthoringEditorShell = AuthoringEditorShell.create(AuthoringSurfaceNames.INTERNAL_DEV)
	add_child(shell)
	shell.open()
	shell.tools.place_next_checkpoint()
	shell.tools.place_next_portal()
