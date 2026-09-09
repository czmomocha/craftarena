class_name AuthoringEditorShellPlaceTriggers
extends RefCounted

## Place switch / Place gate payloads. Public try_place_* stays on the shell
## facade so authoring_editor_shell_place.gd stays under E9.

const DEFAULT_LINK_GROUP: int = 1
## Place hazard 的 cooldown 桩是 1，喷火用那个半周期不可读。30 tick ≈ 0.5 s。
const FLAME_COOLDOWN_STUB: int = 30


static func try_place_switch(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place(shell, entity_id, cell_x, cell_y, cell_z, switch_payload)


static func try_place_gate(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place(shell, entity_id, cell_x, cell_y, cell_z, gate_payload)


static func try_place_energy_wall(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place(shell, entity_id, cell_x, cell_y, cell_z, energy_wall_payload)


static func try_place_spike(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place(shell, entity_id, cell_x, cell_y, cell_z, spike_payload)


static func try_place_flame(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place(shell, entity_id, cell_x, cell_y, cell_z, flame_payload)


static func try_place_crusher(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	var x: int = cell_x * cell
	var y: int = cell_y * cell
	var z: int = cell_z * cell
	return shell.try_edit(crusher_payload(entity_id, x, y, z, cell / 2, cell))


static func try_place_roller(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place(shell, entity_id, cell_x, cell_y, cell_z, roller_payload)


static func try_place_rubble(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place(shell, entity_id, cell_x, cell_y, cell_z, rubble_payload)


static func try_place_obstacle_core(
	shell: AuthoringEditorShell, entity_id: int, cell_x: int, cell_y: int, cell_z: int
) -> bool:
	return _try_place(shell, entity_id, cell_x, cell_y, cell_z, obstacle_core_payload)


static func try_place_named(
	shell: AuthoringEditorShell,
	kind: String,
	entity_id: int,
	cell_x: int,
	cell_y: int,
	cell_z: int
) -> bool:
	match kind:
		"spike":
			return try_place_spike(shell, entity_id, cell_x, cell_y, cell_z)
		"flame":
			return try_place_flame(shell, entity_id, cell_x, cell_y, cell_z)
		"crusher":
			return try_place_crusher(shell, entity_id, cell_x, cell_y, cell_z)
		"roller":
			return try_place_roller(shell, entity_id, cell_x, cell_y, cell_z)
		"rubble":
			return try_place_rubble(shell, entity_id, cell_x, cell_y, cell_z)
		"obstacle_core":
			return try_place_obstacle_core(shell, entity_id, cell_x, cell_y, cell_z)
		"pendulum":
			return AuthoringEditorShellPlaceMotion.try_place_pendulum(
				shell, entity_id, cell_x, cell_y, cell_z
			)
		_:
			return false


static func try_place_gated_portal(
	shell: AuthoringEditorShell,
	entity_id: int,
	target_id: int,
	cell_x: int,
	cell_y: int,
	cell_z: int
) -> bool:
	if shell.session == null or shell.session.world == null or shell.session.world.grid == null:
		return false
	var cell: int = shell.session.world.grid.cell
	return shell.try_edit(
		gated_portal_payload(
			entity_id, target_id, cell_x * cell, cell_y * cell, cell_z * cell, cell / 2
		)
	)


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


static func energy_wall_payload(entity_id: int, x: int, y: int, z: int, half: int) -> Dictionary:
	return _destructible_payload(
		entity_id, x, y, z, half, TraprushTopologyCompiler.ENERGY_WALL_ZONE_TAG
	)


static func rubble_payload(entity_id: int, x: int, y: int, z: int, half: int) -> Dictionary:
	return _destructible_payload(
		entity_id, x, y, z, half, TraprushTopologyCompiler.RUBBLE_ZONE_TAG
	)


static func obstacle_core_payload(entity_id: int, x: int, y: int, z: int, half: int) -> Dictionary:
	return _destructible_payload(
		entity_id, x, y, z, half, TraprushTopologyCompiler.OBSTACLE_CORE_ZONE_TAG
	)


static func _destructible_payload(
	entity_id: int, x: int, y: int, z: int, half: int, tag: String
) -> Dictionary:
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


static func gated_portal_payload(
	entity_id: int, target_id: int, x: int, y: int, z: int, half: int
) -> Dictionary:
	return {
		"op": "place",
		"record": {
			"schema_version": 1,
			"entity_id": entity_id,
			"components": {
				"transform": {"x": x, "y": y, "z": z, "yaw_bam": 0},
				"portal": {"target_id": target_id, "yaw_bam": 0, "cooldown_ticks": 0},
				"zone": {
					"shape": {
						"kind": SharedCollisionShapeKinds.BOX,
						"hx": half,
						"hy": half,
						"hz": half,
					},
					"tags": [TraprushTopologyCompiler.PORTAL_SWITCH_ZONE_TAG],
				},
				"interactable": {
					"state": 0,
					"link_group": DEFAULT_LINK_GROUP,
				},
			},
		},
	}


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


static func spike_payload(entity_id: int, x: int, y: int, z: int, half: int) -> Dictionary:
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
						TraprushTopologyCompiler.SPIKE_ZONE_TAG,
					],
				},
			},
		},
	}


static func flame_payload(entity_id: int, x: int, y: int, z: int, half: int) -> Dictionary:
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
					"cooldown_ticks": FLAME_COOLDOWN_STUB,
				},
				"zone": {
					"shape": {
						"kind": SharedCollisionShapeKinds.BOX,
						"hx": half,
						"hy": half,
						"hz": half,
					},
					"tags": [TraprushTopologyCompiler.FLAME_ZONE_TAG],
				},
			},
		},
	}


static func roller_payload(entity_id: int, x: int, y: int, z: int, half: int) -> Dictionary:
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
					"cooldown_ticks": FLAME_COOLDOWN_STUB,
				},
				"zone": {
					"shape": {
						"kind": SharedCollisionShapeKinds.BOX,
						"hx": half,
						"hy": half,
						"hz": half,
					},
					"tags": [TraprushTopologyCompiler.ROLLER_ZONE_TAG],
				},
			},
		},
	}


static func crusher_payload(
	entity_id: int, x: int, y: int, z: int, half: int, cell: int
) -> Dictionary:
	var dest_y: int = y + cell
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
						TraprushTopologyCompiler.CRUSHER_ZONE_TAG,
					],
				},
				"mover": {
					"path": [
						{"x": x, "y": dest_y, "z": z},
						{"x": x, "y": y, "z": z},
					],
					"speed": Fixed.SCALE / 16,
					"loop": true,
				},
			},
		},
	}
