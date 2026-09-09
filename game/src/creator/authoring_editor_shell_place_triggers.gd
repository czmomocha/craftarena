class_name AuthoringEditorShellPlaceTriggers
extends RefCounted

## Place switch / Place gate payloads. Public try_place_* stays on the shell
## facade so authoring_editor_shell_place.gd stays under E9.

const DEFAULT_LINK_GROUP: int = 1


static func try_place_switch(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place(shell, entity_id, cell_x, cell_y, cell_z, switch_payload)


static func try_place_gate(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place(shell, entity_id, cell_x, cell_y, cell_z, gate_payload)


static func _try_place(
	shell: AuthoringEditorShell,
	entity_id: int,
	cell_x: int,
	cell_y: int,
	cell_z: int,
	payload_fn: Callable
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	var raw: Variant = payload_fn.call(
		entity_id, cell_x * cell, cell_y * cell, cell_z * cell, cell / 2
	)
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = raw
	return shell.try_edit(payload)


static func switch_payload(entity_id: int, x: int, y: int, z: int, half: int) -> Dictionary:
	return _trigger_payload(
		entity_id, x, y, z, half, TraprushTopologyCompiler.SWITCH_ZONE_TAG
	)


static func gate_payload(entity_id: int, x: int, y: int, z: int, half: int) -> Dictionary:
	return _trigger_payload(
		entity_id, x, y, z, half, TraprushTopologyCompiler.GATE_ZONE_TAG
	)


static func _trigger_payload(
	entity_id: int, x: int, y: int, z: int, half: int, tag: String
) -> Dictionary:
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
						tag,
					],
				},
				"interactable": {
					"state": 0,
					"link_group": DEFAULT_LINK_GROUP,
				},
			},
		},
	}
