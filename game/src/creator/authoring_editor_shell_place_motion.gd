class_name AuthoringEditorShellPlaceMotion
extends RefCounted

## Place pendulum / Place ice. Public try_place_* stays on the shell
## facade so place_triggers.gd stays under E9.


static func try_place_pendulum(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	var x: int = cell_x * cell
	var y: int = cell_y * cell
	var z: int = cell_z * cell
	return shell.try_edit(pendulum_payload(entity_id, x, y, z, cell / 2, cell))


static func try_place_ice(
	shell: AuthoringEditorShell,
	entity_id: int,
	cell_x: int,
	cell_y: int,
	cell_z: int,
	yaw_bam: int
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	return shell.try_edit(
		ice_payload(entity_id, cell_x * cell, cell_y * cell, cell_z * cell, cell / 2, yaw_bam)
	)


static func pendulum_payload(
	entity_id: int, x: int, y: int, z: int, half: int, cell: int
) -> Dictionary:
	var dest_x: int = x + cell * 2
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"zone": {
					"shape": {
						"kind": SharedCollisionShapeKinds.BOX,
						"hx": half,
						"hy": half,
						"hz": half,
					},
					"tags": [
						TraprushTopologyCompiler.SOLID_ZONE_TAG,
						TraprushTopologyCompiler.PENDULUM_ZONE_TAG,
					],
				},
				"mover": {
					"path": [
						{"x": dest_x, "y": y, "z": z},
						{"x": x, "y": y, "z": z},
					],
					"speed": Fixed.SCALE / 16,
					"loop": true,
				},
			},
		},
	}


static func ice_payload(
	entity_id: int, x: int, y: int, z: int, half: int, yaw_bam: int
) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": yaw_bam},
				"zone": {
					"shape": {
						"kind": SharedCollisionShapeKinds.BOX,
						"hx": half,
						"hy": half,
						"hz": half,
					},
					"tags": [
						TraprushTopologyCompiler.SOLID_ZONE_TAG,
						TraprushTopologyCompiler.ICE_ZONE_TAG,
					],
				},
			},
		},
	}
