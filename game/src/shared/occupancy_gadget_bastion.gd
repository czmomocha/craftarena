extends RefCounted

## BASTION occupancy silhouettes. OccupancyGadget.attach dispatches here so
## occupancy_gadget.gd stays under E9. Colours come from PlaceholderSpec.


static func fill(gadget: Node3D, kind: String) -> bool:
	match kind:
		OccupancyGadget.KIND_BASTION_CORE:
			fill_core(gadget, PlaceholderSpec.BASTION_CORE_A_ALBEDO)
		OccupancyGadget.KIND_BASTION_CORE_B:
			fill_core(gadget, PlaceholderSpec.BASTION_CORE_B_ALBEDO)
		OccupancyGadget.KIND_BASTION_BUILD_SLOT:
			fill_slot(gadget, PlaceholderSpec.BASTION_BUILD_SLOT_ALBEDO)
		OccupancyGadget.KIND_BASTION_OBSTACLE_SLOT:
			fill_slot(gadget, PlaceholderSpec.BASTION_OBSTACLE_SLOT_ALBEDO)
		OccupancyGadget.KIND_BASTION_TOWER_ARROW:
			fill_tower(gadget, PlaceholderSpec.BASTION_TOWER_ARROW_ALBEDO)
		OccupancyGadget.KIND_BASTION_TOWER_CANNON:
			fill_tower(gadget, PlaceholderSpec.BASTION_TOWER_CANNON_ALBEDO)
		OccupancyGadget.KIND_BASTION_TOWER_FROST:
			fill_tower(gadget, PlaceholderSpec.BASTION_TOWER_FROST_ALBEDO)
		OccupancyGadget.KIND_BASTION_UNIT_SWIFT:
			fill_unit(gadget, PlaceholderSpec.BASTION_UNIT_SWIFT_ALBEDO, Vector3(0.28, 0.42, 0.28))
		OccupancyGadget.KIND_BASTION_UNIT_HEAVY:
			fill_unit(gadget, PlaceholderSpec.BASTION_UNIT_HEAVY_ALBEDO, Vector3(0.42, 0.55, 0.42))
		OccupancyGadget.KIND_BASTION_UNIT_SWARM:
			fill_unit(gadget, PlaceholderSpec.BASTION_UNIT_SWARM_ALBEDO, Vector3(0.22, 0.28, 0.22))
		OccupancyGadget.KIND_BASTION_OBSTACLE_BARRICADE:
			fill_barricade(gadget)
		OccupancyGadget.KIND_BASTION_OBSTACLE_SLOW:
			fill_slow(gadget)
		OccupancyGadget.KIND_BASTION_OBSTACLE_DIVERTER:
			fill_diverter(gadget)
		OccupancyGadget.KIND_BASTION_PATH:
			fill_path(gadget)
		_:
			return false
	return true


static func kind_for_tower(prototype_id: int) -> String:
	match prototype_id:
		BastionPrototypeCatalog.TOWER_ARROW:
			return OccupancyGadget.KIND_BASTION_TOWER_ARROW
		BastionPrototypeCatalog.TOWER_CANNON:
			return OccupancyGadget.KIND_BASTION_TOWER_CANNON
		BastionPrototypeCatalog.TOWER_FROST:
			return OccupancyGadget.KIND_BASTION_TOWER_FROST
		_:
			return ""


static func kind_for_unit(prototype_id: int) -> String:
	match prototype_id:
		BastionPrototypeCatalog.UNIT_SWIFT:
			return OccupancyGadget.KIND_BASTION_UNIT_SWIFT
		BastionPrototypeCatalog.UNIT_HEAVY:
			return OccupancyGadget.KIND_BASTION_UNIT_HEAVY
		BastionPrototypeCatalog.UNIT_SWARM:
			return OccupancyGadget.KIND_BASTION_UNIT_SWARM
		_:
			return ""


static func kind_for_obstacle(prototype_id: int) -> String:
	match prototype_id:
		BastionPrototypeCatalog.OBSTACLE_BARRICADE:
			return OccupancyGadget.KIND_BASTION_OBSTACLE_BARRICADE
		BastionPrototypeCatalog.OBSTACLE_SLOW_TILE:
			return OccupancyGadget.KIND_BASTION_OBSTACLE_SLOW
		BastionPrototypeCatalog.OBSTACLE_DIVERTER:
			return OccupancyGadget.KIND_BASTION_OBSTACLE_DIVERTER
		_:
			return ""


static func fill_core(gadget: Node3D, albedo: Color) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Keep",
		OccupancyGadget._box(Vector3(0.72, 0.85, 0.72)),
		albedo,
		Vector3(0.0, 0.05, 0.0)
	)
	OccupancyGadget._mesh(
		gadget,
		"Heart",
		OccupancyGadget._box(Vector3(0.28, 0.28, 0.28)),
		PlaceholderSpec.BASTION_SELECTED_ALBEDO,
		Vector3(0.0, 0.22, 0.0)
	)


static func fill_slot(gadget: Node3D, albedo: Color) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Pad",
		OccupancyGadget._box(Vector3(0.82, 0.1, 0.82)),
		albedo,
		Vector3(0.0, -0.4, 0.0)
	)


static func fill_tower(gadget: Node3D, albedo: Color) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Stem",
		OccupancyGadget._box(Vector3(0.18, 0.7, 0.18)),
		albedo,
		Vector3(0.0, 0.0, 0.0)
	)
	OccupancyGadget._mesh(
		gadget,
		"Head",
		OccupancyGadget._box(Vector3(0.42, 0.22, 0.42)),
		albedo.lightened(0.18),
		Vector3(0.0, 0.38, 0.0)
	)


static func fill_unit(gadget: Node3D, albedo: Color, size: Vector3) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Body",
		OccupancyGadget._box(size),
		albedo,
		Vector3(0.0, size.y * 0.15, 0.0)
	)


static func fill_barricade(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Slab",
		OccupancyGadget._box(Vector3(0.92, 0.62, 0.22)),
		PlaceholderSpec.BASTION_OBSTACLE_BARRICADE_ALBEDO,
		Vector3(0.0, -0.05, 0.0)
	)


static func fill_slow(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Sheet",
		OccupancyGadget._box(Vector3(0.9, 0.08, 0.9)),
		PlaceholderSpec.BASTION_OBSTACLE_SLOW_ALBEDO,
		Vector3(0.0, -0.4, 0.0),
		true
	)


static func fill_diverter(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Post",
		OccupancyGadget._box(Vector3(0.16, 0.7, 0.16)),
		PlaceholderSpec.BASTION_OBSTACLE_DIVERTER_ALBEDO,
		Vector3(0.0, 0.0, 0.0)
	)
	OccupancyGadget._mesh(
		gadget,
		"Arm",
		OccupancyGadget._box(Vector3(0.55, 0.12, 0.12)),
		PlaceholderSpec.BASTION_OBSTACLE_DIVERTER_ALBEDO.lightened(0.2),
		Vector3(0.18, 0.12, 0.0)
	)


static func fill_path(gadget: Node3D) -> void:
	OccupancyGadget._mesh(
		gadget,
		"Mark",
		OccupancyGadget._box(Vector3(0.22, 0.08, 0.22)),
		PlaceholderSpec.BASTION_PATH_ALBEDO,
		Vector3(0.0, -0.42, 0.0),
		true
	)
