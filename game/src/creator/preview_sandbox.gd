extends Node

## F6 visual sandbox for Preview 3D mapping. Not the main scene. Not CI.
## Opens AuthoringPreviewShell with two lattice placeholders.

const CELL: int = 65536


func _ready() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	session.try_apply(_edit(1, 0, _place_transform(1, 0, 0, 0, 0)))
	session.try_apply(_edit(2, 1, _place_transform(2, 2 * CELL, 0, 0, 16384)))
	var shell: AuthoringPreviewShell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(shell)
	shell.open_from(session)


func _place_transform(entity_id: int, x: int, y: int, z: int, yaw_bam: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": yaw_bam},
			},
		},
	}


func _edit(command_id: int, expected_revision: int, payload: Dictionary) -> SharedCommand:
	return SharedCommand.create(
		command_id,
		2,
		command_id,
		0,
		expected_revision,
		"content-v1",
		payload,
		"trace-preview-sandbox",
		SharedCommand.Kind.EDIT
	)
