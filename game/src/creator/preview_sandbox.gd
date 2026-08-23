extends Node

## F6 visual sandbox for Preview 3D mapping and portal gizmos.
## Not the main scene. Not CI. Play current scene (F6), not the project (F5).

const CELL: int = 65536


func _ready() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	session.try_apply(_edit(1, 0, _place_portal(1, 2, 0, 0, 0)))
	session.try_apply(_edit(2, 1, _place_portal(2, 1, 2 * CELL, 0, 0)))
	session.try_apply(_edit(3, 2, _place_portal(3, 1, 0, 0, 2 * CELL)))
	session.try_apply(_edit(4, 3, _place_portal(4, 99, 2 * CELL, 0, 2 * CELL)))
	var shell: AuthoringPreviewShell = AuthoringPreviewShell.create(AuthoringPreviewHostKinds.WINDOW)
	add_child(shell)
	shell.open_from(session)


func _place_portal(entity_id: int, target_id: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
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
