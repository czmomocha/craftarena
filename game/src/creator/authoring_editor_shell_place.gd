class_name AuthoringEditorShellPlace
extends RefCounted

## EDIT place payloads for AuthoringEditorShell.
## Public try_place_* stays on the shell facade so this file stays under E9.


const PickupKindsGd := preload("res://src/ugc/traprush_pickup_kinds.gd")
const ConvertGd := preload("res://src/creator/authoring_preview_map_convert.gd")


static func try_place_checkpoint(
	shell: AuthoringEditorShell, entity_id: int, order: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	return shell.try_edit(checkpoint_payload(entity_id, order, cell_x * cell, cell_y * cell, cell_z * cell))


static func try_place_portal(
	shell: AuthoringEditorShell, entity_id: int, target_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	return shell.try_edit(portal_payload(entity_id, target_id, cell_x * cell, cell_y * cell, cell_z * cell))


static func try_place_solid(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place_zone(shell, entity_id, cell_x, cell_y, cell_z, TraprushTopologyCompiler.SOLID_ZONE_TAG)


static func try_place_finish(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place_zone(shell, entity_id, cell_x, cell_y, cell_z, TraprushTopologyCompiler.FINISH_ZONE_TAG)


static func try_place_hazard(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	return shell.try_edit(hazard_payload(entity_id, cell_x * cell, cell_y * cell, cell_z * cell))


static func try_place_crate(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	return shell.try_edit(crate_payload(entity_id, cell_x * cell, cell_y * cell, cell_z * cell))


static func try_place_pickup(
	shell: AuthoringEditorShell,
	entity_id: int,
	cell_x: int,
	cell_y: int,
	cell_z: int,
	kind: String
) -> bool:
	if not PickupKindsGd.contains(kind):
		return false
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	return shell.try_edit(pickup_payload(entity_id, cell_x * cell, cell_y * cell, cell_z * cell, kind))


static func try_move_entity(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var record: SharedComponentRecord = shell.session.world.get_record(entity_id)
	if record == null:
		return false
	var pose: Dictionary = ConvertGd.pose_from_record(record)
	if pose.is_empty():
		return false
	var pose_x_raw: Variant = pose.get("x", null)
	var pose_y_raw: Variant = pose.get("y", null)
	var pose_z_raw: Variant = pose.get("z", null)
	if typeof(pose_x_raw) != TYPE_INT or typeof(pose_y_raw) != TYPE_INT or typeof(pose_z_raw) != TYPE_INT:
		return false
	var pose_x: int = pose_x_raw
	var pose_y: int = pose_y_raw
	var pose_z: int = pose_z_raw
	var cell: int = shell.session.world.grid.cell
	var x: int = cell_x * cell
	var y: int = cell_y * cell
	var z: int = cell_z * cell
	if pose_x == x and pose_y == y and pose_z == z:
		return true
	if not shell.session.world.grid.accepts_xyz(x, y, z):
		return false
	var next: Dictionary = record.to_dictionary()
	var components_raw: Variant = next.get("components", {})
	if typeof(components_raw) != TYPE_DICTIONARY:
		return false
	var components: Dictionary = components_raw
	var transform_raw: Variant = components.get(SharedComponentNames.TRANSFORM, {})
	if typeof(transform_raw) != TYPE_DICTIONARY:
		return false
	var transform_bag: Dictionary = transform_raw
	var transform: Dictionary = transform_bag.duplicate(true)
	transform["x"] = x
	transform["y"] = y
	transform["z"] = z
	components[SharedComponentNames.TRANSFORM] = transform
	next["components"] = components
	return shell.try_edit({"op": "set_component", "record": next})


static func _try_place_zone(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int, tag: String
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	return shell.try_edit(zone_payload(entity_id, cell_x * cell, cell_y * cell, cell_z * cell, cell / 2, tag))


static func checkpoint_payload(entity_id: int, order: int, x: int, y: int, z: int) -> Dictionary:
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


static func portal_payload(entity_id: int, target_id: int, x: int, y: int, z: int) -> Dictionary:
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


static func zone_payload(entity_id: int, x: int, y: int, z: int, half: int, tag: String) -> Dictionary:
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
					"tags": [tag],
				},
			},
		},
	}


static func hazard_payload(entity_id: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"hazard": {
					"damage": 0,
					"knockback": 0,
					"cooldown_ticks": TraprushEditorPanel.HAZARD_COOLDOWN_STUB,
				},
			},
		},
	}


static func crate_payload(entity_id: int, x: int, y: int, z: int) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"destructible": {
					"durability": TraprushEditorPanel.CRATE_DURABILITY_STUB,
					"regen_policy_id": TraprushEditorPanel.CRATE_REGEN_POLICY_STUB,
				},
			},
		},
	}


static func pickup_payload(entity_id: int, x: int, y: int, z: int, kind: String) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"inventory": {"item_state": kind},
			},
		},
	}
