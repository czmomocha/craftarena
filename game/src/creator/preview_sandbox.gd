extends Node

## F6 visual sandbox for Preview 3D, gizmos, reachability overlay, and Play.
## Not the main scene. Not CI. Play current scene (F6), not the project (F5).
## Preview Play compiles this seeded world and draws the player marker.
## WASD moves the marker in world XZ while the Preview window is visible.
## Occupancy accepts checkpoint pads; walking into a portal marker lands
## through try_land_exit. Overlapping the finish box after every pad records
## finish=n. Reset or R snaps back to the last accepted pad. Status shows
## pads=n/m, floor=n, and finish=n. Entity 6 is a period-1 hazard on +X so
## Play then D hits a wall; Advance tick opens it.

const CELL: int = 65536


func _ready() -> void:
	var session: AuthoringSession = AuthoringSession.new()
	session.try_apply(_edit(1, 0, _place_portal_checkpoint(1, 2, 0, 0, 0, 0)))
	session.try_apply(_edit(2, 1, _place_portal_checkpoint(2, 1, 1, 2 * CELL, 0, 0)))
	session.try_apply(_edit(3, 2, _place_portal_checkpoint(3, 1, 2, 0, 0, 2 * CELL)))
	session.try_apply(_edit(4, 3, _place_portal(4, 99, 2 * CELL, 0, 2 * CELL)))
	session.try_apply(_edit(5, 4, _place_checkpoint(5, 3, 0, CELL, 0)))
	session.try_apply(_edit(6, 5, _place_hazard(6, CELL, 0, 0, 1)))
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


func _place_checkpoint(entity_id: int, order: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"checkpoint": {"order": order, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
			},
		},
	}


func _place_hazard(entity_id: int, x: int, y: int, z: int, cooldown_ticks: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"hazard": {"damage": 0, "knockback": 0, "cooldown_ticks": cooldown_ticks},
			},
		},
	}


func _place_portal_checkpoint(
	entity_id: int,
	target_id: int,
	order: int,
	x: int,
	y: int,
	z: int
) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
				"checkpoint": {"order": order, "respawn_dx": 0, "respawn_dy": 0, "respawn_dz": 0},
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
